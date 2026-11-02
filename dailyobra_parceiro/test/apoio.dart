// Apoio dos testes de tela do Parceiros: celular de 360 × 780, tema claro ou escuro, dados em memória.

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> abrir(
  WidgetTester tester,
  Widget tela, {
  bool escuro = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
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

/// Rola a lista vertical principal até o alvo aparecer.
Future<void> rolarAte(WidgetTester tester, Finder alvo) async {
  await tester.scrollUntilVisible(
    alvo,
    300,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// Rola a primeira lista até o fim, para todos os blocos serem montados e conferidos.
Future<void> rolarAteOFim(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

final hoje = DateTime.now();

const cimento = ItemCatalogo(
  id: 'cimento-cp2-50kg',
  nome: 'Cimento CP II 50 kg',
  unidade: 'saco',
  categoriaId: 'basico',
  tier: 1,
  sinonimos: ['cimento'],
);
const tijolo = ItemCatalogo(
  id: 'tijolo-8-furos',
  nome: 'Tijolo cerâmico 8 furos',
  unidade: 'unidade',
  categoriaId: 'alvenaria',
  tier: 1,
  sinonimos: ['tijolo'],
);
const torneira = ItemCatalogo(
  id: 'torneira-banheiro',
  nome: 'Torneira de banheiro cromada',
  unidade: 'unidade',
  categoriaId: 'loucas-metais',
  tier: 4,
  sinonimos: ['torneira'],
);
const catalogoTeste = [cimento, tijolo, torneira];
const categoriasTeste = [
  Categoria(id: 'basico', nome: 'Básico', ordem: 1),
  Categoria(id: 'alvenaria', nome: 'Alvenaria', ordem: 3),
  Categoria(id: 'loucas-metais', nome: 'Louças e metais', ordem: 9),
];

const minhaLoja = Loja(
  id: 'l1',
  nome: 'Casa do Construtor',
  cidade: 'Maringá',
  uf: 'PR',
  freteFixo: 50,
  pedidoMinimo: 100,
  whatsapp: '44999990000',
);
