import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/inicio_screen.dart';
import 'package:dailyobra_parceiro/screens/resultados_mes.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/ofertas_service.dart';
import 'package:dailyobra_parceiro/services/propostas_loja_service.dart';
import 'package:dailyobra_parceiro/services/resultados_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

DateTime agora() => DateTime(2026, 11, 3, 14, 30);

const novembro = ResultadosPeriodo(
  faturamento: 3150,
  pedidos: 9,
  cashback: 46,
  top: [
    ConstrutorTop(
      construtorId: 'c1',
      nome: 'Ana Souza',
      empresa: 'Souza Obras',
      pedidos: 2,
      total: 1500,
    ),
    ConstrutorTop(construtorId: 'c2', pedidos: 1, total: 800),
  ],
);

/// Começo de cada período pedido ao serviço, na ordem.
final pedidos = <DateTime>[];

void usar(ResultadosPeriodo Function(DateTime de) resposta) {
  pedidos.clear();
  ResultadosService.instance.definirParaTeste(
    buscar: (de, ate) async {
      pedidos.add(de);
      return resposta(de);
    },
  );
}

Future<void> abrirResultados(WidgetTester tester, {required bool escuro}) =>
    abrir(
      tester,
      Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(Espaco.s4),
          children: const [ResultadosDoMes(agora: agora)],
        ),
      ),
      escuro: escuro,
    );

Finder valorDo(String rotulo, String valor) => find.descendant(
  of: find.widgetWithText(Indicador, rotulo),
  matching: find.text(valor),
);

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('dono vê os resultados do mês', (tester) async {
        usar(
          (de) => de == DateTime(2026, 11)
              ? novembro
              : const ResultadosPeriodo(faturamento: 2000, pedidos: 5),
        );
        await abrirResultados(tester, escuro: escuro);
        expect(find.text('Resultados do mês'), findsOneWidget);
        expect(find.text('novembro de 2026'), findsOneWidget);
        expect(valorDo('Faturamento', brl.format(3150)), findsOneWidget);
        expect(
          find.text('Faturamento: +57,5% sobre o mesmo período de outubro'),
          findsOneWidget,
        );
        expect(valorDo('Pedidos fechados', '9'), findsOneWidget);
        expect(valorDo('Ticket médio', brl.format(350)), findsOneWidget);
        expect(
          valorDo('Cashback gerado para os clientes', brl.format(46)),
          findsOneWidget,
        );
        await rolarAte(tester, find.text('1 pedido'));
        expect(find.text('Top construtores'), findsOneWidget);
        expect(find.text('Ana Souza'), findsOneWidget);
        expect(find.text('Souza Obras · 2 pedidos'), findsOneWidget);
        expect(find.text(brl.format(1500)), findsOneWidget);
        expect(find.text('Construtor'), findsOneWidget);
        expect(find.text('1 pedido'), findsOneWidget);
        expect(find.text(brl.format(800)), findsOneWidget);
      });

      testWidgets('voltar um mês e voltar para o atual', (tester) async {
        usar((de) => const ResultadosPeriodo(faturamento: 100, pedidos: 1));
        await abrirResultados(tester, escuro: escuro);
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.chevron_right),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('Mês anterior'));
        await tester.pumpAndSettle();
        expect(find.text('outubro de 2026'), findsOneWidget);
        expect(pedidos.skip(2), [DateTime(2026, 10), DateTime(2026, 9)]);
        expect(find.text('Faturamento: 0,0% sobre setembro'), findsOneWidget);
        await tester.tap(find.byTooltip('Próximo mês'));
        await tester.pumpAndSettle();
        expect(find.text('novembro de 2026'), findsOneWidget);
      });

      testWidgets('mês vazio', (tester) async {
        usar((de) => const ResultadosPeriodo());
        await abrirResultados(tester, escuro: escuro);
        expect(find.text('Nenhum pedido em novembro ainda.'), findsOneWidget);
        expect(valorDo('Ticket médio', '—'), findsOneWidget);
        expect(
          find.text('Faturamento: sem vendas em outubro para comparar'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Mês anterior'));
        await tester.pumpAndSettle();
        expect(find.text('Nenhum pedido em outubro.'), findsOneWidget);
      });

      testWidgets('erro aparece', (tester) async {
        ResultadosService.instance.definirParaTeste(
          buscar: (de, ate) async =>
              throw const FalhaComMensagem('Sem conexão.'),
        );
        await abrirResultados(tester, escuro: escuro);
        expect(find.text('Sem conexão.'), findsOneWidget);
      });

      testWidgets('vendedor não vê a seção', (tester) async {
        usar((de) => novembro);
        LojaService.instance.definirParaTeste(
          loja: minhaLoja,
          papel: PapelLoja.vendedor,
        );
        PropostasLojaService.instance.definirParaTeste();
        OfertasService.instance.definirParaTeste(
          categorias: categoriasTeste,
          catalogo: catalogoTeste,
        );
        await abrir(tester, const InicioScreen(), escuro: escuro);
        await rolarAteOFim(tester);
        expect(find.text('Resultados do mês'), findsNothing);
        expect(pedidos, isEmpty);
        LojaService.instance.definirParaTeste(
          loja: minhaLoja,
          papel: PapelLoja.dono,
        );
        await tester.pumpAndSettle();
        await rolarAte(tester, find.text('Resultados do mês'));
        expect(find.text('Resultados do mês'), findsOneWidget);
        expect(pedidos, isNotEmpty);
      });
    });
  }
}
