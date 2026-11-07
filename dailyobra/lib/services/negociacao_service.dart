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
    this.ofertasFora = 0,
  });
  final String orcamentoId;

  /// Algum preço mudou entre a prévia e o envio (o servidor usou o preço atual).
  final bool precosAtualizados;
  final int lojas;

  /// Propostas de valor que não entraram: a proposta foi, sem o valor pedido.
  final int ofertasFora;
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

  /// A obra que [enviar] mandaria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  String? obraDeTeste;

  /// As formas de pagamento por loja que [enviar] mandaria ao banco.
  @visibleForTesting
  Map<String, FormaPagamento> formasDoEnvioDeTeste = const {};

  /// Os valores propostos por loja que [enviar] mandaria ao banco.
  @visibleForTesting
  Map<String, double> ofertasDoEnvioDeTeste = const {};
  bool _teste = false;
  String? _pixTeste;
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

  /// O que [fazerOferta] mandaria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  final ofertasDeTeste = <(String, double, String?)>[];

  @visibleForTesting
  void definirParaTeste({
    List<PropostaResumo> propostas = const [],
    ResultadoEnvio? resultadoEnvio,
    String? erro,
    String? pix,
  }) {
    ofertasDeTeste.clear();
    _propostas = propostas;
    _resultadoTeste = resultadoEnvio;
    _erro = erro;
    _teste = true;
    _pixTeste = pix;
    _carregado = true;
    notifyListeners();
  }

  static const _colunas =
      'id, orcamento_id, loja_id, modo, status, subtotal_anunciado, desconto, frete, total, '
      'cashback_previsto, saldo_aplicado, mensagem_construtor, mensagem_loja, motivo_recusa, forma_escolhida, '
      'oferta_valor, oferta_status, oferta_mensagem, oferta_motivo, oferta_em, '
      'valida_ate, criada_em, '
      'lojas(id, nome, descricao, logo_path, capa_path, whatsapp, cidade, uf, frete_fixo, pedido_minimo, aberta, criada_em, formas_pagamento), '
      'proposta_itens(item_id, nome, unidade, tier, quantidade, preco_anunciado, preco_ofertado), '
      'pedidos(id, status, total, pagamento_confirmado_em, entregue_em, criado_em, pagador, pagador_nome, '
      'pagador_whatsapp, link_codigo, documento_informado_em, pagamento_informado_em, forma_pagamento, prazo, '
      'prazo_status, prazo_respondido_em)';

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
  /// O saldo da carteira não entra aqui: só na hora de pagar, no "Eu pago".
  /// [formas] e [ofertas] vão por loja, depois do envio: se falharem, a cotação já chegou às lojas.
  /// Lança [FalhaComMensagem] com o motivo (pedido mínimo, loja fechada, sem conexão...).
  Future<ResultadoEnvio> enviar({
    required ModoProposta modo,
    required ResultadoCotacao cotacao,
    String? mensagem,
    String? obraId,
    Map<String, FormaPagamento> formas = const {},
    Map<String, double> ofertas = const {},
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
    if (_resultadoTeste != null) {
      obraDeTeste = obraId;
      formasDoEnvioDeTeste = formas;
      ofertasDoEnvioDeTeste = ofertas;
      return _resultadoTeste!;
    }
    final r = await comMensagem(
      () => _db.rpc(
        'enviar_cotacao',
        params: {
          'p_itens': itens,
          'p_modo': modo.codigo,
          'p_obra': obraId,
          'p_usar_saldo': false,
          'p_mensagem': (mensagem?.trim().isEmpty ?? true)
              ? null
              : mensagem!.trim(),
        },
      ),
    );
    final mapa = Map<String, dynamic>.from(r as Map);
    final orcamentoId = mapa['orcamento_id'] as String;
    final enviadas = (mapa['propostas'] as List? ?? const []).cast<Map>();
    await _gravarFormas(orcamentoId, formas);
    var ofertasFora = 0;
    for (final p in enviadas) {
      final valor = ofertas[p['loja_id']];
      if (valor == null) continue;
      try {
        await _db.rpc(
          'fazer_oferta',
          params: {'p_proposta': p['id'], 'p_valor': valor},
        );
      } on Exception {
        ofertasFora++;
      }
    }
    await Future.wait([
      carregar(),
      CarteiraService.instance.carregar(),
      EconomiaService.instance.carregar(),
    ]);
    return ResultadoEnvio(
      orcamentoId: orcamentoId,
      precosAtualizados: mapa['precos_atualizados'] == true,
      lojas: enviadas.length,
      ofertasFora: ofertasFora,
    );
  }

  /// A forma é uma preferência: se não gravar, o construtor escolhe de novo no pedido.
  Future<void> _gravarFormas(
    String orcamentoId,
    Map<String, FormaPagamento> formas,
  ) async {
    if (formas.isEmpty) return;
    try {
      await _db.rpc(
        'definir_formas_do_orcamento',
        params: {
          'p_orcamento': orcamentoId,
          'p_formas': {for (final e in formas.entries) e.key: e.value.codigo},
        },
      );
    } on Exception {
      // Segue sem a forma
    }
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

  /// Oferta de [valor] no total da proposta (o servidor confere de novo).
  Future<void> fazerOferta(String id, double valor, String? mensagem) async {
    if (_teste) {
      ofertasDeTeste.add((id, valor, mensagem));
      return;
    }
    await _acao('fazer_oferta', {
      'p_proposta': id,
      'p_valor': valor,
      'p_mensagem': mensagem,
    });
  }

  Future<void> cancelarPedido(String pedidoId) => _acao('atualizar_pedido', {
    'p_pedido': pedidoId,
    'p_status': 'cancelado',
  });

  /// PIX do pedido: a cobrança do Asaas quando a loja tem carteira lá; fora isso, ou se o Asaas falhar, o copia e cola da
  /// chave da loja (função pix_do_pedido). Nulo quando a loja não tem chave PIX.
  Future<PixDoPedido?> pixDoPedido(String pedidoId) async {
    if (_teste) {
      final pix = _pixTeste;
      return pix == null ? null : PixDoPedido(pix);
    }
    try {
      final resposta = await _db.functions.invoke(
        'pix-asaas',
        body: {'acao': 'cobrar', 'pedido': pedidoId},
      );
      final codigo = (resposta.data as Map?)?['codigo'] as String?;
      if (codigo != null) return PixDoPedido(codigo, automatico: true);
    } on Exception {
      // Segue com a chave da loja
    }
    final pix = await comMensagem(
      () => _db.rpc('pix_do_pedido', params: {'p_pedido': pedidoId}),
    );
    return pix == null ? null : PixDoPedido(pix as String);
  }

  /// "Eu pago": a nota sai no CPF/CNPJ do construtor (fica salvo no perfil).
  Future<void> pagarEuMesmo(String pedidoId, String documento) =>
      _acao('pagar_eu_mesmo', {'p_pedido': pedidoId, 'p_documento': documento});

  /// Liga ou desliga o saldo da carteira no pedido (função usar_saldo; só no "Eu pago").
  Future<void> usarSaldo(String pedidoId, bool usar) =>
      _acao('usar_saldo', {'p_pedido': pedidoId, 'p_usar': usar});

  /// PIX, cartão na loja ou crediário (com o prazo pedido, que a loja aprova).
  Future<void> escolherPagamento(
    String pedidoId,
    FormaPagamento forma, {
    String? prazo,
  }) => _acao('escolher_pagamento', {
    'p_pedido': pedidoId,
    'p_forma': forma.codigo,
    'p_prazo': prazo,
  });

  /// Cria (ou troca) o link de pagamento do cliente e devolve o código.
  /// Com o documento do cliente, a página já mostra os dados da nota.
  Future<String> criarLink(
    String pedidoId, {
    required String nome,
    required String whatsapp,
    String? documento,
  }) async {
    final codigo = await comMensagem(
      () => _db.rpc(
        'criar_link_pagamento',
        params: {
          'p_pedido': pedidoId,
          'p_nome': nome,
          'p_whatsapp': whatsapp,
          if (documento != null && documento.isNotEmpty)
            'p_documento': documento,
        },
      ),
    );
    await carregar();
    return codigo as String;
  }
}
