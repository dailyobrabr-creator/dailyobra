import 'dart:async';
import 'dart:convert';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'apoio.dart';

const rondonopolis = EnderecoCep(
  logradouro: 'R. Fernando Corrêa da Costa',
  bairro: 'Vila Operária',
  cidade: 'Rondonópolis',
  uf: 'MT',
);
const se = EnderecoCep(
  logradouro: 'Praça da Sé',
  bairro: 'Sé',
  cidade: 'São Paulo',
  uf: 'SP',
);
const naoDeu = 'Não deu para buscar o CEP agora. Preencha o endereço à mão.';

Finder campo(String nome) => find.descendant(
  of: find.byKey(Key('endereco-$nome')),
  matching: find.byType(TextField),
);

String texto(WidgetTester tester, String nome) =>
    tester.widget<TextField>(campo(nome)).controller!.text;

Future<ControleEndereco> abrirCampos(
  WidgetTester tester, {
  required bool escuro,
  required BuscarCep buscar,
}) async {
  final controle = ControleEndereco();
  addTearDown(controle.dispose);
  await abrir(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.s4),
        child: CamposEndereco(controle: controle, buscar: buscar),
      ),
    ),
    escuro: escuro,
  );
  return controle;
}

void main() {
  test('buscarCep lê o ViaCEP', () async {
    Uri? pedida;
    http.Client cliente(int status, String corpo) => MockClient((r) async {
      pedida = r.url;
      return http.Response.bytes(
        utf8.encode(corpo),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final e = await buscarCep(
      '78700000',
      cliente: cliente(
        200,
        jsonEncode({
          'cep': '78700-000',
          'logradouro': 'R. Fernando Corrêa da Costa',
          'bairro': 'Vila Operária',
          'localidade': 'Rondonópolis',
          'uf': 'MT',
        }),
      ),
    );
    expect(pedida.toString(), 'https://viacep.com.br/ws/78700000/json/');
    expect(
      [e!.logradouro, e.bairro, e.cidade, e.uf],
      ['R. Fernando Corrêa da Costa', 'Vila Operária', 'Rondonópolis', 'MT'],
    );
    expect(
      await buscarCep('00000000', cliente: cliente(200, '{"erro": "true"}')),
      isNull,
    );
    expect(
      await buscarCep('00000000', cliente: cliente(200, '{"erro": true}')),
      isNull,
    );
    await expectLater(
      buscarCep('78700000', cliente: cliente(500, '')),
      throwsA(
        isA<FalhaComMensagem>().having((f) => f.mensagem, 'mensagem', naoDeu),
      ),
    );
  });

  test('validar mostra o que falta', () {
    final c = ControleEndereco();
    addTearDown(c.dispose);
    expect(c.preenchido, isFalse);
    expect(c.validar(), {
      'cep': 'Informe o CEP com 8 números.',
      'logradouro': 'Informe a rua.',
      'numero': 'Informe o número (ou S/N).',
      'cidade': 'Informe a cidade.',
      'uf': 'Escolha o estado.',
    });
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('CEP preenche rua, bairro, cidade e UF', (tester) async {
        final c = await abrirCampos(
          tester,
          escuro: escuro,
          buscar: (cep) async => rondonopolis,
        );
        await tester.enterText(campo('cep'), '78700000');
        await tester.pumpAndSettle();
        expect(texto(tester, 'cep'), '78700-000');
        expect(texto(tester, 'rua'), 'R. Fernando Corrêa da Costa');
        expect(texto(tester, 'bairro'), 'Vila Operária');
        expect(find.text('Rondonópolis · MT'), findsOneWidget);
        await tester.enterText(campo('numero'), '1500');
        await tester.pumpAndSettle();
        expect(c.campos(), {
          'cep': '78700000',
          'logradouro': 'R. Fernando Corrêa da Costa',
          'numero': '1500',
          'complemento': null,
          'bairro': 'Vila Operária',
          'cidade': 'Rondonópolis',
          'uf': 'MT',
          'outras_unidades': null,
        });
        expect(c.validar(), isEmpty);
      });

      testWidgets('CEP com traço busca os 8 números', (tester) async {
        final pedidos = <String>[];
        await abrirCampos(
          tester,
          escuro: escuro,
          buscar: (cep) async {
            pedidos.add(cep);
            return rondonopolis;
          },
        );
        await tester.enterText(campo('cep'), ' 78700-000 ');
        await tester.pumpAndSettle();
        expect(pedidos, ['78700000']);
      });

      testWidgets('CEP não encontrado', (tester) async {
        await abrirCampos(tester, escuro: escuro, buscar: (cep) async => null);
        await tester.enterText(campo('cep'), '00000000');
        await tester.pumpAndSettle();
        expect(find.text('CEP não encontrado.'), findsOneWidget);
        await tester.enterText(campo('rua'), 'Rua Um');
        expect(texto(tester, 'rua'), 'Rua Um');
      });

      testWidgets('falha de rede', (tester) async {
        await abrirCampos(
          tester,
          escuro: escuro,
          buscar: (cep) async => throw const FalhaComMensagem(naoDeu),
        );
        await tester.enterText(campo('cep'), '78700000');
        await tester.pumpAndSettle();
        expect(find.text(naoDeu), findsOneWidget);
      });

      testWidgets('resposta atrasada de outro CEP é ignorada', (tester) async {
        final esperas = <String, Completer<EnderecoCep?>>{};
        await abrirCampos(
          tester,
          escuro: escuro,
          buscar: (cep) => (esperas[cep] = Completer()).future,
        );
        await tester.enterText(campo('cep'), '78700000');
        await tester.pump();
        await tester.enterText(campo('cep'), '01001000');
        await tester.pump();
        esperas['01001000']!.complete(se);
        await tester.pumpAndSettle();
        esperas['78700000']!.complete(rondonopolis);
        await tester.pumpAndSettle();
        expect(texto(tester, 'rua'), 'Praça da Sé');
        expect(find.text('São Paulo · SP'), findsOneWidget);
      });
    });
  }
}
