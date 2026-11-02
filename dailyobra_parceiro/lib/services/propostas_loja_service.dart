import 'dart:async';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Quem mandou a proposta (a loja vê nome, empresa e telefone pela RLS de profiles).
class Construtor {
  const Construtor({
    required this.id,
    this.nome = '',
    this.empresa = '',
    this.telefone,
  });
  final String id;
  final String nome;
  final String empresa;
  final String? telefone;

  String get exibicao => nome.isEmpty ? 'Construtor' : nome;
}

/// Propostas e pedidos da loja, com tempo real. As respostas passam pelas funções do servidor,
/// que conferem o papel de novo, o prazo e se a proposta ainda está aberta.
class PropostasLojaService extends ChangeNotifier {
  PropostasLojaService._();

  static final instance = PropostasLojaService._();

  SupabaseClient get _db => Supabase.instance.client;

  List<PropostaResumo> _propostas = const [];
  Map<String, Construtor> _construtores = const {};
  String? _erro;
  bool _carregado = false;
  String? _lojaId;
  RealtimeChannel? _canal;
  Timer? _recarga;
  int _pedido = 0;

  List<PropostaResumo> get todas => _propostas;
  String? get erro => _erro;
  bool get carregado => _carregado;

  /// Esperando a loja responder (proposta ou pedido direto).
  List<PropostaResumo> get novas =>
      _propostas.where((p) => p.status == StatusProposta.enviada).toList();

  /// Contraproposta enviada, esperando o construtor.
  List<PropostaResumo> get emNegociacao => _propostas
      .where((p) => p.status == StatusProposta.contraproposta)
      .toList();

  List<PropostaResumo> get pedidos =>
      _propostas.where((p) => p.pedido != null).toList()
        ..sort((a, b) => b.pedido!.criadoEm.compareTo(a.pedido!.criadoEm));

  List<PropostaResumo> get pedidosEmAndamento => pedidos
      .where(
        (p) => const {
          StatusPedido.confirmado,
          StatusPedido.emSeparacao,
          StatusPedido.saiuEntrega,
        }.contains(p.pedido!.status),
      )
      .toList();

  List<PropostaResumo> get encerradas =>
      _propostas.where((p) => p.pedido == null && !p.status.aberta).toList();

  /// Soma dos pedidos entregues no mês de [hoje].
  double vendidoNoMes(DateTime hoje) => pedidos
      .where((p) {
        final e = p.pedido!.entregueEm;
        return p.pedido!.status == StatusPedido.entregue &&
            e != null &&
            e.year == hoje.year &&
            e.month == hoje.month;
      })
      .fold(0.0, (s, p) => s + p.pedido!.total);

  Construtor construtor(String? id) =>
      _construtores[id] ?? Construtor(id: id ?? '');

  PropostaResumo? proposta(String id) {
    for (final p in _propostas) {
      if (p.id == id) return p;
    }
    return null;
  }

  PropostaResumo? propostaDoPedido(String pedidoId) {
    for (final p in _propostas) {
      if (p.pedido?.id == pedidoId) return p;
    }
    return null;
  }

  @visibleForTesting
  void definirParaTeste({
    List<PropostaResumo> propostas = const [],
    List<Construtor> construtores = const [],
    Map<String, String> documentos = const {},
  }) {
    _propostas = propostas;
    _construtores = {for (final c in construtores) c.id: c};
    _documentosDeTeste = documentos;
    _carregado = true;
    _erro = null;
    notifyListeners();
  }

  Map<String, String>? _documentosDeTeste;

  /// CPF/CNPJ que vai na nota (pedido_documentos: só a equipe da loja lê).
  Future<String?> documentoDoPagador(String pedidoId) async {
    final teste = _documentosDeTeste;
    if (teste != null) return teste[pedidoId];
    final linha = await _db
        .from('pedido_documentos')
        .select('documento')
        .eq('pedido_id', pedidoId)
        .maybeSingle();
    return linha?['documento'] as String?;
  }

  static const _colunas =
      'id, orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, desconto, frete, total, '
      'cashback_previsto, saldo_aplicado, mensagem_construtor, mensagem_loja, motivo_recusa, valida_ate, criada_em, '
      'proposta_itens(item_id, nome, unidade, tier, quantidade, preco_anunciado, preco_ofertado), '
      'pedidos(id, status, total, pagamento_confirmado_em, entregue_em, criado_em, pagador, pagador_nome, '
      'pagador_whatsapp, link_codigo, documento_informado_em, pagamento_informado_em)';

