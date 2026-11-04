import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// Diaristas, presenças, contratos e medições. As tabelas não abrem direto: as funções do banco
/// decidem quem vê valor e quem pode pagar.
class MaoDeObraService {
  MaoDeObraService._();

  static final instance = MaoDeObraService._();

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<Diarista> _diaristas = const [];
  List<Presenca> _presencas = const [];
  List<Contrato> _contratos = const [];
  List<Medicao> _medicoes = const [];
  bool _aprovaAoLancar = true;

  @visibleForTesting
  final diaristasSalvosDeTeste = <Diarista>[];
  @visibleForTesting
  final marcacoesDeTeste = <(String, DateTime, double)>[];
  @visibleForTesting
  final pagamentosDeTeste = <(DateTime, EtapaId?)>[];
  @visibleForTesting
  final contratosSalvosDeTeste = <Contrato>[];
  @visibleForTesting
  final contratosExcluidosDeTeste = <String>[];
  @visibleForTesting
  final medicoesLancadasDeTeste = <(String, double, String?)>[];
  @visibleForTesting
  final medicoesAprovadasDeTeste = <String>[];
  @visibleForTesting
  final medicoesExcluidasDeTeste = <String>[];
  @visibleForTesting
  final medicoesPagasDeTeste = <(String, DateTime)>[];

