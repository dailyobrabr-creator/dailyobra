import 'package:dailyobra/screens/componentes.dart';
import 'package:dailyobra/screens/carteira_screen.dart';
import 'package:dailyobra/screens/inicio_screen.dart';
import 'package:dailyobra/screens/produto_screen.dart';
import 'package:dailyobra/screens/vitrine_do_inicio.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra/services/economia_service.dart';
import 'package:dailyobra/services/negociacao_service.dart';
import 'package:dailyobra/services/novidades_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart' hide hoje;

final hoje = DateTime(2026, 11, 5);

ItemCatalogo produto(String id, String categoria, {String? foto}) =>
    ItemCatalogo(
      id: id,
      nome: 'Produto $id',
      unidade: 'un',
      categoriaId: categoria,
      tier: 1,
      imagemUrl: foto,
    );

Oferta preco(String loja, String item, double valor, {double? promocional}) =>
    Oferta(
      lojaId: loja,
      itemId: item,
      preco: valor,
      precoPromocional: promocional,
      promoAte: promocional == null ? null : DateTime(2026, 12, 31),
    );

const lojaUm = Loja(id: 'l1', nome: 'Loja Um', cidade: 'Maringá', uf: 'PR');
const lojaDois = Loja(id: 'l2', nome: 'Loja Dois', cidade: 'Maringá', uf: 'PR');

void preparar({
  List<ItemCatalogo> itens = const [],
  List<Oferta> ofertas = const [],
  List<Categoria> categorias = categoriasTeste,
}) {
  SharedPreferences.setMockInitialValues({});
  CatalogoService.instance.definirParaTeste(
    categorias: categorias,
    itens: itens,
    lojas: const [lojaUm, lojaDois],
    ofertas: ofertas,
  );
  PerfilService.instance.definirParaTeste(nome: 'Ana Souza', cidade: 'Maringá');
  CarteiraService.instance.definirParaTeste(disponivel: 10);
  ObrasService.instance.definirParaTeste(obras: const []);
  NegociacaoService.instance.definirParaTeste(propostas: const []);
  EconomiaService.instance.definirParaTeste(const []);
  NovidadesService.instance.definirParaTeste();
  abaAtual.value = Aba.inicio;
}

Widget prateleira({bool emFaixa = false, VoidCallback? aoVerMais}) => Scaffold(
  body: ListView(
    children: [
      Prateleira(
        titulo: 'Melhores preços em Básico',
        margem: 16,
        emFaixa: emFaixa,
        aoVerMais: aoVerMais,
        produtos: [
          for (var i = 0; i < 8; i++)
            ProdutoDaPrateleira(
              item: produto('p$i', 'basico'),
              preco: 1234.56,
              precoCheio: i == 0 ? 2000 : null,
              rodape: 'em 3 lojas',
            ),
        ],
      ),
    ],
  ),
);