  void iniciar(String lojaId) {
    if (_lojaId == lojaId && _canal != null) return;
    parar();
    _lojaId = lojaId;
    final filtro = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'loja_id',
      value: lojaId,
    );
    _canal = _db.channel('loja-$lojaId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'propostas',
        filter: filtro,
        callback: (_) => _agendarRecarga(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'pedidos',
        filter: filtro,
        callback: (_) => _agendarRecarga(),
      )
      ..subscribe();
    carregar();
  }

  void parar() {
    _recarga?.cancel();
    final canal = _canal;
    _canal = null;
    if (canal != null) _db.removeChannel(canal);
    _lojaId = null;
    _pedido++;
    _propostas = const [];
    _carregado = false;
    notifyListeners();
  }

  void _agendarRecarga() {
    _recarga?.cancel();
    _recarga = Timer(const Duration(milliseconds: 400), carregar);
  }

  Future<void> carregar() async {
    final lojaId = _lojaId;
    if (lojaId == null) return;
    final meu = ++_pedido;
    try {
      await _db.rpc('expirar_propostas').catchError((_) => 0);
      final linhas = await _db
          .from('propostas')
          .select(_colunas)
          .eq('loja_id', lojaId)
          .order('criada_em', ascending: false)
          .limit(200);
      final propostas = [for (final j in linhas) PropostaResumo.fromJson(j)];
      final ids = {for (final p in propostas) ?p.construtorId}.toList();
      final perfis = ids.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _db
                .from('profiles')
                .select('id, nome, empresa, telefone')
                .inFilter('id', ids);
      if (meu != _pedido) return;
      _propostas = propostas;
      _construtores = {
        for (final j in perfis)
          j['id'] as String: Construtor(
            id: j['id'] as String,
            nome: (j['nome'] as String?) ?? '',
            empresa: (j['empresa'] as String?) ?? '',
            telefone: j['telefone'] as String?,
          ),
      };
      _erro = null;
      _carregado = true;
    } catch (e) {
      if (meu != _pedido) return;
      _erro = mensagemDoServidor(e);
    }
    notifyListeners();
  }

  Future<void> _responder(
    String id,
    String acao, {
    Object? precos,
    double? desconto,
    String? mensagem,
    String? motivo,
    int? validade,
  }) async {
    await comMensagem(
      () => _db.rpc(
        'responder_proposta',
        params: {
          'p_proposta': id,
          'p_acao': acao,
          'p_precos': precos,
          'p_desconto': desconto,
          'p_mensagem': (mensagem?.trim().isEmpty ?? true)
              ? null
              : mensagem!.trim(),
          'p_motivo': motivo,
          'p_validade_horas': validade,
        },
      ),
    );
    await carregar();
  }

  Future<void> aceitar(String id) => _responder(id, 'aceitar');

  Future<void> recusar(String id, String motivo) =>
      _responder(id, 'recusar', motivo: motivo.trim());

  /// [precos] por item_id; só pode baixar (o servidor confere de novo).
  Future<void> contrapropor(
    String id, {
    required Map<String, double> precos,
    double desconto = 0,
    int validadeHoras = 48,
    String? mensagem,
  }) => _responder(
    id,
    'contrapropor',
    precos: [
      for (final MapEntry(key: item, value: preco) in precos.entries)
        {'item_id': item, 'preco': preco},
    ],
    desconto: desconto,
    mensagem: mensagem,
    validade: validadeHoras,
  );

  Future<void> _pedidoRpc(String funcao, Map<String, dynamic> params) async {
    await comMensagem(() => _db.rpc(funcao, params: params));
    await carregar();
  }

  Future<void> atualizarPedido(String pedidoId, StatusPedido status) =>
      _pedidoRpc('atualizar_pedido', {
        'p_pedido': pedidoId,
        'p_status': status.codigo,
      });

  Future<void> confirmarPagamento(String pedidoId) =>
      _pedidoRpc('confirmar_pagamento', {'p_pedido': pedidoId});
}
