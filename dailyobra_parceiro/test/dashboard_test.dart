import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/componentes.dart';
import 'package:dailyobra_parceiro/screens/dashboard_blocos.dart';
import 'package:dailyobra_parceiro/screens/inicio_screen.dart';
import 'package:dailyobra_parceiro/screens/layout_parceiros.dart';
import 'package:dailyobra_parceiro/screens/resultados_mes.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/mercado_service.dart';
import 'package:dailyobra_parceiro/services/ofertas_service.dart';
import 'package:dailyobra_parceiro/services/periodo_resultados.dart';
import 'package:dailyobra_parceiro/services/propostas_loja_service.dart';
import 'package:dailyobra_parceiro/services/resultados_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

DateTime agora() => DateTime(2026, 11, 20, 10);

final periodo = periodoDoMes(DateTime(2026, 11), agora());

ItemProposta item(
  int tier,
  double quantidade,
  double preco, {
  double? oferta,
}) => ItemProposta(
  itemId: 'i$tier',
  nome: 'Item $tier',
  unidade: 'un',
  tier: tier,
  quantidade: quantidade,
  precoAnunciado: preco,
  precoOfertado: oferta,
);

PropostaResumo pedido(
  DateTime quando,
  List<ItemProposta> itens, {
  StatusPedido status = StatusPedido.entregue,
}) => PropostaResumo(
  id: 'p${quando.microsecondsSinceEpoch}',
  orcamentoId: 'o1',
  lojaId: 'minha',
  lojaNome: 'Loja',
  modo: ModoProposta.negociacao,
  status: StatusProposta.aceita,
  subtotalAnunciado: 0,
  desconto: 0,
  frete: 50,
  total: 0,
  cashbackPrevisto: 0,
  saldoAplicado: 0,
  validaAte: quando,
  criadaEm: quando,
  itens: itens,
  pedido: PedidoResumo(id: 'd1', status: status, total: 0, criadoEm: quando),
);

const catalogo = [
  ItemCatalogo(
    id: 'a',
    nome: 'Cimento',
    unidade: 'saco',
    categoriaId: 'basico',
    tier: 1,
    precoReferencia: 40,
    fonteReferencia: 'SINAPI',
  ),
  ItemCatalogo(
    id: 'b',
    nome: 'Tijolo',
    unidade: 'un',
    categoriaId: 'basico',
    tier: 1,
    precoReferencia: 100,
    fonteReferencia: 'SINAPI',
  ),
  ItemCatalogo(
    id: 'c',
    nome: 'Sem referência',
    unidade: 'un',
    categoriaId: 'basico',
    tier: 1,
  ),
  ItemCatalogo(
    id: 'd',
    nome: 'Pausado',
    unidade: 'un',
    categoriaId: 'basico',
    tier: 1,
    precoReferencia: 10,
    fonteReferencia: 'SINAPI',
  ),
];

Oferta preco(String id, double valor, {bool pausada = false}) =>
    Oferta(lojaId: 'minha', itemId: id, preco: valor, pausada: pausada);

