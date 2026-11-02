// Gera o ícone do DailyObra Parceiros a partir da marca já recortada do app do construtor
// (../dailyobra/assets/icone/icone_frente.png): o grafite do capacete vira branco, o laranja fica,
// e tudo vai sobre o grafite da marca (#565966).
// Uso: dart run tool/gerar_icone.dart  e depois  dart run flutter_launcher_icons

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final frente = img.decodePng(File('../dailyobra/assets/icone/icone_frente.png').readAsBytesSync())!;

  img.Image clarear(img.Image origem) {
    final saida = img.Image(width: origem.width, height: origem.height, numChannels: 4);
    for (final p in origem) {
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt(), a = p.a.toInt();
      if (a == 0) continue;
      final laranja = r > 150 && r - b > 70 && g < r - 30;
      if (laranja) {
        saida.setPixelRgba(p.x, p.y, r, g, b, a);
      } else {
        saida.setPixelRgba(p.x, p.y, 255, 255, 255, a);
      }
    }
    return saida;
  }

  final marca = clarear(frente);
  Directory('assets/icone').createSync(recursive: true);

  // Ícone adaptável do Android: só a marca, o fundo #565966 vem do pubspec
  File('assets/icone/icone_frente.png').writeAsBytesSync(img.encodePng(marca));

  // Ícone comum (iPhone e Android antigo): marca um pouco maior sobre o fundo grafite
  const lado = 1024;
  final tela = img.Image(width: lado, height: lado, numChannels: 4);
  img.fill(tela, color: img.ColorRgba8(0x56, 0x59, 0x66, 255));
  final maior = img.copyResize(marca, width: (lado * 1.3).round(), height: (lado * 1.3).round(), interpolation: img.Interpolation.average);
  final centro = img.copyCrop(maior, x: (maior.width - lado) ~/ 2, y: (maior.height - lado) ~/ 2, width: lado, height: lado);
  img.compositeImage(tela, centro);
  File('assets/icone/icone.png').writeAsBytesSync(img.encodePng(tela));
  stdout.writeln('ok: assets/icone/icone.png e icone_frente.png');
}
