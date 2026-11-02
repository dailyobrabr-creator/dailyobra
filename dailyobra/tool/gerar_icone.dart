// Gera o ícone do app a partir do logo oficial empilhado (tool/logo_empilhado_oficial.png):
// recorta o "O" com o capacete, sem redesenhar nada, e monta as bases para o flutter_launcher_icons.
// Uso: dart run tool/gerar_icone.dart  e depois  dart run flutter_launcher_icons
//
// O manual pede validar o capacete em tamanhos pequenos antes de usar como ícone: trate como proposta.

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final logo = img.decodePng(File('tool/logo_empilhado_oficial.png').readAsBytesSync())!;
  stdout.writeln('logo ${logo.width}x${logo.height}, canais ${logo.numChannels}');

  // Região do "O" com capacete no logo empilhado (proporção sobre 2970 × 2005)
  final x0 = (logo.width * 0.0).round(), x1 = (logo.width * 0.386).round();
  final y0 = (logo.height * 0.50).round(), y1 = logo.height;
  // O "b" começa logo à direita do "O": dali em diante só vale o laranja da aba do capacete
  final limiteGrafite = (logo.width * 0.36).round();

  final marca = img.Image(width: x1 - x0, height: y1 - y0, numChannels: 4);
  var minX = marca.width, minY = marca.height, maxX = 0, maxY = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final p = logo.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt(), a = p.a.toInt();
      if (a < 40) continue;
      final laranja = r > 150 && r - b > 70 && g < r - 30;
      final grafite = r < 140 && g < 140 && b < 160 && (r - b).abs() < 40;
      if (laranja || (grafite && x < limiteGrafite)) {
        marca.setPixelRgba(x - x0, y - y0, r, g, b, a);
        if (x - x0 < minX) minX = x - x0;
        if (x - x0 > maxX) maxX = x - x0;
        if (y - y0 < minY) minY = y - y0;
        if (y - y0 > maxY) maxY = y - y0;
      }
    }
  }
  final recorte = img.copyCrop(marca, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
  stdout.writeln('marca ${recorte.width}x${recorte.height}');

  img.Image composto(double fracao, {required bool fundoBranco}) {
    const lado = 1024;
    final tela = img.Image(width: lado, height: lado, numChannels: 4);
    if (fundoBranco) img.fill(tela, color: img.ColorRgba8(255, 255, 255, 255));
    final escala = (lado * fracao) / (recorte.width > recorte.height ? recorte.width : recorte.height);
    final m = img.copyResize(recorte, width: (recorte.width * escala).round(), height: (recorte.height * escala).round(), interpolation: img.Interpolation.average);
    img.compositeImage(tela, m, dstX: (lado - m.width) ~/ 2, dstY: (lado - m.height) ~/ 2);
    return tela;
  }

  Directory('assets/icone').createSync(recursive: true);
  // Ícone comum (iPhone e Android antigo): fundo branco, marca em 68% do lado
  File('assets/icone/icone.png').writeAsBytesSync(img.encodePng(composto(0.68, fundoBranco: true)));
  // Ícone adaptável do Android: a marca precisa caber no círculo seguro central (66%)
  File('assets/icone/icone_frente.png').writeAsBytesSync(img.encodePng(composto(0.50, fundoBranco: false)));
  stdout.writeln('ok: assets/icone/icone.png e icone_frente.png');
}