Future<void> abrirVazio(
  WidgetTester tester,
  double largura, {
  bool escuro = false,
}) async {
  ResultadosService.instance.definirParaTeste(
    buscar: (_, _) async => const ResultadosPeriodo(),
    percentuais: const {1: 0.01, 2: 0.02, 3: 0.03, 4: 0.05},
  );
  await abrirLargura(
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
}

Future<void> montarMenu(
  WidgetTester tester, {
  bool gere = true,
  bool dono = false,
}) => abrirLargura(
  tester,
  LayoutParceiros(
    aba: Aba.inicio,
    onAba: (_) {},
    novas: 0,
    gere: gere,
    dono: dono,
    loja: minhaLoja,
    conteudo: const Text('Conteúdo'),
  ),
  1366,
);

void main() {
  setUp(() {
    MercadoService.instance.definirParaTeste(() async => null);
    OfertasService.instance.definirParaTeste(catalogo: const []);
    PropostasLojaService.instance.definirParaTeste();
  });

  group('vendas por faixa', () {
    test('soma os produtos do mês por faixa, sem frete', () {
      final faixas = vendasPorFaixa(
        [
          pedido(DateTime(2026, 11, 5), [item(1, 10, 40), item(4, 2, 100)]),
          pedido(DateTime(2026, 11, 6), [item(1, 5, 40)]),
        ],
        periodo,
        const {1: 0.01, 4: 0.05},
      );
      expect([for (final f in faixas) f.tier], [1, 2, 3, 4]);
      expect(faixas[0].total, 600);
      expect(faixas[0].percentual, 0.01);
      expect(faixas[1].total, 0);
      expect(faixas[1].percentual, isNull);
      expect(faixas[3].total, 200);
    });

    test('vale o preço negociado', () {
      final faixas = vendasPorFaixa(
        [
          pedido(DateTime(2026, 11, 5), [item(2, 10, 40, oferta: 35)]),
        ],
        periodo,
        const {},
      );
      expect(faixas[1].total, 350);
    });

    test('deixa de fora pedido cancelado e de outro mês', () {
      final faixas = vendasPorFaixa(
        [
          pedido(DateTime(2026, 11, 5), [
            item(1, 1, 40),
          ], status: StatusPedido.cancelado),
          pedido(DateTime(2026, 10, 31, 23), [item(1, 1, 40)]),
        ],
        periodo,
        const {},
      );
      expect(faixas.every((f) => f.total == 0), isTrue);
    });

    test('faixa desconhecida não quebra a conta', () {
      final faixas = vendasPorFaixa(
        [
          pedido(DateTime(2026, 11, 5), [item(9, 1, 40)]),
        ],
        periodo,
        const {},
      );
      expect(faixas, hasLength(4));
      expect(faixas.every((f) => f.total == 0), isTrue);
    });
  });

  group('preços x referência', () {
    test('mostra primeiro o que mais se afasta da referência', () {
      final lista = compararComReferencia(catalogo, {
        'a': preco('a', 44),
        'b': preco('b', 70),
      }, agora());
      expect([for (final p in lista) p.item.id], ['b', 'a']);
      expect(lista.first.diferenca, closeTo(-0.3, 0.0001));
      expect(lista.last.diferenca, closeTo(0.1, 0.0001));
    });

    test('ignora sem referência, sem preço e pausado', () {
      final lista = compararComReferencia(catalogo, {
        'c': preco('c', 10),
        'd': preco('d', 12, pausada: true),
      }, agora());
      expect(lista, isEmpty);
    });

    test('respeita o limite', () {
      final lista = compararComReferencia(
        catalogo,
        {'a': preco('a', 44), 'b': preco('b', 70)},
        agora(),
        limite: 1,
      );
      expect(lista, hasLength(1));
    });
  });

  group('dólar', () {
    test('lê a resposta da AwesomeAPI', () {
      final dolar = CotacaoDolar.fromJson({
        'USDBRL': {'bid': '5.5163', 'pctChange': '0.227117'},
      });
      expect(dolar.valor, 5.5163);
      expect(dolar.variacao, 0.227117);
    });

    test('não busca de novo dentro de meia hora', () async {
      var chamadas = 0;
      MercadoService.instance.definirParaTeste(() async {
        chamadas++;
        return const CotacaoDolar(valor: 5.5, variacao: 0.1);
      });
      await MercadoService.instance.carregar(agora: DateTime(2026, 11, 6, 10));
      await MercadoService.instance.carregar(
        agora: DateTime(2026, 11, 6, 10, 29),
      );
      expect(chamadas, 1);
      await MercadoService.instance.carregar(
        agora: DateTime(2026, 11, 6, 10, 31),
      );
      expect(chamadas, 2);
      expect(MercadoService.instance.dolar?.valor, 5.5);
    });

    testWidgets('sem resposta a linha só não aparece', (tester) async {
      await abrirVazio(tester, 360);
      await rolarAte(tester, find.text('Cotações de mercado'));
      expect(find.text('Dólar comercial'), findsNothing);
      expect(
        find.textContaining('Coloque preços nos produtos'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('com resposta mostra valor e variação', (tester) async {
      MercadoService.instance.definirParaTeste(
        () async => const CotacaoDolar(valor: 5.5, variacao: 1.5),
      );
      await abrirVazio(tester, 360);
      await rolarAte(tester, find.text('Dólar comercial'));
      expect(find.text(brl.format(5.5)), findsOneWidget);
      expect(find.text('+1,5%'), findsOneWidget);
    });
  });

  group('dashboard sem vendas', () {
    for (final largura in [360.0, 800.0, 1366.0]) {
      for (final escuro in [false, true]) {
        testWidgets('mostra todos os blocos em ${largura.toInt()} px '
            '(${escuro ? 'escuro' : 'claro'})', (tester) async {
          await abrirVazio(tester, largura, escuro: escuro);
          expect(find.text('Faturamento'), findsOneWidget);
          expect(find.text('Conversão de propostas'), findsOneWidget);
          for (final titulo in [
            'Vendas por dia',
            'Vendas e cashback por faixa',
            'Funil de propostas',
            'Cotações de mercado',
            'Top construtores',
            'Produtos mais vendidos',
          ]) {
            await rolarAte(tester, find.text(titulo));
          }
          await rolarAteOFim(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('as quatro faixas aparecem zeradas com o cashback', (
      tester,
    ) async {
      await abrirVazio(tester, 1366);
      await rolarAte(tester, find.text('Faixa 4: Acabamentos'));
      expect(find.text('Faixa 1: Commodities'), findsOneWidget);
      expect(find.textContaining('cashback 5%'), findsOneWidget);
    });
  });

  group('cabeçalho', () {
    Future<void> abrirInicio(WidgetTester tester, double largura) async {
      LojaService.instance.definirParaTeste(loja: minhaLoja);
      await abrirVazio(tester, largura);
      await abrirLargura(tester, const InicioScreen(), largura);
    }

    testWidgets('no computador não repete a loja da barra laranja', (
      tester,
    ) async {
      await abrirInicio(tester, 1366);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text(minhaLoja.nome), findsNothing);
      expect(find.byType(LogoLoja), findsNothing);
    });

    testWidgets('no celular mostra a logo e o nome da loja', (tester) async {
      await abrirInicio(tester, 360);
      expect(find.text(minhaLoja.nome), findsOneWidget);
      expect(find.byType(LogoLoja), findsOneWidget);
    });
  });

  group('menu', () {
    testWidgets('dono vê Dashboard, Sincronização e Usuários', (tester) async {
      await montarMenu(tester, dono: true);
      for (final item in ['Dashboard', 'Sincronização D+0', 'Usuários']) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
    });

    testWidgets('gerente não vê Usuários', (tester) async {
      await montarMenu(tester);
      expect(find.text('Sincronização D+0'), findsOneWidget);
      expect(find.text('Usuários'), findsNothing);
    });

    testWidgets('vendedor não vê Sincronização nem Usuários', (tester) async {
      await montarMenu(tester, gere: false);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Sincronização D+0'), findsNothing);
      expect(find.text('Usuários'), findsNothing);
    });
  });
}
