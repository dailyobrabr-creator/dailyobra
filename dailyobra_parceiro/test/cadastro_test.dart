import 'package:dailyobra_parceiro/screens/cadastro_loja_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

/// Primeiros campos na ordem da tela: nome, CNPJ, cidade; os demais pelo texto de exemplo.
Finder campo(int i) => find.byType(TextField).at(i);

final botaoCadastrar = find.widgetWithText(FilledButton, 'Cadastrar loja');

Future<void> preencher(WidgetTester tester, {required String cnpj}) async {
  await tester.enterText(campo(0), 'Casa do Construtor');
  await tester.enterText(campo(1), cnpj);
  await tester.enterText(campo(2), 'Maringá');
  await tester.tap(find.text('UF'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('AL').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, '(44) 99999-0000'),
    '(44) 99999-0000',
  );
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
          ),
          escuro: escuro,
        );
        await preencher(tester, cnpj: '11.222.333/0001-80');
        await rolarAte(tester, botaoCadastrar);
        await tester.tap(botaoCadastrar);
        await tester.pumpAndSettle();
        expect(chamadas, 0);
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
          ),
          escuro: escuro,
        );
        await preencher(tester, cnpj: '11222333000181');
        expect(find.text('11.222.333/0001-81'), findsOneWidget);
        await rolarAte(tester, botaoCadastrar);
        await tester.tap(botaoCadastrar);
        await tester.pumpAndSettle();
        expect(enviado, isNotNull);
        expect(enviado!['cnpj'], '11222333000181');
        expect(enviado!['uf'], 'AL');
        expect(enviado!['whatsapp'], '44999990000');
        expect(enviado!['frete_fixo'], 50.0);
        expect(enviado!['pedido_minimo'], 100.0);
      });

      testWidgets('cadastro vazio mostra o que falta', (tester) async {
        await abrir(
          tester,
          CadastroLojaScreen(criar: (_) async => 'x'),
          escuro: escuro,
        );
        await rolarAte(tester, botaoCadastrar);
        await tester.tap(botaoCadastrar);
        await tester.pumpAndSettle();
        await rolarAteOFim(tester);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await tester.pumpAndSettle();
        expect(find.text('Informe o nome da loja.'), findsOneWidget);
      });
    });
  }
}
