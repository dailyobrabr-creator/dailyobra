import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final temas = {
  'claro': AppTheme.claro(ThemeData.light().textTheme),
  'escuro': AppTheme.escuro(ThemeData.dark().textTheme),
};

final nomeLongo = 'Porcelanato retificado acetinado bege areia 60 x 60 cm caixa com 2,16 m² extra'.padRight(80, 'x');
final item = ItemCatalogo(id: 'p', nome: nomeLongo, unidade: 'm²', categoriaId: 'acabamento', tier: 4);
final hoje = DateTime(2026, 10, 31);
final promo = Oferta(lojaId: 'a', itemId: 'p', preco: 89.90, precoPromocional: 74.50, promoAte: DateTime(2026, 11, 5));
const loja = Loja(
  id: 'a', nome: 'Casa do Construtor Materiais de Construção e Acabamentos Ltda', cidade: 'Maringá', uf: 'PR',
  freteFixo: 50, pedidoMinimo: 300, nova: true,
);

Future<void> montar(WidgetTester tester, ThemeData tema, Widget filho) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: tema, home: Scaffold(body: SingleChildScrollView(child: filho))));
}

void main() {
  for (final MapEntry(key: nome, value: tema) in temas.entries) {
    group('tema $nome', () {
      testWidgets('cartão de produto com nome longo cabe em 360 px', (tester) async {
        var adicionou = false;
        await montar(
          tester, tema,
          CartaoProduto(item: item, melhorOferta: promo, lojas: 3, hoje: hoje, onAdicionar: () => adicionou = true),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Oferta'), findsOneWidget);
        expect(find.textContaining('3 lojas'), findsOneWidget);
        await tester.tap(find.byTooltip('Adicionar ao orçamento'));
        expect(adicionou, isTrue);
      });

      testWidgets('cartão de produto sem oferta avisa', (tester) async {
        await montar(tester, tema, CartaoProduto(item: item, hoje: hoje));
        expect(tester.takeException(), isNull);
        expect(find.text('Sem oferta no momento'), findsOneWidget);
      });

      testWidgets('cartão de loja com nome longo cabe em 360 px', (tester) async {
        await montar(tester, tema, const CartaoLoja(loja: loja));
        expect(tester.takeException(), isNull);
        expect(find.text('Nova'), findsOneWidget);
        expect(find.textContaining('Frete'), findsOneWidget);
      });

      testWidgets('rodapé com total, cashback e duas ações cabe em 360 px', (tester) async {
        await montar(
          tester, tema,
          RodapeTotal(
            total: 123456.78,
            cashback: 1234.56,
            acoes: [
              OutlinedButton(onPressed: () {}, child: const Text('Proposta')),
              FilledButton(onPressed: () {}, child: const Text('Fechar pedido')),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(brl.format(123456.78)), findsOneWidget);
        expect(find.textContaining(brl.format(1234.56)), findsOneWidget);
      });
    });
  }

  testWidgets('preço em promoção mostra o cheio riscado', (tester) async {
    await montar(tester, temas['claro']!, PrecoOferta(oferta: promo, hoje: hoje, unidade: 'm²'));
    final cheio = tester.widget<Text>(find.text(brl.format(89.90)));
    expect(cheio.style?.decoration, TextDecoration.lineThrough);
    expect(find.text(brl.format(74.50)), findsOneWidget);
  });

  testWidgets('produto sem foto mostra o ícone da categoria', (tester) async {
    await montar(tester, temas['claro']!, ImagemProduto(item: item));
    expect(find.byIcon(iconeDaCategoria('acabamento')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('estado vazio mostra orientação e ação', (tester) async {
    var tocou = false;
    await montar(
      tester, temas['escuro']!,
      EstadoVazio(
        titulo: 'Nenhuma loja na sua cidade ainda',
        texto: 'Troque a cidade no perfil ou veja lojas de outras cidades.',
        acao: TextButton(onPressed: () => tocou = true, child: const Text('Ver todas as lojas')),
      ),
    );
    expect(find.text('Nenhuma loja na sua cidade ainda'), findsOneWidget);
    await tester.tap(find.text('Ver todas as lojas'));
    expect(tocou, isTrue);
  });

  testWidgets('chip de categoria marca a selecionada', (tester) async {
    await montar(
      tester, temas['claro']!,
      const ChipCategoria(categoria: Categoria(id: 'eletrica', nome: 'Elétrica', ordem: 6), selecionada: true),
    );
    expect(find.byIcon(iconeDaCategoria('eletrica')), findsOneWidget);
    expect(tester.getSemantics(find.byType(ChipCategoria)), isSemantics(isSelected: true, isButton: true, label: 'Elétrica'));
  });

  test('frete: grátis, valor ou a combinar com a loja', () {
    const base = Loja(id: 'a', nome: 'Loja', cidade: 'Rondonópolis', uf: 'MT');
    expect(freteEMinimo(base), 'Frete grátis');
    expect(freteEMinimo(const Loja(id: 'a', nome: 'Loja', cidade: 'Rondonópolis', uf: 'MT', freteFixo: 30)), 'Frete ${brl.format(30)}');
    const combinar = Loja(id: 'a', nome: 'Loja', cidade: 'Rondonópolis', uf: 'MT', freteACombinar: true);
    expect(textoFrete(combinar), 'Frete a combinar');
    expect(freteEMinimo(combinar), 'Frete a combinar');
    const comMinimo = Loja(id: 'a', nome: 'Loja', cidade: 'Rondonópolis', uf: 'MT', freteACombinar: true, pedidoMinimo: 200);
    expect(freteEMinimo(comMinimo), 'Frete a combinar · Pedido mínimo ${brl.format(200)}');
  });

  group('vitrine', () {
    final semPromo = const Oferta(lojaId: 'a', itemId: 'p', preco: 1234567.89);
    for (final MapEntry(key: nome, value: tema) in temas.entries) {
      for (final largura in [360.0, 1366.0]) {
        testWidgets('cartão de oferta com nome longo e valor grande em ${largura.toInt()} px ($nome)', (tester) async {
          tester.view.physicalSize = Size(largura, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(
            theme: tema,
            home: Scaffold(
              body: Row(children: [
                Expanded(child: CartaoOferta(item: item, oferta: promo, hoje: hoje, nomeLoja: loja.nome)),
                const SizedBox(width: 12),
                Expanded(child: CartaoOferta(item: item, oferta: semPromo, hoje: hoje)),
                const SizedBox(width: 12),
                Expanded(child: CartaoOferta(item: item, oferta: null, hoje: hoje)),
              ]),
            ),
          ));
          expect(tester.takeException(), isNull);
          expect(find.text('-17%'), findsOneWidget);
          expect(find.text('Sem oferta no momento'), findsOneWidget);
          final alturas = tester.widgetList(find.byType(CartaoOferta)).map((w) => tester.getSize(find.byWidget(w)).height).toSet();
          expect(alturas.length, 1, reason: 'cartões da mesma linha com a mesma altura');
        });
      }
    }

    testWidgets('categoria com nome longo cabe em 150 px', (tester) async {
      await montar(tester, temas['claro']!, const Center(
        child: SizedBox(width: 150, child: TileCategoria(categoria: Categoria(id: 'loucas-metais', nome: 'Louças e metais', ordem: 9), horizontal: true)),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Louças e metais'), findsOneWidget);
    });

    testWidgets('marca: a mesma logo nos dois temas, com o texto claro no escuro', (tester) async {
      Finder logo(String arquivo) => find.byWidgetPredicate(
          (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith('/$arquivo'));
      await montar(tester, temas['claro']!, const MarcaDailyObra(soSimbolo: false));
      expect(logo('logo_tela.png'), findsOneWidget);
      await montar(tester, temas['escuro']!, const MarcaDailyObra(soSimbolo: false));
      await tester.pumpAndSettle();
      expect(logo('logo_tela_claro.png'), findsOneWidget);
      expect(logo('logo_tela.png'), findsNothing);
      expect(find.textContaining('Obra'), findsNothing, reason: 'sem nome montado em texto');
    });

    testWidgets('gráfico mostra os seis meses', (tester) async {
      await montar(tester, temas['claro']!, const SizedBox(height: 80, child: GraficoMeses(meses: [('mai', 30), ('jun', 46), ('jul', 38), ('ago', 60), ('set', 52), ('out', 80)])));
      expect(tester.takeException(), isNull);
      for (final m in ['mai', 'jun', 'jul', 'ago', 'set', 'out']) {
        expect(find.text(m), findsOneWidget);
      }
    });

    testWidgets('loja fechada mostra o selo', (tester) async {
      await montar(tester, temas['escuro']!, const CartaoLoja(loja: Loja(id: 'f', nome: 'Ferragens Sarandi', cidade: 'Sarandi', uf: 'PR', aberta: false), ofertas: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('fechada'), findsOneWidget);
      expect(find.textContaining('2 ofertas'), findsOneWidget);
    });
  });
}
