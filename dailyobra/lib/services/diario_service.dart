import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// Lê e grava o diário de obra. Gravar passa pela função salvar_dia_obra do banco, que confere
/// quem pode e troca o dia inteiro de uma vez.
class DiarioService {
  DiarioService._();

  static final instance = DiarioService._();

  /// O bucket rdo-fotos recusa acima disso.
  static const tamanhoMaximo = 5 * 1024 * 1024;
  static const fotosPorDia = 10;

  static const _balde = 'rdo-fotos';
  static const _campos =
      '*, rdo_efetivo(*), rdo_atividades(*), rdo_ocorrencias(*), rdo_materiais(*), rdo_equipamentos(*), rdo_fotos(*)';
  static const _semConexao =
      'Não foi possível carregar o diário. Verifique a conexão e tente de novo.';

  SupabaseClient get _db => Supabase.instance.client;

  List<DiaObra>? _teste;
  var _fotosDeTeste = 0;

  /// O que [salvar] mandaria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  final salvosDeTeste = <(DiaObra, bool)>[];

  @visibleForTesting
  final reabertosDeTeste = <String>[];

  @visibleForTesting
  void definirParaTeste({List<DiaObra> dias = const []}) {
    _teste = [...dias];
    _fotosDeTeste = 0;
    salvosDeTeste.clear();
    reabertosDeTeste.clear();
  }

  /// Todos os dias da obra, do mais novo para o mais antigo.
  Future<List<DiaObra>> listar(String obraId) async {
    final teste = _teste;
    if (teste != null) {
      return [
        for (final d in teste)
          if (d.obraId == obraId) d,
      ]..sort((a, b) => b.data.compareTo(a.data));
    }
    try {
      final r = await _db
          .from('rdos')
          .select(_campos)
          .eq('obra_id', obraId)
          .order('data', ascending: false);
      return [for (final j in r) DiaObra.fromJson(j)];
    } catch (_) {
      throw const FalhaAoSalvar(_semConexao);
    }
  }

  Future<DiaObra?> doDia(String obraId, DateTime data) async {
    final teste = _teste;
    if (teste != null) {
      return teste
          .where((d) => d.obraId == obraId && mesmoDia(d.data, data))
          .firstOrNull;
    }
    try {
      final r = await _db
          .from('rdos')
          .select(_campos)
          .eq('obra_id', obraId)
          .eq('data', dataIso(data))
          .maybeSingle();
      return r == null ? null : DiaObra.fromJson(r);
    } catch (_) {
      throw const FalhaAoSalvar(_semConexao);
    }
  }

  /// O último dia antes de [antesDe] com equipe anotada, para o botão "Repetir equipe".
  Future<DiaObra?> ultimoComEquipe(
    String obraId, {
    required DateTime antesDe,
  }) async {
    final teste = _teste;
    if (teste != null) {
      final dias = await listar(obraId);
      return dias
          .where((d) => d.data.isBefore(antesDe) && d.equipe.isNotEmpty)
          .firstOrNull;
    }
    try {
      final r = await _db
          .from('rdos')
          .select(_campos)
          .eq('obra_id', obraId)
          .lt('data', dataIso(antesDe))
          .order('data', ascending: false)
          .limit(15);
      return r
          .map(DiaObra.fromJson)
          .where((d) => d.equipe.isNotEmpty)
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<DiaObra> salvar(DiaObra dia, {bool finalizar = false}) async {
    final situacao = finalizar ? SituacaoDia.finalizado : SituacaoDia.rascunho;
    final teste = _teste;
    if (teste != null) {
      salvosDeTeste.add((dia, finalizar));
      final salvo = dia.copyWith(id: dia.id ?? 'novo', situacao: situacao);
      _teste = [
        for (final d in teste)
          if (!mesmoDia(d.data, dia.data)) d,
        salvo,
      ];
      return salvo;
    }
    try {
      final id = await _db.rpc<String>(
        'salvar_dia_obra',
        params: {
          'p_obra': dia.obraId,
          'p_data': dataIso(dia.data),
          'p_dados': dia.paraSalvar(),
          'p_finalizar': finalizar,
        },
      );
      return dia.copyWith(id: id, situacao: situacao);
    } on PostgrestException catch (e) {
      throw FalhaAoSalvar(
        e.code == 'P0001' ? e.message : 'Não foi possível salvar o dia. Verifique a conexão e tente de novo.',
      );
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível salvar o dia. Verifique a conexão e tente de novo.',
      );
    }
  }

  Future<void> reabrir(String id) async {
    if (_teste != null) {
      reabertosDeTeste.add(id);
      return;
    }
    try {
      await _db.rpc<void>('reabrir_dia_obra', params: {'p_rdo': id});
    } on PostgrestException catch (e) {
      throw FalhaAoSalvar(
        e.code == 'P0001'
            ? e.message
            : 'Não foi possível reabrir o dia. Tente de novo.',
      );
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível reabrir o dia. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// Sobe a foto e devolve o caminho dela no bucket. A primeira parte do caminho é a obra:
  /// é por ela que o banco confere quem pode enviar.
  Future<String> enviarFoto({
    required String obraId,
    required DateTime data,
    required Uint8List bytes,
    required String nome,
  }) async {
    final minusculo = nome.toLowerCase();
    final (extensao, tipo) = minusculo.endsWith('.png')
        ? ('png', 'image/png')
        : minusculo.endsWith('.webp')
        ? ('webp', 'image/webp')
        : ('jpg', 'image/jpeg');
    if (_teste != null) {
      return '$obraId/${dataIso(data)}/${_fotosDeTeste++}.$extensao';
    }
    final arquivo = '${DateTime.now().microsecondsSinceEpoch}.$extensao';
    final caminho = '$obraId/${dataIso(data)}/$arquivo';
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
        'Não foi possível enviar a foto. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// Foto tirada do dia. Falhar aqui só deixa um arquivo sobrando, o dia já foi salvo.
  Future<void> apagarFotos(List<String> caminhos) async {
    if (_teste != null || caminhos.isEmpty) return;
    try {
      await _db.storage.from(_balde).remove(caminhos);
    } catch (_) {}
  }

  /// Links de 1 hora para mostrar as fotos: o bucket é privado.
  Future<Map<String, String>> linksDasFotos(List<String> caminhos) async {
    if (_teste != null || caminhos.isEmpty) return const {};
    try {
      final r = await _db.storage
          .from(_balde)
          .createSignedUrlsResult(caminhos, 3600);
      return {
        for (final l in r)
          if (l is SignedUrlSuccess) l.path: l.signedUrl,
      };
    } catch (_) {
      return const {};
    }
  }

  /// As fotos do dia para o PDF. Uma que não baixar fica de fora, sem impedir o documento.
  Future<Map<String, Uint8List>> bytesDasFotos(DiaObra dia) =>
      bytesDe(dia.fotos);

  Future<Map<String, Uint8List>> bytesDe(List<FotoDia> fotos) async {
    if (_teste != null) return const {};
    final baixadas = await Future.wait([
      for (final f in fotos)
        _db.storage
            .from(_balde)
            .download(f.caminho)
            .then<(String, Uint8List)?>((b) => (f.caminho, b))
            .catchError((Object _) => null),
    ]);
    return {
      for (final b in baixadas)
        if (b != null) b.$1: b.$2,
    };
  }
}
