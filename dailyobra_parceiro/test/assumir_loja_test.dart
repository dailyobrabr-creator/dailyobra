import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/assumir_loja_screen.dart';
import 'package:dailyobra_parceiro/screens/cadastro_loja_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

/// Campo obrigatório mostra "Rótulo *": acha pela ordem na tela.
Finder campo(String rotulo) =>
    find.byType(TextField).at(rotulo.startsWith('CNPJ') ? 0 : 1);

final botao = find.widgetWithText(FilledButton, 'Entrar na minha loja');

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('CNPJ inválido não chega ao servidor', (tester) async {
        var chamadas = 0;
        await abrir(
          tester,
          AssumirLojaScreen(assumir: (_, _) async => chamadas++),
          escuro: escuro,
        );
        await tester.enterText(campo('CNPJ da loja'), '11111111111111');
        await tester.enterText(campo('Código de acesso'), 'ABCD-1234-EF56');
        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(find.text('CNPJ inválido. Confira os números.'), findsOneWidget);
        expect(chamadas, 0);
      });

      testWidgets('código vazio pede o código', (tester) async {
        var chamadas = 0;
        await abrir(
          tester,
          AssumirLojaScreen(assumir: (_, _) async => chamadas++),
          escuro: escuro,
        );
        await tester.enterText(campo('CNPJ da loja'), '11222333000181');
        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(find.text('Digite o código que você recebeu.'), findsOneWidget);
        expect(chamadas, 0);
      });

      testWidgets('manda só os números do CNPJ e o código', (tester) async {
        (String, String)? recebido;
        await abrir(
          tester,
          AssumirLojaScreen(assumir: (c, k) async => recebido = (c, k)),
          escuro: escuro,
        );
        await tester.enterText(campo('CNPJ da loja'), '11.222.333/0001-81');
        await tester.enterText(campo('Código de acesso'), ' abcd-1234-ef56 ');
        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(recebido, ('11222333000181', 'abcd-1234-ef56'));
      });

      testWidgets('erro do servidor aparece e deixa tentar de novo', (
        tester,
      ) async {
        await abrir(
          tester,
          AssumirLojaScreen(
            assumir: (_, _) async =>
                throw const FalhaComMensagem('CNPJ ou código não conferem.'),
          ),
          escuro: escuro,
        );
        await tester.enterText(campo('CNPJ da loja'), '11222333000181');
        await tester.enterText(campo('Código de acesso'), 'ABCD-1234-EF56');
        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(find.text('CNPJ ou código não conferem.'), findsOneWidget);
        expect(tester.widget<FilledButton>(botao).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cadastro mostra a entrada de quem já está no DailyObra', (
        tester,
      ) async {
        await abrir(tester, const CadastroLojaScreen(), escuro: escuro);
        await tester.tap(find.text('Minha loja já está no DailyObra'));
        await tester.pumpAndSettle();
        expect(find.byType(AssumirLojaScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
