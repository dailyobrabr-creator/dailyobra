import 'modelos.dart';
import 'pagamento.dart';

/// Proposta, itens e pedido como os dois apps leem do banco (tabelas propostas, proposta_itens
/// e pedidos). Toda mudança de estado é feita pelas funções do servidor.
class ItemProposta {
  const ItemProposta({
    required this.itemId,
    required this.nome,
    required this.unidade,
    required this.tier,
    required this.quantidade,
    required this.precoAnunciado,
    this.precoOfertado,
  });
  final String itemId;
  final String nome;
  final String unidade;
  final int tier;
  final double quantidade;
  final double precoAnunciado;

  /// Preço da contraproposta; nulo quando a loja manteve o anunciado.
  final double? precoOfertado;

  double get precoFinal => precoOfertado ?? precoAnunciado;
  bool get mudou => precoOfertado != null && precoOfertado != precoAnunciado;
  double get total => (precoFinal * quantidade * 100).roundToDouble() / 100;

  factory ItemProposta.fromJson(Map<String, dynamic> j) => ItemProposta(
    itemId: j['item_id'] as String,
    nome: j['nome'] as String,
    unidade: j['unidade'] as String,
    tier: (j['tier'] as num).toInt(),
    quantidade: lerValor(j['quantidade']),
    precoAnunciado: lerValor(j['preco_anunciado']),
    precoOfertado: j['preco_ofertado'] == null
        ? null
        : lerValor(j['preco_ofertado']),
  );
}

class PedidoResumo {
  const PedidoResumo({
    required this.id,
    required this.status,
    required this.total,
    required this.criadoEm,
    this.pagamentoConfirmadoEm,
    this.entregueEm,
    this.pagador,
    this.pagadorNome,
    this.pagadorWhatsapp,
    this.linkCodigo,
    this.documentoInformadoEm,
    this.pagamentoInformadoEm,
    this.formaPagamento,
    this.prazo,
    this.prazoStatus,
    this.prazoRespondidoEm,
    this.parcelas,
    this.erpNumero,
    this.erpLancadoEm,
  });
  final String id;
  final StatusPedido status;
  final double total;
  final DateTime criadoEm;
  final DateTime? pagamentoConfirmadoEm;
  final DateTime? entregueEm;

  /// Número da venda no Santri, registrado pela loja no Faturamento / Caixa. Só a equipe da loja lê.
  final String? erpNumero;
  final DateTime? erpLancadoEm;

  /// Pode entrar no Santri: pagamento confirmado, ou crediário e duplicata com o prazo aprovado. É a regra de registrar_faturamento.
  bool get prontoParaFaturar => pagamentoConfirmadoEm != null || ((formaPagamento == FormaPagamento.crediario || formaPagamento == FormaPagamento.duplicata) && prazoStatus == StatusPrazo.aprovado);

  /// Quem paga (nulo até o construtor escolher). O CPF/CNPJ de quem paga fica em pedido_documentos, só para a loja.
  final Pagador? pagador;
  final String? pagadorNome;
  final String? pagadorWhatsapp;

  /// Código do link de pagamento enviado ao cliente; nulo quando o construtor paga ou o link foi trocado.
  final String? linkCodigo;
  final DateTime? documentoInformadoEm;

  /// Quando o cliente apertou "Já paguei" na página (a loja ainda confere e confirma).
  final DateTime? pagamentoInformadoEm;

  /// Forma escolhida no "Eu pago" (nula até escolher; o link do cliente grava PIX).
  final FormaPagamento? formaPagamento;

  /// Prazo pedido no crediário ('28', '28/35' ou '28/35/42') e a resposta do dono ou gerente da loja.
  final String? prazo;
  final StatusPrazo? prazoStatus;
  final DateTime? prazoRespondidoEm;

  /// Em quantas vezes no cartão ou no boleto; nulo nas outras formas.
  final int? parcelas;

