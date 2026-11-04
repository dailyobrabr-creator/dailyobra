import 'package:dailyobra/screens/caixa_screen.dart';
import 'package:dailyobra/screens/componentes.dart';
import 'package:dailyobra/screens/contratos_screen.dart';
import 'package:dailyobra/screens/mao_de_obra_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/services/caixa_service.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/dinheiro_service.dart';
import 'package:dailyobra/services/equipe_service.dart';
import 'package:dailyobra/services/mao_de_obra_service.dart';
import 'package:dailyobra/services/marca_service.dart';
import 'package:dailyobra/services/mudancas_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

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

const ze = Diarista(id: 'd1', nome: 'Zé', funcao: 'Pedreiro', diaria: 200);
const ana = Diarista(id: 'd2', nome: 'Ana', funcao: 'Servente', diaria: 100);
const semValor = Diarista(id: 'd3', nome: 'Bia', funcao: 'Servente', diaria: 0);
const zeMestre = Diarista(id: 'd1', nome: 'Zé', funcao: 'Pedreiro');

const contrato = Contrato(
  id: 'c1',
  empreiteiro: 'João Reboco',
  servico: 'Reboco interno',
  valor: 10000,
);
const contratoMestre = Contrato(
  id: 'c1',
  empreiteiro: 'João Reboco',
  servico: 'Reboco interno',
);

Medicao medicao({
  int numero = 1,
  double pct = 30,
  double? valor = 3000,
  bool aprovada = true,
  bool paga = false,
}) => Medicao(
  id: 'm$numero',
  contratoId: 'c1',
  numero: numero,
  data: DateTime(2026, 11, numero),
  percentual: pct,
  valor: valor,
  aprovada: aprovada,
  paga: paga,
  pagaEm: paga ? DateTime(2026, 11, 3) : null,
);

