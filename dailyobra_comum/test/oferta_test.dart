import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> linha({
  String status = 'enviada',
  String modo = 'negociacao',
  Map<String, dynamic> oferta = const {},
}) => {
  'id': 'p1',
  'orcamento_id': 'o1',
  'loja_id': 'l1',
  'modo': modo,
  'status': status,
  'subtotal_anunciado': 1000,
  'desconto': 0,
  'frete': 50,
  'total': 1050,
  'cashback_previsto': 10,
  'saldo_aplicado': 0,
  'valida_ate': '2026-11-05T12:00:00+00:00',
  'criada_em': '2026-11-03T12:00:00+00:00',
  ...oferta,
};

const pendente = {
  'oferta_valor': 840,
  'oferta_status': 'pendente',
  'oferta_mensagem': 'Fecho hoje',
  'oferta_em': '2026-11-03T15:00:00+00:00',
};

void main() {
  test('lê a oferta da proposta', () {
    final p = PropostaResumo.fromJson(linha(oferta: pendente));
    expect(p.ofertaValor, 840);
    expect(p.ofertaStatus, StatusOferta.pendente);
    expect(p.ofertaMensagem, 'Fecho hoje');
    expect(p.ofertaMotivo, isNull);
    expect(p.ofertaEm!.toUtc(), DateTime.utc(2026, 11, 3, 15));
    expect(p.descontoDaOferta, 210);
  });

  test('proposta sem oferta', () {
    final p = PropostaResumo.fromJson(linha());
    expect(p.ofertaValor, isNull);
    expect(p.ofertaStatus, isNull);
    expect(p.ofertaPendente, isFalse);
    expect(p.descontoDaOferta, 0);
  });

  test('lê o motivo da recusa', () {
    final p = PropostaResumo.fromJson(
      linha(
        oferta: {
          ...pendente,
          'oferta_status': 'recusada',
          'oferta_motivo': 'Abaixo do custo',
        },
      ),
    );
    expect(p.ofertaStatus, StatusOferta.recusada);
    expect(p.ofertaMotivo, 'Abaixo do custo');
    expect(p.ofertaPendente, isFalse);
  });

  test('proposta traz a forma escolhida na cotação', () {
    expect(PropostaResumo.fromJson({...linha(), 'forma_escolhida': 'boleto'}).formaEscolhida, FormaPagamento.boleto);
    expect(PropostaResumo.fromJson(linha()).formaEscolhida, isNull);
  });

  test('oferta só fica pendente com a proposta aberta', () {
    expect(PropostaResumo.fromJson(linha(oferta: pendente)).ofertaPendente, isTrue);
    expect(PropostaResumo.fromJson(linha(status: 'contraproposta', oferta: pendente)).ofertaPendente, isTrue);
    expect(PropostaResumo.fromJson(linha(status: 'expirada', oferta: pendente)).ofertaPendente, isFalse);
    expect(PropostaResumo.fromJson(linha(status: 'cancelada', oferta: pendente)).ofertaPendente, isFalse);
  });

  test('quem pode fazer oferta', () {
    expect(PropostaResumo.fromJson(linha()).aceitaOferta, isTrue);
    expect(PropostaResumo.fromJson(linha(status: 'contraproposta')).aceitaOferta, isTrue);
    expect(PropostaResumo.fromJson(linha(oferta: pendente)).aceitaOferta, isFalse);
    expect(PropostaResumo.fromJson(linha(modo: 'pedido')).aceitaOferta, isFalse);
    expect(PropostaResumo.fromJson(linha(status: 'aceita')).aceitaOferta, isFalse);
    expect(
      PropostaResumo.fromJson(linha(oferta: {...pendente, 'oferta_status': 'recusada'})).aceitaOferta,
      isTrue,
    );
  });
}
