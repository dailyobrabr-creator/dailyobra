import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/graficos_resultados.dart';
import 'package:dailyobra_parceiro/screens/inicio_screen.dart';
import 'package:dailyobra_parceiro/screens/resultados_mes.dart';
import 'package:dailyobra_parceiro/services/resultados_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

DateTime agora() => DateTime(2026, 11, 20, 14, 30);

final completo = DesempenhoPeriodo(
  vendasPorDia: [
    VendaDoDia(dia: DateTime(2026, 11, 2), total: 1500, pedidos: 2),
    VendaDoDia(dia: DateTime(2026, 11, 10), total: 400, pedidos: 1),
  ],
  propostas: 7,
  respondidas: 5,
  viraramPedido: 2,
  produtos: const [
    ProdutoVendido(
      itemId: 'a',
      nome: 'Cimento CP II 50 kg',
      unidade: 'saco',
      quantidade: 12,
      total: 600,
    ),
    ProdutoVendido(
      itemId: 'b',
      nome: 'Tijolo cerâmico 8 furos',
      unidade: 'unidade',
      quantidade: 2.5,
      total: 300,
    ),
  ],
);

const comPedido = ResultadosPeriodo(faturamento: 1900, pedidos: 3);

final pedidosDesempenho = <DateTime>[];

void usar(
  DesempenhoPeriodo desempenho, {
  ResultadosPeriodo periodo = comPedido,
}) {
  pedidosDesempenho.clear();
  ResultadosService.instance.definirParaTeste(
    buscar: (_, _) async => periodo,
    buscarDesempenho: (de, _) async {
      pedidosDesempenho.add(de);
      return desempenho;
    },
  );
}

Future<void> abrirNaLargura(
  WidgetTester tester,
  double largura, {
  required bool escuro,
}) => abrirLargura(
  tester,
  Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: const [ResultadosDoMes(agora: agora)],
    ),
  ),
  largura,
  escuro: escuro,
);

/// Toca na coluna do dia (1 a 30 em novembro).
Future<void> tocarDia(WidgetTester tester, int dia) async {
  await rolarAte(tester, find.byKey(const Key('grafico-vendas')));
  final area = find.byKey(const Key('grafico-vendas'));
  final largura = tester.getSize(area).width;
  final x = centroDaColuna(dia - 1, largura, 30);
  await tester.tapAt(tester.getTopLeft(area) + Offset(x, 60));
  await tester.pump();
}

