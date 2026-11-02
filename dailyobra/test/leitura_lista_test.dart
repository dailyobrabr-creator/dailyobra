import 'package:dailyobra/services/leitura_lista_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tipo do arquivo pela extensão, sem diferença de maiúsculas', () {
    expect(tipoDoArquivo('Lista da obra.PDF'), 'application/pdf');
    expect(tipoDoArquivo('foto.jpg'), 'image/jpeg');
    expect(tipoDoArquivo('foto.JPEG'), 'image/jpeg');
    expect(tipoDoArquivo('print.png'), 'image/png');
    expect(tipoDoArquivo('print.webp'), 'image/webp');
    expect(tipoDoArquivo('planilha.xlsx'), isNull);
    expect(tipoDoArquivo('sem_extensao'), isNull);
  });
}
