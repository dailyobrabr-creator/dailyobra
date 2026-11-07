import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/componentes.dart';
import 'package:dailyobra_parceiro/screens/financeiro_screen.dart';
import 'package:dailyobra_parceiro/screens/layout_parceiros.dart';
import 'package:dailyobra_parceiro/services/clientes_service.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

final ana = ClienteLoja(
  construtorId: 'c1',
  nome: 'Ana Souza',
  propostas: 1,
  pedidos: 1,
  total: 500,
  ultimoContato: DateTime(2026, 11, 1),
);
final carlos = ClienteLoja(
  construtorId: 'c2',
  nome: 'Carlos Dias',
  propostas: 1,
  pedidos: 0,
  total: 0,
  ultimoContato: DateTime(2026, 11, 2),
);

void preparar({
  PapelLoja papel = PapelLoja.dono,
  List<DuplicataLiberada> duplicatas = const [],
  Loja loja = minhaLoja,
}) {
  LojaService.instance.definirParaTeste(
    loja: loja,
    papel: papel,
    duplicatas: duplicatas,
  );
  ClientesService.instance.definirParaTeste(buscar: () async => [ana, carlos]);
}

Future<void> irPara(WidgetTester tester, String aba) async {
  final alvo = find.descendant(
    of: find.byType(TabBar),
    matching: find.text(aba),
  );
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

Future<void> salvar(WidgetTester tester) async {
  await rolarAte(tester, find.widgetWithText(FilledButton, 'Salvar'));
  await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
  await tester.pumpAndSettle();
}

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('abre em Recebimento, com a chave PIX', (tester) async {
        preparar();
        await abrir(tester, const FinanceiroScreen(), escuro: escuro);
        expect(find.byKey(const ValueKey('chave-pix')), findsOneWidget);
        expect(find.text('Formas que a loja recebe'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('parcelamento grava cartão e boleto', (tester) async {
        preparar();
        await abrir(tester, const FinanceiroScreen(), escuro: escuro);
        await irPara(tester, 'Parcelamento');
        await tester.tap(find.byKey(const ValueKey('parcelas-cartao')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Em até 6x sem juros').last);
        await tester.pumpAndSettle();
        await salvar(tester);
        expect(LojaService.instance.atualizacoesDeTeste.last, {
          'parcelas_cartao': 6,
          'parcelas_boleto': 1,
        });
      });

      testWidgets('parcelamento sem mudança não grava', (tester) async {
        preparar();
        await abrir(tester, const FinanceiroScreen(), escuro: escuro);
        await irPara(tester, 'Parcelamento');
        await salvar(tester);
        expect(find.text('Nada mudou.'), findsOneWidget);
        expect(LojaService.instance.atualizacoesDeTeste, isEmpty);
      });

      testWidgets('parcelamento avisa a forma que falta marcar', (
        tester,
      ) async {
        preparar(
          loja: const Loja(
            id: 'l1',
            nome: 'Casa do Construtor',
            cidade: 'Maringá',
            uf: 'PR',
            formasPagamento: [FormaPagamento.pix, FormaPagamento.cartao],
          ),
        );
        await abrir(tester, const FinanceiroScreen(), escuro: escuro);
        await irPara(tester, 'Parcelamento');
        expect(
          find.text(
            'Marque Boleto em Recebimento para o parcelamento aparecer.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('duplicata: libera um cliente com o prazo', (tester) async {
        preparar();
        await abrir(tester, const FinanceiroScreen(), escuro: escuro);
        await irPara(tester, 'Duplicata');
        expect(find.text('Nenhum cliente com duplicata'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('liberar-duplicata')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('duplicata-cliente')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Carlos Dias').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('duplicata-prazo')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('28/35 dias').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Liberar'));
        await tester.pumpAndSettle();
        expect(LojaService.instance.duplicatasDeTeste, [('c2', '28/35')]);
      });

      testWidgets('duplicata: mostra quem está liberado e retira', (
        tester,
      ) async {
        preparar(
          duplicatas: const [
            DuplicataLiberada(construtorId: 'c1', prazo: '28'),
          ],
        );
        await abrir(tester, const FinanceiroScreen(), escuro: escuro);
        await irPara(tester, 'Duplicata');
        expect(find.text('Ana Souza'), findsOneWidget);
        expect(find.text('Prazo de 28 dias'), findsOneWidget);
        await tester.tap(find.text('Retirar'));
        await tester.pumpAndSettle();
        expect(LojaService.instance.duplicatasDeTeste, [('c1', null)]);
      });

      testWidgets('duplicata: vendedor só vê', (tester) async {
        preparar(
          papel: PapelLoja.vendedor,
          duplicatas: const [
            DuplicataLiberada(construtorId: 'c1', prazo: '28'),
          ],
        );
        await abrir(tester, const FinanceiroScreen(), escuro: escuro);
        await irPara(tester, 'Duplicata');
        expect(find.byKey(const ValueKey('liberar-duplicata')), findsNothing);
        expect(find.text('Retirar'), findsNothing);
      });

      testWidgets('o menu do computador tem Financeiro para quem gere', (
        tester,
      ) async {
        Future<void> montar({required bool gere}) => abrirLargura(
          tester,
          LayoutParceiros(
            aba: Aba.inicio,
            onAba: (_) {},
            novas: 0,
            gere: gere,
            loja: minhaLoja,
            conteudo: const Text('Conteúdo'),
          ),
          1366,
          escuro: escuro,
        );
        await montar(gere: true);
        expect(find.text('Financeiro'), findsOneWidget);
        await montar(gere: false);
        expect(find.text('Financeiro'), findsNothing);
      });
    });
  }
}
