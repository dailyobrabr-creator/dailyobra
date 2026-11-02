import 'package:dailyobra/screens/carteira_screen.dart';
import 'package:dailyobra/screens/proposta_screen.dart';
import 'package:dailyobra/screens/topo_vitrine.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra/services/economia_service.dart';
import 'package:dailyobra/services/negociacao_service.dart';
import 'package:dailyobra/services/novidades_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

Future<void> abrirLargura(
  WidgetTester tester,
  Widget tela,
  double largura, {
  bool escuro = false,
}) async {
  tester.view.physicalSize = Size(largura, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro(ThemeData.light().textTheme),
      darkTheme: AppTheme.escuro(ThemeData.dark().textTheme),
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: tela,
    ),
  );
  await tester.pumpAndSettle();
}

PropostaResumo contraproposta() => PropostaResumo(
  id: 'p1',
  orcamentoId: 'o1',
  lojaId: 'a',
  lojaNome: 'Casa do Construtor',
  loja: lojaA,
  modo: ModoProposta.negociacao,
  status: StatusProposta.contraproposta,
  subtotalAnunciado: 450,
  desconto: 20,
  frete: 50,
  total: 450,
  cashbackPrevisto: 4,
  saldoAplicado: 0,
  validaAte: DateTime.now().add(const Duration(hours: 5)),
  criadaEm: DateTime.now().subtract(const Duration(hours: 2)),
  itens: const [
    ItemProposta(
      itemId: 'cimento-cp2-50kg',
      nome: 'Cimento CP II 50 kg',
      unidade: 'saco',
      tier: 1,
      quantidade: 10,
      precoAnunciado: 45,
      precoOfertado: 42,
    ),
  ],
);

final novidades = [
  Novidade(
    tipo: TipoNovidade.contraproposta,
    quando: DateTime.now().subtract(const Duration(hours: 2)),
    propostaId: 'p1',
    lojaNome: 'Casa do Construtor',
  ),
  Novidade(
    tipo: TipoNovidade.saiuEntrega,
    quando: DateTime.now().subtract(const Duration(days: 1)),
    pedidoId: 'd1',
    lojaNome: 'Depósito Bom Preço',
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PerfilService.instance.definirParaTeste(
      nome: 'Ana Souza',
      cidade: 'Maringá',
      uf: 'PR',
    );
    CatalogoService.instance.definirParaTeste(
      categorias: categoriasTeste,
      itens: itensTeste,
      lojas: const [lojaA, lojaB],
      ofertas: ofertasTeste,
    );
    NegociacaoService.instance.definirParaTeste(propostas: [contraproposta()]);
    CarteiraService.instance.definirParaTeste(disponivel: 125.5, pendente: 50);
    EconomiaService.instance.definirParaTeste([
      for (var m = 6; m <= 10; m++)
        EconomiaMes(
          mes: DateTime(2026, m),
          comparando: 10.0 * m,
          negociando: 0,
          cashback: 0,
        ),
      EconomiaMes(
        mes: DateTime(2026, 11),
        comparando: 70,
        negociando: 50,
        cashback: 4,
      ),
    ]);
  });

  testWidgets('sino mostra as não vistas e abrir zera', (tester) async {
    NovidadesService.instance.definirParaTeste(itens: novidades);
    await abrirLargura(
      tester,
      const Scaffold(body: TopoVitrine(compacto: true)),
      360,
    );
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byTooltip('2 novidades'));
    await tester.pumpAndSettle();
    expect(
      find.text('Casa do Construtor mandou uma contraproposta'),
      findsOneWidget,
    );
    expect(NovidadesService.instance.naoVistas, 0);
    await tester.tap(find.text('Casa do Construtor mandou uma contraproposta'));
    await tester.pumpAndSettle();
    expect(find.byType(PropostaScreen), findsOneWidget);
  });

  testWidgets('no computador as novidades abrem num painel ao lado', (
    tester,
  ) async {
    NovidadesService.instance.definirParaTeste(itens: novidades);
    await abrirLargura(
      tester,
      const Scaffold(body: TopoVitrine(compacto: false)),
      1366,
    );
    await tester.tap(find.byTooltip('2 novidades'));
    await tester.pumpAndSettle();
    final painel = find.byKey(const Key('painel-novidades'));
    expect(painel, findsOneWidget);
    expect(tester.getSize(painel).width, 380);
    expect(tester.getTopLeft(painel).dx, 1366 - 380);
  });

  testWidgets('sem novidades orienta', (tester) async {
    NovidadesService.instance.definirParaTeste();
    await abrirLargura(
      tester,
      const Scaffold(body: TopoVitrine(compacto: true)),
      360,
    );
    await tester.tap(find.byTooltip('Novidades'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhuma novidade por aqui'), findsOneWidget);
  });

  testWidgets('economia que não carregou avisa em vez de girar para sempre', (
    tester,
  ) async {
    EconomiaService.instance.definirParaTeste(
      const [],
      erro: 'Sem conexão com a internet.',
    );
    await abrirLargura(tester, const CarteiraScreen(), 360);
    await rolarAte(
      tester,
      find.textContaining('Não deu para carregar a economia'),
    );
    expect(find.byType(EsqueletoBrilho), findsNothing);
  });

  for (final escuro in [false, true]) {
    for (final largura in [360.0, 800.0, 1366.0]) {
      testWidgets(
        'carteira com a divisão da economia em ${largura.toInt()} px (${escuro ? 'escuro' : 'claro'})',
        (tester) async {
          await abrirLargura(
            tester,
            const CarteiraScreen(),
            largura,
            escuro: escuro,
          );
          await rolarAte(tester, find.text('Comparando lojas'));
          expect(find.text(brl.format(70)), findsOneWidget);
          expect(find.text(brl.format(50)), findsWidgets);
          expect(find.text(brl.format(4)), findsOneWidget);
          expect(find.text(brl.format(124)), findsOneWidget);
          if (largura >= 1024) {
            expect(
              tester.getTopLeft(find.text('Extrato')).dx,
              greaterThan(
                tester.getTopLeft(find.text('Saldo disponível')).dx + 200,
              ),
            );
          }
          await rolarAteOFim(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
