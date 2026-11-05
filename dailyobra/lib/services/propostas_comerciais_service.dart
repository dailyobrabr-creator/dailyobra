import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// Propostas do engenheiro para os clientes dele. São da pessoa, não de uma obra.
class PropostasComerciaisService {
  PropostasComerciaisService._();

  static final instance = PropostasComerciaisService._();

  static const _tabela = 'construtor_propostas';

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<PropostaComercial> _propostas = const [];

  @visibleForTesting
  final salvasDeTeste = <PropostaComercial>[];
  @visibleForTesting
  final excluidasDeTeste = <String>[];
  @visibleForTesting
  final viraramObraDeTeste = <(String, String)>[];

  @visibleForTesting
  void definirParaTeste({
    List<PropostaComercial> propostas = const [],
    String? erro,
  }) {
    _teste = true;
    _erro = erro;
    _propostas = [...propostas];
    salvasDeTeste.clear();
    excluidasDeTeste.clear();
    viraramObraDeTeste.clear();
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

  Future<List<PropostaComercial>> listar() => _executar(
    () async {
      final r = await _db
          .from(_tabela)
          .select()
          .order('numero', ascending: false);
      return [for (final j in r) PropostaComercial.fromJson(j)];
    },
    () => [..._propostas],
    'Não foi possível carregar as propostas. Verifique a conexão e tente de novo.',
  );

  PropostaComercial _comNumero(PropostaComercial p, String id, int? numero) =>
      PropostaComercial(
        id: id,
        numero: numero,
        cliente: p.cliente,
        contato: p.contato,
        titulo: p.titulo,
        endereco: p.endereco,
        cidade: p.cidade,
        uf: p.uf,
        area: p.area,
        padrao: p.padrao,
        itens: p.itens,
        desconto: p.desconto,
        mostrarValores: p.mostrarValores,
        parcelas: p.parcelas,
        inclui: p.inclui,
        naoInclui: p.naoInclui,
        prazoDias: p.prazoDias,
        validade: p.validade,
        observacoes: p.observacoes,
        situacao: p.situacao,
        obraId: p.obraId,
      );

  /// Devolve a proposta com o id e o número, que o PDF usa.
  Future<PropostaComercial> salvar(PropostaComercial p) => _executar(
    () async {
      final r = await _db.rpc<dynamic>(
        'salvar_proposta_comercial',
        params: {'p_id': p.id, 'p_dados': p.paraSalvar()},
      );
      final j = Map<String, dynamic>.from(r as Map);
      return _comNumero(p, j['id'] as String, (j['numero'] as num).toInt());
    },
    () {
      salvasDeTeste.add(p);
      final numero = p.numero ?? _propostas.length + 1;
      final salva = _comNumero(p, p.id ?? 'nova-$numero', numero);
      _propostas = [
        salva,
        for (final x in _propostas)
          if (x.id != salva.id) x,
      ];
      return salva;
    },
    'Não foi possível salvar a proposta. Verifique a conexão e tente de novo.',
  );

  Future<void> excluir(String id) =>
      _executar(() => _db.from(_tabela).delete().eq('id', id), () {
        excluidasDeTeste.add(id);
        _propostas = [
          for (final x in _propostas)
            if (x.id != id) x,
        ];
      }, 'Não foi possível excluir a proposta. Tente de novo.');

  /// Liga a proposta à obra e leva as parcelas para o caixa.
  Future<void> virarObra(
    String id,
    String obraId,
    DateTime inicio,
  ) => _executar(
    () => _db.rpc<void>(
      'proposta_vira_obra',
      params: {'p_id': id, 'p_obra': obraId, 'p_inicio': dataIso(inicio)},
    ),
    () => viraramObraDeTeste.add((id, obraId)),
    'A obra foi criada, mas a proposta não foi ligada a ela. Tente de novo.',
  );
}
