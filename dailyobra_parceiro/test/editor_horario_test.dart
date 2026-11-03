import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/editor_horario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

Future<ControleHorario> abrirEditor(
  WidgetTester tester, {
  required bool escuro,
  String texto = '',
}) async {
  final controle = ControleHorario.doTexto(texto);
  addTearDown(controle.dispose);
  await abrir(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.s4),
        child: EditorHorario(controle: controle),
      ),
    ),
    escuro: escuro,
  );
  return controle;
}

void main() {
  test('texto do horário escolhido', () {
    final c = ControleHorario.doTexto('');
    for (var d = 1; d <= 5; d++) {
      c.abrirDia(d, true);
      c.definir(
        d,
        abre: 420,
        fecha: 1080,
        intervalo: true,
        saida: 660,
        volta: 780,
      );
    }
    c.abrirDia(6, true);
    c.definir(6, abre: 420, fecha: 720);
    expect(c.texto(), 'Seg a sex 7h às 11h e 13h às 18h; sáb 7h às 12h');
    expect(c.alterado, isTrue);
    expect(c.validar(), isNull);
  });

  test('abre o horário salvo', () {
    const salvo = 'Seg 7h30 às 17h30; ter a sex 7h às 17h30; sáb 7h às 12h30';
    final c = ControleHorario.doTexto(salvo);
    expect(c.texto(), salvo);
    expect(c.alterado, isFalse);
    expect(c.naoLido, isNull);
    final seg = c.dia(1);
    expect(
      [seg.aberto, seg.abre, seg.fecha, seg.intervalo],
      [true, 450, 1050, false],
    );
    expect(c.dia(7).aberto, isFalse);
    final comIntervalo = ControleHorario.doTexto(
      'Seg a sex 7h às 11h e 13h às 18h',
    ).dia(3);
    expect(
      [comIntervalo.intervalo, comIntervalo.saida, comIntervalo.volta],
      [true, 660, 780],
    );
  });

  test('sem mexer, o horário antigo fica', () {
    final c = ControleHorario.doTexto('Comercial');
    expect(c.naoLido, 'Comercial');
    expect(c.alterado, isFalse);
    expect([for (var d = 1; d <= 7; d++) c.dia(d).aberto], everyElement(false));
  });

  test('copiar segunda', () {
    final c = ControleHorario.doTexto('Sáb 8h às 12h');
    c.abrirDia(1, true);
    c.definir(1, abre: 480, fecha: 1080, intervalo: true);
    c.copiarSegunda();
    expect(c.texto(), 'Seg a sex 8h às 12h e 13h às 18h; sáb 8h às 12h');
    expect(c.alterado, isTrue);
  });

  test('validar', () {
    final c = ControleHorario.doTexto('');
    c.abrirDia(1, true);
    c.definir(1, abre: 1080, fecha: 480);
    expect(c.validar(), 'Confira o horário de segunda.');
    c.definir(1, abre: 480, fecha: 1080);
    c.abrirDia(6, true);
    c.definir(6, intervalo: true, saida: 840, volta: 780);
    expect(c.validar(), 'Confira o horário de sábado.');
    c.definir(6, saida: 720);
    expect(c.validar(), isNull);
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('escolher no editor', (tester) async {
        final c = await abrirEditor(tester, escuro: escuro);
        expect(find.text('Fechado'), findsNWidgets(7));
        await tester.tap(find.byKey(const Key('horario-1')));
        await tester.pumpAndSettle();
        expect(find.text('Abre'), findsOneWidget);
        expect(find.text('08:00'), findsOneWidget);
        expect(find.text('18:00'), findsOneWidget);
        await tester.tap(find.byKey(const Key('horario-1-fecha')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('17:30').last);
        await tester.pumpAndSettle();
        expect(c.texto(), 'Seg 8h às 17h30');
        expect(c.alterado, isTrue);
      });

      testWidgets('avisa o horário que não deu para ler', (tester) async {
        await abrirEditor(tester, escuro: escuro, texto: 'Comercial');
        expect(
          find.text(
            'Não deu para ler o horário anterior (Comercial). Escolha de novo.',
          ),
          findsOneWidget,
        );
      });
    });
  }
}
