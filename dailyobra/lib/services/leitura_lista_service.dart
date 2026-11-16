import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'catalogo_service.dart';
import 'leitura_no_aparelho_io.dart'
    if (dart.library.js_interop) 'leitura_no_aparelho_web.dart';

/// Arquivo escolhido pelo construtor para ler a lista de materiais.
class ArquivoLista {
  const ArquivoLista(this.nome, this.tipo, this.bytes);
  final String nome;
  final String tipo;
  final Uint8List bytes;

  bool get ehFoto => tipo.startsWith('image/');
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

  Future<List<ArquivoLista>> Function() _escolher = _escolherNoAparelho;
  Future<ArquivoLista?> Function() _tirarFoto = _tirarFotoNoAparelho;
  Future<String> Function(ArquivoLista) _ler = _lerNoAparelho;

  @visibleForTesting
  void definirParaTeste({
    Future<List<ArquivoLista>> Function()? escolher,
    Future<ArquivoLista?> Function()? tirarFoto,
    Future<String> Function(ArquivoLista)? ler,
  }) {
    _escolher = escolher ?? _escolherNoAparelho;
    _tirarFoto = tirarFoto ?? _tirarFotoNoAparelho;
    _ler = ler ?? _lerNoAparelho;
  }

  /// Abre o seletor de arquivos (um ou vários); lista vazia quando a pessoa desiste.
  Future<List<ArquivoLista>> escolher() => _escolher();

  /// Abre a câmera do aparelho direto, sem passar pela galeria; null quando a pessoa desiste.
  Future<ArquivoLista?> tirarFoto() => _tirarFoto();

  /// Texto da lista, um material por linha. Falhas chegam como [FalhaComMensagem].
  Future<String> ler(ArquivoLista arquivo) => _ler(arquivo);

  static Future<List<ArquivoLista>> _escolherNoAparelho() async {
    final arquivos = await FilePicker.pickFiles(
      dialogTitle: 'Arquivos com a lista de materiais',
      type: FileType.custom,
      allowedExtensions: _tipos.keys.toList(),
    );
    final lidos = <ArquivoLista>[];
    for (final arquivo in arquivos) {
      final tipo = tipoDoArquivo(arquivo.name);
      if (tipo == null) {
        throw const FalhaComMensagem('Envie arquivos PDF, JPG, PNG ou WEBP.');
      }
      final tamanho = await arquivo.length();
      if (tamanho != null && tamanho > _maxBytes) {
        throw FalhaComMensagem(
          '${arquivo.name} passa de 10 MB. Envie um menor ou tire uma foto só da lista.',
        );
      }
      lidos.add(ArquivoLista(arquivo.name, tipo, await arquivo.readAsBytes()));
    }
    return lidos;
  }

  static Future<ArquivoLista?> _tirarFotoNoAparelho() async {
    // 3000 px no lado maior já sobra para ler a letra e não pesa no celular
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 3000,
      maxHeight: 3000,
      imageQuality: 92,
    );
    if (foto == null) return null;
    final tipo = foto.mimeType ?? tipoDoArquivo(foto.name) ?? 'image/jpeg';
    return ArquivoLista('Foto da lista', tipo, await foto.readAsBytes());
  }

  static Future<String> _lerNoAparelho(ArquivoLista arquivo) async {
    final lido = await lerNoAparelho(arquivo.bytes, arquivo.tipo);
    final texto = materiaisDoTexto(lido, CatalogoService.instance.itens);
    if (texto.trim().isEmpty) {
      throw FalhaComMensagem(
        arquivo.ehFoto
            ? 'Não achamos materiais do catálogo nesta foto. Tire de novo mais perto, com boa luz e a folha reta, ou digite a lista.'
            : 'Não achamos materiais do catálogo em ${arquivo.nome}. Envie uma foto da lista ou digite.',
      );
    }
    return texto;
  }
}