  SituacaoPagamento get situacaoPagamento {
    if (status == StatusPedido.cancelado) return SituacaoPagamento.cancelado;
    if (pagamentoConfirmadoEm != null) return SituacaoPagamento.pago;
    if (pagamentoInformadoEm != null) return SituacaoPagamento.informado;
    if (pagador != null && documentoInformadoEm != null) return SituacaoPagamento.aguardandoPagamento;
    if (pagador == Pagador.cliente) return SituacaoPagamento.aguardandoDados;
    return SituacaoPagamento.semPagador;
  }

  factory PedidoResumo.fromJson(Map<String, dynamic> j) => PedidoResumo(
    id: j['id'] as String,
    status: StatusPedido.fromCodigo(j['status'] as String?),
    total: lerValor(j['total']),
    criadoEm: DateTime.parse(j['criado_em'] as String).toLocal(),
    pagamentoConfirmadoEm: _data(j['pagamento_confirmado_em']),
    entregueEm: _data(j['entregue_em']),
    pagador: Pagador.fromCodigo(j['pagador'] as String?),
    pagadorNome: j['pagador_nome'] as String?,
    pagadorWhatsapp: j['pagador_whatsapp'] as String?,
    linkCodigo: j['link_codigo'] as String?,
    documentoInformadoEm: _data(j['documento_informado_em']),
    pagamentoInformadoEm: _data(j['pagamento_informado_em']),
    formaPagamento: FormaPagamento.fromCodigo(j['forma_pagamento'] as String?),
    prazo: j['prazo'] as String?,
    prazoStatus: StatusPrazo.fromCodigo(j['prazo_status'] as String?),
    prazoRespondidoEm: _data(j['prazo_respondido_em']),
    parcelas: (j['parcelas'] as num?)?.toInt(),
    erpNumero: _faturamento(j['pedido_faturamento'])?['numero'] as String?,
    erpLancadoEm: _data(_faturamento(j['pedido_faturamento'])?['lancado_em']),
  );
}

DateTime? _data(Object? v) => v is String ? DateTime.parse(v).toLocal() : null;

/// A linha de pedido_faturamento vem como objeto ou como lista, conforme a relação que o banco enxerga.
Map<String, dynamic>? _faturamento(Object? v) => switch (v) {
      final Map<String, dynamic> linha => linha,
      final List<dynamic> lista when lista.isNotEmpty => lista.first as Map<String, dynamic>,
      _ => null,
    };

/// Resposta da loja à oferta do construtor.
enum StatusOferta {
  pendente,
  aprovada,
  recusada;

  static StatusOferta? fromCodigo(String? c) => values.where((v) => v.name == c).firstOrNull;
}

class PropostaResumo {
  const PropostaResumo({
    required this.id,
    required this.orcamentoId,
    required this.lojaId,
    required this.lojaNome,
    this.construtorId,
    required this.modo,
    required this.status,
    required this.subtotalAnunciado,
    required this.desconto,
    required this.frete,
    required this.total,
    required this.cashbackPrevisto,
    required this.saldoAplicado,
    required this.validaAte,
    required this.criadaEm,
    required this.itens,
    this.loja,
    this.mensagemConstrutor,
    this.formaEscolhida,
    this.parcelasEscolhidas,
    this.mensagemLoja,
    this.motivoRecusa,
    this.pedido,
    this.ofertaValor,
    this.ofertaStatus,
    this.ofertaMensagem,
    this.ofertaMotivo,
    this.ofertaEm,
  });
  final String id;
  final String orcamentoId;
  final String lojaId;
  final String lojaNome;

  /// Quem pediu (a loja busca nome e telefone no perfil dele).
  final String? construtorId;
  final Loja? loja;
  final ModoProposta modo;
  final StatusProposta status;
  final double subtotalAnunciado;
  final double desconto;
  final double frete;
  final double total;
  final double cashbackPrevisto;
  final double saldoAplicado;
  final String? mensagemConstrutor;

