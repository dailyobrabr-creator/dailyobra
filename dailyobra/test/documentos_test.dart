import 'dart:convert';
import 'dart:typed_data';

import 'package:dailyobra/screens/checklists_screen.dart';
import 'package:dailyobra/screens/documentos_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/services/checklists_service.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/dinheiro_service.dart';
import 'package:dailyobra/services/documentos_service.dart';
import 'package:dailyobra/services/equipe_service.dart';
import 'package:dailyobra/services/mao_de_obra_service.dart';
import 'package:dailyobra/services/marca_service.dart';
import 'package:dailyobra/services/mudancas_service.dart';
import 'package:dailyobra/services/caixa_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/pdf_checklist.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'apoio.dart' hide hoje;

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final hojeFixo = DateTime(2026, 11, 5);

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

final art = Documento(
  id: 'd1',
  tipo: TipoDocumento.art,
  titulo: 'ART de execução',
  numero: '12345',
  validade: DateTime(2026, 11, 17),
  caminho: 'o1/art.pdf',
  nomeArquivo: 'art.pdf',
);
final alvara = Documento(
  id: 'd2',
  tipo: TipoDocumento.alvara,
  titulo: 'Alvará',
  validade: DateTime(2026, 10, 1),
  acesso: AcessoDocumento.todos,
  possoMexer: false,
);

final rascunho = Checklist(
  id: 'c1',
  modelo: 'alvenaria',
  tipo: TipoChecklist.qualidade,
  titulo: 'Alvenaria',
  data: hojeFixo,
  itens: const [
    ItemChecklist(texto: 'Paredes no prumo'),
    ItemChecklist(texto: 'Juntas uniformes'),
  ],
);
final concluido = Checklist(
  id: 'c2',
  modelo: 'seguranca_geral',
  tipo: TipoChecklist.seguranca,
  titulo: 'Segurança da obra',
  local: 'Térreo',
  data: DateTime(2026, 11, 3),
  concluido: true,
  concluidoPor: 'Seu Jorge',
  concluidoEm: DateTime(2026, 11, 3),
  itens: const [
    ItemChecklist(texto: 'Capacete', resultado: ResultadoItem.ok),
    ItemChecklist(
      texto: 'Guarda-corpo',
      resultado: ResultadoItem.nao,
      observacao: 'Falta na laje',
    ),
    ItemChecklist(texto: 'Andaime', resultado: ResultadoItem.na),
  ],
);

