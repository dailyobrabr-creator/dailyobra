import 'package:dailyobra/screens/busca_screen.dart';
import 'package:dailyobra/screens/componentes.dart';
import 'package:dailyobra/screens/produto_screen.dart';
import 'package:dailyobra/screens/vitrine_do_inicio.dart';
import 'package:dailyobra/services/anuncios_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

final agora = DateTime.now();
DateTime dia(int d) =>
    DateTime(agora.year, agora.month, agora.day).add(Duration(days: d));

ItemCatalogo produto(String id) => ItemCatalogo(
  id: id,
  nome: 'Produto $id',
  unidade: 'un',
  categoriaId: 'basico',
  tier: 1,
);

const lojaUm = Loja(id: 'l1', nome: 'Loja Um', cidade: 'Maringá', uf: 'PR');
const lojaDois = Loja(id: 'l2', nome: 'Loja Dois', cidade: 'Maringá', uf: 'PR');
const lojaFechada = Loja(
  id: 'l3',
  nome: 'Loja Três',
  cidade: 'Maringá',
  uf: 'PR',
  aberta: false,
);

Anuncio destaque(
  String id,
  String item, {
  String loja = 'l2',
  int inicio = -1,
  int fim = 5,
  bool pausado = false,
}) => Anuncio(
  id: id,
  lojaId: loja,
  tipo: TipoAnuncio.destaque,
  titulo: 'Campanha',
  inicio: dia(inicio),
  fim: dia(fim),
  itemId: item,
  pausado: pausado,
);

Anuncio banner(String id, {String loja = 'l2', int fim = 5}) => Anuncio(
  id: id,
  lojaId: loja,
  tipo: TipoAnuncio.banner,
  titulo: 'Campanha',
  inicio: dia(-1),
  fim: dia(fim),
  imagemCaminho: '$loja/anuncio-1.jpg',
);

Oferta preco(String loja, String item, double valor) =>
    Oferta(lojaId: loja, itemId: item, preco: valor);

void preparar({
  List<Anuncio> anuncios = const [],
  List<Oferta>? ofertas,
  List<ItemCatalogo>? itens,
}) {
  AnunciosService.instance.definirParaTeste();
  CatalogoService.instance.definirParaTeste(
    categorias: categoriasTeste,
    itens: itens ?? [produto('a'), produto('b'), produto('c'), produto('d')],
    lojas: const [lojaUm, lojaDois, lojaFechada],
    ofertas:
        ofertas ??
        [
          preco('l1', 'a', 10),
          preco('l1', 'b', 10),
          preco('l2', 'b', 20),
          preco('l2', 'c', 30),
          preco('l2', 'd', 40),
          preco('l3', 'a', 5),
        ],
    anuncios: anuncios,
  );
  abaAtual.value = Aba.inicio;
}

List<(String, String)> get eventos => AnunciosService.instance.eventosDeTeste;

Future<void> buscar(WidgetTester tester, {double? largura}) async {
  await abrir(tester, const BuscaScreen());
  if (largura != null) {
    tester.view.physicalSize = Size(largura, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField), 'produto');
  await tester.pumpAndSettle();
}

