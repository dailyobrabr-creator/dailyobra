import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/assumir_loja_screen.dart';
import 'package:dailyobra_parceiro/screens/cadastro_loja_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

/// Primeiros campos na ordem da tela: nome e CNPJ; o endereço pela chave; os demais pelo texto de exemplo.
Finder campo(int i) => find.byType(TextField).at(i);

Finder doEndereco(String nome) => find.descendant(
  of: find.byKey(Key('endereco-$nome')),
  matching: find.byType(TextField),
);

final botaoCadastrar = find.widgetWithText(FilledButton, 'Cadastrar loja');

/// Volta ao começo do formulário (o que sai da tela deixa de existir na lista).
Future<void> voltarAoTopo(WidgetTester tester) async {
  // Sem foco: o campo digitado por último não puxa a tela de volta para o cursor
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
  await tester.pumpAndSettle();
}

Future<EnderecoCep?> buscarFalso(String cep) async => const EnderecoCep(
  logradouro: 'R. Fernando Corrêa da Costa',
  bairro: 'Vila Operária',
  cidade: 'Rondonópolis',
  uf: 'MT',
);

Future<void> preencher(WidgetTester tester, {required String cnpj}) async {
  await tester.enterText(campo(0), 'Casa do Construtor');
  await tester.enterText(campo(1), cnpj);
  await tester.enterText(
    find.widgetWithText(TextField, '(44) 99999-0000'),
    '(44) 99999-0000',
  );
  await rolarAte(tester, doEndereco('cep'));
  await tester.enterText(doEndereco('cep'), '78700000');
  await tester.pumpAndSettle();
  await tester.enterText(doEndereco('numero'), '1500');
  final frete = find.widgetWithText(TextField, '0 = grátis');
  await rolarAte(tester, frete);
  await tester.enterText(frete, '50');
  await tester.enterText(
    find.widgetWithText(TextField, '0 = sem mínimo'),
    '100',
  );
}

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('CNPJ inválido avisa e não cadastra', (tester) async {
        var chamadas = 0;
        await abrir(
          tester,
          CadastroLojaScreen(
            criar: (_) async {
              chamadas++;
              return 'x';
            },
            buscarCep: buscarFalso,
          ),
          escuro: escuro,
        );
        await preencher(tester, cnpj: '11.222.333/0001-80');
        await rolarAte(tester, botaoCadastrar);
        await tester.tap(botaoCadastrar);
        await tester.pumpAndSettle();
        expect(chamadas, 0);
        await voltarAoTopo(tester);
        await rolarAte(tester, find.textContaining('CNPJ inválido'));
        expect(find.textContaining('CNPJ inválido'), findsOneWidget);
      });

      testWidgets('campos válidos cadastram com o CNPJ só com dígitos', (
        tester,
      ) async {
        Map<String, dynamic>? enviado;
        await abrir(
          tester,
          CadastroLojaScreen(
            criar: (d) async {
              enviado = d;
              return 'l1';
            },
            buscarCep: buscarFalso,
          ),
          escuro: escuro,
        );
        await preencher(tester, cnpj: '11222333000181');
        await voltarAoTopo(tester);
        expect(find.text('11.222.333/0001-81'), findsOneWidget);
        await rolarAte(tester, botaoCadastrar);
        await tester.tap(botaoCadastrar);
        await tester.pumpAndSettle();
        expect(enviado, isNotNull);
        expect(enviado!['cnpj'], '11222333000181');
        expect(enviado!['cep'], '78700000');
        expect(enviado!['logradouro'], 'R. Fernando Corrêa da Costa');
        expect(enviado!['numero'], '1500');
        expect(enviado!['bairro'], 'Vila Operária');
        expect(enviado!['cidade'], 'Rondonópolis');
        expect(enviado!['uf'], 'MT');
        expect(enviado!['horario'], '');
        expect(enviado!.containsKey('endereco'), isFalse);
        expect(enviado!['whatsapp'], '44999990000');
        expect(enviado!['frete_fixo'], 50.0);
        expect(enviado!['pedido_minimo'], 100.0);
      });

      testWidgets('CNPJ que já existe oferece a entrada com código', (
        tester,
      ) async {
        await abrir(
          tester,
          CadastroLojaScreen(
            criar: (_) async => throw const FalhaComMensagem(
              'Já existe uma loja cadastrada com este CNPJ.',
            ),
            buscarCep: buscarFalso,
          ),
          escuro: escuro,
        );
        await preencher(tester, cnpj: '11.222.333/0001-81');
        await rolarAte(tester, botaoCadastrar);
        await tester.tap(botaoCadastrar);
        await tester.pumpAndSettle();
        await rolarAte(
          tester,
          find.text('A loja é minha: entrar com o código'),
        );
        await tester.tap(find.text('A loja é minha: entrar com o código'));
        await tester.pumpAndSettle();
        expect(find.byType(AssumirLojaScreen), findsOneWidget);
      });

      testWidgets('cadastro vazio mostra o que falta', (tester) async {
        await abrir(
          tester,
          CadastroLojaScreen(criar: (_) async => 'x', buscarCep: buscarFalso),
          escuro: escuro,
        );
        await rolarAte(tester, botaoCadastrar);
        await tester.tap(botaoCadastrar);
        await tester.pumpAndSettle();
        await voltarAoTopo(tester);
        for (final erro in [
          'Informe o CEP com 8 números.',
          'Informe a rua.',
          'Informe o número (ou S/N).',
        ]) {
          await rolarAte(tester, find.text(erro));
          expect(find.text(erro), findsOneWidget);
        }
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await tester.pumpAndSettle();
        expect(find.text('Informe o nome da loja.'), findsOneWidget);
      });
    });
  }
}
