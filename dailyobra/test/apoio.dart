// Apoio dos testes de tela do marketplace: celular de 360 × 780, tema claro ou escuro,
// dados em memória (sem Supabase).

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

/// Rola a primeira lista até o fim, para todos os blocos serem montados e conferidos.
Future<void> rolarAteOFim(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Rola a lista vertical principal até o texto aparecer.
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

final hoje = DateTime.now();
final daquiTresDias = DateTime(hoje.year, hoje.month, hoje.day + 3);

const cimento = ItemCatalogo(
  id: 'cimento-cp2-50kg',
  nome: 'Cimento CP II 50 kg',
  unidade: 'saco',
  categoriaId: 'basico',
  tier: 1,
  sinonimos: ['cimento', 'cp2'],
);
const tijolo = ItemCatalogo(
  id: 'tijolo-8-furos',
  nome: 'Tijolo cerâmico 8 furos',
  unidade: 'unidade',
  categoriaId: 'alvenaria',
  tier: 1,
  sinonimos: ['tijolo'],
);
const argamassa = ItemCatalogo(
  id: 'argamassa-ac1-20kg',
  nome: 'Argamassa colante AC-I 20 kg',
  unidade: 'saco',
  categoriaId: 'basico',
  tier: 1,
  sinonimos: ['argamassa', 'ac1'],
);
const torneira = ItemCatalogo(
  id: 'torneira-banheiro',
  nome: 'Torneira de banheiro cromada',
  unidade: 'unidade',
  categoriaId: 'loucas-metais',
  tier: 4,
  sinonimos: ['torneira'],
);
const itensTeste = [cimento, tijolo, argamassa, torneira];

const categoriasTeste = [
  Categoria(id: 'basico', nome: 'Básico', ordem: 1),
  Categoria(id: 'alvenaria', nome: 'Alvenaria', ordem: 3),
  Categoria(id: 'loucas-metais', nome: 'Louças e metais', ordem: 9),
];

const lojaA = Loja(
  id: 'a',
  nome: 'Casa do Construtor',
  cidade: 'Maringá',
  uf: 'PR',
  freteFixo: 50,
  pedidoMinimo: 100,
);
const lojaB = Loja(
  id: 'b',
  nome: 'Depósito Bom Preço',
  cidade: 'Maringá',
  uf: 'PR',
  freteFixo: 30,
);
const lojaC = Loja(
  id: 'c',
  nome: 'Ferragens Sarandi',
  cidade: 'Sarandi',
  uf: 'PR',
);

/// Cada loja é a mais barata em um item: tijolo na A, argamassa na B, cimento na C.
final ofertasTeste = [
  Oferta(lojaId: 'a', itemId: tijolo.id, preco: 1.20),
  Oferta(lojaId: 'b', itemId: tijolo.id, preco: 1.35),
  Oferta(lojaId: 'c', itemId: tijolo.id, preco: 1.40),
  Oferta(lojaId: 'a', itemId: argamassa.id, preco: 30),
  Oferta(
    lojaId: 'b',
    itemId: argamassa.id,
    preco: 28,
    precoPromocional: 25,
    promoAte: daquiTresDias,
  ),
  Oferta(lojaId: 'a', itemId: cimento.id, preco: 45),
  Oferta(
    lojaId: 'b',
    itemId: cimento.id,
    preco: 42,
    precoPromocional: 40,
    promoAte: daquiTresDias,
  ),
  Oferta(lojaId: 'c', itemId: cimento.id, preco: 38),
  Oferta(
    lojaId: 'a',
    itemId: torneira.id,
    preco: 210,
    precoPromocional: 189.9,
    promoAte: daquiTresDias,
  ),
];
