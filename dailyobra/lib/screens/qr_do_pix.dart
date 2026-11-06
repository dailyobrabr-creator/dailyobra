import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Link do Pix do Banco Central, o mesmo formato do Pix por aproximação: o aparelho abre o app de banco que aceitar.
Uri linkDoPix(String codigo) => Uri.parse(
  'pix://dailyobrabr-creator.github.io?qr=${Uri.encodeComponent(codigo)}',
);

/// Módulos do QR Code, linha por linha; nulo quando o código não cabe num QR.
List<List<bool>>? modulosDoQr(String codigo) {
  try {
    final imagem = QrImage(
      QrCode.fromData(data: codigo, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return [
      for (var linha = 0; linha < imagem.moduleCount; linha++)
        [
          for (var coluna = 0; coluna < imagem.moduleCount; coluna++)
            imagem.isDark(linha, coluna),
        ],
    ];
  } on InputTooLongException {
    return null;
  }
}

/// QR Code do PIX. Fica preto no branco nos dois temas para a câmera do banco conseguir ler.
class QrDoPix extends StatelessWidget {
  const QrDoPix({super.key, required this.codigo, this.tamanho = 240});
  final String codigo;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final modulos = modulosDoQr(codigo);
    if (modulos == null) return const SizedBox.shrink();
    return Semantics(
      image: true,
      label: 'QR Code do PIX',
      child: Container(
        key: const Key('qr-do-pix'),
        width: tamanho,
        height: tamanho,
        padding: const EdgeInsets.all(Espaco.s4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Raio.md),
        ),
        child: CustomPaint(painter: _PintorDoQr(modulos)),
      ),
    );
  }
}

class _PintorDoQr extends CustomPainter {
  _PintorDoQr(this.modulos);
  final List<List<bool>> modulos;

  @override
  void paint(Canvas canvas, Size size) {
    final total = modulos.length;
    // Módulo em pixel inteiro, com a sobra dividida nas bordas, para não sair borrado
    final lado = (size.shortestSide / total).floorToDouble();
    final inicio = (size.shortestSide - lado * total) / 2;
    final caminho = Path();
    for (var linha = 0; linha < total; linha++) {
      for (var coluna = 0; coluna < total; coluna++) {
        if (!modulos[linha][coluna]) continue;
        caminho.addRect(
          Rect.fromLTWH(
            inicio + coluna * lado,
            inicio + linha * lado,
            lado,
            lado,
          ),
        );
      }
    }
    canvas.drawPath(
      caminho,
      Paint()
        ..color = Colors.black
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_PintorDoQr antigo) => antigo.modulos != modulos;
}
