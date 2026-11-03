import 'dart:convert';
import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/atualizar_estoque_screen.dart';
import 'package:dailyobra_parceiro/screens/importar_planilha_screen.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/ofertas_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

const argamassa = ItemCatalogo(
  id: 'argamassa-ac1-20kg',
  nome: 'Argamassa colante AC-I 20 kg',
  unidade: 'saco',
  categoriaId: 'basico',
  tier: 1,
  sinonimos: ['argamassa'],
);
const cal = ItemCatalogo(
  id: 'cal-hidratada-20kg',
  nome: 'Cal hidratada 20 kg',
  unidade: 'saco',
  categoriaId: 'basico',
  tier: 1,
  sinonimos: ['cal'],
);
const areia = ItemCatalogo(
  id: 'areia-media',
  nome: 'Areia média',
  unidade: 'm³',
  categoriaId: 'basico',
  tier: 1,
  sinonimos: ['areia'],
);

/// Relatório "Valor do estoque analítico" do Santri em CSV, com o custo (que não pode ir a lugar nenhum).
const relatorio =
    'Santri ADM 1.1.5.9 R1\n'
    'Valor de Estoque - Analítico\n'
    'Produto;Nome;Disponível;Und.;Custo médio;Preço venda\n'
    '10.259;CIMENTO CP II 50KG VOTORAN;10,000;SO;40,00;62,00\n'
    '61.879;TIJOLO 8 FUROS;1000,000;UN;0,80;1,40\n'
    '61.937;ARGAMASSA ACI CINZA 20KG;5,000;SO;10,00;30,00\n'
    '61.880;CAL HIDRATADA 20KG;50,000;CX;10,00;23,90\n'
    '70.100;AREIA MEDIA LAVADA;20,000;;100,00;150,00\n'
    '70.101;AREIA MEDIA FINA;10,000;;90,00;140,00\n';

ArquivoPlanilha arquivo(String texto) =>
    ArquivoPlanilha('estoque.csv', Uint8List.fromList(utf8.encode(texto)));

void preparar() {
  LojaService.instance.definirParaTeste(loja: minhaLoja, papel: PapelLoja.dono);
  OfertasService.instance.definirParaTeste(
    categorias: categoriasTeste,
    catalogo: const [cimento, tijolo, torneira, argamassa, cal, areia],
    minhas: [
      const Oferta(lojaId: 'l1', itemId: 'cimento-cp2-50kg', preco: 60),
      const Oferta(
        lojaId: 'l1',
        itemId: 'tijolo-8-furos',
        preco: 1.35,
        disponibilidade: Disponibilidade.semEstoque,
      ),
      const Oferta(lojaId: 'l1', itemId: 'torneira-banheiro', preco: 200),
      const Oferta(lojaId: 'l1', itemId: 'argamassa-ac1-20kg', preco: 18.88),
    ],
    ligacoes: const [
      LigacaoProduto(codigo: '10259', itemId: 'cimento-cp2-50kg'),
      LigacaoProduto(codigo: '61879', itemId: 'tijolo-8-furos'),
      LigacaoProduto(codigo: '70000', itemId: 'torneira-banheiro'),
      LigacaoProduto(codigo: '61937', itemId: 'argamassa-ac1-20kg'),
    ],
  );
}

Future<void> lerRelatorio(
  WidgetTester tester, {
  required bool escuro,
  String texto = relatorio,
}) async {
  await abrir(
    tester,
    AtualizarEstoqueScreen(
      key: UniqueKey(),
      escolher: () async => arquivo(texto),
    ),
    escuro: escuro,
  );
  await tester.tap(find.text('Escolher relatório'));
  await tester.pumpAndSettle();
}

Finder contagem(String grupo, String n) => find.descendant(
  of: find.byKey(Key('grupo-$grupo')),
  matching: find.text(n),
);

