import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> linha(String? banner) => {
  'id': 'l1',
  'nome': 'Operário',
  'cidade': 'Rondonópolis',
  'uf': 'MT',
  'banner_path': banner,
};

void main() {
  test('loja sem banner', () {
    expect(Loja.fromJson(linha(null)).bannerUrl, isNull);
    expect(Loja.fromJson(linha('')).bannerUrl, isNull);
  });

  test('banner com endereço completo passa direto', () {
    const url = 'https://dailyobrabr-creator.github.io/dailyobra/lojas/operario_banner.jpg';
    expect(Loja.fromJson(linha(url)).bannerUrl, url);
  });

  test('banner enviado pela loja vem do Storage', () {
    expect(Loja.fromJson(linha('l1/banner.jpg')).bannerUrl, endsWith('/storage/v1/object/public/lojas/l1/banner.jpg'));
  });
}