void preparar({
  List<Diarista> diaristas = const [],
  List<Presenca> presencas = const [],
  List<Contrato> contratos = const [],
  List<Medicao> medicoes = const [],
  List<EntradaCaixa> entradas = const [],
  List<MembroObra> equipe = const [],
  bool aprovaAoLancar = true,
  String? erro,
}) {
  MaoDeObraService.instance.definirParaTeste(
    diaristas: diaristas,
    presencas: presencas,
    contratos: contratos,
    medicoes: medicoes,
    aprovaAoLancar: aprovaAoLancar,
    erro: erro,
  );
  CaixaService.instance.definirParaTeste(entradas: entradas, erro: erro);
  DinheiroService.instance.definirParaTeste();
  DiarioService.instance.definirParaTeste();
  MudancasService.instance.definirParaTeste();
  MarcaService.instance.definirParaTeste();
  EquipeService.instance.definirParaTeste(membros: equipe);
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

Future<void> abrirMaoDeObra(
  WidgetTester tester,
  FuncaoObra f, {
  bool escuro = false,
  bool empreiteiros = false,
}) async {
  await abrir(
    tester,
    MaoDeObraScreen(obra: obraDe(f), hoje: hojeFixo),
    escuro: escuro,
  );
  if (empreiteiros) await tocar(tester, find.text('Empreiteiros'));
}

Future<void> abrirContrato(
  WidgetTester tester,
  FuncaoObra f, {
  bool escuro = false,
}) => abrir(
  tester,
  ContratoScreen(obra: obraDe(f), contratoId: 'c1', hoje: hojeFixo),
  escuro: escuro,
);

Future<void> abrirCaixa(WidgetTester tester, {bool escuro = false}) => abrir(
  tester,
  CaixaScreen(obra: obraDe(FuncaoObra.responsavel), hoje: hojeFixo),
  escuro: escuro,
);

void main() {
  final servico = MaoDeObraService.instance;

  test('o que aparece no campo volta como o mesmo número', () {
    for (final v in [999.0, 1000.0, 10000.0, 1234567.0, 1500.5, 0.5, 3500.25]) {
      expect(lerNumero(formatarQuantidade(v)), v);
    }
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      group('diárias', () {
        testWidgets('marca quem veio com um toque', (tester) async {
          preparar(diaristas: const [ze, ana]);
          await abrirMaoDeObra(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(find.text(diaPorExtenso(hojeFixo)), findsOneWidget);
          await tocar(tester, find.text('Dia inteiro').first);
          expect(servico.marcacoesDeTeste.single, ('d1', hojeFixo, 1.0));
          await tocar(tester, find.text('Meio dia').last);
          expect(servico.marcacoesDeTeste.last, ('d2', hojeFixo, 0.5));
          await rolarAte(tester, find.text('Pagar ${brl.format(250)}'));
          expect(find.text('Pagar ${brl.format(250)}'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('corrige para falta', (tester) async {
          preparar(
            diaristas: const [ze],
            presencas: [Presenca(diaristaId: 'd1', data: hojeFixo, dias: 1)],
          );
          await abrirMaoDeObra(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text('Não veio'));
          expect(servico.marcacoesDeTeste.single.$3, 0);
          expect(find.text('A pagar'), findsNothing);
        });

        testWidgets('não anda para o futuro', (tester) async {
          preparar(
            diaristas: const [ze],
            presencas: [
              Presenca(
                diaristaId: 'd1',
                data: DateTime(2026, 11, 3),
                dias: 1,
                pago: true,
              ),
            ],
          );
          await abrirMaoDeObra(tester, FuncaoObra.responsavel, escuro: escuro);
          final proximo = tester.widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Próximo dia'),
              matching: find.byType(IconButton),
            ),
          );
          expect(proximo.onPressed, isNull);
          await tocar(tester, find.byTooltip('Dia anterior'));
          expect(find.text('Pago'), findsOneWidget);
          expect(find.text('Não veio'), findsNothing);
          await tocar(tester, find.byTooltip('Próximo dia'));
          expect(find.text('Não veio'), findsOneWidget);
        });

        testWidgets('responsável adiciona com o valor', (tester) async {
          preparar();
          await abrirMaoDeObra(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(find.text('Ninguém na lista'), findsOneWidget);
          await tocar(tester, find.text('Adicionar pessoa'));
          await tocar(tester, find.text('Salvar'));
          expect(find.text('Diga o nome da pessoa.'), findsOneWidget);
          await tester.enterText(campo('Nome'), ' Zé ');
          await tester.enterText(campo('Função'), 'Pedreiro');
          await tester.enterText(campo('Valor da diária (R\$)'), '200,50');
          await tocar(tester, find.text('Salvar'));
          final d = servico.diaristasSalvosDeTeste.single;
          expect((d.nome, d.funcao, d.diaria), ('Zé', 'Pedreiro', 200.5));
          expect(find.text('Quem veio'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('mestre adiciona sem ver valor', (tester) async {
          preparar(
            diaristas: const [zeMestre],
            presencas: [Presenca(diaristaId: 'd1', data: hojeFixo, dias: 1)],
          );
          await abrirMaoDeObra(tester, FuncaoObra.mestre, escuro: escuro);
          expect(find.text('Dias em aberto'), findsOneWidget);
          expect(find.textContaining('R\$'), findsNothing);
          expect(find.textContaining('Pagar'), findsNothing);
          await tocar(tester, find.text('Adicionar pessoa'));
          expect(campo('Valor da diária (R\$)'), findsNothing);
          await tester.enterText(campo('Nome'), 'Ana');
          await tocar(tester, find.text('Salvar'));
          expect(servico.diaristasSalvosDeTeste.single.diaria, isNull);
        });

        testWidgets('tira da lista sem perder o que deve', (tester) async {
          preparar(
            diaristas: const [ze],
            presencas: [
              Presenca(diaristaId: 'd1', data: DateTime(2026, 11, 3), dias: 1),
            ],
          );
          await abrirMaoDeObra(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text('Zé'));
          await tocar(tester, find.text('Tirar da lista'));
          expect(servico.diaristasSalvosDeTeste.single.ativo, isFalse);
          expect(find.text('Quem veio'), findsNothing);
          expect(find.text('Zé · 1 dia'), findsOneWidget);
        });

        testWidgets('paga tudo e lança no dinheiro', (tester) async {
          preparar(
            diaristas: const [ze, ana],
            presencas: [
              Presenca(diaristaId: 'd1', data: hojeFixo, dias: 1),
              Presenca(
                diaristaId: 'd2',
                data: DateTime(2026, 11, 3),
                dias: 0.5,
              ),
            ],
          );
          await abrirMaoDeObra(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(find.text('Zé · 1 dia'), findsOneWidget);
          expect(find.text('Ana · 0,5 dias'), findsOneWidget);
          await tocar(tester, find.text('Pagar ${brl.format(250)}'));
          await tocar(tester, find.text('Registrar pagamento'));
          expect(servico.pagamentosDeTeste, hasLength(1));
          expect(find.text('A pagar'), findsNothing);
          expect(
            find.text('Pagamento lançado no dinheiro da obra.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('avisa quem está sem valor', (tester) async {
          preparar(
            diaristas: const [semValor],
            presencas: [Presenca(diaristaId: 'd3', data: hojeFixo, dias: 1)],
          );
          await abrirMaoDeObra(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(find.text('Falta a diária'), findsOneWidget);
          final botao = tester.widget<FilledButton>(find.byType(FilledButton));
          expect(botao.onPressed, isNull);
        });

        testWidgets('não deixa pagar enquanto falta uma diária', (
          tester,
        ) async {
          preparar(
            diaristas: const [ze, semValor],
            presencas: [
              Presenca(diaristaId: 'd1', data: hojeFixo, dias: 1),
              Presenca(diaristaId: 'd3', data: hojeFixo, dias: 1),
            ],
          );
          await abrirMaoDeObra(tester, FuncaoObra.responsavel, escuro: escuro);
          final pagar = find.text('Pagar ${brl.format(200)}');
          await rolarAte(tester, pagar);
          expect(find.textContaining('Toque em Bia'), findsOneWidget);
          final botao = tester.widget<FilledButton>(
            find.ancestor(of: pagar, matching: find.byType(FilledButton)),
          );
          expect(botao.onPressed, isNull);
        });

        testWidgets('sem conexão oferece tentar de novo', (tester) async {
          preparar(erro: 'Sem conexão.');
          await abrirMaoDeObra(tester, FuncaoObra.mestre, escuro: escuro);
          expect(find.text('Sem conexão.'), findsOneWidget);
          expect(find.text('Tentar de novo'), findsOneWidget);
        });
      });

      group('contratos', () {
        testWidgets('responsável cria o contrato', (tester) async {
          preparar(
            equipe: const [
              MembroObra(
                id: 'u9',
                nome: 'Beto',
                funcao: FuncaoObra.empreiteiro,
              ),
              MembroObra(id: 'u8', nome: 'Lia', funcao: FuncaoObra.cliente),
            ],
          );
          await abrirMaoDeObra(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            empreiteiros: true,
          );
          expect(find.text('Nenhum contrato'), findsOneWidget);
          await tocar(tester, find.text('Novo contrato'));
          await tocar(tester, find.text('Salvar'));
          expect(find.text('Diga quem é o empreiteiro.'), findsOneWidget);
          expect(find.text('Diga qual é o serviço.'), findsOneWidget);
          expect(find.text('Digite um valor maior que zero.'), findsOneWidget);
          await tester.enterText(campo('Empreiteiro'), ' João ');
          await tester.enterText(campo('Serviço'), 'Reboco');
          await tester.enterText(campo('Valor do contrato (R\$)'), '10.000');
          await tocar(tester, find.text('Ninguém'));
          expect(find.text('Lia'), findsNothing);
          await tocar(tester, find.text('Beto').last);
          await tocar(tester, find.text('Salvar'));
          final c = servico.contratosSalvosDeTeste.single;
          expect(
            (c.empreiteiro, c.servico, c.valor, c.usuario),
            ('João', 'Reboco', 10000, 'u9'),
          );
          expect(find.text('Reboco'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('lista mostra o quanto andou', (tester) async {
          preparar(contratos: const [contrato], medicoes: [medicao()]);
          await abrirMaoDeObra(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            empreiteiros: true,
          );
          expect(find.text('Reboco interno'), findsOneWidget);
          expect(
            find.text(
              '30% pronto · ${brlInteiro.format(3000)} de ${brlInteiro.format(10000)}',
            ),
            findsOneWidget,
          );
          expect(find.text('A pagar'), findsOneWidget);
        });

        testWidgets('mestre lança a medição sem ver valor', (tester) async {
          preparar(
            contratos: const [contratoMestre],
            medicoes: [medicao(valor: null)],
            aprovaAoLancar: false,
          );
          await abrirMaoDeObra(
            tester,
            FuncaoObra.mestre,
            escuro: escuro,
            empreiteiros: true,
          );
          expect(find.text('Novo contrato'), findsNothing);
          expect(find.textContaining('R\$'), findsNothing);
          await tocar(tester, find.text('Reboco interno'));
          expect(find.byTooltip('Editar contrato'), findsNothing);
          expect(find.textContaining('R\$'), findsNothing);
          await tocar(tester, find.text('Lançar medição'));
          expect(find.text('Até agora: 30% pronto.'), findsOneWidget);
          await tester.enterText(campo('Total pronto (%)'), '60');
          await tester.pumpAndSettle();
          expect(find.textContaining('Esta medição'), findsNothing);
          await tocar(tester, find.text('Lançar'));
          expect(servico.medicoesLancadasDeTeste.single, ('c1', 60.0, null));
          expect(find.text('Aguardando aprovação'), findsOneWidget);
          expect(find.text('Lançar medição'), findsNothing);
          expect(find.text('Aprovar'), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('percentual tem que subir', (tester) async {
          preparar(contratos: const [contrato], medicoes: [medicao()]);
          await abrirContrato(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text('Lançar medição'));
          await tester.enterText(campo('Total pronto (%)'), '20');
          await tocar(tester, find.text('Lançar'));
          expect(
            find.text('Digite um percentual acima de 30% e até 100%.'),
            findsOneWidget,
          );
          await tester.enterText(campo('Total pronto (%)'), '101');
          await tocar(tester, find.text('Lançar'));
          expect(servico.medicoesLancadasDeTeste, isEmpty);
          await tester.enterText(campo('Total pronto (%)'), '60');
          await tester.pumpAndSettle();
          expect(
            find.text('Esta medição: ${brl.format(3000)}'),
            findsOneWidget,
          );
        });

        testWidgets('responsável aprova e paga', (tester) async {
          preparar(
            contratos: const [contrato],
            medicoes: [medicao(aprovada: false)],
          );
          await abrirContrato(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(find.text('Lançar medição'), findsNothing);
          await tocar(tester, find.text('Aprovar'));
          expect(servico.medicoesAprovadasDeTeste, ['m1']);
          await tocar(tester, find.text('Pagar'));
          await tocar(tester, find.text('Registrar pagamento'));
          expect(servico.medicoesPagasDeTeste.single.$1, 'm1');
          expect(find.text('Paga'), findsOneWidget);
          expect(find.text('Excluir'), findsNothing);
          expect(find.text('Pago'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('só a última medição sai', (tester) async {
          preparar(
            contratos: const [contrato],
            medicoes: [
              medicao(paga: true),
              medicao(numero: 2, pct: 60),
              medicao(numero: 3, pct: 80, valor: 2000),
            ],
          );
          await abrirContrato(tester, FuncaoObra.responsavel, escuro: escuro);
          await rolarAte(tester, find.text('Medição 3 · 03/11'));
          expect(find.text('Excluir'), findsOneWidget);
          await tocar(tester, find.text('Excluir'));
          await tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));
          expect(servico.medicoesExcluidasDeTeste, ['m3']);
        });

        testWidgets('mestre não tira a aprovada', (tester) async {
          preparar(
            contratos: const [contratoMestre],
            medicoes: [medicao(valor: null)],
          );
          await abrirContrato(tester, FuncaoObra.mestre, escuro: escuro);
          expect(find.text('Excluir'), findsNothing);
        });

        testWidgets('mestre tira a pendente', (tester) async {
          preparar(
            contratos: const [contratoMestre],
            medicoes: [medicao(valor: null, aprovada: false)],
          );
          await abrirContrato(tester, FuncaoObra.mestre, escuro: escuro);
          await tocar(tester, find.text('Excluir'));
          await tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));
          expect(servico.medicoesExcluidasDeTeste, ['m1']);
        });

        testWidgets('empreiteiro acompanha sem mexer', (tester) async {
          preparar(
            contratos: const [contrato],
            medicoes: [medicao(aprovada: false)],
          );
          await abrirContrato(tester, FuncaoObra.empreiteiro, escuro: escuro);
          expect(find.text(brl.format(10000)), findsOneWidget);
          expect(find.text('Aprovar'), findsNothing);
          expect(find.text('Excluir'), findsNothing);
          expect(find.text('Lançar medição'), findsNothing);
          expect(find.byTooltip('Editar contrato'), findsNothing);
        });

        testWidgets('edita, encerra e para de medir', (tester) async {
          preparar(contratos: const [contrato], medicoes: [medicao()]);
          await abrirContrato(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.byTooltip('Editar contrato'));
          expect(find.byTooltip('Excluir contrato'), findsNothing);
          await tocar(tester, find.text('Contrato encerrado'));
          await tocar(tester, find.text('Salvar'));
          expect(servico.contratosSalvosDeTeste.single.encerrado, isTrue);
          expect(find.text('Contrato encerrado.'), findsOneWidget);
          expect(find.text('Lançar medição'), findsNothing);
        });

        testWidgets('contrato sem medição pode ser excluído', (tester) async {
          preparar(contratos: const [contrato]);
          await abrirMaoDeObra(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            empreiteiros: true,
          );
          await tocar(tester, find.text('Reboco interno'));
          await tocar(tester, find.byTooltip('Editar contrato'));
          await tocar(tester, find.byTooltip('Excluir contrato'));
          await tocar(tester, find.text('Excluir'));
          expect(servico.contratosExcluidosDeTeste, ['c1']);
          expect(find.text('Nenhum contrato'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('contrato que sumiu avisa', (tester) async {
          preparar();
          await abrirContrato(tester, FuncaoObra.empreiteiro, escuro: escuro);
          expect(find.text('Contrato não encontrado.'), findsOneWidget);
        });
      });

      group('caixa', () {
        testWidgets('mostra saldo e semanas', (tester) async {
          preparar(
            entradas: [
              EntradaCaixa(
                id: 'e1',
                descricao: 'Sinal',
                valor: 5000,
                data: hojeFixo,
                recebido: true,
              ),
              EntradaCaixa(
                id: 'e2',
                descricao: 'Parcela 2',
                valor: 2000,
                data: DateTime(2026, 11, 10),
              ),
            ],
          );
          await abrirCaixa(tester, escuro: escuro);
          expect(find.text('Saldo em caixa'), findsOneWidget);
          expect(find.text('02/11 a 08/11'), findsOneWidget);
          await rolarAte(tester, find.text('Parcela 2'));
          expect(find.text('Previsto'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('sem entradas explica o que fazer', (tester) async {
          preparar();
          await abrirCaixa(tester, escuro: escuro);
          expect(find.textContaining('Lance o que o cliente'), findsOneWidget);
          expect(find.text('Entradas'), findsNothing);
        });

        testWidgets('diária em aberto e medição contam como a pagar', (
          tester,
        ) async {
          preparar(
            diaristas: const [ze],
            presencas: [Presenca(diaristaId: 'd1', data: hojeFixo, dias: 1)],
            contratos: const [contrato],
            medicoes: [medicao()],
          );
          await abrirCaixa(tester, escuro: escuro);
          expect(find.text(brl.format(3200)), findsOneWidget);
        });

        testWidgets('avisa quando o dinheiro não chega', (tester) async {
          preparar(
            diaristas: const [ze],
            presencas: [Presenca(diaristaId: 'd1', data: hojeFixo, dias: 1)],
            entradas: [
              EntradaCaixa(
                descricao: 'Sinal',
                valor: 100,
                data: hojeFixo,
                recebido: true,
              ),
            ],
          );
          await abrirCaixa(tester, escuro: escuro);
          expect(
            find.text(
              'Na semana de 02/11 a 08/11 o caixa fica negativo em ${brl.format(100)}.',
            ),
            findsOneWidget,
          );
        });

        testWidgets('lança, altera e exclui entrada', (tester) async {
          preparar();
          final caixa = CaixaService.instance;
          await abrirCaixa(tester, escuro: escuro);
          await tocar(tester, find.text('Nova entrada'));
          await tocar(tester, find.text('Salvar'));
          expect(find.text('Diga de onde vem o dinheiro.'), findsOneWidget);
          expect(find.text('Digite um valor maior que zero.'), findsOneWidget);
          await tester.enterText(campo('De onde vem'), 'Sinal');
          await tester.enterText(campo('Valor (R\$)'), '5.000');
          await tocar(tester, find.text('Salvar'));
          expect(caixa.salvasDeTeste.single.recebido, isTrue);
          await rolarAte(tester, find.text('Sinal'));
          await tocar(tester, find.text('Sinal'));
          await tocar(tester, find.text('Já recebido'));
          await tocar(tester, find.text('Salvar'));
          expect(caixa.salvasDeTeste.last.recebido, isFalse);
          await rolarAte(tester, find.text('Sinal'));
          await tocar(tester, find.text('Sinal'));
          await tocar(tester, find.text('Excluir'));
          expect(caixa.excluidasDeTeste, hasLength(1));
          expect(find.text('Sinal'), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('sem conexão oferece tentar de novo', (tester) async {
          preparar(erro: 'Sem conexão.');
          await abrirCaixa(tester, escuro: escuro);
          expect(find.text('Sem conexão.'), findsOneWidget);
          expect(find.text('Nova entrada'), findsNothing);
        });
      });

      group('tela da obra', () {
        void naObra(FuncaoObra f) {
          ObrasService.instance.definirParaTeste(obras: [obraDe(f)]);
        }

        testWidgets('responsável vê mão de obra e caixa', (tester) async {
          preparar(
            contratos: const [contrato],
            medicoes: [medicao(aprovada: false)],
          );
          naObra(FuncaoObra.responsavel);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Mão de obra'));
          expect(find.text('1 medição para aprovar'), findsOneWidget);
          await rolarAte(tester, find.text('Caixa da obra'));
          expect(find.text('Meu contrato'), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('mostra o que está a pagar', (tester) async {
          preparar(
            diaristas: const [ze],
            presencas: [Presenca(diaristaId: 'd1', data: hojeFixo, dias: 1)],
          );
          naObra(FuncaoObra.responsavel);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Mão de obra'));
          expect(find.text('${brl.format(200)} a pagar'), findsOneWidget);
        });

        testWidgets('mestre vê a mão de obra, não o caixa', (tester) async {
          preparar();
          naObra(FuncaoObra.mestre);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Mão de obra'));
          expect(
            find.text('Marque quem veio e lance as medições'),
            findsOneWidget,
          );
          await rolarAte(tester, find.text('Equipe'));
          expect(find.text('Caixa da obra'), findsNothing);
        });

        testWidgets('empreiteiro vê só o contrato dele', (tester) async {
          preparar(contratos: const [contrato]);
          naObra(FuncaoObra.empreiteiro);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Meu contrato'));
          expect(find.text('Mão de obra'), findsNothing);
          await tocar(tester, find.text('Meu contrato'));
          expect(find.text('Reboco interno'), findsOneWidget);
          expect(find.text('Diárias'), findsNothing);
        });

        for (final f in [FuncaoObra.estagiario, FuncaoObra.cliente]) {
          testWidgets('${f.rotulo} não vê mão de obra nem caixa', (
            tester,
          ) async {
            preparar();
            naObra(f);
            await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
            await rolarAte(tester, find.text('Equipe'));
            expect(find.byType(EntradaDaMaoDeObra), findsNothing);
            expect(find.text('Caixa da obra'), findsNothing);
            expect(find.text('Meu contrato'), findsNothing);
          });
        }
      });
    });
  }
}
