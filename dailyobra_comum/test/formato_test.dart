import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('limites de largura', () {
    expect(formatoDe(599), Formato.celular);
    expect(formatoDe(600), Formato.tablet);
    expect(formatoDe(1023), Formato.tablet);
    expect(formatoDe(1024), Formato.computador);
  });
}
