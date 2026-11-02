import 'dart:async';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'carteira_service.dart';
import 'economia_service.dart';
import 'novidades_service.dart';

class ResultadoEnvio {
  const ResultadoEnvio({
    required this.orcamentoId,
    required this.precosAtualizados,
    required this.lojas,
  });
  final String orcamentoId;

  /// Algum preço mudou entre a prévia e o envio (o servidor usou o preço atual).
  final bool precosAtualizados;
  final int lojas;
}

/// Propostas e pedidos do construtor. Toda regra (preço, validade, estados, saldo) é do servidor;
/// aqui só chamamos as funções e acompanhamos as mudanças em tempo real.
class NegociacaoService extends ChangeNotifier {
  NegociacaoService._();

  static final instance = NegociacaoService._();

  SupabaseClient get _db => Supabase.instance.client;

  List<PropostaResumo> _propostas = const [];
  String? _erro;
  bool _carregado = false;
  RealtimeChannel? _canal;
  Timer? _recarga;
  ResultadoEnvio? _resultadoTeste;
  int _pedido = 0;

  List<PropostaResumo> get propostas => _propostas;
  String? get erro => _erro;
  bool get carregado => _carregado;

  /// Propostas esperando resposta do construtor (contrapropostas).
  int get aguardandoVoce =>
      _propostas.where((p) => p.status == StatusProposta.contraproposta).length;

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
    ResultadoEnvio? resultadoEnvio,
    String? erro,
  }) {
    _propostas = propostas;
    _resultadoTeste = resultadoEnvio;
    _erro = erro;
    _carregado = true;
    notifyListeners();
  }

  static const _colunas =
      'id, orcamento_id, loja_id, modo, status, subtotal_anunciado, desconto, frete, total, '
      'cashback_previsto, saldo_aplicado, mensagem_construtor, mensagem_loja, motivo_recusa, '
      'valida_ate, criada_em, '
      'lojas(id, nome, descricao, logo_path, capa_path, whatsapp, cidade, uf, frete_fixo, pedido_minimo, aberta, criada_em), '
      'proposta_itens(item_id, nome, unidade, tier, quantidade, preco_anunciado, preco_ofertado), '
      'pedidos(id, status, total, pagamento_confirmado_em, entregue_em, criado_em)';

  /// Chamado ao entrar: carrega e passa a ouvir as mudanças das propostas e pedidos do usuário.
  void iniciar() {
    final uid = _db.auth.currentUser?.id;
    if (uid == null || _canal != null) return;
    final filtro = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'construtor_id',
      value: uid,
    );
    _canal = _db.channel('construtor-$uid')
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
    _pedido++;
    _propostas = const [];
    _carregado = false;
    _erro = null;
    notifyListeners();
  }

  void _agendarRecarga() {
    _recarga?.cancel();
    _recarga = Timer(const Duration(milliseconds: 400), () {
      carregar();
      CarteiraService.instance.carregar();
      NovidadesService.instance.carregar();
      EconomiaService.instance.carregar();
    });
  }

  Future<void> carregar() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final meu = ++_pedido;
    try {
      // Marca como expiradas as propostas vencidas antes de listar (idempotente)
      await _db.rpc('expirar_propostas').catchError((_) => 0);
      final linhas = await _db
          .from('propostas')
          .select(_colunas)
          .eq('construtor_id', uid)
          .order('criada_em', ascending: false)
          .limit(100);
      if (meu != _pedido) return;
      _propostas = [for (final j in linhas) PropostaResumo.fromJson(j)];
      _erro = null;
      _carregado = true;
    } catch (e) {
      if (meu != _pedido) return;
      _erro = mensagemDoServidor(e);
    }
    notifyListeners();
  }

  /// Envia a cotação: uma proposta (ou pedido direto) por loja, com os preços do servidor.
  /// Lança [FalhaComMensagem] com o motivo (pedido mínimo, loja fechada, sem conexão...).
  Future<ResultadoEnvio> enviar({
    required ModoProposta modo,
    required ResultadoCotacao cotacao,
    required bool usarSaldo,
    String? mensagem,
    String? obraId,
  }) async {
    final itens = [
      for (final g in cotacao.grupos)
        for (final l in g.linhas)
          {
            'item_id': l.item.id,
            'loja_id': g.loja.id,
            'quantidade': l.quantidade,
            'preco_visto': l.precoUnitario,
          },
    ];
    if (itens.isEmpty) {
      throw const FalhaComMensagem('Nenhum produto com oferta para enviar.');
    }
    if (_resultadoTeste != null) return _resultadoTeste!;
    final r = await comMensagem(
      () => _db.rpc(
        'enviar_cotacao',
        params: {
          'p_itens': itens,
          'p_modo': modo.codigo,
          'p_obra': obraId,
          'p_usar_saldo': usarSaldo,
          'p_mensagem': (mensagem?.trim().isEmpty ?? true)
              ? null
              : mensagem!.trim(),
        },
      ),
    );
    final mapa = Map<String, dynamic>.from(r as Map);
    await Future.wait([
      carregar(),
      CarteiraService.instance.carregar(),
      EconomiaService.instance.carregar(),
    ]);
    return ResultadoEnvio(
      orcamentoId: mapa['orcamento_id'] as String,
      precosAtualizados: mapa['precos_atualizados'] == true,
      lojas: (mapa['propostas'] as List? ?? const []).length,
    );
  }

  Future<void> _acao(String funcao, Map<String, dynamic> params) async {
    await comMensagem(() => _db.rpc(funcao, params: params));
    await Future.wait([
      carregar(),
      CarteiraService.instance.carregar(),
      EconomiaService.instance.carregar(),
    ]);
  }

  Future<void> aceitarContraproposta(String id) =>
      _acao('decidir_contraproposta', {'p_proposta': id, 'p_aceitar': true});

  Future<void> recusarContraproposta(String id) =>
      _acao('decidir_contraproposta', {'p_proposta': id, 'p_aceitar': false});

  Future<void> cancelar(String id) =>
      _acao('cancelar_proposta', {'p_proposta': id});

  Future<void> cancelarPedido(String pedidoId) => _acao('atualizar_pedido', {
    'p_pedido': pedidoId,
    'p_status': 'cancelado',
  });
}
