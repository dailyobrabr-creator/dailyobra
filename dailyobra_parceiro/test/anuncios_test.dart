import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/anuncios_screen.dart';
import 'package:dailyobra_parceiro/screens/componentes.dart';
import 'package:dailyobra_parceiro/screens/layout_parceiros.dart';
import 'package:dailyobra_parceiro/services/anuncios_service.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/ofertas_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'apoio.dart';

final agora = DateTime.now();
DateTime dia(int d) =>
    DateTime(agora.year, agora.month, agora.day).add(Duration(days: d));

Anuncio anuncio({
  String id = 'a1',
  TipoAnuncio tipo = TipoAnuncio.banner,
  int inicio = -1,
  int fim = 5,
  bool pausado = false,
  String? imagem = 'l1/anuncio-1.jpg',
  String? itemId,
}) => Anuncio(
  id: id,
  lojaId: 'l1',
  tipo: tipo,
  titulo: 'Semana do porcelanato',
  inicio: dia(inicio),
  fim: dia(fim),
  pausado: pausado,
  imagemCaminho: tipo == TipoAnuncio.banner ? imagem : null,
  itemId: itemId,
);

final banner = AnuncioDaLoja(
  anuncio: anuncio(),
  impressoes: 4820,
  cliques: 612,
);

final destaque = AnuncioDaLoja(
  anuncio: anuncio(
    id: 'a2',
    tipo: TipoAnuncio.destaque,
    itemId: 'cimento-cp2-50kg',
  ),
  itemNome: 'Cimento CP II 50 kg',
  unidade: 'saco',
  impressoes: 8150,
  cliques: 300,
  vendidos: 142,
);

void preparar(List<AnuncioDaLoja> lista) {
  LojaService.instance.definirParaTeste(loja: minhaLoja);
  AnunciosService.instance.definirParaTeste(lista: lista);
  OfertasService.instance.definirParaTeste(
    categorias: categoriasTeste,
    catalogo: catalogoTeste,
    minhas: const [Oferta(lojaId: 'l1', itemId: 'cimento-cp2-50kg', preco: 45)],
  );
}

List<(String, Map<String, Object?>)> get chamadas =>
    AnunciosService.instance.chamadasDeTeste;

Future<XFile?> imagemDeTeste() async =>
    XFile.fromData(Uint8ListDeTeste.bytes, name: 'banner.jpg');

abstract final class Uint8ListDeTeste {
  static final bytes = Uint8List.fromList(const [1, 2, 3]);
}

