import 'package:dailyobra/screens/qr_do_pix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

const codigo =
    '00020126360014br.gov.bcb.pix0114+55669999900005204000053039865406450.005802BR'
    '5911CONTRUNORTE6012RONDONOPOLIS62140510DO6AE570086304431E';

void main() {
  group('link do banco', () {
    test('segue o formato do Banco Central', () {
      final link = linkDoPix(codigo);
      expect(link.scheme, 'pix');
      expect(link.host, 'dailyobrabr-creator.github.io');
      expect(link.queryParameters['qr'], codigo);
    });

    test('símbolos do código não quebram o link', () {
      expect(linkDoPix('a+b&c=d e').queryParameters['qr'], 'a+b&c=d e');
    });
  });

  group('módulos', () {
    test('são quadrados e têm os três cantos de leitura', () {
      final m = modulosDoQr(codigo)!;
      final n = m.length;
      expect(m.every((l) => l.length == n), isTrue);
      expect([m[0][0], m[0][n - 1], m[n - 1][0]], [true, true, true]);
      expect(m[7][7], isFalse, reason: 'borda clara do canto');
      expect(
        [for (var i = 0; i < 7; i++) m[3][n - 1 - i]].every((d) => d) == false,
        isTrue,
      );
    });

    test('o mesmo código gera o mesmo QR', () {
      expect(modulosDoQr(codigo), modulosDoQr(codigo));
    });

    test('código grande demais não gera QR', () {
      expect(modulosDoQr('9' * 8000), isNull);
    });
  });

  for (final escuro in [false, true]) {
    testWidgets('fica branco no tema ${escuro ? 'escuro' : 'claro'}', (
      tester,
    ) async {
      await abrir(
        tester,
        const Center(child: QrDoPix(codigo: codigo)),
        escuro: escuro,
      );
      final caixa = tester.widget<Container>(
        find.byKey(const Key('qr-do-pix')),
      );
      expect((caixa.decoration! as BoxDecoration).color, Colors.white);
      expect(
        tester.getSize(find.byKey(const Key('qr-do-pix'))),
        const Size(240, 240),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('código grande demais não mostra nada', (tester) async {
    await abrir(tester, QrDoPix(codigo: '9' * 8000));
    expect(find.byKey(const Key('qr-do-pix')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
