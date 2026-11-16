import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';

/// web/leitura/leitura.js: PDF.js e Tesseract hospedados no próprio site.
@JS()
external JSPromise<JSString> dailyobraLerArquivo(
  JSUint8Array bytes,
  JSString tipo,
);

/// Texto do PDF ou da foto, lido no navegador. Nada sai do aparelho.
Future<String> lerNoAparelho(Uint8List bytes, String tipo) async {
  try {
    final texto = await dailyobraLerArquivo(bytes.toJS, tipo.toJS).toDart;
    return texto.toDart;
  } catch (e) {
    final erro = e.toString();
    final paginas = RegExp(r'O PDF passa de \d+ páginas\.[^"]*')
        .firstMatch(erro);
    throw FalhaComMensagem(
      paginas?.group(0)?.trim() ?? 'Não deu para ler este arquivo. Tente uma foto mais nítida ou cole o texto da lista.',
    );
  }
}
