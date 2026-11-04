import 'dart:typed_data';

import 'package:dailyobra/screens/cronograma_screen.dart';
import 'package:dailyobra/screens/dia_obra_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/screens/obras_screen.dart';
import 'package:dailyobra/screens/pendencias_screen.dart';
import 'package:dailyobra/services/cronograma_service.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/equipe_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/pendencias_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'apoio.dart';

final dia = DateTime(2026, 11, 20);
final etapas = Calculo.de(const ParametrosObra(area: '120')).resultado!.etapas;
final primeira = etapas[0];
final segunda = etapas[1];

Obra obraDe(
  FuncaoObra f, {
  Map<EtapaId, DatasEtapa> datas = const {},
  Map<EtapaId, StatusEtapa> status = const {},
  List<DateTime?> prazos = const [],
}) => Obra(
  id: 'o1',
  papel: switch (f) {
    FuncaoObra.responsavel => Papel.admin,
    FuncaoObra.cliente => Papel.cliente,
    _ => Papel.membro,
  },
  funcao: f,
  dados: const DadosObra(nome: 'Residência Silva', cidade: 'Maringá', uf: 'PR'),
  parametros: const ParametrosObra(area: '120'),
  statusEtapas: status,
  cronograma: datas,
  prazosAbertos: prazos,
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

final comDatas = {
  primeira.etapa: DatasEtapa(
    inicioPrevisto: DateTime(2026, 11, 1),
    fimPrevisto: DateTime(2026, 11, 15),
    inicioReal: DateTime(2026, 11, 2),
  ),
  segunda.etapa: DatasEtapa(
    inicioPrevisto: DateTime(2026, 11, 16),
    fimPrevisto: DateTime(2026, 11, 30),
  ),
};

const joao = MembroObra(
  id: 'u2',
  nome: 'João Mestre',
  funcao: FuncaoObra.mestre,
);
const dona = MembroObra(id: 'u5', nome: 'Dona Lia', funcao: FuncaoObra.cliente);

final trinca = Pendencia(
  id: 'p1',
  descricao: 'Trinca na parede',
  etapa: primeira.etapa,
  responsavelId: 'u2',
  responsavelNome: 'João Mestre',
  prazo: DateTime(2026, 11, 15),
);
const resolvida = Pendencia(
  id: 'p2',
  descricao: 'Porta riscada',
  resolvida: true,
);

void preparar({List<Pendencia> pendencias = const [], String? erro}) {
  CronogramaService.instance.definirParaTeste(erro: erro);
  PendenciasService.instance.definirParaTeste(
    pendencias: pendencias,
    erro: erro,
  );
  DiarioService.instance.definirParaTeste();
  EquipeService.instance.definirParaTeste(membros: const [joao, dona]);
}

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

Future<void> abrirCronograma(
  WidgetTester tester,
  Obra obra, {
  bool escuro = false,
}) => abrir(
  tester,
  CronogramaScreen(obra: obra, hoje: dia),
  escuro: escuro,
);

Future<void> abrirPendencias(
  WidgetTester tester,
  Obra obra, {
  bool escuro = false,
  Future<XFile?> Function(bool camera)? escolherFoto,
}) => abrir(
  tester,
  PendenciasScreen(obra: obra, hoje: dia, escolherFoto: escolherFoto),
  escuro: escuro,
);

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('sem datas, quem lidera monta o cronograma', (tester) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        await tocar(tester, find.text('Montar cronograma'));
        expect(find.text('Início da obra'), findsOneWidget);
        expect(find.text('Fim previsto'), findsOneWidget);
        await tocar(tester, find.text('Montar'));
        final (datas, comReal) =
            CronogramaService.instance.salvosDeTeste.single;
        expect(datas.length, etapas.length);
        expect(comReal, isFalse);
        expect(find.text(primeira.nome), findsOneWidget);
        expect(find.text('Previsto'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('sem datas, quem não lidera só espera', (tester) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(FuncaoObra.estagiario),
          escuro: escuro,
        );
        expect(
          find.text('O cronograma ainda não foi montado.'),
          findsOneWidget,
        );
        expect(find.text('Montar cronograma'), findsNothing);
      });

      testWidgets('mostra previsto, real e atraso de cada etapa', (
        tester,
      ) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(
            FuncaoObra.responsavel,
            datas: comDatas,
            status: {primeira.etapa: StatusEtapa.iniciada},
          ),
          escuro: escuro,
        );
        expect(find.text('2 etapas atrasadas'), findsOneWidget);
        expect(find.text('5 dias de atraso'), findsOneWidget);
        expect(find.text('4 dias de atraso'), findsOneWidget);
        expect(find.text('Previsto: 01/11 a 15/11'), findsOneWidget);
        expect(find.text('Real: 02/11, em andamento'), findsOneWidget);
        expect(find.text('Em andamento'), findsNothing);
        expect(find.text('Real: não começou'), findsWidgets);
        expect(find.byType(BarrasDaEtapa), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('etapa concluída mostra quanto atrasou', (tester) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(
            FuncaoObra.responsavel,
            datas: {
              primeira.etapa: DatasEtapa(
                inicioPrevisto: DateTime(2026, 11, 1),
                fimPrevisto: DateTime(2026, 11, 15),
                inicioReal: DateTime(2026, 11, 2),
                fimReal: DateTime(2026, 11, 18),
              ),
            },
            status: {primeira.etapa: StatusEtapa.concluida},
          ),
          escuro: escuro,
        );
        expect(find.text('Concluída'), findsOneWidget);
        expect(find.text('Real: 02/11 a 18/11'), findsOneWidget);
        expect(find.text('Terminou 3 dias depois do previsto'), findsOneWidget);
        expect(find.text('Em dia'), findsOneWidget);
      });

      testWidgets('quem lidera ajusta as datas de uma etapa', (tester) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(FuncaoObra.mestre, datas: comDatas),
          escuro: escuro,
        );
        await tocar(tester, find.text(primeira.nome));
        expect(find.text('Início real'), findsOneWidget);
        await tocar(tester, find.text('Salvar'));
        final (datas, comReal) =
            CronogramaService.instance.salvosDeTeste.single;
        expect(datas.keys.single, primeira.etapa);
        expect(comReal, isTrue);
      });

      testWidgets('fim antes do início fica na janela com o motivo', (
        tester,
      ) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(FuncaoObra.mestre, datas: comDatas),
          escuro: escuro,
        );
        await tocar(tester, find.text(primeira.nome));
        await tocar(tester, find.text('01/11/2026'));
        await tocar(tester, find.text('20'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Salvar'));
        expect(
          find.text('O fim previsto não pode vir antes do início.'),
          findsOneWidget,
        );
        expect(CronogramaService.instance.salvosDeTeste, isEmpty);
      });

      testWidgets('quem não lidera só vê as datas', (tester) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(FuncaoObra.estagiario, datas: comDatas),
          escuro: escuro,
        );
        await tester.tap(find.text(primeira.nome));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Refazer datas'), findsNothing);
      });

      testWidgets('refazer avisa que troca as datas previstas', (tester) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(FuncaoObra.responsavel, datas: comDatas),
          escuro: escuro,
        );
        await tocar(tester, find.text('Refazer datas'));
        expect(
          find.textContaining('As datas reais ficam como estão'),
          findsOneWidget,
        );
        await tocar(tester, find.text('Montar'));
        expect(CronogramaService.instance.salvosDeTeste.single.$2, isFalse);
      });

      testWidgets('falha ao salvar avisa e mantém a tela', (tester) async {
        preparar(erro: 'Sem conexão.');
        await abrirCronograma(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        await tocar(tester, find.text('Montar cronograma'));
        await tocar(tester, find.text('Montar'));
        expect(find.text('Sem conexão.'), findsOneWidget);
        expect(find.text('Montar cronograma'), findsOneWidget);
      });

      testWidgets('empreiteiro vê o cronograma sem valores', (tester) async {
        preparar();
        await abrirCronograma(
          tester,
          obraDe(FuncaoObra.empreiteiro, datas: comDatas),
          escuro: escuro,
        );
        expect(find.text(primeira.nome), findsOneWidget);
        expect(find.textContaining('R\$'), findsNothing);
      });

      testWidgets('lista as pendências abertas com prazo e responsável', (
        tester,
      ) async {
        preparar(pendencias: [trinca, resolvida]);
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        expect(find.text('Trinca na parede'), findsOneWidget);
        expect(find.text('Porta riscada'), findsNothing);
        expect(find.textContaining('João Mestre'), findsOneWidget);
        expect(find.textContaining('até 15/11'), findsOneWidget);
        expect(find.text('5 dias vencida'), findsOneWidget);
        await tester.tap(find.text('Resolvidas (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Porta riscada'), findsOneWidget);
        expect(find.text('Trinca na parede'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('sem pendências convida a registrar', (tester) async {
        preparar();
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        expect(find.text('Nenhuma pendência aberta'), findsOneWidget);
      });

      testWidgets('registra pendência com etapa, responsável e prazo', (
        tester,
      ) async {
        preparar();
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.estagiario),
          escuro: escuro,
        );
        await tester.tap(find.text('Nova pendência'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('descricao')),
          'Falta rejunte',
        );
        await tocar(tester, find.text('Sem responsável'));
        expect(
          find.text('Dona Lia'),
          findsNothing,
          reason: 'cliente não resolve pendência',
        );
        await tester.tap(find.text('João Mestre').last);
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Salvar'));
        final salva = PendenciasService.instance.salvasDeTeste.single;
        expect(salva.descricao, 'Falta rejunte');
        expect(salva.responsavelId, 'u2');
        expect(find.text('Falta rejunte'), findsOneWidget);
      });

      testWidgets('pendência sem descrição não salva', (tester) async {
        preparar();
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        await tester.tap(find.text('Nova pendência'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Salvar'));
        expect(find.text('Descreva a pendência.'), findsOneWidget);
        expect(PendenciasService.instance.salvasDeTeste, isEmpty);
      });

      testWidgets('foto entra na pendência', (tester) async {
        preparar();
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
          escolherFoto: (_) async =>
              XFile.fromData(Uint8List(100), name: 'a.jpg'),
        );
        await tester.tap(find.text('Nova pendência'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('descricao')), 'Trinca');
        await tocar(tester, find.text('Da galeria'));
        expect(find.byType(MiniaturaFoto), findsOneWidget);
        expect(find.text('Da galeria'), findsNothing);
        await tocar(tester, find.text('Salvar'));
        expect(
          PendenciasService.instance.salvasDeTeste.single.fotoPath,
          isNotNull,
        );
      });

      testWidgets('foto grande demais avisa', (tester) async {
        preparar();
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
          escolherFoto: (_) async =>
              XFile.fromData(Uint8List(6 * 1024 * 1024), name: 'a.jpg'),
        );
        await tester.tap(find.text('Nova pendência'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Da galeria'));
        expect(find.textContaining('passou de 5 MB'), findsOneWidget);
        expect(find.byType(MiniaturaFoto), findsNothing);
      });

      testWidgets('marca como resolvida', (tester) async {
        preparar(pendencias: [trinca]);
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        await tester.tap(find.text('Trinca na parede'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Marcar como resolvida'));
        expect(PendenciasService.instance.resolvidasDeTeste, [('p1', true)]);
        expect(find.text('Nenhuma pendência aberta'), findsOneWidget);
      });

      testWidgets('reabre uma resolvida', (tester) async {
        preparar(pendencias: [resolvida]);
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        await tester.tap(find.text('Resolvidas (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Porta riscada'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Reabrir'));
        expect(PendenciasService.instance.resolvidasDeTeste, [('p2', false)]);
      });

      testWidgets('exclui depois de confirmar', (tester) async {
        preparar(pendencias: [trinca]);
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        await tester.tap(find.text('Trinca na parede'));
        await tester.pumpAndSettle();
        await tocar(tester, find.byTooltip('Excluir'));
        expect(PendenciasService.instance.excluidasDeTeste, isEmpty);
        await tocar(tester, find.text('Excluir'));
        expect(PendenciasService.instance.excluidasDeTeste, ['p1']);
      });

      testWidgets('quem não tem relação com a pendência só lê', (tester) async {
        preparar(
          pendencias: const [
            Pendencia(
              id: 'p3',
              descricao: 'De outra pessoa',
              possoMexer: false,
            ),
          ],
        );
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.empreiteiro),
          escuro: escuro,
        );
        await tester.tap(find.text('De outra pessoa'));
        await tester.pumpAndSettle();
        expect(find.text('Salvar'), findsNothing);
        expect(find.text('Marcar como resolvida'), findsNothing);
        expect(find.byTooltip('Excluir'), findsNothing);
      });

      testWidgets('falha ao carregar pendências deixa tentar de novo', (
        tester,
      ) async {
        preparar(erro: 'Sem conexão.');
        await abrirPendencias(
          tester,
          obraDe(FuncaoObra.mestre),
          escuro: escuro,
        );
        expect(find.text('Sem conexão.'), findsOneWidget);
        expect(find.text('Tentar de novo'), findsOneWidget);
      });

      testWidgets('obra avisa do atraso e das pendências vencidas', (
        tester,
      ) async {
        preparar();
        final atrasada = DateTime(hoje.year, hoje.month, hoje.day - 5);
        ObrasService.instance.definirParaTeste(
          obras: [
            obraDe(
              FuncaoObra.responsavel,
              datas: {
                primeira.etapa: DatasEtapa(
                  inicioPrevisto: DateTime(hoje.year, hoje.month, hoje.day - 9),
                  fimPrevisto: atrasada,
                ),
              },
              prazos: [atrasada, null],
            ),
          ],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        expect(
          find.text(
            '1 etapa atrasada, a maior com 5 dias. 1 pendência vencida.',
          ),
          findsOneWidget,
        );
        await rolarAte(tester, find.text('Cronograma'));
        expect(find.text('1 etapa atrasada'), findsOneWidget);
        expect(find.text('2 abertas · 1 vencida'), findsOneWidget);
      });

      testWidgets('obra em dia não mostra aviso', (tester) async {
        preparar();
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.responsavel)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Cronograma'));
        expect(find.text('Sem datas ainda'), findsOneWidget);
        expect(find.textContaining('atrasada'), findsNothing);
      });

      testWidgets('cliente vê o cronograma e não vê pendências', (
        tester,
      ) async {
        preparar();
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.cliente)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Cronograma'));
        expect(find.text('Pendências'), findsNothing);
      });

      testWidgets('lista de obras mostra a obra atrasada', (tester) async {
        preparar();
        ObrasService.instance.definirParaTeste(
          obras: [
            obraDe(
              FuncaoObra.responsavel,
              datas: {
                primeira.etapa: DatasEtapa(
                  inicioPrevisto: DateTime(hoje.year, hoje.month, hoje.day - 9),
                  fimPrevisto: DateTime(hoje.year, hoje.month, hoje.day - 5),
                ),
              },
            ),
          ],
        );
        await abrir(tester, const ObrasScreen(), escuro: escuro);
        expect(find.text('Atrasada'), findsOneWidget);
      });
    });
  }
}
