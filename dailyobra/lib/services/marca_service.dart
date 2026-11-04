import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// A marca do engenheiro nos documentos. Cada um mexe só na sua; quem está na obra lê a do
/// responsável, para o PDF sair igual para todos.
class MarcaService {
  MarcaService._();

  static final instance = MarcaService._();

  /// O bucket marcas recusa acima disso.
  static const tamanhoMaximo = 2 * 1024 * 1024;
  static const _balde = 'marcas';
  static const _falha =
      'Não foi possível salvar a marca. Verifique a conexão e tente de novo.';

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  MarcaEngenheiro _minha = const MarcaEngenheiro();
  MarcaEngenheiro? _daObra;
  Uint8List? _logo;

  @visibleForTesting
  final salvasDeTeste = <MarcaEngenheiro>[];
  @visibleForTesting
  final logosApagadosDeTeste = <String>[];

  @visibleForTesting
  void definirParaTeste({
    MarcaEngenheiro minha = const MarcaEngenheiro(),
    MarcaEngenheiro? daObra,
    Uint8List? logo,
    String? erro,
  }) {
    _teste = true;
    _minha = minha;
    _daObra = daObra;
    _logo = logo;
    _erro = erro;
    salvasDeTeste.clear();
    logosApagadosDeTeste.clear();
  }

  Future<MarcaEngenheiro> minha() async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      return _minha;
    }
    try {
      final r = await _db
          .from('construtor_marca')
          .select()
          .eq('user_id', _db.auth.currentUser!.id)
          .maybeSingle();
      return r == null ? const MarcaEngenheiro() : MarcaEngenheiro.fromJson(r);
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível carregar a marca. Verifique a conexão e tente de novo.',
      );
    }
  }

  Future<void> salvar(MarcaEngenheiro marca) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      salvasDeTeste.add(marca);
      _minha = marca;
      return;
    }
    try {
      await _db.from('construtor_marca').upsert({
        'user_id': _db.auth.currentUser!.id,
        ...marca.paraSalvar(),
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      throw const FalhaAoSalvar(_falha);
    }
  }

  /// A primeira parte do caminho é a conta: é por ela que o banco confere quem pode enviar.
  Future<String> enviarLogo(Uint8List bytes, String nome) async {
    final minusculo = nome.toLowerCase();
    final (extensao, tipo) = minusculo.endsWith('.png')
        ? ('png', 'image/png')
        : minusculo.endsWith('.webp')
        ? ('webp', 'image/webp')
        : ('jpg', 'image/jpeg');
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      return 'eu/logo.$extensao';
    }
    final caminho =
        '${_db.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.$extensao';
    try {
      await _db.storage
          .from(_balde)
          .uploadBinary(
            caminho,
            bytes,
            fileOptions: FileOptions(contentType: tipo),
          );
      return caminho;
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível enviar a logo. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// Logo trocada ou tirada. Falhar aqui só deixa um arquivo sobrando.
  Future<void> apagarLogo(String caminho) async {
    if (_teste) {
      logosApagadosDeTeste.add(caminho);
      return;
    }
    try {
      await _db.storage.from(_balde).remove([caminho]);
    } catch (_) {}
  }

  /// Link de 1 hora para mostrar a logo: o bucket é privado.
  Future<String?> linkDoLogo(String caminho) async {
    if (_teste) return null;
    try {
      return await _db.storage.from(_balde).createSignedUrl(caminho, 3600);
    } catch (_) {
      return null;
    }
  }

  /// Sem a marca o documento sai do mesmo jeito, só sem o cabeçalho dela.
  Future<MarcaEngenheiro?> daObra(String obraId) async {
    if (_teste) return _daObra;
    try {
      final r = await _db.rpc<List<dynamic>>(
        'marca_da_obra',
        params: {'p_obra': obraId},
      );
      return r.isEmpty
          ? null
          : MarcaEngenheiro.fromJson(Map<String, dynamic>.from(r.first as Map));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> logoBytes(String? caminho) async {
    if (_teste) return _logo;
    if (caminho == null) return null;
    try {
      return await _db.storage.from(_balde).download(caminho);
    } catch (_) {
      return null;
    }
  }
}
