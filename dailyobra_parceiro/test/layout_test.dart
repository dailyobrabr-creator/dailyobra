import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/componentes.dart';
import 'package:dailyobra_parceiro/screens/layout_parceiros.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      final abas = <Aba>[];

      Future<void> montar(
        WidgetTester tester,
        double largura, {
        Loja loja = minhaLoja,
      }) {
        abas.clear();
        return abrirLargura(
          tester,
          LayoutParceiros(
            aba: Aba.inicio,
            onAba: abas.add,
            novas: 2,
            loja: loja,
            conteudo: const Text('Conteúdo'),
          ),
          largura,
          escuro: escuro,
        );
      }

      testWidgets('celular: abas embaixo', (tester) async {
        await montar(tester, 360);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.text('2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tablet: trilho lateral', (tester) async {
        await montar(tester, 800);
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('computador: menu lateral e barra da loja', (tester) async {
        await montar(tester, 1366);
        expect(find.byKey(const Key('menu-lateral')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('barra-da-loja')),
            matching: find.text(minhaLoja.nome),
          ),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const Key('conteudo-adaptativo'))).width,
          lessThanOrEqualTo(1320),
        );
        await tester.tap(find.text('Produtos'));
        await tester.pump();
        expect(abas, [Aba.produtos]);
        expect(tester.takeException(), isNull);
      });

      testWidgets('nome comprido na barra não estoura', (tester) async {
        await montar(
          tester,
          1366,
          loja: const Loja(
            id: 'l1',
            nome: 'Operário Construção e Acabamentos Materiais para Construção Filial 01 Matriz Rondonópolis',
            cidade: 'Rondonópolis',
            uf: 'MT',
          ),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
