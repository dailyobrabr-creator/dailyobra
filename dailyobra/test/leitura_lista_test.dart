import 'package:dailyobra/screens/componentes.dart';
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

  test('unidade no plural só quando passa de 1', () {
    expect(unidadeNoPlural('saco', 10), 'sacos');
    expect(unidadeNoPlural('saco', 1), 'saco');
    expect(unidadeNoPlural('unidade', 1000), 'unidades');
    expect(unidadeNoPlural('barra', 2.5), 'barras');
    expect(unidadeNoPlural('galão', 3), 'galões');
    expect(unidadeNoPlural('painel', 2), 'painéis');
    expect(unidadeNoPlural('par', 2), 'pares');
    expect(unidadeNoPlural('kit', 2), 'kits');
    expect(unidadeNoPlural('un', 50), 'un');
    expect(unidadeNoPlural('und', 50), 'und');
    expect(unidadeNoPlural('m³', 3), 'm³');
    expect(unidadeNoPlural('kg', 3), 'kg');
  });
}
