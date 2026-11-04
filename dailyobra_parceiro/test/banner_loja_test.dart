import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/secoes_loja.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'apoio.dart';

const comBanner = Loja(
  id: 'l1',
  nome: 'Casa do Construtor',
  cidade: 'Maringá',
  uf: 'PR',
  bannerUrl: 'https://exemplo.test/banner.jpg',
);

void preparar({Loja loja = minhaLoja, PapelLoja papel = PapelLoja.dono}) =>
    LojaService.instance.definirParaTeste(loja: loja, papel: papel);

Future<void> abrirPerfil(
  WidgetTester tester, {
  required bool escuro,
  Future<XFile?> Function(ImagemLoja)? escolher,
}) => abrir(
  tester,
  Scaffold(body: SecaoPerfil(escolherImagem: escolher)),
  escuro: escuro,
);

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('loja sem banner só oferece enviar', (tester) async {
        preparar();
        await abrirPerfil(tester, escuro: escuro);
        expect(find.text('Banner da loja'), findsOneWidget);
        expect(find.text('Enviar banner'), findsOneWidget);
        expect(find.text('Trocar banner'), findsNothing);
        expect(find.text('Remover'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('enviar grava a imagem como banner', (tester) async {
        preparar();
        ImagemLoja? pedido;
        await abrirPerfil(
          tester,
          escuro: escuro,
          escolher: (tipo) async {
            pedido = tipo;
            return XFile.fromData(Uint8List(100), name: 'banner.jpg');
          },
        );
        await tester.tap(find.text('Enviar banner'));
        await tester.pumpAndSettle();
        expect(pedido, ImagemLoja.banner);
        expect(LojaService.instance.imagensDeTeste, [ImagemLoja.banner]);
        expect(find.text('Banner atualizado.'), findsOneWidget);
      });

      testWidgets('desistir de escolher não envia nada', (tester) async {
        preparar();
        await abrirPerfil(tester, escuro: escuro, escolher: (_) async => null);
        await tester.tap(find.text('Enviar banner'));
        await tester.pumpAndSettle();
        expect(LojaService.instance.imagensDeTeste, isEmpty);
      });

      testWidgets('imagem grande demais avisa', (tester) async {
        preparar();
        await abrirPerfil(
          tester,
          escuro: escuro,
          escolher: (_) async =>
              XFile.fromData(Uint8List(3 * 1024 * 1024), name: 'banner.jpg'),
        );
        await tester.tap(find.text('Enviar banner'));
        await tester.pumpAndSettle();
        expect(find.textContaining('passou de 2 MB'), findsOneWidget);
        expect(LojaService.instance.imagensDeTeste, isEmpty);
      });

      testWidgets('loja com banner troca ou remove', (tester) async {
        preparar(loja: comBanner);
        await abrirPerfil(tester, escuro: escuro);
        expect(find.text('Trocar banner'), findsOneWidget);
        await tester.tap(find.text('Remover'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
        await tester.pumpAndSettle();
        expect(LojaService.instance.atualizacoesDeTeste, [
          {'banner_path': null},
        ]);
        expect(tester.takeException(), isNull);
      });

      testWidgets('voltar na confirmação mantém o banner', (tester) async {
        preparar(loja: comBanner);
        await abrirPerfil(tester, escuro: escuro);
        await tester.tap(find.text('Remover'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
        expect(LojaService.instance.atualizacoesDeTeste, isEmpty);
      });

      testWidgets('vendedor não mexe no banner', (tester) async {
        preparar(loja: comBanner, papel: PapelLoja.vendedor);
        await abrirPerfil(tester, escuro: escuro);
        expect(find.text('Banner da loja'), findsOneWidget);
        expect(find.text('Trocar banner'), findsNothing);
        expect(find.text('Remover'), findsNothing);
      });
    });
  }
}
