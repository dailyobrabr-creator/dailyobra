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
        Aba aba = Aba.inicio,
      }) {
        abas.clear();
        return abrirLargura(
          tester,
          LayoutParceiros(
            aba: aba,
            onAba: abas.add,
            novas: 2,
            pedidos: 3,
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
        expect(find.text('3'), findsOneWidget);
        for (final rotulo in [
          'Dashboard',
          'Propostas',
          'Pedidos',
          'Produtos',
          'Mais',
        ]) {
          expect(find.text(rotulo), findsOneWidget);
        }
        expect(find.text('Clientes'), findsNothing);
        await tester.tap(find.text('Mais'));
        await tester.pump();
        expect(abas, [Aba.configuracoes]);
        expect(tester.takeException(), isNull);
      });

      testWidgets('celular com Clientes aberto marca Mais', (tester) async {
        await montar(tester, 360, aba: Aba.clientes);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          4,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('tablet: trilho lateral', (tester) async {
        await montar(tester, 800);
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('2'), findsOneWidget);
        await tester.tap(find.byTooltip('Clientes'));
        await tester.pump();
        expect(abas, [Aba.clientes]);
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
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        await tester.tap(find.text('Produtos'));
        await tester.tap(find.text('Pedidos'));
        await tester.tap(find.text('Clientes'));
        await tester.tap(find.text('Configurações'));
        await tester.pump();
        expect(abas, [
          Aba.produtos,
          Aba.pedidos,
          Aba.clientes,
          Aba.configuracoes,
        ]);
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