void main() {
  group('produtos da prateleira', () {
    test('com foto primeiro, depois os de mais lojas', () {
      preparar(
        itens: [
          produto('a', 'basico'),
          produto('b', 'basico'),
          produto('c', 'basico', foto: 'https://exemplo.test/c.png'),
        ],
        ofertas: [
          preco('l1', 'a', 10),
          preco('l1', 'b', 20),
          preco('l2', 'b', 25),
          preco('l1', 'c', 30),
        ],
      );
      final lista = CatalogoService.instance.produtosDaPrateleira(
        'basico',
        hoje: hoje,
      );
      expect([for (final p in lista) p.item.id], ['c', 'b', 'a']);
      expect(lista[1].lojas, 2);
      expect(lista[1].oferta.preco, 20);
    });

    test('produto sem preço fica de fora e o limite vale', () {
      preparar(
        itens: [for (var i = 0; i < 5; i++) produto('p$i', 'basico')],
        ofertas: [for (var i = 0; i < 4; i++) preco('l1', 'p$i', 10.0 + i)],
      );
      final lista = CatalogoService.instance.produtosDaPrateleira(
        'basico',
        hoje: hoje,
        limite: 3,
      );
      expect(lista, hasLength(3));
      expect(lista.any((p) => p.item.id == 'p4'), isFalse);
    });
  });

  group('prateleira', () {
    for (final escuro in [false, true]) {
      for (final emFaixa in [false, true]) {
        testWidgets('desenha sem estourar (escuro: $escuro, faixa: $emFaixa)', (
          tester,
        ) async {
          preparar();
          await abrir(tester, prateleira(emFaixa: emFaixa), escuro: escuro);
          expect(find.text('Melhores preços em Básico'), findsOneWidget);
          expect(find.text('38% off'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('separa reais e centavos e lê o preço inteiro', (tester) async {
      preparar();
      await abrir(tester, prateleira());
      expect(find.text('1.234'), findsWidgets);
      expect(find.text('56'), findsWidgets);
      final leitura = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('1\\.234,56')), findsWidgets);
      leitura.dispose();
    });

    testWidgets('produto abre a tela dele', (tester) async {
      preparar(itens: [produto('p0', 'basico')]);
      await abrir(tester, prateleira());
      await tester.tap(find.text('Produto p0'));
      await tester.pumpAndSettle();
      expect(find.byType(ProdutoScreen), findsOneWidget);
    });

    testWidgets('ver mais só aparece com destino', (tester) async {
      preparar();
      var tocou = false;
      await abrir(tester, prateleira(aoVerMais: () => tocou = true));
      await tester.tap(find.text('Ver mais'));
      expect(tocou, isTrue);
      await abrir(tester, prateleira());
      expect(find.text('Ver mais'), findsNothing);
    });

    testWidgets('no celular corre com o dedo, sem seta', (tester) async {
      preparar();
      await abrir(tester, prateleira());
      expect(find.byTooltip('Ver mais produtos'), findsNothing);
    });

    testWidgets('na tela grande a seta passa os produtos', (tester) async {
      preparar();
      await abrir(tester, prateleira());
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      final horizontal = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      );
      final rolagem = tester.state<ScrollableState>(horizontal).position;
      expect(rolagem.pixels, 0);
      await tester.tap(find.byTooltip('Ver mais produtos'));
      await tester.pumpAndSettle();
      expect(rolagem.pixels, greaterThan(0));
      for (var i = 0; i < 4 && rolagem.pixels < rolagem.maxScrollExtent; i++) {
        await tester.tap(find.byTooltip('Ver mais produtos'));
        await tester.pumpAndSettle();
      }
      expect(rolagem.pixels, rolagem.maxScrollExtent);
      await tester.tap(find.byTooltip('Ver mais produtos'));
      await tester.pumpAndSettle();
      expect(rolagem.pixels, 0, reason: 'no fim, volta ao começo');
    });

    testWidgets('produtos que cabem dispensam a seta', (tester) async {
      preparar();
      await abrir(
        tester,
        Scaffold(
          body: ListView(
            children: [
              Prateleira(
                titulo: 'Poucos',
                margem: 16,
                produtos: [
                  ProdutoDaPrateleira(item: produto('p0', 'basico'), preco: 10),
                ],
              ),
            ],
          ),
        ),
      );
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ver mais produtos'), findsNothing);
    });
  });

  group('Início', () {
    List<ItemCatalogo> dois(String categoria) => [
      produto('$categoria-1', categoria),
      produto('$categoria-2', categoria),
    ];

    testWidgets('cada categoria com produtos ganha uma prateleira', (
      tester,
    ) async {
      preparar(
        itens: [...dois('basico'), ...dois('alvenaria')],
        ofertas: [
          preco('l1', 'basico-1', 10),
          preco('l1', 'basico-2', 20),
          preco('l1', 'alvenaria-1', 30),
          preco('l1', 'alvenaria-2', 40),
        ],
      );
      await abrir(tester, const InicioScreen());
      await rolarAte(tester, find.text('Melhores preços em Alvenaria'));
      await rolarAte(tester, find.text('Melhores preços em Básico'));
    });

    testWidgets('categoria com um produto só não vira prateleira', (
      tester,
    ) async {
      preparar(
        itens: [produto('x', 'basico')],
        ofertas: [preco('l1', 'x', 10)],
      );
      await abrir(tester, const InicioScreen());
      await rolarAteOFim(tester);
      expect(find.text('Melhores preços em Básico'), findsNothing);
    });

    testWidgets('sem nada mostrar, não sobra prateleira vazia', (tester) async {
      preparar();
      await abrir(tester, const InicioScreen());
      await rolarAteOFim(tester);
      expect(find.byType(Prateleira), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a primeira faixa é laranja e elas se alternam', (
      tester,
    ) async {
      preparar(
        itens: [...dois('basico'), ...dois('alvenaria')],
        ofertas: [
          preco('l1', 'basico-1', 10),
          preco('l2', 'basico-1', 12),
          preco('l1', 'basico-2', 20),
          preco('l1', 'alvenaria-1', 30),
          preco('l1', 'alvenaria-2', 40),
        ],
      );
      await abrir(tester, const InicioScreen());
      tester.view.physicalSize = const Size(1080, 12000);
      await tester.pumpAndSettle();
      final faixas = tester
          .widgetList<Prateleira>(find.byType(Prateleira))
          .map((p) => (p.titulo, p.emFaixa))
          .toList();
      expect(faixas, [
        ('Mais barato hoje', true),
        ('Melhores preços em Básico', false),
        ('Melhores preços em Alvenaria', true),
      ]);
    });

    testWidgets('promoção mostra o preço cheio riscado', (tester) async {
      preparar(
        itens: [produto('x', 'basico')],
        ofertas: [preco('l1', 'x', 100, promocional: 75)],
      );
      await abrir(tester, const InicioScreen());
      await rolarAte(tester, find.text('Ofertas do dia'));
      expect(find.text('25% off'), findsOneWidget);
      expect(find.text(brl.format(100)), findsOneWidget);
    });

    testWidgets('o banner de cashback abre a carteira', (tester) async {
      preparar();
      await abrir(tester, const Scaffold(body: CarrosselDeBanners(lojas: [])));
      await tester.tap(find.byKey(const Key('marca-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver carteira'));
      await tester.pumpAndSettle();
      expect(find.byType(CarteiraScreen), findsOneWidget);
    });

    testWidgets('o banner de compare leva à aba Busca', (tester) async {
      preparar();
      await abrir(tester, const Scaffold(body: CarrosselDeBanners(lojas: [])));
      await tester.tap(find.byKey(const Key('marca-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar material'));
      await tester.pumpAndSettle();
      expect(abaAtual.value, Aba.busca);
    });
  });
}
