import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// No Android a leitura roda num WebView escondido com a mesma pasta web/leitura do site (PDF.js e Tesseract),
/// guardada dentro do APK e aberta pelo endereço reservado do Android para arquivos do app: nada vai para a rede.
const _pagina =
    'https://appassets.androidplatform.net/assets/flutter_assets/web/leitura/pagina.html';

const _naoLeu =
    'Não deu para ler este arquivo. Tente uma foto mais nítida ou digite a lista.';

HeadlessInAppWebView? _webview;
Future<InAppWebViewController>? _pronto;

Future<InAppWebViewController> _abrirLeitor() {
  final carregou = Completer<InAppWebViewController>();
  final webview = HeadlessInAppWebView(
    initialUrlRequest: URLRequest(url: WebUri(_pagina)),
    initialSettings: InAppWebViewSettings(
      javaScriptEnabled: true,
      allowFileAccess: false,
      allowContentAccess: false,
      webViewAssetLoader: WebViewAssetLoader(
        pathHandlers: [AssetsPathHandler(path: '/assets/')],
      ),
    ),
    onLoadStop: (controller, _) {
      if (!carregou.isCompleted) carregou.complete(controller);
    },
    onReceivedError: (_, pedido, erro) {
      if ((pedido.isForMainFrame ?? true) && !carregou.isCompleted) {
        carregou.completeError(StateError(erro.description));
      }
    },
  );
  _webview = webview;
  webview.run();
  return carregou.future.timeout(const Duration(seconds: 30));
}

/// Uma página só para o app todo: o Tesseract carregado uma vez lê as fotos seguintes mais rápido.
Future<InAppWebViewController> _leitor() async {
  try {
    return await (_pronto ??= _abrirLeitor());
  } catch (_) {
    _pronto = null;
    final w = _webview;
    _webview = null;
    await w?.dispose();
    rethrow;
  }
}

/// Texto do PDF ou da foto, lido no próprio celular.
Future<String> lerNoAparelho(Uint8List bytes, String tipo) async {
  if (!Platform.isAndroid) {
    throw const FalhaComMensagem(
      'Neste aparelho a leitura de foto e PDF ainda não funciona. Abra o DailyObra pelo navegador ou digite a lista.',
    );
  }
  final InAppWebViewController leitor;
  try {
    leitor = await _leitor();
  } catch (_) {
    throw const FalhaComMensagem(
      'Não deu para abrir a leitura neste celular. Feche e abra o app de novo ou digite a lista.',
    );
  }
  final CallAsyncJavaScriptResult? r;
  try {
    r = await leitor.callAsyncJavaScript(
      functionBody: '''
        const bin = atob(dados);
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        return await window.dailyobraLerArquivo(bytes, tipo);
      ''',
      arguments: {'dados': base64Encode(bytes), 'tipo': tipo},
    );
  } catch (_) {
    throw const FalhaComMensagem(_naoLeu);
  }
  final erro = r?.error;
  if (r == null || erro != null) {
    final paginas = erro == null
        ? null
        : RegExp(r'O PDF passa de \d+ páginas\.[^"]*').firstMatch(erro);
    throw FalhaComMensagem(paginas?.group(0)?.trim() ?? _naoLeu);
  }
  return r.value is String ? r.value as String : '';
}
