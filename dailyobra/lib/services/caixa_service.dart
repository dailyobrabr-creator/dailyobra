import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dinheiro_service.dart';
import 'mao_de_obra_service.dart';
import 'obras_service.dart';

class DadosCaixa {
  const DadosCaixa({required this.previsao, required this.entradas});
  final PrevisaoCaixa previsao;
  final List<EntradaCaixa> entradas;
}

/// Entradas de dinheiro da obra e a previsão das próximas semanas. Só o responsável entra aqui.
class CaixaService {
  CaixaService._();

  static final instance = CaixaService._();

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<EntradaCaixa> _entradas = const [];

  @visibleForTesting
  final salvasDeTeste = <EntradaCaixa>[];
  @visibleForTesting
  final excluidasDeTeste = <String>[];

  @visibleForTesting
  void definirParaTeste({
    List<EntradaCaixa> entradas = const [],
    String? erro,
  }) {
    _teste = true;
    _erro = erro;
    _entradas = [...entradas];
    salvasDeTeste.clear();
    excluidasDeTeste.clear();
  }

  Future<List<EntradaCaixa>> entradas(String obraId) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      return [..._entradas]..sort((a, b) => a.data.compareTo(b.data));
    }
    try {
      final r = await _db
          .from('obra_entradas')
          .select()
          .eq('obra_id', obraId)
          .order('data');
      return [for (final j in r) EntradaCaixa.fromJson(j)];
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível carregar as entradas. Verifique a conexão e tente de novo.',
      );
    }
  }

  Future<void> salvar(String obraId, EntradaCaixa e) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      salvasDeTeste.add(e);
      final id = e.id ?? 'nova-${salvasDeTeste.length}';
      _entradas = [
        for (final x in _entradas)
          if (x.id != id) x,
        EntradaCaixa(
          id: id,
          descricao: e.descricao,
          valor: e.valor,
          data: e.data,
          recebido: e.recebido,
        ),
      ];
      return;
    }
    try {
      final id = e.id;
      if (id == null) {
        await _db.from('obra_entradas').insert({
          'obra_id': obraId,
          ...e.paraSalvar(),
        });
      } else {
        await _db.from('obra_entradas').update(e.paraSalvar()).eq('id', id);
      }
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível salvar a entrada. Verifique a conexão e tente de novo.',
      );
    }
  }

  Future<void> excluir(String id) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      excluidasDeTeste.add(id);
      _entradas = [
        for (final x in _entradas)
          if (x.id != id) x,
      ];
      return;
    }
    try {
      await _db.from('obra_entradas').delete().eq('id', id);
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível excluir a entrada. Tente de novo.',
      );
    }
  }

  /// Junta tudo o que a previsão precisa. Sem a mão de obra, a previsão sai sem ela.
  Future<DadosCaixa> carregar(Obra obra, DateTime hoje) async {
    final maoDeObra = MaoDeObraService.instance;
    final dinheiro = await DinheiroService.instance.carregar(obra.id);
    final lista = await entradas(obra.id);
    var diarias = 0.0;
    var contratos = const <ResumoContrato>[];
    try {
      diarias = totalEmAberto(
        diariasEmAberto(
          await maoDeObra.diaristas(obra.id),
          await maoDeObra.presencas(obra.id),
        ),
      );
      contratos = await maoDeObra.contratos(obra.id);
    } on FalhaAoSalvar {
      // A previsão fica menor, mas a tela continua útil
    }
    return DadosCaixa(
      entradas: lista,
      previsao: preverCaixa(
        hoje: hoje,
        resumo: resumoDaObra(obra, dinheiro),
        datas: obra.cronograma,
        status: obra.statusEtapas,
        entradas: lista,
        diariasAbertas: diarias,
        contratos: contratos,
      ),
    );
  }
}
