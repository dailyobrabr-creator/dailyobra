import 'dart:convert';
import 'dart:typed_data';

import 'package:dailyobra/screens/dia_obra_screen.dart' show MiniaturaFoto;
import 'package:dailyobra/screens/dinheiro_screen.dart';
import 'package:dailyobra/screens/marca_screen.dart';
import 'package:dailyobra/screens/mudancas_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/screens/relatorio_screen.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/dinheiro_service.dart';
import 'package:dailyobra/services/equipe_service.dart';
import 'package:dailyobra/services/marca_service.dart';
import 'package:dailyobra/services/mudancas_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/pdf_diario.dart';
import 'package:dailyobra/services/pdf_relatorio.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'apoio.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

final hojeFixo = DateTime(2026, 11, 4);

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

const piso = Mudanca(
  id: 'm1',
  titulo: 'Trocar o piso da sala',
  descricao: 'Porcelanato no lugar da cerâmica',
  valor: 3500,
  dias: 5,
);
final aprovada = Mudanca(
  id: 'm2',
  titulo: 'Tirar a churrasqueira',
  valor: -1200,
  situacao: SituacaoMudanca.aprovada,
  resposta: 'Pode fazer',
  respondidoPor: 'Dona Lia',
  respondidaEm: DateTime(2026, 11, 3),
);

final diaFechado = DiaObra(
  obraId: 'o1',
  data: DateTime(2026, 11, 3),
  situacao: SituacaoDia.finalizado,
  equipe: const [ItemEquipe(funcao: 'Pedreiro', quantidade: 4)],
  atividades: const [
    Atividade(descricao: 'Reboco', local: 'Sala', percentual: 70),
  ],
  ocorrencias: const [Ocorrencia(descricao: 'Chuva à tarde')],
  fotos: const [FotoDia(caminho: 'o1/a.jpg', legenda: 'Sala')],
);
final diaRascunho = DiaObra(
  obraId: 'o1',
  data: DateTime(2026, 11, 4),
  atividades: const [Atividade(descricao: 'Texto não revisado')],
  fotos: const [FotoDia(caminho: 'o1/b.jpg')],
);

void preparar({
  List<Mudanca> mudancas = const [],
  List<DiaObra> dias = const [],
  List<MembroObra>? equipe,
  MarcaEngenheiro minha = const MarcaEngenheiro(),
  MarcaEngenheiro? daObra,
  String? erro,
}) {
  MudancasService.instance.definirParaTeste(mudancas: mudancas, erro: erro);
  DiarioService.instance.definirParaTeste(dias: dias);
  MarcaService.instance.definirParaTeste(
    minha: minha,
    daObra: daObra,
    erro: erro,
  );
  EquipeService.instance.definirParaTeste(
    membros:
        equipe ??
        const [
          MembroObra(
            id: 'eu',
            nome: 'Marina',
            funcao: FuncaoObra.responsavel,
            eu: true,
          ),
          MembroObra(id: 'c', nome: 'Dona Lia', funcao: FuncaoObra.cliente),
        ],
  );
}

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

/// O rótulo de campo obrigatório vem com " *": procura pelo próprio campo.
Finder campo(String rotulo) => find.descendant(
  of: find.byWidgetPredicate((w) => w is CampoTexto && w.rotulo == rotulo),
  matching: find.byType(TextField),
);

Future<void> abrirMudancas(
  WidgetTester tester,
  FuncaoObra f, {
  bool escuro = false,
  List<String>? enviados,
}) => abrir(
  tester,
  MudancasScreen(obra: obraDe(f), compartilhar: (t) async => enviados?.add(t)),
  escuro: escuro,
);