void main() {
  group('catálogo', () {
    final catalogo = CatalogoService.instance;

    test('devolve o destaque com o preço da loja que anuncia', () {
      preparar(anuncios: [destaque('x', 'b')]);
      final d = catalogo.destaqueDoItem('b', agora)!;
      expect(d.loja.id, 'l2');
      expect(d.oferta.preco, 20);
    });

    test('ignora pausado, agendado e encerrado', () {
      preparar(
        anuncios: [
          destaque('p', 'b', pausado: true),
          destaque('ag', 'c', inicio: 2),
          destaque('en', 'd', inicio: -9, fim: -1),
        ],
      );
      expect(catalogo.destaqueDoItem('b', agora), isNull);
      expect(catalogo.destaqueDoItem('c', agora), isNull);
      expect(catalogo.destaqueDoItem('d', agora), isNull);
    });

    test('loja fechada ou sem preço não aparece', () {
      preparar(
        anuncios: [
          destaque('x', 'a', loja: 'l3'),
          destaque('y', 'a'),
        ],
        ofertas: [preco('l3', 'a', 5)],
      );
      expect(catalogo.destaqueDoItem('a', agora), isNull);
    });

    test('banners pagos só de loja aberta', () {
      preparar(
        anuncios: [
          banner('ok'),
          banner('fechada', loja: 'l3'),
          banner('fim', fim: -1),
        ],
      );
      expect([for (final (a, _) in catalogo.bannersPagos(agora)) a.id], ['ok']);
    });
  });

  group('busca', () {
    for (final escuro in [false, true]) {
      testWidgets('destaque vem primeiro, identificado '
          '(${escuro ? 'escuro' : 'claro'})', (tester) async {
        preparar(anuncios: [destaque('x', 'c')]);
        await abrir(tester, const BuscaScreen(), escuro: escuro);
        await tester.enterText(find.byType(TextField), 'produto');
        await tester.pumpAndSettle();
        expect(find.text('Patrocinado'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Produto c')).dy,
          lessThan(tester.getTopLeft(find.text('Produto a')).dy),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('mostra o preço e a logo de quem anuncia', (tester) async {
      preparar(anuncios: [destaque('x', 'b')]);
      await buscar(tester);
      final cartao = tester.widget<CartaoProduto>(
        find.widgetWithText(CartaoProduto, 'Produto b'),
      );
      expect(cartao.melhorOferta?.lojaId, 'l2');
      expect(cartao.loja?.id, 'l2');
      expect(cartao.patrocinado, isTrue);
    });

    testWidgets('sem anúncio nada muda', (tester) async {
      preparar();
      await buscar(tester);
      expect(find.text('Patrocinado'), findsNothing);
      expect(eventos, isEmpty);
    });

    testWidgets('no máximo dois destaques por lista', (tester) async {
      preparar(
        anuncios: [destaque('1', 'b'), destaque('2', 'c'), destaque('3', 'd')],
      );
      await buscar(tester);
      expect(find.text('Patrocinado'), findsNWidgets(2));
    });

    testWidgets('o terceiro anunciado fica como produto comum', (tester) async {
      preparar(
        anuncios: [destaque('1', 'b'), destaque('2', 'c'), destaque('3', 'd')],
      );
      await buscar(tester);
      await rolarAte(tester, find.text('Produto d'));
      expect(
        tester
            .widget<CartaoProduto>(
              find.widgetWithText(CartaoProduto, 'Produto d'),
            )
            .patrocinado,
        isFalse,
      );
      expect(eventos.map((e) => e.$1), isNot(contains('3')));
    });

    testWidgets('conta a impressão uma vez e o clique ao abrir', (
      tester,
    ) async {
      preparar(anuncios: [destaque('x', 'c')]);
      await buscar(tester);
      await tester.enterText(find.byType(TextField), 'produto c');
      await tester.pumpAndSettle();
      expect(eventos, [('x', 'impressao')]);
      await tester.tap(find.text('Produto c'));
      await tester.pumpAndSettle();
      expect(find.byType(ProdutoScreen), findsOneWidget);
      expect(eventos, [('x', 'impressao'), ('x', 'clique')]);
    });

    testWidgets('na grade do computador também aparece primeiro', (
      tester,
    ) async {
      preparar(anuncios: [destaque('x', 'c')]);
      await buscar(tester, largura: 1366);
      expect(find.text('Patrocinado'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Produto c')).dx,
        lessThan(tester.getTopLeft(find.text('Produto a')).dx),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('quem escolhe outra ordem não vê o patrocinado na frente', (
      tester,
    ) async {
      preparar(anuncios: [destaque('x', 'c'), destaque('y', 'b')]);
      await buscar(tester, largura: 1366);
      await tester.tap(find.text('Nome'));
      await tester.pumpAndSettle();
      expect(find.text('Patrocinado'), findsNothing);
      final cartao = tester.widget<CartaoOferta>(
        find.widgetWithText(CartaoOferta, 'Produto b'),
      );
      expect(cartao.oferta?.preco, 10, reason: 'volta o melhor preço');
      expect(
        tester.getTopLeft(find.text('Produto a')).dx,
        lessThan(tester.getTopLeft(find.text('Produto c')).dx),
      );
    });
  });

  group('carrossel', () {
    Widget carrossel(List<(Anuncio, Loja)> anuncios) => Scaffold(
      body: ListView(
        children: [
          CarrosselDeBanners(
            lojas: const [
              Loja(
                id: 'l1',
                nome: 'Loja Um',
                cidade: 'Maringá',
                uf: 'PR',
                bannerUrl: 'https://exemplo.test/banner.png',
              ),
            ],
            anuncios: anuncios,
          ),
        ],
      ),
    );

    testWidgets('banner pago vem primeiro, identificado e conta a impressão', (
      tester,
    ) async {
      preparar();
      await abrir(tester, carrossel([(banner('x'), lojaDois)]));
      expect(find.text('Patrocinado'), findsOneWidget);
      expect(eventos, [('x', 'impressao')]);
    });

    testWidgets('sem anúncio segue como antes', (tester) async {
      preparar();
      await abrir(tester, carrossel(const []));
      expect(find.text('Patrocinado'), findsNothing);
      expect(eventos, isEmpty);
    });

    testWidgets('banner pago que ainda não apareceu não conta', (tester) async {
      preparar();
      await abrir(
        tester,
        carrossel([(banner('x'), lojaDois), (banner('y'), lojaUm)]),
      );
      expect(eventos, [('x', 'impressao')]);
      await tester.tap(find.byKey(const Key('marca-1')));
      await tester.pumpAndSettle();
      expect(eventos, [('x', 'impressao'), ('y', 'impressao')]);
    });

    testWidgets('tocar conta o clique', (tester) async {
      preparar();
      await abrir(tester, carrossel([(banner('x'), lojaDois)]));
      await tester.tap(find.bySemanticsLabel('Anúncio de Loja Dois'));
      await tester.pumpAndSettle();
      expect(eventos.last, ('x', 'clique'));
    });
  });
}
