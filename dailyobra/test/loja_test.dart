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

      testWidgets('telefone da loja abre o WhatsApp', (tester) async {
        final links = <Uri>[];
        CatalogoService.instance.definirParaTeste(
          categorias: categoriasTeste,
          itens: itensTeste,
          lojas: const [
            Loja(
              id: 'w',
              nome: 'Operário',
              cidade: 'Rondonópolis',
              uf: 'MT',
              whatsapp: '6634112520',
            ),
          ],
        );
        await abrir(
          tester,
          LojaScreen(
            lojaId: 'w',
            abrirLink: (uri) async {
              links.add(uri);
              return true;
            },
          ),
          escuro: escuro,
        );
        await rolarAte(tester, find.textContaining('(66) 3411-2520'));
        await tester.tap(find.textContaining('(66) 3411-2520'));
        await tester.pump();
        expect(links.single.host, 'wa.me');
        expect(links.single.path, '/556634112520');
        expect(
          links.single.queryParameters['text'],
          'Olá! Vi a Operário no DailyObra.',
        );
      });

      testWidgets('avisa quando o WhatsApp não abre', (tester) async {
        CatalogoService.instance.definirParaTeste(
          categorias: categoriasTeste,
          itens: itensTeste,
          lojas: const [
            Loja(
              id: 'w',
              nome: 'Operário',
              cidade: 'Rondonópolis',
              uf: 'MT',
              whatsapp: '6634112520',
            ),
          ],
        );
        await abrir(
          tester,
          LojaScreen(lojaId: 'w', abrirLink: (_) async => false),
          escuro: escuro,
        );
        await rolarAte(tester, find.textContaining('(66) 3411-2520'));
        await tester.tap(find.textContaining('(66) 3411-2520'));
        await tester.pump();
        expect(find.text('Não deu para abrir o WhatsApp.'), findsOneWidget);
      });

      testWidgets('loja mostra outras unidades', (tester) async {
        CatalogoService.instance.definirParaTeste(
          categorias: categoriasTeste,
          itens: itensTeste,
          lojas: const [
            Loja(
              id: 'a',
              nome: 'Casa do Construtor',
              cidade: 'Rondonópolis',
              uf: 'MT',
              endereco: 'R. A, 100, CEP 78700-000',
              outrasUnidades: 'Sagrada Família e Médici',
            ),
            lojaB,
          ],
          ofertas: ofertasTeste,
        );
        await abrir(tester, const LojaScreen(lojaId: 'a'), escuro: escuro);
        expect(find.text('R. A, 100, CEP 78700-000'), findsOneWidget);
        expect(
          find.text('Outras unidades: Sagrada Família e Médici'),
          findsOneWidget,
        );
        preparar();
        await abrir(tester, const LojaScreen(lojaId: 'a'), escuro: escuro);
        expect(find.textContaining('Outras unidades'), findsNothing);
      });
    });
  }
}