  /// Forma de pagamento que o construtor escolheu para esta loja na cotação.
  final FormaPagamento? formaEscolhida;
  final int? parcelasEscolhidas;
  final String? mensagemLoja;
  final String? motivoRecusa;
  final DateTime validaAte;
  final DateTime criadaEm;
  final List<ItemProposta> itens;
  final PedidoResumo? pedido;

  /// Total que o construtor ofereceu; o dono ou o gerente responde na Mesa do Gerente.
  final double? ofertaValor;
  final StatusOferta? ofertaStatus;
  final String? ofertaMensagem;

  /// Por que a loja recusou a oferta.
  final String? ofertaMotivo;
  final DateTime? ofertaEm;

  /// Proposta fechada não tem mais oferta esperando resposta.
  bool get ofertaPendente => ofertaStatus == StatusOferta.pendente && status.aberta;

  /// Só proposta aberta em negociação, sem oferta esperando, recebe oferta nova.
  bool get aceitaOferta => status.aberta && modo == ModoProposta.negociacao && !ofertaPendente;

  /// Quanto a oferta tira do total.
  double get descontoDaOferta => ofertaValor == null ? 0 : total - ofertaValor!;

  /// Soma dos itens com o preço que vale agora (ofertado na contraproposta, senão o anunciado).
  double get subtotalFinal =>
      (itens.fold(0.0, (s, i) => s + i.total) * 100).roundToDouble() / 100;

  /// O que o construtor paga: total da proposta menos o saldo da carteira reservado.
  double get aPagar => total - saldoAplicado < 0 ? 0 : total - saldoAplicado;

  factory PropostaResumo.fromJson(Map<String, dynamic> j) {
    final lojaJson = j['lojas'] as Map<String, dynamic>?;
    final pedidos = j['pedidos'];
    final pedidoJson = pedidos is List
        ? (pedidos.isEmpty ? null : pedidos.first as Map<String, dynamic>)
        : pedidos as Map<String, dynamic>?;
    return PropostaResumo(
      id: j['id'] as String,
      orcamentoId: j['orcamento_id'] as String,
      lojaId: j['loja_id'] as String,
      construtorId: j['construtor_id'] as String?,
      lojaNome: (lojaJson?['nome'] as String?) ?? 'Loja',
      loja: lojaJson == null ? null : Loja.fromJson(lojaJson),
      modo: ModoProposta.fromCodigo(j['modo'] as String?),
      status: StatusProposta.fromCodigo(j['status'] as String?),
      subtotalAnunciado: lerValor(j['subtotal_anunciado']),
      desconto: lerValor(j['desconto']),
      frete: lerValor(j['frete']),
      total: lerValor(j['total']),
      cashbackPrevisto: lerValor(j['cashback_previsto']),
      saldoAplicado: lerValor(j['saldo_aplicado']),
      mensagemConstrutor: j['mensagem_construtor'] as String?,
      formaEscolhida: FormaPagamento.fromCodigo(j['forma_escolhida'] as String?),
      parcelasEscolhidas: (j['parcelas'] as num?)?.toInt(),
      mensagemLoja: j['mensagem_loja'] as String?,
      motivoRecusa: j['motivo_recusa'] as String?,
      validaAte: DateTime.parse(j['valida_ate'] as String).toLocal(),
      criadaEm: DateTime.parse(j['criada_em'] as String).toLocal(),
      itens: [
        for (final i in (j['proposta_itens'] as List? ?? const []))
          ItemProposta.fromJson(i as Map<String, dynamic>),
      ],
      pedido: pedidoJson == null ? null : PedidoResumo.fromJson(pedidoJson),
      ofertaValor: j['oferta_valor'] == null ? null : lerValor(j['oferta_valor']),
      ofertaStatus: StatusOferta.fromCodigo(j['oferta_status'] as String?),
      ofertaMensagem: j['oferta_mensagem'] as String?,
      ofertaMotivo: j['oferta_motivo'] as String?,
      ofertaEm: j['oferta_em'] == null ? null : DateTime.parse(j['oferta_em'] as String).toLocal(),
    );
  }
}

