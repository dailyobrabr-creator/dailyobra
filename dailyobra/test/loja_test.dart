import 'package:dailyobra/screens/loja_screen.dart';
import 'package:dailyobra/services/carrinho_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

Finder chip(String nome) => find.widgetWithText(ChipCategoria, nome);

void preparar({List<Oferta>? ofertas}) =>
    CatalogoService.instance.definirParaTeste(
      categorias: categoriasTeste,
      itens: itensTeste,
      lojas: const [lojaA, lojaB, lojaC],
      ofertas: ofertas ?? ofertasTeste,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CarrinhoService.instance.carregar();
  });

  test('seções seguem a ordem do catálogo, com Outros no fim', () {
    const sem = ItemCatalogo(
      id: 'sem-categoria',
      nome: 'Produto sem categoria',
      unidade: 'unidade',
      categoriaId: 'nao-existe',
      tier: 1,
    );
    Oferta o(ItemCatalogo i) => Oferta(lojaId: 'a', itemId: i.id, preco: 1);
    final secoes = secoesPorCategoria([
      (o(torneira), torneira),
      (o(sem), sem),
      (o(cimento), cimento),
      (o(tijolo), tijolo),
      (o(argamassa), argamassa),
    ], categoriasTeste);
    expect(
      [
        for (final (categoria, produtos) in secoes)
          '${categoria.nome}: ${[for (final p in produtos) p.$2.id].join(', ')}',
      ],
      [
        'Básico: cimento-cp2-50kg, argamassa-ac1-20kg',
        'Alvenaria: tijolo-8-furos',
        'Louças e metais: torneira-banheiro',
        'Outros: sem-categoria',
      ],
    );
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('loja mostra seções e atalhos por categoria', (tester) async {
        preparar();
        await abrir(tester, const LojaScreen(lojaId: 'a'), escuro: escuro);
        await rolarAte(tester, chip('Todas'));
        for (final nome in [
          'Todas',
          'Básico',
          'Alvenaria',
          'Louças e metais',
        ]) {
          expect(chip(nome), findsOneWidget);
        }
        for (final titulo in [
          'Básico · 2',
          'Alvenaria · 1',
          'Louças e metais · 1',
        ]) {
          await rolarAte(tester, find.text(titulo));
          expect(find.text(titulo), findsOneWidget);
        }
        await rolarAteOFim(tester);
      });

      testWidgets('categoria escolhida mostra só ela e volta para todas', (
        tester,
      ) async {
        preparar();
        await abrir(tester, const LojaScreen(lojaId: 'a'), escuro: escuro);
        await rolarAte(tester, chip('Alvenaria'));
        await tester.tap(chip('Alvenaria'));
        await tester.pumpAndSettle();
        expect(find.text('Alvenaria · 1'), findsOneWidget);
        expect(find.text('Tijolo cerâmico 8 furos'), findsOneWidget);
        expect(find.text('Básico · 2'), findsNothing);
        expect(find.text('Cimento CP II 50 kg'), findsNothing);
        await tester.tap(chip('Alvenaria'));
        await tester.pumpAndSettle();
        expect(find.text('Básico · 2'), findsOneWidget);
        await tester.tap(chip('Louças e metais'));
        await tester.pumpAndSettle();
        expect(find.text('Básico · 2'), findsNothing);
        await tester.tap(chip('Todas'));
        await tester.pumpAndSettle();
        expect(find.text('Básico · 2'), findsOneWidget);
      });

      testWidgets('loja de uma categoria só não mostra atalhos', (
        tester,
      ) async {
        preparar(
          ofertas: [
            Oferta(lojaId: 'a', itemId: cimento.id, preco: 45),
            Oferta(lojaId: 'a', itemId: argamassa.id, preco: 30),
          ],
        );
        await abrir(tester, const LojaScreen(lojaId: 'a'), escuro: escuro);
        await rolarAte(tester, find.text('Básico · 2'));
        expect(find.byType(ChipCategoria), findsNothing);
      });
    });
  }
}
