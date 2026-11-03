import 'dart:convert';
import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/importar_planilha_screen.dart';
import 'package:dailyobra_parceiro/screens/produtos_screen.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/ofertas_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

void preparar({PapelLoja papel = PapelLoja.dono}) {
  LojaService.instance.definirParaTeste(loja: minhaLoja, papel: papel);
  OfertasService.instance.definirParaTeste(
    categorias: categoriasTeste,
    catalogo: catalogoTeste,
  );
}

ArquivoPlanilha csv(String texto) =>
    ArquivoPlanilha('tabela.csv', Uint8List.fromList(utf8.encode(texto)));

/// O que a tela mandou gravar.
class Gravadas {
  List<Oferta>? ofertas;
}

Future<Gravadas> abrirImportacao(
  WidgetTester tester,
  ArquivoPlanilha arquivo, {
  required bool escuro,
}) async {
  final gravadas = Gravadas();
  await abrir(
    tester,
    ImportarPlanilhaScreen(
      escolher: () async => arquivo,
      salvar: (ofertas) async => gravadas.ofertas = ofertas,
    ),
    escuro: escuro,
  );
  await tester.tap(find.text('Escolher arquivo'));
  await tester.pumpAndSettle();
  return gravadas;
}

Future<void> escolherNoMenu(
  WidgetTester tester,
  String chave,
  String opcao,
) async {
  await tester.tap(find.byKey(ValueKey(chave)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcao).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('dono vê Importar planilha e vendedor não', (tester) async {
        preparar();
        await abrir(tester, const ProdutosScreen(), escuro: escuro);
        expect(find.byTooltip('Importar planilha'), findsOneWidget);
        await tester.tap(find.byTooltip('Importar planilha'));
        await tester.pumpAndSettle();
        expect(find.byType(ImportarPlanilhaScreen), findsOneWidget);

        preparar(papel: PapelLoja.vendedor);
        await abrir(tester, const ProdutosScreen(), escuro: escuro);
        expect(find.byTooltip('Importar planilha'), findsNothing);
      });

      testWidgets('revisão conta os grupos e grava os preços marcados', (
        tester,
      ) async {
        preparar();
        final gravadas = await abrirImportacao(
          tester,
          csv(
            'Produto;Preço\nCIMENTO CP II 50KG VOTORAN;45,90\nTIJOLO 8 FUROS;1,35\nMANGUEIRA DE JARDIM;30,00\n',
          ),
          escuro: escuro,
        );
        expect(find.textContaining('2 ligados'), findsOneWidget);
        expect(find.textContaining('1 fora do catálogo'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('preco-3')), '1,40');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gravar 2 preços'));
        await tester.pumpAndSettle();
        expect(
          {for (final o in gravadas.ofertas!) o.itemId: o.preco},
          {'cimento-cp2-50kg': 45.9, 'tijolo-8-furos': 1.4},
        );
        expect(find.textContaining('2 preços gravados'), findsOneWidget);
        expect(find.text('MANGUEIRA DE JARDIM'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('unidade diferente vem desmarcada', (tester) async {
        preparar();
        await abrirImportacao(
          tester,
          csv('Produto;Preço;Unidade\nCIMENTO CP II 50KG;45,90;CX\n'),
          escuro: escuro,
        );
        final botao = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Gravar 0 preços'),
        );
        expect(botao.onPressed, isNull);
        expect(find.textContaining('CX'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('colunas desconhecidas pedem a escolha', (tester) async {
        preparar();
        await abrirImportacao(
          tester,
          csv('Mercadoria;Custo\nCIMENTO CP II 50KG;45,90\n'),
          escuro: escuro,
        );
        expect(find.text('Coluna do produto'), findsOneWidget);
        expect(find.text('Coluna do preço'), findsOneWidget);
        await escolherNoMenu(tester, 'coluna-nome', 'Mercadoria');
        await escolherNoMenu(tester, 'coluna-preco', 'Custo');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 ligado ·'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('arquivo inválido avisa sem sair', (tester) async {
        preparar();
        await abrirImportacao(
          tester,
          ArquivoPlanilha('lista.pdf', Uint8List(3)),
          escuro: escuro,
        );
        expect(find.text('Envie um arquivo .csv, .xlsx ou .ods.'), findsOneWidget);
        expect(find.text('Escolher arquivo'), findsOneWidget);
      });
    });
  }
}
