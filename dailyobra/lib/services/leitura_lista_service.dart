import 'dart:convert';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Lê a lista de materiais de um PDF ou foto pela função `ler-lista` do Supabase, que devolve
/// uma linha por material no formato da lista inteligente.
class LeituraListaService {
  LeituraListaService._();

  static final instance = LeituraListaService._();

  Future<ArquivoLista?> Function() _escolher = _escolherNoAparelho;
  Future<String> Function(ArquivoLista) _ler = _lerNoServidor;

  @visibleForTesting
  void definirParaTeste({
    Future<ArquivoLista?> Function()? escolher,
    Future<String> Function(ArquivoLista)? ler,
  }) {
    _escolher = escolher ?? _escolherNoAparelho;
    _ler = ler ?? _lerNoServidor;
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

  static Future<String> _lerNoServidor(ArquivoLista arquivo) async {
    try {
      final resposta = await Supabase.instance.client.functions.invoke(
        'ler-lista',
        body: {
          'nome': arquivo.nome,
          'tipo': arquivo.tipo,
          'base64': base64Encode(arquivo.bytes),
        },
      );
      final dados = resposta.data;
      final texto = dados is Map ? dados['texto'] as String? : null;
      if (texto == null || texto.trim().isEmpty) {
        throw const FalhaComMensagem(
          'Não encontramos materiais de construção neste arquivo.',
        );
      }
      return texto;
    } on FunctionException catch (e) {
      final detalhes = e.details;
      final erro = detalhes is Map ? detalhes['erro'] as String? : null;
      throw FalhaComMensagem(
        erro ?? 'Não deu para ler o arquivo agora. Tente de novo.',
      );
    } on FalhaComMensagem {
      rethrow;
    } catch (e) {
      throw FalhaComMensagem(mensagemDoServidor(e));
    }
  }
}