Finder naSugestao(String itemId, String texto) => find.descendant(
  of: find.byKey(Key('sugestao-$itemId')),
  matching: find.text(texto),
);

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('resumo do relatório', (tester) async {
        preparar();
        await lerRelatorio(tester, escuro: escuro);
        expect(contagem('precoNovo', '1'), findsOneWidget);
        expect(contagem('voltouAoEstoque', '1'), findsOneWidget);
        expect(contagem('naoVeio', '1'), findsOneWidget);
        expect(contagem('conferir', '1'), findsOneWidget);
        await rolarAte(
          tester,
          find.byKey(const Key('conferir-argamassa-ac1-20kg')),
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('conferir-argamassa-ac1-20kg')),
              )
              .value,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('confirmar manda só o marcado', (tester) async {
        preparar();
        await lerRelatorio(tester, escuro: escuro);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        final (ofertas, ligacoes) =
            OfertasService.instance.importacoesDeTeste.single;
        expect(
          {for (final o in ofertas) o.itemId: (o.preco, o.disponibilidade)},
          {
            'cimento-cp2-50kg': (62.0, Disponibilidade.disponivel),
            'tijolo-8-furos': (1.40, Disponibilidade.disponivel),
          },
        );
        expect(ligacoes, isEmpty);
        expect(find.text('Estoque atualizado: 2 produtos.'), findsOneWidget);

        preparar();
        await lerRelatorio(tester, escuro: escuro);
        await rolarAte(
          tester,
          find.byKey(const Key('conferir-argamassa-ac1-20kg')),
        );
        await tester.tap(find.byKey(const Key('conferir-argamassa-ac1-20kg')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect([
          for (final o in OfertasService.instance.importacoesDeTeste.single.$1)
            o.itemId,
        ], contains('argamassa-ac1-20kg'));
      });

      testWidgets('ligar e pular sugestões', (tester) async {
        preparar();
        await lerRelatorio(tester, escuro: escuro);
        await rolarAte(tester, find.byKey(const Key('sugestao-areia-media')));
        expect(naSugestao('areia-media', 'AREIA MEDIA FINA'), findsOneWidget);
        await tester.tap(naSugestao('areia-media', 'Outro'));
        await tester.pumpAndSettle();
        expect(naSugestao('areia-media', 'AREIA MEDIA LAVADA'), findsOneWidget);
        await tester.tap(naSugestao('areia-media', 'Ligar'));
        await tester.pumpAndSettle();
        await rolarAte(
          tester,
          find.byKey(const Key('sugestao-cal-hidratada-20kg')),
        );
        await tester.tap(naSugestao('cal-hidratada-20kg', 'Pular'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sugestao-cal-hidratada-20kg')),
          findsNothing,
        );
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        final (ofertas, ligacoes) =
            OfertasService.instance.importacoesDeTeste.single;
        expect(ligacoes, const [
          LigacaoProduto(
            codigo: '70100',
            itemId: 'areia-media',
            nome: 'AREIA MEDIA LAVADA',
          ),
        ]);
        final nova = ofertas.singleWhere((o) => o.itemId == 'areia-media');
        expect(
          [nova.preco, nova.disponibilidade],
          [150.0, Disponibilidade.disponivel],
        );
        expect(ofertas.where((o) => o.itemId == 'cal-hidratada-20kg'), isEmpty);
      });

      testWidgets('procurar outra linha do relatório', (tester) async {
        preparar();
        await lerRelatorio(
          tester,
          escuro: escuro,
          texto: '${relatorio}80.300;SAIBRO PENEIRADO;15,000;M3;50,00;95,00\n',
        );
        await rolarAte(tester, find.byKey(const Key('sugestao-areia-media')));
        await tester.tap(naSugestao('areia-media', 'Procurar'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('procurar-linha')),
          'saibro',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('SAIBRO PENEIRADO'));
        await tester.pumpAndSettle();
        expect(naSugestao('areia-media', 'SAIBRO PENEIRADO'), findsOneWidget);
        expect(naSugestao('areia-media', 'Vai ser ligado'), findsOneWidget);
        await rolarAte(
          tester,
          find.byKey(const Key('sugestao-cal-hidratada-20kg')),
        );
        await tester.tap(naSugestao('cal-hidratada-20kg', 'Procurar'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('procurar-linha')),
          'saibro',
        );
        await tester.pumpAndSettle();
        expect(find.text('Nada encontrado no relatório.'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        final (_, ligacoes) = OfertasService.instance.importacoesDeTeste.single;
        expect(ligacoes, const [
          LigacaoProduto(
            codigo: '80300',
            itemId: 'areia-media',
            nome: 'SAIBRO PENEIRADO',
            unidade: 'M3',
          ),
        ]);
      });

      testWidgets('unidade diferente avisa', (tester) async {
        preparar();
        await lerRelatorio(tester, escuro: escuro);
        await rolarAte(
          tester,
          find.byKey(const Key('sugestao-cal-hidratada-20kg')),
        );
        expect(
          naSugestao(
            'cal-hidratada-20kg',
            'Unidade diferente: confira se é o mesmo produto e tamanho.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('arquivo errado avisa', (tester) async {
        preparar();
        await lerRelatorio(
          tester,
          escuro: escuro,
          texto: 'Produto;Nome;Disponível\n1;CAL;1\n',
        );
        expect(
          find.text(
            'Este arquivo não é o relatório "Valor do estoque analítico" do Santri.',
          ),
          findsOneWidget,
        );
        expect(find.text('Escolher relatório'), findsOneWidget);
      });
    });
  }
}
