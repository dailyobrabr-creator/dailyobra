import 'dart:async';
import 'dart:typed_data';

import 'package:dailyobra/screens/dia_obra_screen.dart';
import 'package:dailyobra/screens/dinheiro_screen.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/dinheiro_service.dart';
import 'package:dailyobra/services/ditado.dart';
import 'package:dailyobra/services/ia_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'apoio.dart' hide hoje;

Obra obraDe(FuncaoObra f) => Obra(
  id: 'o1',
  papel: switch (f) {
    FuncaoObra.responsavel => Papel.admin,
    FuncaoObra.cliente => Papel.cliente,
    _ => Papel.membro,
  },
  funcao: f,
  dados: const DadosObra(nome: 'Residência Silva', cidade: 'Maringá', uf: 'PR'),
  parametros: const ParametrosObra(area: '120'),
  statusEtapas: const {},
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

final dia = DateTime(2026, 11, 3);

const sugestao = SugestaoDoDia(
  climaManha: Clima.sol,
  climaTarde: Clima.chuva,
  equipe: [ItemEquipe(funcao: 'Pedreiro', quantidade: 3)],
  atividades: [Atividade(descricao: 'Reboco da sala', local: 'Térreo')],
  ocorrencias: [Ocorrencia(descricao: 'Faltou água')],
  materiais: [
    MaterialDia(material: 'Cimento', quantidade: 20, unidade: 'sacos'),
  ],
  equipamentos: [EquipamentoDia(equipamento: 'Betoneira')],
  observacoes: 'Vistoria na sexta',
);

/// Um ditado de mentira: o teste decide o que foi ouvido e quando a escuta termina.
class DitadoDeTeste implements Ditado {
  DitadoDeTeste({this.funciona = true});
  final bool funciona;
  ValueChanged<String>? ouvir_;
  VoidCallback? parou;
  var escutas = 0;
  var paradas = 0;

  @override
  Future<bool> preparar() async => funciona;

  @override
  Future<void> ouvir({
    required ValueChanged<String> aoOuvir,
    required VoidCallback aoParar,
  }) async {
    escutas++;
    ouvir_ = aoOuvir;
    parou = aoParar;
  }

  @override
  Future<void> parar() async => paradas++;
}

Future<void> abrirDia(
  WidgetTester tester, {
  FuncaoObra f = FuncaoObra.responsavel,
  List<DiaObra> dias = const [],
  bool escuro = false,
}) {
  DiarioService.instance.definirParaTeste(dias: dias);
  return abrir(
    tester,
    DiaObraScreen(obra: obraDe(f), data: dia),
    escuro: escuro,
  );
}

Future<void> abrirJanela(WidgetTester tester) async {
  await tester.tap(find.text('Ditar o dia'));
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

final textoDoDitado = find.byKey(const Key('texto-do-ditado'));

String textoEscrito(WidgetTester tester) =>
    tester.widget<TextField>(textoDoDitado).controller!.text;

Future<void> ditar(
  WidgetTester tester, [
  String texto = 'Vieram 3 pedreiros',
]) async {
  await abrirJanela(tester);
  await tester.enterText(textoDoDitado, texto);
  await tester.tap(find.text('Organizar'));
  await tester.pumpAndSettle();
}

Finder campo(String rotulo) => find.descendant(
  of: find.byWidgetPredicate((w) => w is CampoTexto && w.rotulo == rotulo),
  matching: find.byType(TextField),
);

String lido(WidgetTester tester, String rotulo) =>
    tester.widget<TextField>(campo(rotulo)).controller!.text;

Widget telaDoGasto({
  FuncaoObra f = FuncaoObra.responsavel,
  LancamentoObra? gasto,
}) => GastoScreen(
  obra: obraDe(f),
  gasto: gasto,
  escolherFoto: (_) async => XFile.fromData(Uint8List(100), name: 'a.jpg'),
);

final nota = SugestaoDaNota(
  fornecedor: 'Casa do Construtor',
  descricao: 'Cimento e areia',
  valor: 1234.5,
  data: DateTime(2026, 10, 20),
  tipo: TipoGasto.servico,
);

void main() {
  setUp(() {
    IaService.instance.definirParaTeste(dia: sugestao, nota: nota);
    DinheiroService.instance.definirParaTeste();
    Ditado.instancia = DitadoDeTeste();
  });

  group('diário por voz', () {
    testWidgets('quem registra vê o botão', (tester) async {
      await abrirDia(tester, f: FuncaoObra.estagiario);
      expect(find.text('Ditar o dia'), findsOneWidget);
    });

    testWidgets('cliente não vê o botão', (tester) async {
      await abrirDia(tester, f: FuncaoObra.cliente);
      expect(find.text('Ditar o dia'), findsNothing);
    });

    testWidgets('dia finalizado não tem o botão', (tester) async {
      await abrirDia(
        tester,
        dias: [
          DiaObra(
            id: 'd1',
            obraId: 'o1',
            data: dia,
            situacao: SituacaoDia.finalizado,
            atividades: const [Atividade(descricao: 'Reboco')],
          ),
        ],
      );
      expect(find.text('Ditar o dia'), findsNothing);
    });

    testWidgets('a janela avisa que o texto vai para a IA', (tester) async {
      await abrirDia(tester);
      await abrirJanela(tester);
      expect(find.textContaining('vai para a IA'), findsOneWidget);
    });

    testWidgets('preenche a tela e não salva sozinho', (tester) async {
      await abrirDia(tester);
      await ditar(tester, 'Vieram 3 pedreiros, rebocamos a sala');
      expect(IaService.instance.pedidosDeTeste, [
        'Vieram 3 pedreiros, rebocamos a sala',
      ]);
      expect(find.byKey(const Key('texto-do-ditado')), findsNothing);
      expect(
        find.text('Dia preenchido. Confira antes de salvar.'),
        findsOneWidget,
      );
      await rolarAte(tester, find.text('Reboco da sala'));
      expect(find.text('Reboco da sala'), findsOneWidget);
      await rolarAte(tester, find.text('Faltou água'));
      await rolarAte(tester, find.textContaining('Cimento'));
      await rolarAte(tester, find.textContaining('Betoneira'));
      await rolarAte(tester, find.byKey(const Key('observacoes')));
      final observacoes = find.descendant(
        of: find.byKey(const Key('observacoes')),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(observacoes).controller!.text,
        'Vistoria na sexta',
      );
      expect(DiarioService.instance.salvosDeTeste, isEmpty);
    });

    testWidgets('salvar grava o que foi conferido', (tester) async {
      await abrirDia(tester);
      await ditar(tester);
      await tocar(tester, find.text('Salvar rascunho'));
      final (salvo, finalizar) = DiarioService.instance.salvosDeTeste.single;
      expect(finalizar, isFalse);
      expect(salvo.climaManha, Clima.sol);
      expect(salvo.climaTarde, Clima.chuva);
      expect(salvo.equipe.single.funcao, 'Pedreiro');
      expect(salvo.materiais.single.quantidade, 20);
      expect(salvo.observacoes, 'Vistoria na sexta');
    });

    testWidgets('desfazer devolve o dia como estava', (tester) async {
      await abrirDia(
        tester,
        dias: [
          DiaObra(
            id: 'd1',
            obraId: 'o1',
            data: dia,
            observacoes: 'Antes',
            atividades: const [Atividade(descricao: 'Limpeza')],
          ),
        ],
      );
      await ditar(tester);
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      await rolarAte(tester, find.text('Limpeza'));
      expect(find.text('Reboco da sala'), findsNothing);
      await rolarAte(tester, find.byKey(const Key('observacoes')));
      final observacoes = find.descendant(
        of: find.byKey(const Key('observacoes')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(observacoes).controller!.text, 'Antes');
      await tocar(tester, find.text('Salvar rascunho'));
      final (salvo, _) = DiarioService.instance.salvosDeTeste.single;
      expect(salvo.atividades.map((a) => a.descricao), ['Limpeza']);
      expect(salvo.equipe, isEmpty);
    });

    testWidgets('soma ao que já estava preenchido', (tester) async {
      await abrirDia(
        tester,
        dias: [
          DiaObra(
            id: 'd1',
            obraId: 'o1',
            data: dia,
            climaManha: Clima.nublado,
            observacoes: 'Antes',
            equipe: const [ItemEquipe(funcao: 'Servente')],
          ),
        ],
      );
      await ditar(tester);
      await tocar(tester, find.text('Salvar rascunho'));
      final (salvo, _) = DiarioService.instance.salvosDeTeste.single;
      expect(salvo.climaManha, Clima.nublado);
      expect(salvo.climaTarde, Clima.chuva);
      expect(salvo.equipe.map((e) => e.funcao), ['Servente', 'Pedreiro']);
      expect(salvo.observacoes, 'Antes\nVistoria na sexta');
    });

    testWidgets('texto vazio não gasta o uso da IA', (tester) async {
      await abrirDia(tester);
      await abrirJanela(tester);
      await tester.tap(find.text('Organizar'));
      await tester.pumpAndSettle();
      expect(find.text('Fale ou escreva como foi o dia.'), findsOneWidget);
      expect(IaService.instance.pedidosDeTeste, isEmpty);
    });

    testWidgets('se a IA falhar, o texto continua na janela', (tester) async {
      IaService.instance.definirParaTeste(
        erro: 'A IA ainda não está ligada. Preencha à mão.',
      );
      await abrirDia(tester);
      await ditar(tester, 'Vieram 3 pedreiros');
      expect(
        find.text('A IA ainda não está ligada. Preencha à mão.'),
        findsOneWidget,
      );
      expect(textoEscrito(tester), 'Vieram 3 pedreiros');
      IaService.instance.definirParaTeste(dia: sugestao);
      await tester.tap(find.text('Organizar'));
      await tester.pumpAndSettle();
      expect(textoDoDitado, findsNothing);
      expect(
        find.text('Dia preenchido. Confira antes de salvar.'),
        findsOneWidget,
      );
    });

    testWidgets('trava a janela enquanto organiza', (tester) async {
      final resposta = Completer<void>();
      IaService.instance.definirParaTeste(
        dia: sugestao,
        segurar: resposta.future,
      );
      await abrirDia(tester);
      await abrirJanela(tester);
      await tester.enterText(textoDoDitado, 'Vieram 3 pedreiros');
      await tester.tap(find.text('Organizar'));
      await tester.pump();
      expect(find.text('Organizando...'), findsOneWidget);
      final botoes = tester.widgetList<ButtonStyleButton>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(botoes.every((b) => b.onPressed == null), isTrue);
      resposta.complete();
      await tester.pumpAndSettle();
      expect(textoDoDitado, findsNothing);
    });

    testWidgets('cancelar não muda o dia', (tester) async {
      await abrirDia(tester);
      await abrirJanela(tester);
      await tester.enterText(textoDoDitado, 'Vieram 3 pedreiros');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(IaService.instance.pedidosDeTeste, isEmpty);
      await tester.tap(find.text('Salvar rascunho'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(DiarioService.instance.salvosDeTeste.single.$1.vazio, isTrue);
    });

    testWidgets('toque fora não joga fora o ditado', (tester) async {
      await abrirDia(tester);
      await abrirJanela(tester);
      await tester.enterText(textoDoDitado, 'Vieram 3 pedreiros');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(textoEscrito(tester), 'Vieram 3 pedreiros');
    });

    testWidgets('a fala vira texto e cada escuta soma à anterior', (
      tester,
    ) async {
      final ditado = DitadoDeTeste();
      Ditado.instancia = ditado;
      await abrirDia(tester);
      await abrirJanela(tester);
      await tocar(tester, find.text('Falar'));
      expect(find.text('Parar de ouvir'), findsOneWidget);
      ditado.ouvir_!('vieram três');
      await tester.pump();
      ditado.ouvir_!('vieram três pedreiros');
      await tester.pump();
      expect(textoEscrito(tester), 'vieram três pedreiros');
      ditado.parou!();
      await tester.pumpAndSettle();
      expect(find.text('Falar'), findsOneWidget);
      await tocar(tester, find.text('Falar'));
      ditado.ouvir_!('e choveu');
      await tester.pump();
      expect(textoEscrito(tester), 'vieram três pedreiros e choveu');
      expect(ditado.escutas, 2);
    });

    testWidgets('parar de ouvir mantém o texto', (tester) async {
      final ditado = DitadoDeTeste();
      Ditado.instancia = ditado;
      await abrirDia(tester);
      await abrirJanela(tester);
      await tocar(tester, find.text('Falar'));
      ditado.ouvir_!('vieram três');
      await tocar(tester, find.text('Parar de ouvir'));
      expect(ditado.paradas, 1);
      expect(find.text('Falar'), findsOneWidget);
      expect(textoEscrito(tester), 'vieram três');
    });

    testWidgets('organizar com o microfone ligado para de ouvir', (
      tester,
    ) async {
      final ditado = DitadoDeTeste();
      Ditado.instancia = ditado;
      await abrirDia(tester);
      await abrirJanela(tester);
      await tocar(tester, find.text('Falar'));
      ditado.ouvir_!('vieram três');
      await tester.pump();
      await tester.tap(find.text('Organizar'));
      await tester.pumpAndSettle();
      expect(ditado.paradas, 1);
      expect(IaService.instance.pedidosDeTeste, ['vieram três']);
    });

    testWidgets('cancelar com o microfone ligado para de ouvir', (
      tester,
    ) async {
      final ditado = DitadoDeTeste();
      Ditado.instancia = ditado;
      await abrirDia(tester);
      await abrirJanela(tester);
      await tocar(tester, find.text('Falar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(ditado.paradas, 1);
    });

    testWidgets('sem microfone dá para escrever', (tester) async {
      Ditado.instancia = DitadoDeTeste(funciona: false);
      await abrirDia(tester);
      await abrirJanela(tester);
      await tocar(tester, find.text('Falar'));
      expect(find.textContaining('microfone do teclado'), findsOneWidget);
      expect(find.text('Falar'), findsOneWidget);
      await tester.enterText(textoDoDitado, 'Choveu');
      await tester.tap(find.text('Organizar'));
      await tester.pumpAndSettle();
      expect(IaService.instance.pedidosDeTeste, ['Choveu']);
    });

    testWidgets('no tema escuro o desfazer aparece', (tester) async {
      await abrirDia(tester, escuro: true);
      await ditar(tester);
      final contexto = tester.element(find.text('Desfazer'));
      expect(
        Theme.of(contexto).snackBarTheme.actionTextColor,
        contexto.cores.acao,
      );
    });
  });

  group('nota por foto', () {
    testWidgets('gasto novo começa pela foto', (tester) async {
      await abrir(tester, telaDoGasto());
      expect(find.textContaining('A IA lê a nota'), findsOneWidget);
      final foto = tester.getTopLeft(find.text('Tirar foto')).dy;
      final descricao = tester.getTopLeft(campo('O que foi pago')).dy;
      expect(foto, lessThan(descricao));
    });

    testWidgets('a foto preenche o gasto e pede conferência', (tester) async {
      await abrir(tester, telaDoGasto());
      await tocar(tester, find.text('Da galeria'));
      expect(IaService.instance.pedidosDeTeste, ['o1/nota-0.jpg']);
      expect(lido(tester, 'O que foi pago'), 'Cimento e areia');
      expect(lido(tester, 'Valor (R\$)'), '1.234,5');
      expect(lido(tester, 'Fornecedor'), 'Casa do Construtor');
      expect(
        find.text('Confira os dados lidos da nota antes de salvar.'),
        findsOneWidget,
      );
      expect(find.text('Serviço'), findsOneWidget);
      expect(DinheiroService.instance.salvosDeTeste, isEmpty);
    });

    testWidgets('salvar grava o que foi lido', (tester) async {
      await abrir(tester, telaDoGasto());
      await tocar(tester, find.text('Da galeria'));
      await tocar(tester, find.text('Salvar'));
      final g = DinheiroService.instance.salvosDeTeste.single;
      expect(g.descricao, 'Cimento e areia');
      expect(g.valor, 1234.5);
      expect(g.fornecedor, 'Casa do Construtor');
      expect(g.data, DateTime(2026, 10, 20));
      expect(g.tipo, TipoGasto.servico);
      expect(g.notaPath, 'o1/nota-0.jpg');
    });

    testWidgets('não troca o que a pessoa já digitou', (tester) async {
      await abrir(tester, telaDoGasto());
      await tester.enterText(campo('O que foi pago'), 'Areia');
      await tester.enterText(campo('Valor (R\$)'), '100');
      await tocar(tester, find.text('Da galeria'));
      expect(lido(tester, 'O que foi pago'), 'Areia');
      expect(lido(tester, 'Valor (R\$)'), '100');
      expect(lido(tester, 'Fornecedor'), 'Casa do Construtor');
    });

    testWidgets('não troca o tipo que a pessoa escolheu', (tester) async {
      await abrir(tester, telaDoGasto());
      await tocar(tester, find.text('Material'));
      await tester.tap(find.text('Outro').last);
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Da galeria'));
      expect(find.text('Outro'), findsOneWidget);
      await tocar(tester, find.text('Salvar'));
      expect(
        DinheiroService.instance.salvosDeTeste.single.tipo,
        TipoGasto.outro,
      );
    });

    testWidgets('mostra a leitura e deixa salvar sem esperar', (tester) async {
      final resposta = Completer<void>();
      IaService.instance.definirParaTeste(nota: nota, segurar: resposta.future);
      await abrir(tester, telaDoGasto());
      await tester.tap(find.text('Da galeria'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Lendo a nota...'), findsOneWidget);
      final salvar = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Salvar'),
      );
      expect(salvar.onPressed, isNotNull);
      resposta.complete();
      await tester.pumpAndSettle();
      expect(find.text('Lendo a nota...'), findsNothing);
    });

    testWidgets('se a IA falhar, a foto fica e o resto é à mão', (
      tester,
    ) async {
      IaService.instance.definirParaTeste(
        erro: 'Esta foto não parece uma nota. Preencha à mão.',
      );
      await abrir(tester, telaDoGasto());
      await tocar(tester, find.text('Da galeria'));
      expect(
        find.text('Esta foto não parece uma nota. Preencha à mão.'),
        findsOneWidget,
      );
      expect(find.byType(MiniaturaFoto), findsOneWidget);
      expect(lido(tester, 'O que foi pago'), '');
      expect(
        find.text('Confira os dados lidos da nota antes de salvar.'),
        findsNothing,
      );
    });

    testWidgets('remover a foto durante a leitura descarta o resultado', (
      tester,
    ) async {
      final resposta = Completer<void>();
      IaService.instance.definirParaTeste(nota: nota, segurar: resposta.future);
      await abrir(tester, telaDoGasto());
      await tester.tap(find.text('Da galeria'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      tester.widget<MiniaturaFoto>(find.byType(MiniaturaFoto)).aoRemover!();
      resposta.complete();
      await tester.pumpAndSettle();
      expect(lido(tester, 'O que foi pago'), '');
      expect(
        find.text('Confira os dados lidos da nota antes de salvar.'),
        findsNothing,
      );
    });

    testWidgets('gasto já lançado não é preenchido de novo', (tester) async {
      final gasto = LancamentoObra(
        id: 'g1',
        descricao: 'Areia lavada',
        valor: 500,
        data: DateTime(2026, 11, 3),
        fornecedor: '',
      );
      await abrir(tester, telaDoGasto(gasto: gasto));
      expect(find.textContaining('A IA lê a nota'), findsNothing);
      await tocar(tester, find.text('Da galeria'));
      expect(IaService.instance.pedidosDeTeste, isEmpty);
      expect(lido(tester, 'Fornecedor'), '');
    });

    testWidgets('a data lida aparece no campo', (tester) async {
      await abrir(tester, telaDoGasto());
      await tocar(tester, find.text('Da galeria'));
      expect(find.textContaining('20/10/2026'), findsOneWidget);
    });
  });
}