/// Abre por cima de outra tela, porque salvar volta para a anterior.
Future<void> abrirMarca(
  WidgetTester tester, {
  bool escuro = false,
  Future<XFile?> Function()? escolherLogo,
}) async {
  await abrir(
    tester,
    Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => MarcaScreen(escolherLogo: escolherLogo),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
    escuro: escuro,
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> abrirRelatorio(
  WidgetTester tester,
  FuncaoObra f, {
  bool escuro = false,
  List<RelatorioDaSemana>? enviados,
  DateTime? hoje,
}) => abrir(
  tester,
  RelatorioScreen(
    obra: obraDe(f),
    hoje: hoje ?? hojeFixo,
    enviarPdf: (r) async => enviados?.add(r),
  ),
  escuro: escuro,
);

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      group('marca', () {
        testWidgets('mostra e salva os dados', (tester) async {
          preparar(
            minha: const MarcaEngenheiro(nome: 'Duarte', registro: 'CREA 1'),
          );
          await abrirMarca(tester, escuro: escuro);
          expect(find.text('Duarte'), findsOneWidget);
          await tester.enterText(campo('Telefone'), '65 99999-0000');
          await tester.enterText(campo('E-mail'), 'contato@duarte.com.br');
          await tocar(tester, find.text('Salvar'));
          final salva = MarcaService.instance.salvasDeTeste.single;
          expect(salva.nome, 'Duarte');
          expect(salva.registro, 'CREA 1');
          expect(salva.telefone, '65 99999-0000');
          expect(salva.email, 'contato@duarte.com.br');
          expect(find.text('abrir'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('recusa e-mail errado', (tester) async {
          preparar();
          await abrirMarca(tester, escuro: escuro);
          await tester.enterText(campo('E-mail'), 'contato');
          await tocar(tester, find.text('Salvar'));
          expect(find.text('Confira o e-mail.'), findsOneWidget);
          expect(MarcaService.instance.salvasDeTeste, isEmpty);
        });

        testWidgets('logo nova entra no lugar da antiga', (tester) async {
          preparar(minha: const MarcaEngenheiro(logoPath: 'eu/velha.png'));
          await abrirMarca(
            tester,
            escuro: escuro,
            escolherLogo: () async => XFile.fromData(png, path: 'nova.png'),
          );
          await tocar(tester, find.text('Trocar logo'));
          await tocar(tester, find.text('Salvar'));
          final servico = MarcaService.instance;
          expect(servico.salvasDeTeste.single.logoPath, 'eu/logo.png');
          expect(servico.logosApagadosDeTeste, ['eu/velha.png']);
          expect(tester.takeException(), isNull);
        });

        testWidgets('tirar a logo apaga o arquivo', (tester) async {
          preparar(minha: const MarcaEngenheiro(logoPath: 'eu/velha.png'));
          await abrirMarca(tester, escuro: escuro);
          await tocar(tester, find.text('Tirar'));
          expect(find.text('Escolher logo'), findsOneWidget);
          await tocar(tester, find.text('Salvar'));
          final servico = MarcaService.instance;
          expect(servico.salvasDeTeste.single.logoPath, isNull);
          expect(servico.logosApagadosDeTeste, ['eu/velha.png']);
        });

        testWidgets('imagem grande demais não entra', (tester) async {
          preparar();
          await abrirMarca(
            tester,
            escuro: escuro,
            escolherLogo: () async => XFile.fromData(
              Uint8List(MarcaService.tamanhoMaximo + 1),
              name: 'grande.png',
            ),
          );
          await tocar(tester, find.text('Escolher logo'));
          expect(find.text('Use uma imagem de até 2 MB.'), findsOneWidget);
          expect(find.text('Tirar'), findsNothing);
        });

        testWidgets('sem conexão oferece tentar de novo', (tester) async {
          preparar(erro: 'Sem conexão.');
          await abrirMarca(tester, escuro: escuro);
          expect(find.text('Sem conexão.'), findsOneWidget);
          expect(find.text('Tentar de novo'), findsOneWidget);
          expect(find.text('Salvar'), findsNothing);
        });
      });

      group('mudanças', () {
        testWidgets('responsável pede aprovação e o aviso sai pronto', (
          tester,
        ) async {
          preparar();
          final enviados = <String>[];
          await abrirMudancas(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            enviados: enviados,
          );
          expect(find.text('Nenhuma mudança'), findsOneWidget);
          await tocar(tester, find.text('Nova mudança'));
          await tester.enterText(campo('O que muda'), ' Trocar o piso ');
          await tester.enterText(find.byKey(const Key('descricao')), 'Sala');
          await tester.enterText(campo('Valor (R\$)'), '3.500,50');
          await tester.enterText(campo('Dias no prazo'), '5');
          await tocar(tester, find.text('Pedir aprovação'));
          final m = MudancasService.instance.salvasDeTeste.single;
          expect(m.titulo, 'Trocar o piso');
          expect(m.descricao, 'Sala');
          expect(m.valor, 3500.5);
          expect(m.dias, 5);
          expect(find.text('Trocar o piso'), findsOneWidget);
          expect(enviados.single, contains('Residência Silva'));
          expect(enviados.single, contains('Trocar o piso'));
          expect(tester.takeException(), isNull);
        });

        testWidgets('mudança que reduz vai com sinal negativo', (tester) async {
          preparar();
          await abrirMudancas(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text('Nova mudança'));
          await tester.enterText(campo('O que muda'), 'Tirar a churrasqueira');
          await tocar(tester, find.text('Reduz'));
          await tester.enterText(campo('Valor (R\$)'), '1200');
          await tester.enterText(campo('Dias no prazo'), '3');
          await tocar(tester, find.text('Pedir aprovação'));
          final m = MudancasService.instance.salvasDeTeste.single;
          expect(m.valor, -1200);
          expect(m.dias, -3);
        });

        testWidgets('confere o formulário', (tester) async {
          preparar();
          await abrirMudancas(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text('Nova mudança'));
          await tester.enterText(campo('Valor (R\$)'), 'abc');
          await tester.enterText(campo('Dias no prazo'), '1,5');
          await tocar(tester, find.text('Pedir aprovação'));
          expect(find.text('Diga qual é a mudança.'), findsOneWidget);
          expect(find.text('Digite um valor válido.'), findsOneWidget);
          expect(find.text('Digite um número de dias.'), findsOneWidget);
          expect(MudancasService.instance.salvasDeTeste, isEmpty);
        });

        testWidgets('pendente pode ser editada, mantendo o sinal', (
          tester,
        ) async {
          preparar(
            mudancas: const [Mudanca(id: 'm3', titulo: 'Reduzir', valor: -100)],
          );
          await abrirMudancas(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text('Reduzir'));
          expect(find.text('Editar mudança'), findsOneWidget);
          await tocar(tester, find.text('Salvar'));
          final m = MudancasService.instance.salvasDeTeste.single;
          expect(m.id, 'm3');
          expect(m.valor, -100);
        });

        testWidgets('editar mantém o valor com milhar', (tester) async {
          preparar(mudancas: const [piso]);
          await abrirMudancas(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text(piso.titulo));
          await tocar(tester, find.text('Salvar'));
          expect(MudancasService.instance.salvasDeTeste.single.valor, 3500);
        });

        testWidgets('pendente pode ser excluída', (tester) async {
          preparar(mudancas: const [piso]);
          await abrirMudancas(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text(piso.titulo));
          await tocar(tester, find.byTooltip('Excluir mudança'));
          await tocar(tester, find.text('Excluir'));
          expect(MudancasService.instance.excluidasDeTeste, ['m1']);
          expect(find.text(piso.titulo), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('respondida não abre para editar', (tester) async {
          preparar(mudancas: [aprovada]);
          await abrirMudancas(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text(aprovada.titulo));
          expect(find.text('Editar mudança'), findsNothing);
          expect(find.text('Avisar o cliente'), findsNothing);
          expect(
            find.text('Aprovada por Dona Lia em 03/11/2026'),
            findsOneWidget,
          );
          expect(find.text('“Pode fazer”'), findsOneWidget);
        });

        testWidgets('responsável avisa o cliente de novo', (tester) async {
          preparar(mudancas: const [piso]);
          final enviados = <String>[];
          await abrirMudancas(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            enviados: enviados,
          );
          expect(find.text('Aprovar'), findsNothing);
          await tocar(tester, find.text('Avisar o cliente'));
          expect(enviados.single, contains(piso.impacto));
        });

        testWidgets('obra sem cliente avisa para convidar', (tester) async {
          preparar(
            equipe: const [
              MembroObra(
                id: 'eu',
                nome: 'Marina',
                funcao: FuncaoObra.responsavel,
                eu: true,
              ),
            ],
          );
          final enviados = <String>[];
          await abrirMudancas(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            enviados: enviados,
          );
          expect(find.textContaining('ainda não tem cliente'), findsOneWidget);
          await tocar(tester, find.text('Nova mudança'));
          await tester.enterText(campo('O que muda'), 'Trocar o piso');
          await tocar(tester, find.text('Pedir aprovação'));
          expect(enviados, isEmpty);
        });

        testWidgets('cliente aprova com comentário', (tester) async {
          preparar(mudancas: const [piso]);
          await abrirMudancas(tester, FuncaoObra.cliente, escuro: escuro);
          expect(find.text('Nova mudança'), findsNothing);
          expect(find.text(piso.impacto), findsOneWidget);
          await tocar(tester, find.text('Aprovar'));
          expect(find.text('Aprovar esta mudança?'), findsOneWidget);
          await tester.enterText(campo('Comentário'), ' Pode fazer ');
          await tocar(
            tester,
            find.widgetWithText(FilledButton, 'Aprovar').last,
          );
          expect(MudancasService.instance.respostasDeTeste, [
            ('m1', true, 'Pode fazer'),
          ]);
          expect(find.text('Aprovada'), findsOneWidget);
          expect(find.text('Aprovar'), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('cliente recusa sem comentário', (tester) async {
          preparar(mudancas: const [piso]);
          await abrirMudancas(tester, FuncaoObra.cliente, escuro: escuro);
          await tocar(tester, find.text('Recusar'));
          await tocar(tester, find.widgetWithText(FilledButton, 'Recusar'));
          expect(MudancasService.instance.respostasDeTeste, [
            ('m1', false, null),
          ]);
          expect(find.text('Recusada'), findsOneWidget);
        });

        testWidgets('cliente pode desistir de responder', (tester) async {
          preparar(mudancas: const [piso]);
          await abrirMudancas(tester, FuncaoObra.cliente, escuro: escuro);
          await tocar(tester, find.text('Aprovar'));
          await tocar(tester, find.text('Voltar'));
          expect(MudancasService.instance.respostasDeTeste, isEmpty);
          expect(find.text('Aguardando o cliente'), findsOneWidget);
        });

        testWidgets('mestre só acompanha', (tester) async {
          preparar(
            mudancas: const [Mudanca(id: 'm1', titulo: 'Trocar', dias: 5)],
          );
          await abrirMudancas(tester, FuncaoObra.mestre, escuro: escuro);
          expect(find.text('Nova mudança'), findsNothing);
          expect(find.text('Aprovar'), findsNothing);
          expect(find.text('Avisar o cliente'), findsNothing);
          await tocar(tester, find.text('Trocar'));
          expect(find.text('Editar mudança'), findsNothing);
        });

        testWidgets('sem conexão oferece tentar de novo', (tester) async {
          preparar(erro: 'Sem conexão.');
          await abrirMudancas(tester, FuncaoObra.cliente, escuro: escuro);
          expect(find.text('Sem conexão.'), findsOneWidget);
          expect(find.text('Tentar de novo'), findsOneWidget);
        });
      });

      group('relatório', () {
        testWidgets('mostra a semana e gera o PDF', (tester) async {
          preparar(dias: [diaFechado], mudancas: const [piso]);
          final enviados = <RelatorioDaSemana>[];
          await abrirRelatorio(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            enviados: enviados,
          );
          expect(find.text('02/11 a 08/11'), findsOneWidget);
          expect(find.text('Dias registrados'), findsOneWidget);
          expect(find.text('Reboco · Sala · 70%'), findsOneWidget);
          await rolarAte(tester, find.textContaining('Chuva à tarde'));
          await tocar(tester, find.text('Gerar PDF'));
          final r = enviados.single;
          expect(r.resumo.atividades.single.descricao, 'Reboco');
          expect(r.mudancas.single.titulo, piso.titulo);
          expect(tester.takeException(), isNull);
        });

        testWidgets('dia em rascunho fica de fora, com aviso', (tester) async {
          preparar(dias: [diaFechado, diaRascunho]);
          await abrirRelatorio(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(
            find.textContaining('1 dia em rascunho ficou de fora'),
            findsOneWidget,
          );
          expect(find.textContaining('Texto não revisado'), findsNothing);
        });

        testWidgets('semana só com rascunho não gera PDF', (tester) async {
          preparar(dias: [diaRascunho]);
          await abrirRelatorio(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.byTooltip('Próxima semana'));
          expect(find.text('Nenhum dia finalizado'), findsOneWidget);
          final botao = tester.widget<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          );
          expect(botao.onPressed, isNull);
        });

        testWidgets('semana vazia abre na anterior', (tester) async {
          preparar(dias: [diaFechado]);
          await abrirRelatorio(
            tester,
            FuncaoObra.cliente,
            escuro: escuro,
            hoje: DateTime(2026, 11, 9),
          );
          expect(find.text('02/11 a 08/11'), findsOneWidget);
          expect(find.text('Reboco · Sala · 70%'), findsOneWidget);
        });

        testWidgets('anda pelas semanas, sem passar de hoje', (tester) async {
          preparar(dias: [diaFechado]);
          await abrirRelatorio(tester, FuncaoObra.mestre, escuro: escuro);
          final proxima = find.byTooltip('Próxima semana');
          expect(
            tester
                .widget<IconButton>(
                  find.ancestor(of: proxima, matching: find.byType(IconButton)),
                )
                .onPressed,
            isNull,
          );
          await tocar(tester, find.byTooltip('Semana anterior'));
          expect(find.text('26/10 a 01/11'), findsOneWidget);
          await tocar(tester, proxima);
          expect(find.text('02/11 a 08/11'), findsOneWidget);
        });

        testWidgets('convida o responsável a colocar a marca', (tester) async {
          preparar(dias: [diaFechado]);
          await abrirRelatorio(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(find.text('Coloque a sua marca'), findsOneWidget);
          await tocar(tester, find.text('Coloque a sua marca'));
          expect(find.text('Sua marca'), findsOneWidget);
        });

        testWidgets('com marca, ou sem ser o responsável, não convida', (
          tester,
        ) async {
          preparar(
            dias: [diaFechado],
            daObra: const MarcaEngenheiro(nome: 'Duarte', registro: 'CREA 1'),
          );
          await abrirRelatorio(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(find.text('Coloque a sua marca'), findsNothing);
          preparar(dias: [diaFechado]);
          await abrirRelatorio(tester, FuncaoObra.cliente, escuro: escuro);
          expect(find.text('Coloque a sua marca'), findsNothing);
        });
      });

      group('tela da obra', () {
        void naObra(FuncaoObra f) {
          ObrasService.instance.definirParaTeste(obras: [obraDe(f)]);
        }

        testWidgets('cliente vê o que espera a resposta dele e as fotos', (
          tester,
        ) async {
          preparar(mudancas: const [piso], dias: [diaFechado, diaRascunho]);
          naObra(FuncaoObra.cliente);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          expect(find.text('1 mudança espera a sua aprovação'), findsOneWidget);
          expect(find.text('Últimas fotos'), findsOneWidget);
          expect(find.byType(MiniaturaFoto), findsOneWidget);
          await rolarAte(tester, find.text('Relatório da semana'));
          expect(
            find.text('O resumo da obra, semana a semana'),
            findsOneWidget,
          );
          expect(find.text('Pendências'), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('cliente sem fotos não vê o bloco vazio', (tester) async {
          preparar();
          naObra(FuncaoObra.cliente);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          expect(find.text('Nada para aprovar'), findsOneWidget);
          expect(find.text('Últimas fotos'), findsNothing);
        });

        testWidgets('responsável acompanha o que espera o cliente', (
          tester,
        ) async {
          preparar(mudancas: const [piso]);
          naObra(FuncaoObra.responsavel);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Mudanças'));
          expect(find.text('1 aguardando o cliente'), findsOneWidget);
          expect(find.text('Últimas fotos'), findsNothing);
        });

        for (final f in [FuncaoObra.estagiario, FuncaoObra.empreiteiro]) {
          testWidgets('${f.rotulo} não entra na conversa com o cliente', (
            tester,
          ) async {
            preparar(mudancas: const [piso]);
            naObra(f);
            await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
            await rolarAte(tester, find.text('Equipe'));
            expect(find.text('Mudanças'), findsNothing);
            expect(find.text('Relatório da semana'), findsNothing);
          });
        }
      });

      testWidgets('mudança aprovada entra na conta da obra', (tester) async {
        final orcamento = Calculo.de(const ParametrosObra(area: '120'))
            .resultado!;
        DinheiroService.instance.definirParaTeste(mudancas: 3500);
        await abrir(
          tester,
          DinheiroScreen(obra: obraDe(FuncaoObra.responsavel)),
          escuro: escuro,
        );
        expect(
          find.text('de ${brl.format(orcamento.totalEtapas + 3500)} orçados'),
          findsOneWidget,
        );
        await rolarAte(tester, find.text('Mudanças aprovadas'));
        expect(find.text(brl.format(3500)), findsOneWidget);
      });
    });
  }

  group('PDF', () {
    final obra = obraDe(FuncaoObra.responsavel);
    const marca = MarcaEngenheiro(
      nome: 'Duarte Engenharia',
      registro: 'CREA 1234/D',
      telefone: '65 99999-0000',
    );
    RelatorioDaSemana relatorio(List<DiaObra> dias) => montarRelatorio(
      obra: obra,
      etapas: Calculo.de(obra.parametros).resultado!.etapas,
      dias: dias,
      mudancas: const [piso],
      semana: SemanaObra.doDia(hojeFixo),
    );
    String inicio(Uint8List b) => String.fromCharCodes(b.take(4));

    test('relatório sai com marca, logo e fotos', () async {
      final b = await pdfDaSemana(
        obra: obra,
        relatorio: relatorio([diaFechado]),
        marca: marca,
        logo: png,
        fotos: {'o1/a.jpg': png},
      );
      expect(inicio(b), '%PDF');
    });

    test('relatório sai sem marca', () async {
      final b = await pdfDaSemana(
        obra: obra,
        relatorio: relatorio([diaFechado]),
      );
      expect(inicio(b), '%PDF');
    });

    test('logo e foto que não abrem não derrubam o documento', () async {
      final b = await pdfDaSemana(
        obra: obra,
        relatorio: relatorio([diaFechado]),
        marca: marca,
        logo: Uint8List.fromList([1, 2, 3]),
        fotos: {
          'o1/a.jpg': Uint8List.fromList([1, 2, 3]),
        },
      );
      expect(inicio(b), '%PDF');
    });

    test('texto do celular e semana longa continuam saindo', () async {
      final dia = DiaObra(
        obraId: 'o1',
        data: DateTime(2026, 11, 3),
        situacao: SituacaoDia.finalizado,
        atividades: [
          for (var i = 0; i < 200; i++)
            Atividade(descricao: 'Serviço $i — “ok” 😀', local: 'Sala $i'),
        ],
      );
      final b = await pdfDaSemana(
        obra: obra,
        relatorio: relatorio([dia]),
        marca: marca,
      );
      expect(inicio(b), '%PDF');
    });

    test('leva as últimas 6 fotos da semana', () {
      final r = ResumoDaSemana(
        dias: const [],
        atividades: const [],
        ocorrencias: const [],
        fotos: [for (var i = 0; i < 9; i++) FotoDia(caminho: '$i')],
      );
      expect(fotosDoRelatorio(r).map((f) => f.caminho), [
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
      ]);
    });

    test('nome do arquivo tem a semana', () {
      expect(
        nomeDoRelatorio(SemanaObra.doDia(hojeFixo)),
        'relatorio-semanal-2026-11-02.pdf',
      );
    });

    test('diário também sai com a marca', () async {
      final b = await pdfDoDia(
        obra: obra,
        dia: diaFechado,
        marca: marca,
        logo: png,
      );
      expect(inicio(b), '%PDF');
    });
  });
}
