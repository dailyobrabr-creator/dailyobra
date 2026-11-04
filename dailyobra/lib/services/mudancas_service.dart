import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// Mudanças da obra. Tudo passa por funções do banco: é ele que garante que só o cliente responde
/// e que uma resposta não muda depois.
class MudancasService {
  MudancasService._();

  static final instance = MudancasService._();

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<Mudanca> _mudancas = const [];

  @visibleForTesting
  final salvasDeTeste = <Mudanca>[];
  @visibleForTesting
  final excluidasDeTeste = <String>[];
  @visibleForTesting
  final respostasDeTeste = <(String, bool, String?)>[];

  @visibleForTesting
  void definirParaTeste({List<Mudanca> mudancas = const [], String? erro}) {
    _teste = true;
    _mudancas = [...mudancas];
    _erro = erro;
    salvasDeTeste.clear();
    excluidasDeTeste.clear();
    respostasDeTeste.clear();
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

  Future<List<Mudanca>> listar(String obraId) => _executar(
    () async {
      final r = await _db.rpc<List<dynamic>>(
        'mudancas_da_obra',
        params: {'p_obra': obraId},
      );
      return [
        for (final m in r)
          Mudanca.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    },
    () => [..._mudancas],
    'Não foi possível carregar as mudanças. Verifique a conexão e tente de novo.',
  );

  /// Devolve o id da mudança.
  Future<String> salvar(String obraId, Mudanca m) => _executar(
    () => _db.rpc<String>(
      'salvar_mudanca',
      params: {'p_obra': obraId, 'p_id': m.id, 'p_dados': m.paraSalvar()},
    ),
    () {
      salvasDeTeste.add(m);
      final id = m.id ?? 'nova-${salvasDeTeste.length}';
      _mudancas = [
        Mudanca(
          id: id,
          titulo: m.titulo,
          descricao: m.descricao,
          valor: m.valor,
          dias: m.dias,
        ),
        for (final x in _mudancas)
          if (x.id != id) x,
      ];
      return id;
    },
    'Não foi possível salvar a mudança. Verifique a conexão e tente de novo.',
  );

  Future<void> excluir(String id) => _executar(
    () => _db.rpc<void>('excluir_mudanca', params: {'p_id': id}),
    () {
      excluidasDeTeste.add(id);
      _mudancas = [
        for (final x in _mudancas)
          if (x.id != id) x,
      ];
    },
    'Não foi possível excluir a mudança. Tente de novo.',
  );

  Future<void> responder(
    String id, {
    required bool aprovar,
    String? resposta,
  }) => _executar(
    () => _db.rpc<void>(
      'responder_mudanca',
      params: {'p_id': id, 'p_aprovar': aprovar, 'p_resposta': resposta},
    ),
    () {
      respostasDeTeste.add((id, aprovar, resposta));
      _mudancas = [
        for (final x in _mudancas)
          x.id == id
              ? Mudanca(
                  id: x.id,
                  titulo: x.titulo,
                  descricao: x.descricao,
                  valor: x.valor,
                  dias: x.dias,
                  situacao: aprovar
                      ? SituacaoMudanca.aprovada
                      : SituacaoMudanca.recusada,
                  resposta: resposta ?? '',
                  respondidoPor: 'Dona Lia',
                  respondidaEm: DateTime(2026, 11, 4),
                )
              : x,
      ];
    },
    'Não foi possível enviar a resposta. Verifique a conexão e tente de novo.',
  );

  /// Soma do que o cliente aprovou. Sem conseguir ler, a conta da obra segue sem as mudanças.
  Future<double> valorAprovado(String obraId) async {
    try {
      return somarAprovado(await listar(obraId));
    } on FalhaAoSalvar {
      return 0;
    }
  }
}
