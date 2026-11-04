import 'dart:convert';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<EnderecoCep?> cepFalso(String cep) async => switch (cep) {
  '78720586' => const EnderecoCep(logradouro: 'Av. João Ponce de Arruda', bairro: 'Vila Operária', cidade: 'Rondonópolis', uf: 'MT'),
  '78700000' => const EnderecoCep(logradouro: '', bairro: '', cidade: 'Rondonópolis', uf: 'MT'),
  _ => null,
};

Future<List<String>> cidadesFalsas(String uf) async => uf == 'MT' ? const ['Cuiabá', 'Rondonópolis', 'Sinop'] : const ['Maringá'];

Finder campo(String nome) => find.descendant(of: find.byKey(Key('endereco-$nome')), matching: find.byType(TextField));

Future<ControleEndereco> abrir(
  WidgetTester tester, {
  ControleEndereco? controle,
  bool escuro = false,
  bool exigeEndereco = false,
  bool exigeCidade = false,
  bool comOutrasUnidades = false,
  Map<String, String> erros = const {},
  BuscarCep buscar = cepFalso,
  BuscarCidades buscarCidades = cidadesFalsas,
  VoidCallback? aoMudar,
}) async {
  final c = controle ?? ControleEndereco();
  addTearDown(c.dispose);
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro(ThemeData.light().textTheme),
      darkTheme: AppTheme.escuro(ThemeData.dark().textTheme),
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CamposEndereco(
            controle: c,
            erros: erros,
            buscar: buscar,
            buscarCidades: buscarCidades,
            exigeEndereco: exigeEndereco,
            exigeCidade: exigeCidade,
            comOutrasUnidades: comOutrasUnidades,
            aoMudar: aoMudar,
            ajudaCidade: 'As lojas dela aparecem primeiro.',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
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

  group('enderecoEmTexto', () {
    test('completo', () {
      expect(
        enderecoEmTexto(logradouro: 'Av. Brasil', numero: '10', complemento: 'sala 2', bairro: 'Centro', cep: '78700000'),
        'Av. Brasil, 10, sala 2 – Centro, CEP 78700-000',
      );
    });

    test('pula o que falta', () {
      expect(enderecoEmTexto(logradouro: 'Av. Brasil'), 'Av. Brasil');
      expect(enderecoEmTexto(), '');
    });
  });

  group('validarOpcional', () {
    test('tudo vazio passa', () {
      final c = ControleEndereco();
      addTearDown(c.dispose);
      expect(c.validarOpcional(), isEmpty);
    });

    test('CEP pela metade não passa', () {
      final c = ControleEndereco(cep: '7872');
      addTearDown(c.dispose);
      expect(c.validarOpcional().keys, contains('cep'));
    });

    test('rua pede número e número pede rua', () {
      final a = ControleEndereco(logradouro: 'Av. Brasil', cidade: 'Sinop', uf: 'MT');
      final b = ControleEndereco(numero: '10', cidade: 'Sinop', uf: 'MT');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      expect(a.validarOpcional().keys, ['numero']);
      expect(b.validarOpcional().keys, ['logradouro']);
    });

    test('endereço pede a cidade', () {
      final c = ControleEndereco(logradouro: 'Av. Brasil', numero: '10');
      addTearDown(c.dispose);
      expect(c.validarOpcional().keys, ['cidade']);
    });
  });

  test('partes para o banco, com CEP só em números e vazios como nulos', () {
    final c = ControleEndereco(cep: '78720-586', logradouro: ' Av. Brasil ', numero: '10');
    addTearDown(c.dispose);
    expect(c.partes(), {'cep': '78720586', 'logradouro': 'Av. Brasil', 'numero': '10', 'complemento': null, 'bairro': null});
    final vazio = ControleEndereco();
    addTearDown(vazio.dispose);
    expect(vazio.partes()['cep'], isNull);
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('mostra todos os campos desde o começo', (tester) async {
        await abrir(tester, escuro: escuro);
        for (final nome in ['cep', 'rua', 'numero', 'complemento', 'bairro']) {
          expect(campo(nome), findsOneWidget, reason: nome);
        }
        expect(find.text('Cidade e estado'), findsOneWidget);
        expect(find.text('Não sei o CEP'), findsOneWidget);
        expect(find.text('Escolher cidade'), findsOneWidget);
        expect(find.text('As lojas dela aparecem primeiro.'), findsOneWidget);
        expect(campo('outras'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CEP preenche rua, bairro, cidade e estado', (tester) async {
        var mudancas = 0;
        final c = await abrir(tester, escuro: escuro, aoMudar: () => mudancas++);
        await tester.enterText(campo('cep'), '78720586');
        await tester.pumpAndSettle();
        expect(c.logradouro.text, 'Av. João Ponce de Arruda');
        expect(c.bairro.text, 'Vila Operária');
        expect(c.cidade.text, 'Rondonópolis');
        expect(c.uf, 'MT');
        expect(find.text('Rondonópolis · MT'), findsOneWidget);
        expect(mudancas, greaterThan(0));
      });

      testWidgets('CEP da cidade inteira não apaga a rua digitada', (tester) async {
        final c = await abrir(tester, escuro: escuro);
        await tester.enterText(campo('rua'), 'Rua da Obra');
        await tester.enterText(campo('cep'), '78700000');
        await tester.pumpAndSettle();
        expect(c.logradouro.text, 'Rua da Obra');
        expect(c.cidade.text, 'Rondonópolis');
      });

      testWidgets('CEP que não existe avisa e deixa seguir', (tester) async {
        await abrir(tester, escuro: escuro);
        await tester.enterText(campo('cep'), '00000000');
        await tester.pumpAndSettle();
        expect(find.text('CEP não encontrado.'), findsOneWidget);
        expect(find.text('Não sei o CEP'), findsOneWidget);
      });

      testWidgets('sem CEP escolhe estado e cidade na lista', (tester) async {
        final c = await abrir(tester, escuro: escuro);
        await tester.tap(find.text('Não sei o CEP'));
        await tester.pumpAndSettle();
        expect(find.text('Escolha o estado'), findsOneWidget);
        await tester.tap(find.text('MT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rondonópolis'));
        await tester.pumpAndSettle();
        expect(c.cidade.text, 'Rondonópolis');
        expect(c.uf, 'MT');
        expect(find.text('Rondonópolis · MT'), findsOneWidget);
      });

      testWidgets('tocar na cidade abre a lista para trocar', (tester) async {
        await abrir(tester, escuro: escuro, controle: ControleEndereco(cidade: 'Maringá', uf: 'PR'));
        await tester.tap(find.text('Maringá · PR'));
        await tester.pumpAndSettle();
        expect(find.text('Escolha o estado'), findsOneWidget);
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
        final c = await abrir(
          tester,
          escuro: escuro,
          buscarCidades: (_) async => throw const FalhaComMensagem('fora do ar'),
        );
        await tester.tap(find.text('Não sei o CEP'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MT'));
        await tester.pumpAndSettle();
        expect(find.text('Não deu para carregar as cidades.'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '  Rondonópolis ');
        await tester.tap(find.text('Usar esta cidade'));
        await tester.pumpAndSettle();
        expect(c.cidade.text, 'Rondonópolis');
        expect(c.uf, 'MT');
      });

      testWidgets('erros aparecem em cada campo', (tester) async {
        await abrir(tester, escuro: escuro, erros: const {'logradouro': 'Informe a rua.', 'cidade': 'Escolha a cidade.'});
        expect(find.text('Informe a rua.'), findsOneWidget);
        expect(find.text('Escolha a cidade.'), findsOneWidget);
      });

      testWidgets('quem exige marca os campos e a loja tem outras unidades', (tester) async {
        await abrir(tester, escuro: escuro, exigeEndereco: true, exigeCidade: true, comOutrasUnidades: true);
        expect(campo('outras'), findsOneWidget);
        expect(find.text('Rua *'), findsOneWidget);
        expect(find.text('Cidade e estado *'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
