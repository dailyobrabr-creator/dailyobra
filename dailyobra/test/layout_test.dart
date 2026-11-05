import 'package:dailyobra/screens/componentes.dart';
import 'package:dailyobra/screens/layout_adaptativo.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Aba? escolhida;

Future<void> abrirLargura(
  WidgetTester tester,
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
      home: LayoutAdaptativo(
        aba: Aba.inicio,
        onAba: (a) => escolhida = a,
        pendencias: 3,
        conteudo: const ColoredBox(
          color: Colors.transparent,
          child: Center(child: Text('conteúdo')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    escolhida = null;
    PerfilService.instance.definirParaTeste(
      nome: 'Ana Souza',
      cidade: 'Maringá',
      uf: 'PR',
    );
    CarteiraService.instance.definirParaTeste(
      disponivel: 125.5,
      pendente: 12.5,
    );
  });

  test('formato pela largura', () {
    expect(formatoDe(599), Formato.celular);
    expect(formatoDe(600), Formato.tablet);
    expect(formatoDe(1023), Formato.tablet);
    expect(formatoDe(1024), Formato.computador);
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('celular: abas embaixo', (tester) async {
        await abrirLargura(tester, 599, escuro: escuro);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.text('3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('celular: Obras é a aba do meio', (tester) async {
        await abrirLargura(tester, 390, escuro: escuro);
        final rotulos = tester
            .widgetList<NavigationDestination>(
              find.byType(NavigationDestination),
            )
            .map((d) => d.label)
            .toList();
        expect(rotulos, [
          'Início',
          'Orçamentos',
          'Obras',
          'Carteira',
          'Perfil',
        ]);
        await tester.tap(find.text('Obras'));
        expect(escolhida, Aba.obras);
      });

      testWidgets('tablet: trilho lateral', (tester) async {
        for (final largura in [600.0, 1023.0]) {
          await abrirLargura(tester, largura, escuro: escuro);
          expect(
            find.byType(NavigationRail),
            findsOneWidget,
            reason: '$largura',
          );
          expect(find.byType(NavigationBar), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('computador: menu lateral, clube e barra laranja', (
        tester,
      ) async {
        await abrirLargura(tester, 1024, escuro: escuro);
        expect(find.text('Obras'), findsOneWidget);
        expect(find.text('Clube DailyObra'), findsOneWidget);
        expect(find.text('Usar no orçamento'), findsOneWidget);
        expect(find.text('Olá, Ana'), findsOneWidget);
        expect(find.textContaining('Buscar cimento'), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Carteira'));
        expect(escolhida, Aba.carteira);
      });

      testWidgets('tela muito larga: conteúdo até 1320 px', (tester) async {
        await abrirLargura(tester, 1920, escuro: escuro);
        expect(
          tester.getSize(find.byKey(const Key('conteudo-adaptativo'))).width,
          lessThanOrEqualTo(1320),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