void main() {
  group('DesempenhoPeriodo', () {
    test('lê a resposta do banco', () {
      final d = DesempenhoPeriodo.fromJson({
        'vendas_por_dia': [
          {'dia': '2026-10-02', 'total': 1500.5, 'pedidos': 2},
        ],
        'propostas': 7,
        'respondidas': 5,
        'viraram_pedido': 2,
        'produtos': [
          {
            'item_id': 'a',
            'nome': 'Cimento',
            'unidade': 'saco',
            'quantidade': 12,
            'total': 600,
          },
        ],
      });
      expect(d.vendasPorDia.single.dia, DateTime(2026, 10, 2));
      expect(d.vendasPorDia.single.total, 1500.5);
      expect(d.vendasPorDia.single.pedidos, 2);
      expect(d.propostas, 7);
      expect(d.respondidas, 5);
      expect(d.viraramPedido, 2);
      expect(d.produtos.single.nome, 'Cimento');
      expect(d.produtos.single.quantidade, 12);
      expect(d.produtos.single.total, 600);
    });

    test('conversão sobre as propostas recebidas', () {
      expect(completo.conversao, closeTo(2 / 7, 0.0001));
      expect(const DesempenhoPeriodo().conversao, isNull);
    });
  });

  group('contas do gráfico', () {
    test('todos os dias do mês, com zero nos dias sem venda', () {
      final dias = diasDoMes(DateTime(2026, 11), completo.vendasPorDia);
      expect(dias, hasLength(30));
      expect(dias.first.dia, DateTime(2026, 11, 1));
      expect(dias.first.total, 0);
      expect(dias[1].total, 1500);
      expect(dias.last.dia, DateTime(2026, 11, 30));
      expect(diasDoMes(DateTime(2026, 2), const []), hasLength(28));
      expect(diasDoMes(DateTime(2026, 10), const []), hasLength(31));
    });

    test('venda fora do mês fica de fora', () {
      final dias = diasDoMes(DateTime(2026, 11), [
        VendaDoDia(dia: DateTime(2026, 12, 1), total: 9, pedidos: 1),
      ]);
      expect(dias.every((d) => d.total == 0), isTrue);
    });

    test('melhor dia é o de maior venda, e o primeiro no empate', () {
      expect(melhorDia(completo.vendasPorDia)!.total, 1500);
      expect(
        melhorDia([
          VendaDoDia(dia: DateTime(2026, 11, 1), total: 5, pedidos: 1),
          VendaDoDia(dia: DateTime(2026, 11, 2), total: 5, pedidos: 1),
        ])!.dia,
        DateTime(2026, 11, 1),
      );
      expect(melhorDia(const []), isNull);
    });

    test('topo da escala é um número redondo', () {
      expect(topoDaEscala(0), 1);
      expect(topoDaEscala(1), 1);
      expect(topoDaEscala(9), 10);
      expect(topoDaEscala(120), 200);
      expect(topoDaEscala(1000), 1000);
      expect(topoDaEscala(1500), 2000);
      expect(topoDaEscala(4200), 5000);
      expect(topoDaEscala(5100), 10000);
    });

    test('rótulo da escala por extenso até 10 mil', () {
      expect(rotuloDaEscala(0), '0');
      expect(rotuloDaEscala(500), '500');
      expect(rotuloDaEscala(1000), '1.000');
      expect(rotuloDaEscala(10000), '10 mil');
      expect(rotuloDaEscala(2500000), '2,5 mi');
    });

    test('toque vai para a coluna mais próxima', () {
      expect(diaDoToque(0, 300, 30), 0);
      expect(diaDoToque(1000, 300, 30), 29);
      expect(diaDoToque(centroDaColuna(14, 300, 30), 300, 30), 14);
    });

    test('percentual com uma casa', () {
      expect(textoPercentual(2 / 7), '28,6%');
      expect(textoPercentual(1), '100%');
      expect(textoPercentual(0), '0%');
    });
  });

  group('serviço', () {
    tearDown(ResultadosService.instance.limpar);

    test('carrega o desempenho do mesmo mês dos resultados', () async {
      usar(completo);
      await ResultadosService.instance.carregar(
        DateTime(2026, 11),
        agora: agora(),
      );
      expect(ResultadosService.instance.desempenho, completo);
      expect(pedidosDesempenho, [DateTime(2026, 11)]);
    });

    test('trocar de mês esconde o desempenho do mês anterior', () async {
      usar(completo);
      final servico = ResultadosService.instance;
      await servico.carregar(DateTime(2026, 11), agora: agora());
      final trocando = servico.carregar(DateTime(2026, 10), agora: agora());
      expect(servico.desempenho, isNull);
      await trocando;
      expect(servico.desempenho, completo);
    });

    test('falha no desempenho aparece como erro', () async {
      ResultadosService.instance.definirParaTeste(
        buscar: (_, _) async => comPedido,
        buscarDesempenho: (_, _) async =>
            throw const FalhaComMensagem('Sem internet.'),
      );
      await ResultadosService.instance.carregar(
        DateTime(2026, 11),
        agora: agora(),
      );
      expect(ResultadosService.instance.erro, 'Sem internet.');
    });
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      tearDown(ResultadosService.instance.limpar);

      testWidgets('gráfico mostra o melhor dia', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 360, escuro: escuro);
        await rolarAte(tester, find.text('Vendas por dia'));
        expect(
          find.text('Melhor dia: 02/11 · ${brl.format(1500)}'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('tocar numa coluna mostra o dia', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 360, escuro: escuro);
        await tocarDia(tester, 10);
        expect(
          find.text('10/11: ${brl.format(400)} · 1 pedido'),
          findsOneWidget,
        );
        await tocarDia(tester, 2);
        expect(
          find.text('02/11: ${brl.format(1500)} · 2 pedidos'),
          findsOneWidget,
        );
        await tocarDia(tester, 5);
        expect(find.text('05/11: sem vendas'), findsOneWidget);
      });

      testWidgets('tocar de novo volta para o melhor dia', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 360, escuro: escuro);
        await tocarDia(tester, 10);
        await tocarDia(tester, 10);
        expect(find.textContaining('Melhor dia'), findsOneWidget);
      });

      testWidgets('dia a dia lista só os dias com venda', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 360, escuro: escuro);
        await rolarAte(tester, find.text('Ver dia a dia'));
        await tester.tap(find.text('Ver dia a dia'));
        await tester.pumpAndSettle();
        expect(find.text('02/11'), findsOneWidget);
        expect(find.text('2 pedidos'), findsOneWidget);
        expect(find.text('10/11'), findsOneWidget);
        expect(find.text('1 pedido'), findsOneWidget);
        expect(find.text('05/11'), findsNothing);
      });

      testWidgets('funil com percentuais e conversão', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 360, escuro: escuro);
        await rolarAte(tester, find.text('Funil de propostas'));
        await rolarAte(tester, find.textContaining('viraram pedido'));
        expect(find.text('Recebidas'), findsOneWidget);
        expect(find.text('Respondidas'), findsOneWidget);
        expect(find.text('Viraram pedido'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        expect(find.text('5 · 71,4%'), findsOneWidget);
        expect(find.text('2 · 28,6%'), findsOneWidget);
        expect(find.text('28,6% das propostas viraram pedido'), findsOneWidget);
      });

      testWidgets('produtos do maior valor ao menor', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 360, escuro: escuro);
        await rolarAte(tester, find.text('Produtos mais vendidos'));
        await rolarAte(tester, find.textContaining('sem frete'));
        final cimento = tester.getTopLeft(find.text('Cimento CP II 50 kg'));
        final tijolo = tester.getTopLeft(find.text('Tijolo cerâmico 8 furos'));
        expect(cimento.dy, lessThan(tijolo.dy));
        expect(find.text('12 saco · ${brl.format(600)}'), findsOneWidget);
        expect(find.text('2,5 unidade · ${brl.format(300)}'), findsOneWidget);
      });

      testWidgets('nome de produto comprido não estoura', (tester) async {
        usar(
          const DesempenhoPeriodo(
            produtos: [
              ProdutoVendido(
                itemId: 'a',
                nome: 'Argamassa colante flexível ACIII cinza para porcelanato e áreas externas 20 kg',
                unidade: 'saco',
                quantidade: 1234.5,
                total: 1234567.89,
              ),
            ],
          ),
        );
        await abrirNaLargura(tester, 360, escuro: escuro);
        await rolarAte(tester, find.text('Produtos mais vendidos'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('mês sem venda não desenha gráfico nem produtos', (
        tester,
      ) async {
        usar(
          const DesempenhoPeriodo(propostas: 3, respondidas: 1),
          periodo: const ResultadosPeriodo(),
        );
        await abrirNaLargura(tester, 360, escuro: escuro);
        expect(find.text('Vendas por dia'), findsNothing);
        expect(find.text('Produtos mais vendidos'), findsNothing);
        await rolarAte(tester, find.text('Funil de propostas'));
        expect(find.text('0 · 0%'), findsOneWidget);
      });

      testWidgets('mês sem proposta não desenha o funil', (tester) async {
        usar(const DesempenhoPeriodo(), periodo: const ResultadosPeriodo());
        await abrirNaLargura(tester, 360, escuro: escuro);
        expect(find.text('Funil de propostas'), findsNothing);
      });

      testWidgets('computador põe funil e produtos lado a lado', (
        tester,
      ) async {
        usar(completo);
        await abrirNaLargura(tester, 1366, escuro: escuro);
        await rolarAte(tester, find.text('Vendas por dia'));
        await rolarAte(tester, find.text('Funil de propostas'));
        expect(
          tester.getTopLeft(find.text('Funil de propostas')).dy,
          tester.getTopLeft(find.text('Produtos mais vendidos')).dy,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('computador põe os quatro números numa linha só', (
        tester,
      ) async {
        usar(completo);
        await abrirNaLargura(tester, 1366, escuro: escuro);
        expect(
          tester.getTopLeft(find.text('Faturamento')).dy,
          tester.getTopLeft(find.text('Ticket médio')).dy,
        );
        expect(
          tester.getSize(find.widgetWithText(Indicador, 'Faturamento')).height,
          lessThan(160),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('tablet cabe os quatro números sem estourar', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 680, escuro: escuro);
        expect(
          tester.getTopLeft(find.widgetWithText(Indicador, 'Faturamento')).dy,
          tester.getTopLeft(find.widgetWithText(Indicador, 'Ticket médio')).dy,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('celular mantém os números em duas colunas', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 360, escuro: escuro);
        expect(
          tester.getTopLeft(find.text('Faturamento')).dy,
          lessThan(tester.getTopLeft(find.text('Ticket médio')).dy),
        );
      });

      testWidgets('coluna tem no máximo 24 px no computador', (tester) async {
        usar(completo);
        await abrirNaLargura(tester, 1366, escuro: escuro);
        await rolarAte(tester, find.byKey(const Key('grafico-vendas')));
        expect(
          larguraDaColuna(
            tester.getSize(find.byKey(const Key('grafico-vendas'))).width,
            30,
          ),
          lessThanOrEqualTo(24),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
