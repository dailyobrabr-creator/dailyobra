import 'package:dailyobra/screens/componentes.dart';
import 'package:dailyobra/screens/dia_obra_screen.dart';
import 'package:dailyobra/screens/ditar_dia.dart';
import 'package:dailyobra/screens/hoje_na_obra.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/ia_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart' hide hoje;

final agora = DateTime.now();
final hoje = DateTime(agora.year, agora.month, agora.day);

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
  statusEtapas: const {EtapaId.preparacao: StatusEtapa.concluida},
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

Future<void> abrirPainel(
  WidgetTester tester, {
  FuncaoObra f = FuncaoObra.responsavel,
  List<DiaObra> dias = const [],
  bool compacto = true,
  bool escuro = false,
}) async {
  final obra = obraDe(f);
  ObrasService.instance.definirParaTeste(obras: [obra]);
  DiarioService.instance.definirParaTeste(dias: dias);
  IaService.instance.definirParaTeste();
  await abrir(
    tester,
    Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [HojeNaObra(obra: obra, compacto: compacto)],
      ),
    ),
    escuro: escuro,
  );
}

void telaLarga(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

DiaObra diaDeHoje(SituacaoDia situacao) => DiaObra(
  id: 'd1',
  obraId: 'o1',
  data: hoje,
  situacao: situacao,
  equipe: const [ItemEquipe(funcao: 'Pedreiro', quantidade: 3)],
);

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra a obra, o dia e o andamento', (tester) async {
    await abrirPainel(tester);
    expect(find.text('Hoje na obra'), findsOneWidget);
    expect(
      find.text('Residência Silva\n${diaPorExtenso(agora)}'),
      findsOneWidget,
    );
    final etapas = Calculo.de(const ParametrosObra(area: '120'))
        .resultado!
        .etapas;
    expect(find.text('1 de ${etapas.length} etapas'), findsOneWidget);
    expect(find.textContaining('% concluída'), findsOneWidget);
    expect(find.textContaining('Etapa atual:'), findsOneWidget);
  });

  group('atalhos por função', () {
    final atalhos = ['Ditar o dia', 'Lançar gasto', 'Marcar presença'];
    final todos = [...atalhos, 'Nova pendência'];

    for (final f in [FuncaoObra.responsavel, FuncaoObra.mestre]) {
      testWidgets('${f.name} tem todos', (tester) async {
        await abrirPainel(tester, f: f);
        for (final a in todos) {
          expect(find.text(a), findsOneWidget, reason: a);
        }
      });
    }

    for (final f in [FuncaoObra.estagiario, FuncaoObra.empreiteiro]) {
      testWidgets('${f.name} registra e não lança dinheiro', (tester) async {
        await abrirPainel(tester, f: f);
        expect(find.text('Ditar o dia'), findsOneWidget);
        expect(find.text('Nova pendência'), findsOneWidget);
        expect(find.text('Lançar gasto'), findsNothing);
        expect(find.text('Marcar presença'), findsNothing);
      });
    }

    testWidgets('cliente só acompanha', (tester) async {
      await abrirPainel(tester, f: FuncaoObra.cliente, compacto: false);
      for (final a in todos) {
        expect(find.text(a), findsNothing, reason: a);
      }
      expect(find.text('Dinheiro da obra'), findsNothing);
      expect(find.text('Caixa da obra'), findsNothing);
      expect(find.text('Propostas comerciais'), findsNothing);
      expect(find.text('Diário de hoje'), findsOneWidget);
    });
  });

  group('diário de hoje', () {
    testWidgets('avisa que ainda não foi preenchido', (tester) async {
      await abrirPainel(tester);
      expect(find.text('Ainda não preenchido'), findsOneWidget);
    });

    testWidgets('para o cliente, ainda não registrado', (tester) async {
      await abrirPainel(tester, f: FuncaoObra.cliente);
      expect(find.text('Ainda não registrado'), findsOneWidget);
    });

    testWidgets('mostra o rascunho', (tester) async {
      await abrirPainel(tester, dias: [diaDeHoje(SituacaoDia.rascunho)]);
      expect(find.text('Em rascunho · 3 pessoas'), findsOneWidget);
    });

    testWidgets('mostra o dia finalizado', (tester) async {
      await abrirPainel(tester, dias: [diaDeHoje(SituacaoDia.finalizado)]);
      expect(find.text('Finalizado · 3 pessoas'), findsOneWidget);
    });

    testWidgets('a linha leva ao dia de hoje', (tester) async {
      await abrirPainel(tester);
      await tocar(tester, find.text('Diário de hoje'));
      final tela = tester.widget<DiaObraScreen>(find.byType(DiaObraScreen));
      expect(tela.data, hoje);
      expect(find.byType(JanelaDoDitado), findsNothing);
    });
  });

  group('ditar pelo atalho', () {
    testWidgets('abre direto a janela no dia de hoje', (tester) async {
      await abrirPainel(tester);
      await tocar(tester, find.text('Ditar o dia'));
      expect(find.byType(JanelaDoDitado), findsOneWidget);
      expect(
        tester.widget<DiaObraScreen>(find.byType(DiaObraScreen)).data,
        hoje,
      );
    });

    testWidgets('dia finalizado abre sem a janela', (tester) async {
      await abrirPainel(tester, dias: [diaDeHoje(SituacaoDia.finalizado)]);
      await tocar(tester, find.text('Ditar o dia'));
      expect(find.byType(DiaObraScreen), findsOneWidget);
      expect(find.byType(JanelaDoDitado), findsNothing);
    });

    testWidgets('fechar a janela não reabre ao salvar', (tester) async {
      await abrirPainel(tester);
      await tocar(tester, find.text('Ditar o dia'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(JanelaDoDitado), findsNothing);
      await tester.tap(find.text('Salvar rascunho'));
      await tester.pumpAndSettle();
      expect(find.byType(JanelaDoDitado), findsNothing);
    });

    testWidgets('ao voltar, a linha mostra o que foi salvo', (tester) async {
      await abrirPainel(tester);
      IaService.instance.definirParaTeste(
        dia: const SugestaoDoDia(
          equipe: [ItemEquipe(funcao: 'Pedreiro', quantidade: 2)],
        ),
      );
      await tocar(tester, find.text('Ditar o dia'));
      await tester.enterText(
        find.byKey(const Key('texto-do-ditado')),
        'Vieram 2 pedreiros',
      );
      await tester.tap(find.text('Organizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar rascunho'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DiaObraScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Em rascunho · 2 pessoas'), findsOneWidget);
    });
  });

  group('tamanho da tela', () {
    testWidgets('no celular mostra tudo em duas colunas', (tester) async {
      await abrirPainel(tester);
      expect(find.byType(EntradaDaObra), findsNWidgets(13));
      expect(find.text('Ver tudo da obra'), findsNothing);
      final diario = tester.getTopLeft(find.text('Diário de hoje'));
      final cronograma = tester.getTopLeft(find.text('Cronograma'));
      final pendencias = tester.getTopLeft(find.text('Pendências'));
      expect(cronograma.dy, diario.dy);
      expect(pendencias.dy, greaterThan(diario.dy));
    });

    testWidgets('no computador mostra tudo em quatro colunas', (tester) async {
      await abrirPainel(tester, compacto: false);
      telaLarga(tester);
      await tester.pumpAndSettle();
      expect(find.text('Ver tudo da obra'), findsNothing);
      for (final parte in [
        'Diário de hoje',
        'Cronograma',
        'Pendências',
        'Compras da obra',
        'Dinheiro da obra',
        'Mão de obra',
        'Caixa da obra',
        'Documentos',
        'Qualidade e segurança',
        'Equipe',
        'Propostas comerciais',
      ]) {
        expect(find.text(parte), findsOneWidget, reason: parte);
      }
      final diario = tester.getTopLeft(find.text('Diário de hoje'));
      final cronograma = tester.getTopLeft(find.text('Cronograma'));
      expect(cronograma.dy, diario.dy);
      expect(cronograma.dx, greaterThan(diario.dx));
      expect(tester.getTopLeft(find.text('Compras da obra')).dy, diario.dy);
      expect(
        tester.getTopLeft(find.text('Dinheiro da obra')).dy,
        greaterThan(diario.dy),
      );
    });

    testWidgets('no celular os atalhos ficam em duas colunas', (tester) async {
      await abrirPainel(tester);
      final ditar = tester.getTopLeft(find.text('Ditar o dia'));
      final gasto = tester.getTopLeft(find.text('Lançar gasto'));
      final presenca = tester.getTopLeft(find.text('Marcar presença'));
      expect(gasto.dy, ditar.dy);
      expect(presenca.dy, greaterThan(ditar.dy));
    });

    testWidgets('abrir a obra leva à tela dela', (tester) async {
      await abrirPainel(tester);
      await tocar(tester, find.text('Abrir a obra'));
      expect(find.byType(ObraScreen), findsOneWidget);
    });

    testWidgets('funciona no tema escuro', (tester) async {
      await abrirPainel(tester, escuro: true);
      expect(tester.takeException(), isNull);
      expect(find.text('Hoje na obra'), findsOneWidget);
    });
  });
}
