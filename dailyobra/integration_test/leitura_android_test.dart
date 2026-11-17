// Roda no Android de verdade (emulador ou celular): flutter test integration_test -d <aparelho>.
import 'dart:typed_data';
// Confere que o WebView escondido lê foto e PDF dentro do APK, sem rede.
import 'dart:ui' as ui;

import 'package:dailyobra/services/leitura_no_aparelho_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const linhas = [
  'Lista de materiais - Obra Jardim',
  '10 sacos de cimento',
  '3 m3 de areia media',
  '1000 tijolos 8 furos',
  '20 barras ferro 5/16',
];

Future<List<int>> fotoDaLista() async {
  const w = 1500.0, h = 2000.0;
  final gravador = ui.PictureRecorder();
  final c = Canvas(gravador);
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(w, h), [
        const Color(0xFFD8D2C0),
        const Color(0xFF8E897C),
      ]),
  );
  c.translate(80, 200);
  c.rotate(-0.04);
  for (final (i, t) in linhas.indexed) {
    final p = TextPainter(
      text: TextSpan(
        text: t,
        style: const TextStyle(fontSize: 52, color: Color(0xFF2B2B2B)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, Offset(0, i * 90.0));
  }
  final img = await gravador.endRecording().toImage(w.toInt(), h.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lê a foto da lista no Android', (tester) async {
    final bytes = await fotoDaLista();
    final texto = await tester.runAsync(
      () => lerNoAparelho(Uint8List.fromList(bytes), 'image/png'),
    );
    debugPrint('FOTO>>> $texto');
    expect(texto, contains('cimento'));
    expect(texto, contains('tijolos'));
  });

  testWidgets('lê o PDF com texto no Android', (tester) async {
    final doc = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [for (final t in linhas) pw.Text(t)],
          ),
        ),
      );
    final bytes = await doc.save();
    final texto = await tester.runAsync(
      () => lerNoAparelho(bytes, 'application/pdf'),
    );
    debugPrint('PDF>>> $texto');
    expect(texto, contains('10 sacos de cimento'));
  });
}
