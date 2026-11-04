import 'dart:convert';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const enderecoFalso = EnderecoCep(logradouro: 'Av. João Ponce de Arruda', bairro: 'Vila Operária', cidade: 'Rondonópolis', uf: 'MT');

Future<EnderecoCep?> cepFalso(String cep) async => cep == '78720586' ? enderecoFalso : null;

Future<List<String>> cidadesFalsas(String uf) async => uf == 'MT' ? const ['Cuiabá', 'Rondonópolis', 'Sinop'] : const ['Maringá'];

final campoCep = find.byKey(const Key('regiao-cep'));

Future<void> abrir(
  WidgetTester tester, {
  String cidade = '',
  String uf = '',
  String? erro,
  bool escuro = false,
  BuscarCep consultarCep = cepFalso,
  BuscarCidades consultarCidades = cidadesFalsas,
  void Function(String cidade, String uf)? aoEscolher,
  ValueChanged<EnderecoCep>? onCep,
}) async {
  var c = cidade, u = uf;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro(ThemeData.light().textTheme),
      darkTheme: AppTheme.escuro(ThemeData.dark().textTheme),
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, atualizar) => Padding(
            padding: const EdgeInsets.all(16),
            child: CampoRegiao(
              cidade: c,
              uf: u,
              erro: erro,
              ajuda: 'As lojas dela aparecem primeiro.',
              consultarCep: consultarCep,
              consultarCidades: consultarCidades,
              onCep: onCep,
              onEscolher: (nova, sigla) {
                aoEscolher?.call(nova, sigla);
                atualizar(() {
                  c = nova;
                  u = sigla;
                });
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('cidadesDoEstado', () {
    test('devolve os nomes da lista do IBGE', () async {
      late Uri pedido;
      final cidades = await cidadesDoEstado(
        'MT',
        cliente: MockClient((r) async {
          pedido = r.url;
          return http.Response.bytes(
            utf8.encode(jsonEncode([
              {'id': 1, 'nome': 'Rondonópolis'},
              {'id': 2, 'nome': 'Cuiabá'},
            ])),
            200,
          );
        }),
      );
      expect(cidades, ['Rondonópolis', 'Cuiabá']);
      expect(pedido.path, contains('/estados/MT/municipios'));
    });

    test('falha do serviço vira mensagem', () async {
      expect(
        cidadesDoEstado('MT', cliente: MockClient((_) async => http.Response('', 500))),
        throwsA(isA<FalhaComMensagem>()),
      );
    });
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('sem região pede o CEP, sem campo de digitar cidade', (tester) async {
        await abrir(tester, escuro: escuro);
        expect(campoCep, findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Não sei o CEP'), findsOneWidget);
        expect(find.text('As lojas dela aparecem primeiro.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CEP preenche cidade e estado', (tester) async {
        (String, String)? escolha;
        EnderecoCep? endereco;
        await abrir(
          tester,
          escuro: escuro,
          aoEscolher: (c, u) => escolha = (c, u),
          onCep: (e) => endereco = e,
        );
        await tester.enterText(campoCep, '78720586');
        await tester.pumpAndSettle();
        expect(escolha, ('Rondonópolis', 'MT'));
        expect(endereco?.logradouro, 'Av. João Ponce de Arruda');
        expect(find.text('Rondonópolis · MT'), findsOneWidget);
        expect(campoCep, findsNothing);
      });

      testWidgets('máscara aceita CEP com traço', (tester) async {
        await abrir(tester, escuro: escuro);
        await tester.enterText(campoCep, '78720-586');
        await tester.pumpAndSettle();
        expect(find.text('Rondonópolis · MT'), findsOneWidget);
      });

      testWidgets('CEP pela metade não consulta', (tester) async {
        var consultas = 0;
        await abrir(
          tester,
          escuro: escuro,
          consultarCep: (_) async {
            consultas++;
            return null;
          },
        );
        await tester.enterText(campoCep, '7872');
        await tester.pumpAndSettle();
        expect(consultas, 0);
      });

      testWidgets('CEP que não existe avisa e mantém a escolha pela lista', (tester) async {
        await abrir(tester, escuro: escuro);
        await tester.enterText(campoCep, '00000000');
        await tester.pumpAndSettle();
        expect(find.text('CEP não encontrado. Confira os números ou escolha na lista.'), findsOneWidget);
        expect(find.text('Não sei o CEP'), findsOneWidget);
      });

      testWidgets('ViaCEP fora do ar não trava', (tester) async {
        await abrir(
          tester,
          escuro: escuro,
          consultarCep: (_) async => throw const FalhaComMensagem('fora do ar'),
        );
        await tester.enterText(campoCep, '78720586');
        await tester.pumpAndSettle();
        expect(find.text('Não deu para buscar o CEP agora. Escolha na lista.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('região salva aparece pronta e pode trocar', (tester) async {
        await abrir(tester, cidade: 'Maringá', uf: 'PR', escuro: escuro);
        expect(find.text('Maringá · PR'), findsOneWidget);
        expect(campoCep, findsNothing);
        await tester.tap(find.text('Trocar'));
        await tester.pumpAndSettle();
        expect(campoCep, findsOneWidget);
      });

      testWidgets('cidade antiga sem estado continua aparecendo', (tester) async {
        await abrir(tester, cidade: 'Maringá', escuro: escuro);
        expect(find.text('Maringá'), findsOneWidget);
      });

      testWidgets('erro da tela aparece nos dois estados', (tester) async {
        await abrir(tester, erro: 'Informe a cidade.', escuro: escuro);
        expect(find.text('Informe a cidade.'), findsOneWidget);
      });

      testWidgets('sem CEP escolhe estado e cidade na lista', (tester) async {
        (String, String)? escolha;
        await abrir(tester, escuro: escuro, aoEscolher: (c, u) => escolha = (c, u));
        await tester.tap(find.text('Não sei o CEP'));
        await tester.pumpAndSettle();
        expect(find.text('Escolha o estado'), findsOneWidget);
        await tester.tap(find.text('MT'));
        await tester.pumpAndSettle();
        expect(find.text('Cuiabá'), findsOneWidget);
        expect(find.text('Sinop'), findsOneWidget);
        await tester.tap(find.text('Rondonópolis'));
        await tester.pumpAndSettle();
        expect(escolha, ('Rondonópolis', 'MT'));
        expect(find.text('Rondonópolis · MT'), findsOneWidget);
      });

      testWidgets('busca na lista ignora acento', (tester) async {
        await abrir(tester, escuro: escuro);
        await tester.tap(find.text('Não sei o CEP'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MT'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'cuiaba');
        await tester.pumpAndSettle();
        expect(find.text('Cuiabá'), findsOneWidget);
        expect(find.text('Sinop'), findsNothing);
      });

      testWidgets('dá para voltar e escolher outro estado', (tester) async {
        await abrir(tester, escuro: escuro);
        await tester.tap(find.text('Não sei o CEP'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trocar estado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PR'));
        await tester.pumpAndSettle();
        expect(find.text('Maringá'), findsOneWidget);
      });

      testWidgets('lista fora do ar deixa digitar a cidade', (tester) async {
        (String, String)? escolha;
        await abrir(
          tester,
          escuro: escuro,
          consultarCidades: (_) async => throw const FalhaComMensagem('fora do ar'),
          aoEscolher: (c, u) => escolha = (c, u),
        );
        await tester.tap(find.text('Não sei o CEP'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MT'));
        await tester.pumpAndSettle();
        expect(find.text('Não deu para carregar as cidades.'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '  Rondonópolis ');
        await tester.tap(find.text('Usar esta cidade'));
        await tester.pumpAndSettle();
        expect(escolha, ('Rondonópolis', 'MT'));
      });
    });
  }
}