void preparar({
  List<Documento> documentos = const [],
  List<Checklist> checklists = const [],
  String? erro,
}) {
  DocumentosService.instance.definirParaTeste(
    documentos: documentos,
    erro: erro,
  );
  ChecklistsService.instance.definirParaTeste(
    checklists: checklists,
    erro: erro,
  );
  DiarioService.instance.definirParaTeste();
  DinheiroService.instance.definirParaTeste();
  MudancasService.instance.definirParaTeste();
  MarcaService.instance.definirParaTeste();
  MaoDeObraService.instance.definirParaTeste();
  CaixaService.instance.definirParaTeste();
  EquipeService.instance.definirParaTeste();
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

Future<void> abrirDocumentos(
  WidgetTester tester,
  FuncaoObra f, {
  bool escuro = false,
  Future<bool> Function(Uri)? abrirLink,
  Future<(String, Uint8List)?> Function()? escolherArquivo,
}) => abrir(
  tester,
  DocumentosScreen(
    obra: obraDe(f),
    hoje: hojeFixo,
    abrirLink: abrirLink,
    escolherArquivo: escolherArquivo,
  ),
  escuro: escuro,
);

Future<void> abrirChecklists(
  WidgetTester tester,
  FuncaoObra f, {
  bool escuro = false,
  Future<XFile?> Function(bool)? escolherFoto,
  Future<void> Function(Checklist)? enviarPdf,
}) => abrir(
  tester,
  ChecklistsScreen(
    obra: obraDe(f),
    hoje: hojeFixo,
    escolherFoto: escolherFoto,
    enviarPdf: enviarPdf,
  ),
  escuro: escuro,
);

void main() {
  final documentos = DocumentosService.instance;
  final checklists = ChecklistsService.instance;

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      group('documentos', () {
        testWidgets('separa por tipo e mostra o que vence', (tester) async {
          preparar(documentos: [art, alvara]);
          await abrirDocumentos(tester, FuncaoObra.responsavel, escuro: escuro);
          expect(find.text('Alvará está vencido.'), findsOneWidget);
          expect(find.text('ART ou RRT'), findsOneWidget);
          expect(find.text('Vence em 12 dias'), findsOneWidget);
          expect(find.text('Vencido há 35 dias'), findsOneWidget);
          expect(find.byTooltip('Editar ART de execução'), findsOneWidget);
          expect(find.byTooltip('Editar Alvará'), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('guarda um documento com arquivo', (tester) async {
          preparar();
          await abrirDocumentos(
            tester,
            FuncaoObra.mestre,
            escuro: escuro,
            escolherArquivo: () async => ('alvara.pdf', png),
          );
          expect(find.text('Nenhum documento'), findsOneWidget);
          await tocar(tester, find.text('Novo documento'));
          await tocar(tester, find.text('Salvar'));
          expect(find.text('Diga o nome do documento.'), findsOneWidget);
          await tester.enterText(campo('Nome'), ' ART ');
          await tester.enterText(campo('Número'), ' 123 ');
          await tocar(tester, find.text('Escolher arquivo'));
          expect(find.text('alvara.pdf'), findsOneWidget);
          await tocar(tester, find.text('Só o responsável e o mestre'));
          await tocar(tester, find.text('A equipe e o cliente').last);
          await tocar(tester, find.text('Salvar'));
          final d = documentos.salvosDeTeste.single;
          expect(
            (d.titulo, d.numero, d.tipo, d.acesso, d.nomeArquivo),
            (
              'ART',
              '123',
              TipoDocumento.art,
              AcessoDocumento.todos,
              'alvara.pdf',
            ),
          );
          expect(d.caminho, 'o1/1.pdf');
          expect(documentos.enviadosDeTeste, ['alvara.pdf']);
          expect(find.text('Novo documento'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('recusa arquivo errado', (tester) async {
          preparar();
          var escolha = ('planilha.xlsx', png);
          await abrirDocumentos(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            escolherArquivo: () async => escolha,
          );
          await tocar(tester, find.text('Novo documento'));
          await tocar(tester, find.text('Escolher arquivo'));
          expect(
            find.text('Use um arquivo PDF ou uma imagem.'),
            findsOneWidget,
          );
          escolha = (
            'grande.pdf',
            Uint8List(DocumentosService.tamanhoMaximo + 1),
          );
          await tocar(tester, find.text('Escolher arquivo'));
          expect(find.text('Use um arquivo de até 20 MB.'), findsOneWidget);
          expect(find.text('Trocar arquivo'), findsNothing);
        });

        testWidgets('trocar o arquivo apaga o antigo', (tester) async {
          preparar(documentos: [art]);
          await abrirDocumentos(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            escolherArquivo: () async => ('nova.pdf', png),
          );
          await tocar(tester, find.byTooltip('Editar ART de execução'));
          await tocar(tester, find.text('Trocar arquivo'));
          await tocar(tester, find.text('Salvar'));
          expect(documentos.salvosDeTeste.single.caminho, 'o1/1.pdf');
          expect(documentos.apagadosDeTeste, ['o1/art.pdf']);
        });

        testWidgets('editar sem trocar mantém o arquivo', (tester) async {
          preparar(documentos: [art]);
          await abrirDocumentos(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.byTooltip('Editar ART de execução'));
          await tocar(tester, find.text('Salvar'));
          expect(documentos.salvosDeTeste.single.caminho, 'o1/art.pdf');
          expect(documentos.apagadosDeTeste, isEmpty);
        });

        testWidgets('excluir tira o arquivo junto', (tester) async {
          preparar(documentos: [art]);
          await abrirDocumentos(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.byTooltip('Editar ART de execução'));
          await tocar(tester, find.byTooltip('Excluir documento'));
          await tocar(tester, find.text('Excluir'));
          expect(documentos.excluidosDeTeste, ['d1']);
          expect(documentos.apagadosDeTeste, ['o1/art.pdf']);
          expect(find.text('Nenhum documento'), findsOneWidget);
        });

        testWidgets('abre o arquivo', (tester) async {
          preparar(documentos: [art]);
          final abertos = <Uri>[];
          await abrirDocumentos(
            tester,
            FuncaoObra.cliente,
            escuro: escuro,
            abrirLink: (u) async {
              abertos.add(u);
              return true;
            },
          );
          await tocar(tester, find.text('ART de execução'));
          expect(abertos.single.path, '/o1/art.pdf');
        });

        testWidgets('avisa quando não abre', (tester) async {
          preparar(documentos: [art]);
          await abrirDocumentos(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            abrirLink: (_) async => false,
          );
          await tocar(tester, find.text('ART de execução'));
          expect(
            find.text('Não foi possível abrir o arquivo. Tente de novo.'),
            findsOneWidget,
          );
        });

        testWidgets('documento sem arquivo avisa', (tester) async {
          preparar(documentos: [alvara]);
          await abrirDocumentos(tester, FuncaoObra.cliente, escuro: escuro);
          await tocar(tester, find.text('Alvará').last);
          expect(find.text('Este documento não tem arquivo.'), findsOneWidget);
        });

        testWidgets('cliente só consulta', (tester) async {
          preparar();
          await abrirDocumentos(tester, FuncaoObra.cliente, escuro: escuro);
          expect(find.text('Novo documento'), findsNothing);
          expect(find.textContaining('Quando o responsável'), findsOneWidget);
        });

        testWidgets('sem conexão oferece tentar de novo', (tester) async {
          preparar(erro: 'Sem conexão.');
          await abrirDocumentos(tester, FuncaoObra.mestre, escuro: escuro);
          expect(find.text('Sem conexão.'), findsOneWidget);
          expect(find.text('Novo documento'), findsNothing);
        });
      });

      group('checklists', () {
        testWidgets('começa de um modelo pronto', (tester) async {
          preparar();
          await abrirChecklists(tester, FuncaoObra.mestre, escuro: escuro);
          expect(find.text('Nenhum checklist'), findsOneWidget);
          await tocar(tester, find.text('Novo checklist'));
          await tocar(tester, find.text('Trabalho em altura'));
          expect(find.textContaining('Trabalhadores com'), findsOneWidget);
          await tocar(tester, find.text('Salvar'));
          final (c, concluir) = checklists.salvosDeTeste.single;
          expect(
            (c.modelo, c.titulo, concluir),
            ('seguranca_altura', 'Trabalho em altura', false),
          );
          expect(c.itens, hasLength(7));
          expect(find.text('Rascunho'), findsOneWidget);
          expect(find.text('0 de 7 respondidos'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('não conclui com item sem resposta', (tester) async {
          preparar(checklists: [rascunho]);
          await abrirChecklists(tester, FuncaoObra.mestre, escuro: escuro);
          await tocar(tester, find.text('Alvenaria'));
          await tocar(tester, find.text('Conforme').first);
          await tocar(tester, find.text('Concluir'));
          expect(find.text('Falta responder 1 item.'), findsOneWidget);
          expect(checklists.salvosDeTeste, isEmpty);
        });

        testWidgets('não conforme pede detalhe e vira pendência', (
          tester,
        ) async {
          preparar(checklists: [rascunho]);
          await abrirChecklists(
            tester,
            FuncaoObra.responsavel,
            escuro: escuro,
            escolherFoto: (_) async => XFile.fromData(png, path: 'f.png'),
          );
          await tocar(tester, find.text('Alvenaria'));
          expect(find.text('O que está errado'), findsNothing);
          await tocar(tester, find.text('Conforme').first);
          await tocar(tester, find.text('Não').last);
          await tester.enterText(
            campo('O que está errado'),
            ' Parede 3 torta ',
          );
          await tocar(tester, find.text('Tirar foto'));
          await tocar(tester, find.text('Concluir'));
          expect(find.textContaining('1 item não conforme'), findsOneWidget);
          await tocar(
            tester,
            find.widgetWithText(FilledButton, 'Concluir').last,
          );
          final (c, concluir) = checklists.salvosDeTeste.single;
          expect(concluir, isTrue);
          expect(c.itens.last.resultado, ResultadoItem.nao);
          expect(c.itens.last.observacao, 'Parede 3 torta');
          expect(c.itens.last.fotoPath, 'o1/2026-11-05/0.png');
          expect(
            find.text('Checklist concluído. 1 pendência aberta.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('pode desistir de concluir', (tester) async {
          preparar(checklists: [rascunho]);
          await abrirChecklists(tester, FuncaoObra.mestre, escuro: escuro);
          await tocar(tester, find.text('Alvenaria'));
          await tocar(tester, find.text('Conforme').first);
          await tocar(tester, find.text('Conforme').last);
          await tocar(tester, find.text('Concluir'));
          await tocar(tester, find.text('Voltar'));
          expect(checklists.salvosDeTeste, isEmpty);
          expect(find.text('Concluir'), findsOneWidget);
        });

        testWidgets('estagiário preenche, quem lidera conclui', (tester) async {
          preparar(checklists: [rascunho]);
          await abrirChecklists(tester, FuncaoObra.estagiario, escuro: escuro);
          await tocar(tester, find.text('Alvenaria'));
          expect(find.text('Concluir'), findsNothing);
          await tocar(tester, find.text('Conforme').first);
          await tocar(tester, find.text('Salvar'));
          expect(checklists.salvosDeTeste.single.$2, isFalse);
          expect(find.text('1 de 2 respondidos'), findsOneWidget);
        });

        testWidgets('adiciona item e confere o nome', (tester) async {
          preparar();
          await abrirChecklists(tester, FuncaoObra.mestre, escuro: escuro);
          await tocar(tester, find.text('Novo checklist'));
          await tocar(tester, find.text('Checklist em branco'));
          await tocar(tester, find.text('Salvar'));
          expect(find.text('Adicione pelo menos um item.'), findsOneWidget);
          await tocar(tester, find.text('Adicionar item'));
          await tester.enterText(campo('O que verificar'), 'Testar o portão');
          await tocar(tester, find.text('Adicionar'));
          expect(find.text('1. Testar o portão'), findsOneWidget);
          await tester.enterText(campo('Nome'), ' ');
          await tocar(tester, find.text('Salvar'));
          expect(find.text('Diga o nome do checklist.'), findsOneWidget);
          await tester.enterText(campo('Nome'), 'Portão');
          await tocar(tester, find.text('Salvar'));
          expect(checklists.salvosDeTeste.single.$1.itens, hasLength(1));
        });

        testWidgets('concluído só mostra e gera PDF', (tester) async {
          preparar(checklists: [concluido]);
          final enviados = <Checklist>[];
          await abrirChecklists(
            tester,
            FuncaoObra.mestre,
            escuro: escuro,
            enviarPdf: (c) async => enviados.add(c),
          );
          expect(find.text('50% conforme'), findsOneWidget);
          await tocar(tester, find.text('Segurança da obra'));
          expect(find.text('Salvar'), findsNothing);
          expect(find.text('Concluir'), findsNothing);
          expect(find.text('Concluído por Seu Jorge em 03/11'), findsOneWidget);
          expect(find.byTooltip('Excluir checklist'), findsNothing);
          await rolarAte(tester, find.text('Falta na laje'));
          expect(find.text('Não conforme'), findsOneWidget);
          await tocar(tester, find.byTooltip('Gerar PDF'));
          expect(enviados.single.titulo, 'Segurança da obra');
          expect(enviados.single.concluidoPor, 'Seu Jorge');
          expect(tester.takeException(), isNull);
        });

        testWidgets('responsável exclui', (tester) async {
          preparar(checklists: [concluido]);
          await abrirChecklists(tester, FuncaoObra.responsavel, escuro: escuro);
          await tocar(tester, find.text('Segurança da obra'));
          await tocar(tester, find.byTooltip('Excluir checklist'));
          expect(find.textContaining('continuam na obra'), findsOneWidget);
          await tocar(tester, find.text('Excluir'));
          expect(checklists.excluidosDeTeste, ['c2']);
          expect(find.text('Nenhum checklist'), findsOneWidget);
        });

        testWidgets('sem conexão oferece tentar de novo', (tester) async {
          preparar(erro: 'Sem conexão.');
          await abrirChecklists(tester, FuncaoObra.mestre, escuro: escuro);
          expect(find.text('Sem conexão.'), findsOneWidget);
          expect(find.text('Novo checklist'), findsNothing);
        });
      });

      group('tela da obra', () {
        void naObra(FuncaoObra f) {
          ObrasService.instance.definirParaTeste(obras: [obraDe(f)]);
        }

        testWidgets('quem lidera vê o aviso de vencimento', (tester) async {
          final vencido = Documento(
            id: 'x',
            titulo: 'Alvará',
            validade: DateTime.now().subtract(const Duration(days: 5)),
          );
          preparar(documentos: [vencido]);
          naObra(FuncaoObra.mestre);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Documentos'));
          expect(find.text('Alvará está vencido.'), findsOneWidget);
          await rolarAte(tester, find.text('Qualidade e segurança'));
          expect(tester.takeException(), isNull);
        });

        testWidgets('cliente vê os documentos dele, sem aviso', (tester) async {
          final vencido = Documento(
            id: 'x',
            titulo: 'Alvará',
            validade: DateTime.now().subtract(const Duration(days: 5)),
            acesso: AcessoDocumento.todos,
          );
          preparar(documentos: [vencido]);
          naObra(FuncaoObra.cliente);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Documentos'));
          expect(find.text('1 documento'), findsOneWidget);
          await rolarAte(tester, find.text('Equipe'));
          expect(find.text('Qualidade e segurança'), findsNothing);
        });

        testWidgets('estagiário vê os checklists', (tester) async {
          preparar(checklists: [rascunho]);
          naObra(FuncaoObra.estagiario);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Qualidade e segurança'));
          expect(find.text('1 rascunho para concluir'), findsOneWidget);
        });

        testWidgets('empreiteiro não vê os checklists', (tester) async {
          preparar();
          naObra(FuncaoObra.empreiteiro);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Documentos'));
          await rolarAte(tester, find.text('Equipe'));
          expect(find.text('Qualidade e segurança'), findsNothing);
        });
      });
    });
  }

  group('PDF do checklist', () {
    final obra = obraDe(FuncaoObra.responsavel);
    String inicio(Uint8List b) => String.fromCharCodes(b.take(4));

    test('sai com marca e foto', () async {
      final c = Checklist(
        modelo: 'x',
        tipo: TipoChecklist.seguranca,
        titulo: 'Segurança',
        data: hojeFixo,
        itens: const [
          ItemChecklist(
            texto: 'Guarda-corpo',
            resultado: ResultadoItem.nao,
            fotoPath: 'o1/f.png',
          ),
        ],
      );
      final b = await pdfDoChecklist(
        obra: obra,
        checklist: c,
        marca: const MarcaEngenheiro(nome: 'Duarte', registro: 'CREA 1'),
        logo: png,
        fotos: {'o1/f.png': png},
      );
      expect(inicio(b), '%PDF');
    });

    test('checklist longo continua saindo', () async {
      final c = Checklist(
        modelo: 'x',
        tipo: TipoChecklist.qualidade,
        titulo: 'Longo — “ok” 😀',
        data: hojeFixo,
        itens: [
          for (var i = 0; i < 100; i++)
            ItemChecklist(texto: 'Item $i', resultado: ResultadoItem.ok),
        ],
      );
      expect(inicio(await pdfDoChecklist(obra: obra, checklist: c)), '%PDF');
    });

    test('nome do arquivo', () {
      expect(
        nomeDoChecklist(concluido),
        'checklist-seguranca_geral-2026-11-03.pdf',
      );
    });
  });
}
