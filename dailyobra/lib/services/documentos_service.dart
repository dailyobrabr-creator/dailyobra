import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// Documentos da obra. O banco devolve só o que a pessoa pode ver, e o arquivo segue a mesma regra.
class DocumentosService {
  DocumentosService._();

  static final instance = DocumentosService._();

  /// O bucket obra-documentos recusa acima disso.
  static const tamanhoMaximo = 20 * 1024 * 1024;
  static const extensoes = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];
  static const _balde = 'obra-documentos';

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<Documento> _documentos = const [];

  @visibleForTesting
  final salvosDeTeste = <Documento>[];
  @visibleForTesting
  final excluidosDeTeste = <String>[];
  @visibleForTesting
  final enviadosDeTeste = <String>[];
  @visibleForTesting
  final apagadosDeTeste = <String>[];

  @visibleForTesting
  void definirParaTeste({List<Documento> documentos = const [], String? erro}) {
    _teste = true;
    _erro = erro;
    _documentos = [...documentos];
    salvosDeTeste.clear();
    excluidosDeTeste.clear();
    enviadosDeTeste.clear();
    apagadosDeTeste.clear();
  }

  /// Em teste não há banco: [emTeste] faz o papel dele, e o erro combinado vale para tudo.
  Future<T> _executar<T>(
    Future<T> Function() noBanco,
    T Function() emTeste,
    String falha,
  ) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      return emTeste();
    }
    try {
      return await noBanco();
    } on PostgrestException catch (e) {
      throw FalhaAoSalvar(e.code == 'P0001' ? e.message : falha);
    } catch (_) {
      throw FalhaAoSalvar(falha);
    }
  }

  Future<List<Documento>> listar(String obraId) => _executar(
    () async {
      final r = await _db.rpc<List<dynamic>>(
        'documentos_da_obra',
        params: {'p_obra': obraId},
      );
      return [
        for (final d in r)
          Documento.fromJson(Map<String, dynamic>.from(d as Map)),
      ];
    },
    () => [..._documentos],
    'Não foi possível carregar os documentos. Verifique a conexão e tente de novo.',
  );

  Future<String> salvar(String obraId, Documento d) => _executar(
    () => _db.rpc<String>(
      'salvar_documento',
      params: {'p_obra': obraId, 'p_id': d.id, 'p_dados': d.paraSalvar()},
    ),
    () {
      salvosDeTeste.add(d);
      final id = d.id ?? 'novo-${salvosDeTeste.length}';
      _documentos = [
        for (final x in _documentos)
          if (x.id != id) x,
        Documento(
          id: id,
          tipo: d.tipo,
          titulo: d.titulo,
          numero: d.numero,
          validade: d.validade,
          caminho: d.caminho,
          nomeArquivo: d.nomeArquivo,
          acesso: d.acesso,
        ),
      ];
      return id;
    },
    'Não foi possível salvar o documento. Verifique a conexão e tente de novo.',
  );

  /// Tira o documento e o arquivo dele.
  Future<void> excluir(String id) async {
    final caminho = await _executar(
      () => _db.rpc<String?>('excluir_documento', params: {'p_id': id}),
      () {
        excluidosDeTeste.add(id);
        final d = _documentos.where((x) => x.id == id).firstOrNull;
        _documentos = [
          for (final x in _documentos)
            if (x.id != id) x,
        ];
        return d?.caminho;
      },
      'Não foi possível excluir o documento. Tente de novo.',
    );
    if (caminho != null) await apagarArquivo(caminho);
  }

  static String _tipoDe(String extensao) => switch (extensao) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  /// A primeira parte do caminho é a obra: é por ela que o banco confere quem pode enviar.
  Future<String> enviar({
    required String obraId,
    required Uint8List bytes,
    required String nome,
  }) async {
    final extensao = nome.toLowerCase().split('.').last;
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      enviadosDeTeste.add(nome);
      return '$obraId/${enviadosDeTeste.length}.$extensao';
    }
    final caminho =
        '$obraId/${DateTime.now().microsecondsSinceEpoch}.$extensao';
    try {
      await _db.storage
          .from(_balde)
          .uploadBinary(
            caminho,
            bytes,
            fileOptions: FileOptions(contentType: _tipoDe(extensao)),
          );
      return caminho;
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível enviar o arquivo. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// Arquivo trocado. Falhar aqui só deixa um arquivo sobrando.
  Future<void> apagarArquivo(String caminho) async {
    if (_teste) {
      apagadosDeTeste.add(caminho);
      return;
    }
    try {
      await _db.storage.from(_balde).remove([caminho]);
    } catch (_) {}
  }

  /// Link de 1 hora: o bucket é privado.
  Future<String?> link(String caminho) async {
    if (_teste) return 'https://teste.invalid/$caminho';
    try {
      return await _db.storage.from(_balde).createSignedUrl(caminho, 3600);
    } catch (_) {
      return null;
    }
  }
}
