import 'package:dailyobra/screens/proposta_screen.dart';
import 'package:dailyobra/services/negociacao_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

PropostaResumo proposta({
  StatusProposta status = StatusProposta.enviada,
  ModoProposta modo = ModoProposta.negociacao,
  double? ofertaValor,
  StatusOferta? ofertaStatus,
  String? ofertaMotivo,
}) => PropostaResumo(
  id: 'p1',
  orcamentoId: 'o1',
  lojaId: 'a',
  lojaNome: 'Casa do Construtor',
  modo: modo,
  status: status,
  subtotalAnunciado: 1000,
  desconto: 0,
  frete: 50,
  total: 1050,
  cashbackPrevisto: 10,
  saldoAplicado: 0,
  validaAte: DateTime.now().add(const Duration(hours: 40)),
  criadaEm: DateTime.now(),
  itens: const [],
  ofertaValor: ofertaValor,
  ofertaStatus: ofertaStatus,
  ofertaMotivo: ofertaMotivo,
);

Finder campo(String rotulo) => find.descendant(
  of: find.widgetWithText(CampoTexto, rotulo),
  matching: find.byType(TextField),
);

Future<void> abrirProposta(
  WidgetTester tester,
  PropostaResumo p, {
  required bool escuro,
}) {
  NegociacaoService.instance.definirParaTeste(propostas: [p]);
  return abrir(tester, const PropostaScreen(id: 'p1'), escuro: escuro);
}

Future<void> abrirOferta(WidgetTester tester) async {
  await tester.tap(find.text('Fazer uma oferta'));
  await tester.pumpAndSettle();
}

Future<void> enviar(WidgetTester tester, String valor) async {
  await tester.enterText(campo('Sua oferta (R\$)'), valor);
  await tester.tap(find.text('Enviar oferta'));
  await tester.pumpAndSettle();
}

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('aguardando a loja: pode oferecer ou cancelar', (
        tester,
      ) async {
        await abrirProposta(tester, proposta(), escuro: escuro);
        expect(find.text('Fazer uma oferta'), findsOneWidget);
        expect(find.text('Cancelar proposta'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('contraproposta: também pode oferecer', (tester) async {
        await abrirProposta(
          tester,
          proposta(status: StatusProposta.contraproposta),
          escuro: escuro,
        );
        expect(find.text('Fazer uma oferta'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Aceitar'), findsOneWidget);
      });

      testWidgets('pedido direto não oferece', (tester) async {
        await abrirProposta(
          tester,
          proposta(modo: ModoProposta.pedido),
          escuro: escuro,
        );
        expect(find.text('Fazer uma oferta'), findsNothing);
      });

      testWidgets('avisa que a aprovação vira pedido', (tester) async {
        await abrirProposta(tester, proposta(), escuro: escuro);
        await abrirOferta(tester);
        expect(find.textContaining('vira pedido na hora'), findsOneWidget);
        expect(find.textContaining(brl.format(1050)), findsWidgets);
      });

      testWidgets('oferta precisa ser menor que o total', (tester) async {
        await abrirProposta(tester, proposta(), escuro: escuro);
        await abrirOferta(tester);
        await enviar(tester, '1050');
        expect(
          find.text('Precisa ser menor que ${brl.format(1050)}.'),
          findsOneWidget,
        );
        expect(NegociacaoService.instance.ofertasDeTeste, isEmpty);
      });

      testWidgets('oferta precisa cobrir o frete', (tester) async {
        await abrirProposta(tester, proposta(), escuro: escuro);
        await abrirOferta(tester);
        await enviar(tester, '50');
        expect(
          find.text('Precisa ser maior que o frete de ${brl.format(50)}.'),
          findsOneWidget,
        );
      });

      testWidgets('oferta vazia pede o valor', (tester) async {
        await abrirProposta(tester, proposta(), escuro: escuro);
        await abrirOferta(tester);
        await enviar(tester, '');
        expect(find.text('Digite o valor da oferta.'), findsOneWidget);
      });

      testWidgets('envia valor e mensagem', (tester) async {
        await abrirProposta(tester, proposta(), escuro: escuro);
        await abrirOferta(tester);
        await tester.enterText(campo('Mensagem para a loja'), '  Fecho hoje ');
        await enviar(tester, '840,50');
        expect(NegociacaoService.instance.ofertasDeTeste, [
          ('p1', 840.5, 'Fecho hoje'),
        ]);
        expect(find.text('Oferta enviada para a loja.'), findsOneWidget);
      });

      testWidgets('oferta esperando resposta tira o botão', (tester) async {
        await abrirProposta(
          tester,
          proposta(ofertaValor: 840, ofertaStatus: StatusOferta.pendente),
          escuro: escuro,
        );
        expect(find.text('Fazer uma oferta'), findsNothing);
        expect(
          find.textContaining('Sua oferta de ${brl.format(840)}'),
          findsOneWidget,
        );
      });

      testWidgets('oferta recusada mostra o motivo e deixa tentar de novo', (
        tester,
      ) async {
        await abrirProposta(
          tester,
          proposta(
            ofertaValor: 840,
            ofertaStatus: StatusOferta.recusada,
            ofertaMotivo: 'Abaixo do que podemos',
          ),
          escuro: escuro,
        );
        expect(
          find.text(
            'A loja recusou sua oferta de ${brl.format(840)}: Abaixo do que podemos',
          ),
          findsOneWidget,
        );
        expect(find.text('Fazer uma oferta'), findsOneWidget);
      });

      testWidgets('oferta aprovada aparece na proposta aceita', (tester) async {
        await abrirProposta(
          tester,
          proposta(
            status: StatusProposta.aceita,
            ofertaValor: 840,
            ofertaStatus: StatusOferta.aprovada,
          ),
          escuro: escuro,
        );
        expect(
          find.text('A loja aprovou sua oferta de ${brl.format(840)}.'),
          findsOneWidget,
        );
      });
    });
  }
}
