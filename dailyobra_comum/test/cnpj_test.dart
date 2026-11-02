import 'dart:io';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('CNPJ', () {
    test('valida os dígitos verificadores', () {
      expect(cnpjValido('11.222.333/0001-81'), isTrue);
      expect(cnpjValido('11444777000161'), isTrue);
      expect(cnpjValido('11222333000180'), isFalse);
      expect(cnpjValido('00000000000000'), isFalse);
      expect(cnpjValido('1122233300018'), isFalse);
      expect(cnpjValido(''), isFalse);
    });

    test('formata enquanto digita e completo', () {
      expect(formatarCnpj('11222333000181'), '11.222.333/0001-81');
      expect(formatarCnpj('112223'), '11.222.3');
      expect(formatarCnpj('11.222.333/0001-81'), '11.222.333/0001-81');
      expect(formatarCnpj(''), '');
    });
  });

  group('mensagemDoServidor', () {
    test('regra do servidor mostra a mensagem dele', () {
      expect(mensagemDoServidor(const PostgrestException(message: 'O desconto não pode ser negativo.', code: 'P0001')),
          'O desconto não pode ser negativo.');
    });

    test('sem internet pede para verificar a conexão', () {
      const semConexao = 'Sem conexão. Verifique a internet e tente de novo.';
      expect(mensagemDoServidor(const SocketException('falhou')), semConexao);
      expect(mensagemDoServidor(http.ClientException('falhou')), semConexao);
    });

    test('demais erros não mostram detalhe técnico', () {
      const generica = 'Não foi possível concluir agora. Tente de novo.';
      expect(mensagemDoServidor(const PostgrestException(message: 'permission denied for table x', code: '42501')), generica);
      expect(mensagemDoServidor(Exception('boom')), generica);
      expect(mensagemDoServidor('texto'), generica);
    });
  });

  test('comMensagem devolve o resultado ou a falha já traduzida', () async {
    expect(await comMensagem(() async => 7), 7);
    await expectLater(
      comMensagem(() async => throw const PostgrestException(message: 'Proposta já respondida.', code: 'P0001')),
      throwsA(isA<FalhaComMensagem>().having((f) => f.mensagem, 'mensagem', 'Proposta já respondida.')),
    );
    expect(const FalhaComMensagem('x').toString(), 'x');
  });
}
