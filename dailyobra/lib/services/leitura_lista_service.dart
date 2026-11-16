import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'catalogo_service.dart';
import 'leitura_no_aparelho_io.dart'
    if (dart.library.js_interop) 'leitura_no_aparelho_web.dart';

/// Arquivo escolhido pelo construtor para ler a lista de materiais.
class ArquivoLista {
  const ArquivoLista(this.nome, this.tipo, this.bytes);
  final String nome;
  final String tipo;
  final Uint8List bytes;
}

const _tipos = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

const _maxBytes = 10 * 1024 * 1024;

/// Tipo do arquivo pela extensão; null quando a leitura não aceita esse arquivo.
String? tipoDoArquivo(String nome) {
  final ponto = nome.lastIndexOf('.');
  if (ponto < 0) return null;
  return _tipos[nome.substring(ponto + 1).toLowerCase()];
}

/// Lê a lista de materiais de um PDF ou foto no próprio aparelho (nada vai para serviço de fora) e fica só com
/// as linhas que são produtos do catálogo das lojas, uma por material, no formato da lista inteligente.
class LeituraListaService {
  LeituraListaService._();

  static final instance = LeituraListaService._();

  Future<ArquivoLista?> Function() _escolher = _escolherNoAparelho;
  Future<String> Function(ArquivoLista) _ler = _lerNoAparelho;

  @visibleForTesting
  void definirParaTeste({
    Future<ArquivoLista?> Function()? escolher,
    Future<String> Function(ArquivoLista)? ler,
  }) {
    _escolher = escolher ?? _escolherNoAparelho;
    _ler = ler ?? _lerNoAparelho;
  }

  /// Abre o seletor de arquivos; null quando a pessoa desiste.
  Future<ArquivoLista?> escolher() => _escolher();

  /// Texto da lista, um material por linha. Falhas chegam como [FalhaComMensagem].
  Future<String> ler(ArquivoLista arquivo) => _ler(arquivo);

  static Future<ArquivoLista?> _escolherNoAparelho() async {
    final arquivo = await FilePicker.pickFile(
      dialogTitle: 'Arquivo com a lista de materiais',
      type: FileType.custom,
      allowedExtensions: _tipos.keys.toList(),
    );
    if (arquivo == null) return null;
    final tipo = tipoDoArquivo(arquivo.name);
    if (tipo == null) {
      throw const FalhaComMensagem('Envie um arquivo PDF, JPG, PNG ou WEBP.');
    }
    final tamanho = await arquivo.length();
    if (tamanho != null && tamanho > _maxBytes) {
      throw const FalhaComMensagem(
        'O arquivo passa de 10 MB. Envie um menor ou tire uma foto só da lista.',
      );
    }
    return ArquivoLista(arquivo.name, tipo, await arquivo.readAsBytes());
  }

  static Future<String> _lerNoAparelho(ArquivoLista arquivo) async {
    final lido = await lerNoAparelho(arquivo.bytes, arquivo.tipo);
    final texto = materiaisDoTexto(lido, CatalogoService.instance.itens);
    if (texto.trim().isEmpty) {
      throw const FalhaComMensagem(
        'Não encontramos neste arquivo materiais do catálogo das lojas. Tente uma foto mais nítida ou cole o texto da lista.',
      );
    }
    return texto;
  }
}