  @visibleForTesting
  void definirParaTeste({
    List<Diarista> diaristas = const [],
    List<Presenca> presencas = const [],
    List<Contrato> contratos = const [],
    List<Medicao> medicoes = const [],
    bool aprovaAoLancar = true,
    String? erro,
  }) {
    _teste = true;
    _erro = erro;
    _diaristas = [...diaristas];
    _presencas = [...presencas];
    _contratos = [...contratos];
    _medicoes = [...medicoes];
    _aprovaAoLancar = aprovaAoLancar;
    diaristasSalvosDeTeste.clear();
    marcacoesDeTeste.clear();
    pagamentosDeTeste.clear();
    contratosSalvosDeTeste.clear();
    contratosExcluidosDeTeste.clear();
    medicoesLancadasDeTeste.clear();
    medicoesAprovadasDeTeste.clear();
    medicoesExcluidasDeTeste.clear();
    medicoesPagasDeTeste.clear();
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

  Future<List<Map<String, dynamic>>> _linhas(
    String funcao,
    String obraId,
  ) async {
    final r = await _db.rpc<List<dynamic>>(funcao, params: {'p_obra': obraId});
    return [for (final l in r) Map<String, dynamic>.from(l as Map)];
  }

  Future<List<Diarista>> diaristas(String obraId) => _executar(
    () async => [
      for (final d in await _linhas('diaristas_da_obra', obraId))
        Diarista.fromJson(d),
    ],
    () => [..._diaristas],
    'Não foi possível carregar a lista. Verifique a conexão e tente de novo.',
  );

  Future<List<Presenca>> presencas(String obraId) => _executar(
    () async => [
      for (final p in await _linhas('presencas_da_obra', obraId))
        Presenca.fromJson(p),
    ],
    () => [..._presencas],
    'Não foi possível carregar as presenças. Verifique a conexão e tente de novo.',
  );

  Future<String> salvarDiarista(String obraId, Diarista d) => _executar(
    () => _db.rpc<String>(
      'salvar_diarista',
      params: {'p_obra': obraId, 'p_id': d.id, 'p_dados': d.paraSalvar()},
    ),
    () {
      diaristasSalvosDeTeste.add(d);
      final id = d.id ?? 'novo-${diaristasSalvosDeTeste.length}';
      _diaristas = [
        for (final x in _diaristas)
          if (x.id != id) x,
        Diarista(
          id: id,
          nome: d.nome,
          funcao: d.funcao,
          diaria: d.diaria,
          ativo: d.ativo,
        ),
      ];
      return id;
    },
    'Não foi possível salvar a pessoa. Verifique a conexão e tente de novo.',
  );

  /// Zero dias tira a marcação.
  Future<void> marcarPresenca(String diaristaId, DateTime data, double dias) =>
      _executar(
        () => _db.rpc<void>(
          'marcar_presenca',
          params: {
            'p_diarista': diaristaId,
            'p_data': dataIso(data),
            'p_dias': dias,
          },
        ),
        () {
          marcacoesDeTeste.add((diaristaId, data, dias));
          _presencas = [
            for (final p in _presencas)
              if (p.diaristaId != diaristaId || !mesmoDia(p.data, data)) p,
            if (dias > 0)
              Presenca(diaristaId: diaristaId, data: data, dias: dias),
          ];
        },
        'Não foi possível marcar. Verifique a conexão e tente de novo.',
      );

  Future<void> pagarDiarias(String obraId, DateTime data, EtapaId? etapa) =>
      _executar(
        () => _db.rpc<String>(
          'pagar_diarias',
          params: {
            'p_obra': obraId,
            'p_data': dataIso(data),
            'p_etapa': etapa?.codigo,
          },
        ),
        () {
          pagamentosDeTeste.add((data, etapa));
          _presencas = [
            for (final p in _presencas)
              Presenca(
                diaristaId: p.diaristaId,
                data: p.data,
                dias: p.dias,
                pago: true,
              ),
          ];
        },
        'Não foi possível registrar o pagamento. Tente de novo.',
      );

  /// O empreiteiro recebe só o contrato dele.
  Future<List<ResumoContrato>> contratos(String obraId) => _executar(
    () async {
      final (c, m) = await (
        _linhas('contratos_da_obra', obraId),
        _linhas('medicoes_da_obra', obraId),
      ).wait;
      return resumirContratos(
        [for (final j in c) Contrato.fromJson(j)],
        [for (final j in m) Medicao.fromJson(j)],
      );
    },
    () => resumirContratos(_contratos, _medicoes),
    'Não foi possível carregar os contratos. Verifique a conexão e tente de novo.',
  );

  Future<String> salvarContrato(String obraId, Contrato c) => _executar(
    () => _db.rpc<String>(
      'salvar_contrato',
      params: {'p_obra': obraId, 'p_id': c.id, 'p_dados': c.paraSalvar()},
    ),
    () {
      contratosSalvosDeTeste.add(c);
      final id = c.id ?? 'novo-${contratosSalvosDeTeste.length}';
      _contratos = [
        Contrato(
          id: id,
          empreiteiro: c.empreiteiro,
          usuario: c.usuario,
          servico: c.servico,
          etapa: c.etapa,
          valor: c.valor,
          encerrado: c.encerrado,
        ),
        for (final x in _contratos)
          if (x.id != id) x,
      ];
      return id;
    },
    'Não foi possível salvar o contrato. Verifique a conexão e tente de novo.',
  );

  Future<void> excluirContrato(String id) => _executar(
    () => _db.rpc<void>('excluir_contrato', params: {'p_id': id}),
    () {
      contratosExcluidosDeTeste.add(id);
      _contratos = [
        for (final x in _contratos)
          if (x.id != id) x,
      ];
    },
    'Não foi possível excluir o contrato. Tente de novo.',
  );

  Future<void> lancarMedicao(
    String contratoId,
    DateTime data,
    double percentual,
    String? observacao,
  ) => _executar(
    () => _db.rpc<String>(
      'lancar_medicao',
      params: {
        'p_contrato': contratoId,
        'p_data': dataIso(data),
        'p_percentual': percentual,
        'p_observacao': observacao,
      },
    ),
    () {
      medicoesLancadasDeTeste.add((contratoId, percentual, observacao));
      final c = _contratos.firstWhere((x) => x.id == contratoId);
      final anteriores = _medicoes.where((m) => m.contratoId == contratoId);
      final soma = anteriores.fold<double>(0, (s, m) => s + (m.valor ?? 0));
      _medicoes = [
        ..._medicoes,
        Medicao(
          id: 'medicao-${_medicoes.length + 1}',
          contratoId: contratoId,
          numero: anteriores.length + 1,
          data: data,
          percentual: percentual,
          valor: c.valor == null ? null : c.valor! * percentual / 100 - soma,
          observacao: observacao ?? '',
          aprovada: _aprovaAoLancar,
        ),
      ];
    },
    'Não foi possível lançar a medição. Verifique a conexão e tente de novo.',
  );

  Medicao _trocada(Medicao m, {bool? aprovada, bool? paga, DateTime? pagaEm}) =>
      Medicao(
        id: m.id,
        contratoId: m.contratoId,
        numero: m.numero,
        data: m.data,
        percentual: m.percentual,
        valor: m.valor,
        observacao: m.observacao,
        aprovada: aprovada ?? m.aprovada,
        paga: paga ?? m.paga,
        pagaEm: pagaEm ?? m.pagaEm,
      );

  Future<void> aprovarMedicao(String id) => _executar(
    () => _db.rpc<void>('aprovar_medicao', params: {'p_id': id}),
    () {
      medicoesAprovadasDeTeste.add(id);
      _medicoes = [
        for (final m in _medicoes) m.id == id ? _trocada(m, aprovada: true) : m,
      ];
    },
    'Não foi possível aprovar a medição. Tente de novo.',
  );

  Future<void> excluirMedicao(String id) => _executar(
    () => _db.rpc<void>('excluir_medicao', params: {'p_id': id}),
    () {
      medicoesExcluidasDeTeste.add(id);
      _medicoes = [
        for (final m in _medicoes)
          if (m.id != id) m,
      ];
    },
    'Não foi possível excluir a medição. Tente de novo.',
  );

  Future<void> pagarMedicao(String id, DateTime data) => _executar(
    () => _db.rpc<String>(
      'pagar_medicao',
      params: {'p_id': id, 'p_data': dataIso(data)},
    ),
    () {
      medicoesPagasDeTeste.add((id, data));
      _medicoes = [
        for (final m in _medicoes)
          m.id == id ? _trocada(m, paga: true, pagaEm: data) : m,
      ];
    },
    'Não foi possível registrar o pagamento. Tente de novo.',
  );
}
