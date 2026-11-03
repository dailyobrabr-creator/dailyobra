import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> pedido([Map<String, dynamic> extra = const {}]) =>
      {'id': 'p1', 'status': 'confirmado', 'total': 400, 'criado_em': '2026-11-02T12:00:00Z', ...extra};

  group('PedidoResumo.fromJson lê o pagador', () {
    test('link enviado e sem documento: aguardando os dados do cliente', () {
      final p = PedidoResumo.fromJson(pedido({'pagador': 'cliente', 'pagador_nome': 'Ana', 'pagador_whatsapp': '66999990000', 'link_codigo': 'abc', 'documento_informado_em': null}));
      expect(p.pagador, Pagador.cliente);
      expect(p.pagadorNome, 'Ana');
      expect(p.pagadorWhatsapp, '66999990000');
      expect(p.linkCodigo, 'abc');
      expect(p.documentoInformadoEm, isNull);
      expect(p.situacaoPagamento, SituacaoPagamento.aguardandoDados);
    });
    test('documento informado: aguardando o pagamento', () {
      final p = PedidoResumo.fromJson(pedido({'pagador': 'cliente', 'link_codigo': 'abc', 'documento_informado_em': '2026-11-02T13:00:00Z'}));
      expect(p.situacaoPagamento, SituacaoPagamento.aguardandoPagamento);
    });
    test('cliente avisou que pagou: informado', () {
      final p = PedidoResumo.fromJson(pedido({'pagador': 'cliente', 'documento_informado_em': '2026-11-02T13:00:00Z', 'pagamento_informado_em': '2026-11-02T14:32:00Z'}));
      expect(p.pagamentoInformadoEm, DateTime.parse('2026-11-02T14:32:00Z').toLocal());
      expect(p.situacaoPagamento, SituacaoPagamento.informado);
    });
    test('loja confirmou: pago', () {
      final p = PedidoResumo.fromJson(pedido({'pagador': 'proprio', 'documento_informado_em': '2026-11-02T13:00:00Z', 'pagamento_confirmado_em': '2026-11-02T15:00:00Z'}));
      expect(p.pagador, Pagador.proprio);
      expect(p.situacaoPagamento, SituacaoPagamento.pago);
    });
    test('cancelado vale mais que o aviso de pagamento', () {
      final p = PedidoResumo.fromJson(pedido({'status': 'cancelado', 'pagador': 'cliente', 'pagamento_informado_em': '2026-11-02T14:32:00Z'}));
      expect(p.situacaoPagamento, SituacaoPagamento.cancelado);
    });
    test('pedido sem escolha de quem paga', () {
      final p = PedidoResumo.fromJson(pedido());
      expect(p.pagador, isNull);
      expect(p.situacaoPagamento, SituacaoPagamento.semPagador);
    });
  });

  test('PedidoResumo.fromJson lê forma e prazo', () {
    final p = PedidoResumo.fromJson(pedido({'pagador': 'proprio', 'forma_pagamento': 'crediario', 'prazo': '28/35', 'prazo_status': 'pendente', 'prazo_respondido_em': null}));
    expect(p.formaPagamento, FormaPagamento.crediario);
    expect(p.prazo, '28/35');
    expect(p.prazoStatus, StatusPrazo.pendente);
    expect(p.prazoRespondidoEm, isNull);
    final sem = PedidoResumo.fromJson(pedido());
    expect(sem.formaPagamento, isNull);
    expect(sem.prazo, isNull);
    expect(sem.prazoStatus, isNull);
  });

  test('rótulos das formas e prazos do crediário', () {
    expect(FormaPagamento.pix.rotulo, 'PIX');
    expect(FormaPagamento.cartao.rotulo, 'Cartão na loja');
    expect(FormaPagamento.crediario.rotulo, 'Crediário da loja');
    expect(FormaPagamento.fromCodigo('boleto'), isNull);
    expect(StatusPrazo.fromCodigo('aprovado'), StatusPrazo.aprovado);
    expect(prazosCrediario, ['28', '28/35', '28/35/42']);
  });

  test('link de pagamento e mensagem do WhatsApp', () {
    expect(linkDePagamento('xyz'), 'https://dailyobrabr-creator.github.io/dailyobra/pagar/?c=xyz');
    expect(
      mensagemDoLink(nome: 'Ana', loja: 'Taipa', total: 1234.5, link: 'L'),
      'Olá, Ana! Preparei os materiais da sua obra na Taipa: total ${brl.format(1234.5)}. Para pagar direto à loja por PIX e receber a nota no seu nome, abra: L',
    );
  });

  test('WhatsApp com máscara ou com +55 vira um número só, sem 5555', () {
    expect(linkWhatsApp('(66) 99999-0000', 'oi').toString(), 'https://wa.me/5566999990000?text=oi');
    expect(linkWhatsApp('+55 66 99999-0000', 'oi').toString(), 'https://wa.me/5566999990000?text=oi');
    expect(linkWhatsApp('6633334444', 'olá, tudo bem?').toString(), 'https://wa.me/556633334444?text=${Uri.encodeComponent('olá, tudo bem?')}');
  });

  test('CPF e CNPJ com ou sem pontuação', () {
    expect(documentoValido('529.982.247-25'), isTrue);
    expect(documentoValido('11.222.333/0001-81'), isTrue);
    expect(documentoValido('52998224725'), isTrue);
    expect(documentoValido('111.111.111-11'), isFalse);
    expect(documentoValido('529.982.247-24'), isFalse);
    expect(documentoValido('123'), isFalse);
    expect(somenteDigitos('529.982.247-25'), '52998224725');
  });

  test('CPF e CNPJ formatados para a nota', () {
    expect(formatarDocumento('52998224725'), '529.982.247-25');
    expect(formatarDocumento('11222333000181'), '11.222.333/0001-81');
    expect(formatarDocumento('123'), '123');
  });

  test('chave PIX: CPF, CNPJ, e-mail, celular com +55 ou aleatória', () {
    for (final boa in ['+5566999990000', '52998224725', '11222333000181', 'loja@exemplo.com', '123e4567-e12b-12d1-a456-426655440000']) {
      expect(chavePixInvalida(boa), isNull, reason: boa);
    }
    for (final ruim in ['66999990000', 'loja@', '', '+55669']) {
      expect(chavePixInvalida(ruim), 'Chave PIX inválida. Use CPF, CNPJ, e-mail, celular com +55 ou chave aleatória.', reason: ruim);
    }
  });

  test('chave PIX digitada com pontuação fica como o banco guarda', () {
    expect(normalizarChavePix(' 11.222.333/0001-81 '), '11222333000181');
    expect(normalizarChavePix('529.982.247-25'), '52998224725');
    expect(normalizarChavePix('+55 (66) 99999-0000'), '+5566999990000');
    expect(normalizarChavePix('123E4567-E12B-12D1-A456-426655440000'), '123e4567-e12b-12d1-a456-426655440000');
    expect(normalizarChavePix(' Loja@Exemplo.com '), 'loja@exemplo.com');
    expect(normalizarChavePix('loja'), 'loja');
  });
}
