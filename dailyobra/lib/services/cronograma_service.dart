import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// Grava as datas das etapas. Quem pode é o banco que decide: responsável e mestre.
class CronogramaService {
  CronogramaService._();

  static final instance = CronogramaService._();

  static const _falha =
      'Não foi possível salvar o cronograma. Verifique a conexão e tente de novo.';

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;

  /// O que [salvar] mandaria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  final salvosDeTeste = <(Map<EtapaId, DatasEtapa>, bool)>[];

  @visibleForTesting
  void definirParaTeste({String? erro}) {
    _teste = true;
    _erro = erro;
    salvosDeTeste.clear();
  }

  /// Sem [comReal], as datas reais que estão no banco ficam como estão.
  Future<void> salvar(
    String obraId,
    Map<EtapaId, DatasEtapa> datas, {
    bool comReal = true,
  }) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      salvosDeTeste.add((datas, comReal));
      return;
    }
    try {
      await _db.rpc<void>(
        'salvar_cronograma',
        params: {
          'p_obra': obraId,
          'p_etapas': [
            for (final e in datas.entries)
              e.value.paraSalvar(e.key, comReal: comReal),
          ],
        },
      );
    } on PostgrestException catch (e) {
      throw FalhaAoSalvar(e.code == 'P0001' ? e.message : _falha);
    } catch (_) {
      throw const FalhaAoSalvar(_falha);
    }
    await ObrasService.instance.carregar();
  }
}