void main() {
  group('situação do anúncio', () {
    test('no ar entre o início e o fim, inclusive', () {
      expect(anuncio(inicio: 0, fim: 0).situacao(agora), SituacaoAnuncio.ativo);
      expect(anuncio(inicio: 0, fim: 0).noAr(agora), isTrue);
    });

    test('agendado antes do início', () {
      expect(
        anuncio(inicio: 1, fim: 3).situacao(agora),
        SituacaoAnuncio.agendado,
      );
    });

    test('encerrado depois do fim, mesmo pausado', () {
      expect(
        anuncio(inicio: -5, fim: -1, pausado: true).situacao(agora),
        SituacaoAnuncio.encerrado,
      );
    });

    test('pausado não fica no ar', () {
      final a = anuncio(pausado: true);
      expect(a.situacao(agora), SituacaoAnuncio.pausado);
      expect(a.noAr(agora), isFalse);
    });

    test('lê a linha do banco', () {
      final a = Anuncio.fromJson(const {
        'id': 'a1',
        'loja_id': 'l1',
        'tipo': 'destaque',
        'titulo': 'Cimento',
        'inicio': '2026-11-06',
        'fim': '2026-11-10',
        'item_id': 'x',
        'pausado': true,
      });
      expect(a.tipo, TipoAnuncio.destaque);
      expect(a.itemId, 'x');
      expect(a.pausado, isTrue);
      expect(a.fim.day, 10);
    });
  });

  group('resultado', () {
    test('lê as métricas', () {
      final a = AnuncioDaLoja.fromJson(const {
        'id': 'a1',
        'loja_id': 'l1',
        'tipo': 'destaque',
        'titulo': 'Cimento',
        'inicio': '2026-11-06',
        'fim': '2026-11-10',
        'item_nome': 'Cimento',
        'unidade': 'saco',
        'impressoes': 200,
        'cliques': 10,
        'vendidos': 3.5,
      });
      expect(a.taxaDeCliques, 0.05);
      expect(a.vendidos, 3.5);
    });

    test('sem impressão não há taxa de cliques', () {
      expect(AnuncioDaLoja(anuncio: anuncio()).taxaDeCliques, isNull);
    });
  });

  group('lista', () {
    for (final escuro in [false, true]) {
      for (final largura in [360.0, 1366.0]) {
        testWidgets('mostra o resultado em ${largura.toInt()} px '
            '(${escuro ? 'escuro' : 'claro'})', (tester) async {
          preparar([banner, destaque]);
          await abrirLargura(
            tester,
            const AnunciosScreen(),
            largura,
            escuro: escuro,
          );
          expect(find.text('2 anúncios no ar'), findsOneWidget);
          expect(find.text('4820'), findsOneWidget);
          expect(find.text('12,7%'), findsOneWidget);
          await rolarAte(tester, find.text('142 saco'));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('sem anúncio orienta', (tester) async {
      preparar(const []);
      await abrir(tester, const AnunciosScreen());
      expect(find.text('Nenhum anúncio ainda'), findsOneWidget);
    });

    testWidgets('banner não mostra vendidos', (tester) async {
      preparar([banner]);
      await abrir(tester, const AnunciosScreen());
      expect(find.text('Vendidos no período'), findsNothing);
    });

    testWidgets('pausar manda para o banco', (tester) async {
      preparar([banner]);
      await abrir(tester, const AnunciosScreen());
      await rolarAte(tester, find.text('Pausar'));
      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();
      expect(chamadas.single.$1, 'pausar_anuncio');
      expect(chamadas.single.$2['p_pausado'], isTrue);
      expect(find.text('Anúncio pausado.'), findsOneWidget);
    });

    testWidgets('pausado oferece retomar', (tester) async {
      preparar([AnuncioDaLoja(anuncio: anuncio(pausado: true))]);
      await abrir(tester, const AnunciosScreen());
      await rolarAte(tester, find.text('Retomar'));
      await tester.tap(find.text('Retomar'));
      await tester.pumpAndSettle();
      expect(chamadas.single.$2['p_pausado'], isFalse);
    });

    testWidgets('encerrado só pode ser excluído', (tester) async {
      preparar([AnuncioDaLoja(anuncio: anuncio(inicio: -9, fim: -1))]);
      await abrir(tester, const AnunciosScreen());
      await rolarAte(tester, find.text('Excluir'));
      expect(find.text('Encerrado'), findsOneWidget);
      expect(find.text('Pausar'), findsNothing);
      expect(find.text('Editar'), findsNothing);
    });

    testWidgets('excluir pede confirmação', (tester) async {
      preparar([banner]);
      await abrir(tester, const AnunciosScreen());
      await rolarAte(tester, find.text('Excluir'));
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir o anúncio?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(chamadas.single.$1, 'excluir_anuncio');
    });
  });

  group('formulário', () {
    Future<void> abrirFormulario(
      WidgetTester tester, {
      AnuncioDaLoja? item,
    }) async {
      preparar(const []);
      await abrir(
        tester,
        AnuncioFormScreen(item: item, escolherImagem: imagemDeTeste),
      );
    }

    Finder campoTitulo() => find.byType(TextField).first;

    testWidgets('banner pede imagem e título', (tester) async {
      await abrirFormulario(tester);
      await tester.ensureVisible(find.text('Salvar anúncio'));
      await tester.tap(find.text('Salvar anúncio'));
      await tester.pumpAndSettle();
      expect(
        find.text('Dê um título com pelo menos 3 letras.'),
        findsOneWidget,
      );
      await tester.enterText(campoTitulo(), 'Semana do piso');
      await tester.tap(find.text('Salvar anúncio'));
      await tester.pumpAndSettle();
      expect(find.text('Envie a imagem do banner.'), findsOneWidget);
      expect(chamadas, isEmpty);
    });

    testWidgets('cria banner com a imagem enviada', (tester) async {
      await abrirFormulario(tester);
      await tester.enterText(campoTitulo(), '  Semana do piso ');
      await tester.tap(find.text('Enviar imagem'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvar anúncio'));
      await tester.tap(find.text('Salvar anúncio'));
      await tester.pumpAndSettle();
      final (funcao, dados) = chamadas.single;
      expect(funcao, 'salvar_anuncio');
      expect(dados['p_id'], isNull);
      expect(dados['p_tipo'], 'banner');
      expect(dados['p_titulo'], 'Semana do piso');
      expect(dados['p_imagem'], startsWith('l1/anuncio-'));
      expect(dados['p_item'], isNull);
    });

    testWidgets('destaque só oferece produtos com preço', (tester) async {
      await abrirFormulario(tester);
      await tester.tap(find.text('Destaque na busca'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvar anúncio'));
      await tester.enterText(campoTitulo(), 'Cimento');
      await tester.tap(find.text('Salvar anúncio'));
      await tester.pumpAndSettle();
      expect(find.text('Escolha o produto do destaque.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'cimen');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cimento CP II 50 kg').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvar anúncio'));
      await tester.tap(find.text('Salvar anúncio'));
      await tester.pumpAndSettle();
      final (_, dados) = chamadas.single;
      expect(dados['p_tipo'], 'destaque');
      expect(dados['p_item'], 'cimento-cp2-50kg');
      expect(dados['p_imagem'], isNull);
    });

    testWidgets('editar mantém o tipo e o id', (tester) async {
      await abrirFormulario(tester, item: banner);
      expect(find.text('Editar anúncio'), findsOneWidget);
      expect(find.text('Destaque na busca'), findsNothing);
      await tester.ensureVisible(find.text('Salvar anúncio'));
      await tester.tap(find.text('Salvar anúncio'));
      await tester.pumpAndSettle();
      expect(chamadas.single.$2['p_id'], 'a1');
      expect(chamadas.single.$2['p_titulo'], 'Semana do porcelanato');
    });
  });

  group('menu', () {
    Future<void> montar(WidgetTester tester, {bool gere = true}) =>
        abrirLargura(
          tester,
          LayoutParceiros(
            aba: Aba.anuncios,
            onAba: (_) {},
            novas: 0,
            gere: gere,
            loja: minhaLoja,
            conteudo: const Text('Conteúdo'),
          ),
          1366,
        );

    testWidgets('gerente vê Retail Media', (tester) async {
      await montar(tester);
      expect(find.text('Retail Media'), findsOneWidget);
    });

    testWidgets('vendedor não vê', (tester) async {
      await montar(tester, gere: false);
      expect(find.text('Retail Media'), findsNothing);
    });

    testWidgets('o menu ocupa a janela inteira', (tester) async {
      await montar(tester);
      expect(tester.getSize(find.byKey(const Key('menu-lateral'))).height, 900);
      expect(tester.getTopLeft(find.byKey(const Key('menu-lateral'))).dy, 0);
    });

    testWidgets('em janela baixa o menu rola sem estourar', (tester) async {
      tester.view.physicalSize = const Size(1366, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro(ThemeData.light().textTheme),
          home: LayoutParceiros(
            aba: Aba.inicio,
            onAba: (_) {},
            novas: 0,
            dono: true,
            loja: minhaLoja,
            conteudo: const Text('Conteúdo'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
