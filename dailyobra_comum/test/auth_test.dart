import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_comum/src/supabase/conexao_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('link de retorno do e-mail: padrão do construtor e trocável pelo app das lojas', () {
    expect(AuthService.linkRetorno, 'dailyobra://login');
    AuthService.definirLinkRetorno('dailyobraparceiros://login');
    expect(AuthService.linkRetorno, 'dailyobraparceiros://login');
    AuthService.definirLinkRetorno('dailyobra://login');
  });

  test('falha de conexão é reconhecida sem depender do navegador', () {
    expect(ehFalhaDeConexao(http.ClientException('sem rede')), isTrue);
    expect(ehFalhaDeConexao(Exception('outra coisa')), isFalse);
  });
}
