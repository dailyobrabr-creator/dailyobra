import 'dart:typed_data';

import 'package:dailyobra/screens/dia_obra_screen.dart';
import 'package:dailyobra/screens/diario_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/pdf_diario.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'apoio.dart';

Obra obraDe(Papel papel) => Obra(
  id: 'o1',
  papel: papel,
  dados: const DadosObra(
    nome: 'Residência Silva',
    cidade: 'Maringá',
    uf: 'PR',
    endereco: 'Rua das Flores, 120',
  ),
  parametros: const ParametrosObra(area: '120'),
  statusEtapas: const {},
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

final ontem = DiaObra(
  id: 'd0',
  obraId: 'o1',
  data: DateTime(2026, 11, 2),
  climaManha: Clima.sol,
  situacao: SituacaoDia.finalizado,
  equipe: const [
    ItemEquipe(funcao: 'Pedreiro', quantidade: 3, empresa: 'Equipe Silva'),
    ItemEquipe(funcao: 'Servente', quantidade: 2),
  ],
  atividades: const [
    Atividade(descricao: 'Reboco da sala', local: 'Térreo', percentual: 60),
  ],
);

final dia = DateTime(2026, 11, 3);

void preparar({List<DiaObra> dias = const []}) =>
    DiarioService.instance.definirParaTeste(dias: dias);

Future<void> abrirDia(
  WidgetTester tester,
  Papel papel, {
  bool escuro = false,
  DateTime? data,
  Future<List<XFile>> Function(bool camera)? escolherFoto,
  Future<void> Function(DiaObra)? enviarPdf,
}) => abrir(
  tester,
  DiaObraScreen(
    obra: obraDe(papel),
    data: data ?? dia,
    escolherFoto: escolherFoto,
    enviarPdf: enviarPdf,
  ),
  escuro: escuro,
);

/// A tela é maior que o celular do teste: rola até o alvo antes de tocar.
Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

Finder campoDoDialogo(int i) => find
    .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
    .at(i);

Future<void> adicionarEquipe(
  WidgetTester tester,
  String funcao,
  String quantidade,
) async {
  await tocar(tester, find.byKey(const Key('adicionar-equipe')));
  await tester.enterText(campoDoDialogo(0), funcao);
  await tester.enterText(campoDoDialogo(1), quantidade);
  await tester.tap(find.text('Adicionar'));
  await tester.pumpAndSettle();
}

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('dia novo abre em branco e mostra todas as partes', (
        tester,
      ) async {
        preparar();
        await abrirDia(tester, Papel.membro, escuro: escuro);
        expect(find.textContaining('3 de novembro de 2026'), findsOneWidget);
        for (final titulo in [
          'Clima',
          'Equipe',
          'O que foi feito',
          'Ocorrências',
          'Materiais',
          'Equipamentos',
          'Fotos',
          'Observações',
        ]) {
          await rolarAte(tester, find.text(titulo));
          expect(find.text(titulo), findsOneWidget, reason: titulo);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('adiciona, edita e remove equipe', (tester) async {
        preparar();
        await abrirDia(tester, Papel.membro, escuro: escuro);
        await adicionarEquipe(tester, 'Pedreiro', '3');
        expect(find.text('3 · Pedreiro'), findsOneWidget);
        await tocar(tester, find.text('3 · Pedreiro'));
        await tester.enterText(campoDoDialogo(1), '4');
        await tester.tap(find.text('Salvar item'));
        await tester.pumpAndSettle();
        expect(find.text('4 · Pedreiro'), findsOneWidget);
        await tocar(tester, find.byTooltip('Remover'));
        expect(find.text('4 · Pedreiro'), findsNothing);
      });

      testWidgets('atalho preenche a função', (tester) async {
        preparar();
        await abrirDia(tester, Papel.membro, escuro: escuro);
        await tocar(tester, find.byKey(const Key('adicionar-equipe')));
        await tester.tap(find.widgetWithText(ActionChip, 'Servente'));
        await tester.pump();
        await tester.tap(find.text('Adicionar'));
        await tester.pumpAndSettle();
        expect(find.text('1 · Servente'), findsOneWidget);
      });

      testWidgets('repete a equipe do último dia', (tester) async {
        preparar(dias: [ontem]);
        await abrirDia(tester, Papel.membro, escuro: escuro);
        await tocar(tester, find.text('Repetir equipe de 02/11'));
        expect(find.text('3 · Pedreiro'), findsOneWidget);
        expect(find.text('2 · Servente'), findsOneWidget);
        expect(find.text('Repetir equipe de 02/11'), findsNothing);
      });

      testWidgets('salva rascunho com clima e observações', (tester) async {
        preparar();
        await abrirDia(tester, Papel.membro, escuro: escuro);
        await tocar(tester, find.byKey(const Key('clima-manha-sol')));
        await rolarAte(tester, find.byKey(const Key('observacoes')));
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('observacoes')),
            matching: find.byType(TextField),
          ),
          'Dia corrido',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvar rascunho'));
        await tester.pumpAndSettle();
        final (salvo, finalizar) = DiarioService.instance.salvosDeTeste.single;
        expect(finalizar, isFalse);
        expect(salvo.climaManha, Clima.sol);
        expect(salvo.observacoes, 'Dia corrido');
        expect(salvo.data, dia);
      });

      testWidgets('finalizar pede confirmação', (tester) async {
        preparar();
        await abrirDia(tester, Papel.membro, escuro: escuro);
        await adicionarEquipe(tester, 'Pedreiro', '3');
        await tester.tap(find.text('Finalizar o dia'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('não pode mais ser alterado'),
          findsOneWidget,
        );
        expect(DiarioService.instance.salvosDeTeste, isEmpty);
        await tester.tap(find.text('Finalizar').last);
        await tester.pumpAndSettle();
        expect(DiarioService.instance.salvosDeTeste.single.$2, isTrue);
      });

      testWidgets('não finaliza um dia em branco', (tester) async {
        preparar();
        await abrirDia(tester, Papel.membro, escuro: escuro);
        await tester.tap(find.text('Finalizar o dia'));
        await tester.pumpAndSettle();
        expect(
          find.text('Preencha alguma coisa antes de finalizar o dia.'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('dia finalizado fica só para ler', (tester) async {
        preparar(dias: [ontem]);
        await abrirDia(tester, Papel.membro, escuro: escuro, data: ontem.data);
        expect(find.text('Salvar rascunho'), findsNothing);
        expect(find.byKey(const Key('adicionar-equipe')), findsNothing);
        expect(find.byTooltip('Remover'), findsNothing);
        expect(find.text('3 · Pedreiro'), findsOneWidget);
        expect(find.text('Reabrir o dia'), findsNothing);
      });

      testWidgets('administrador reabre o dia', (tester) async {
        preparar(dias: [ontem]);
        await abrirDia(tester, Papel.admin, escuro: escuro, data: ontem.data);
        await tester.tap(find.text('Reabrir o dia'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reabrir').last);
        await tester.pumpAndSettle();
        expect(DiarioService.instance.reabertosDeTeste, ['d0']);
      });

      testWidgets('cliente só lê', (tester) async {
        preparar(dias: [ontem.copyWith(situacao: SituacaoDia.rascunho)]);
        await abrirDia(tester, Papel.cliente, escuro: escuro, data: ontem.data);
        expect(find.text('Salvar rascunho'), findsNothing);
        expect(find.text('Finalizar o dia'), findsNothing);
        expect(find.byKey(const Key('adicionar-equipe')), findsNothing);
      });

      testWidgets('sair sem salvar pede confirmação', (tester) async {
        preparar();
        await abrir(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DiaObraScreen(obra: obraDe(Papel.membro), data: dia),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
          escuro: escuro,
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await adicionarEquipe(tester, 'Pedreiro', '3');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Sair sem salvar?'), findsOneWidget);
        await tester.tap(find.text('Continuar aqui'));
        await tester.pumpAndSettle();
        expect(find.text('3 · Pedreiro'), findsOneWidget);
      });

      testWidgets('foto entra no dia', (tester) async {
        preparar();
        await abrirDia(
          tester,
          Papel.membro,
          escuro: escuro,
          escolherFoto: (_) async => [
            XFile.fromData(Uint8List(100), name: 'a.jpg'),
          ],
        );
        await tocar(tester, find.text('Da galeria'));
        expect(find.byType(MiniaturaFoto), findsOneWidget);
        await rolarAte(tester, find.text('Salvar rascunho'));
        await tester.tap(find.text('Salvar rascunho'));
        await tester.pumpAndSettle();
        expect(
          DiarioService.instance.salvosDeTeste.single.$1.fotos,
          hasLength(1),
        );
      });

      testWidgets('foto grande demais avisa', (tester) async {
        preparar();
        await abrirDia(
          tester,
          Papel.membro,
          escuro: escuro,
          escolherFoto: (_) async => [
            XFile.fromData(Uint8List(6 * 1024 * 1024), name: 'a.jpg'),
          ],
        );
        await tocar(tester, find.text('Da galeria'));
        expect(find.textContaining('passou de 5 MB'), findsOneWidget);
        expect(find.byType(MiniaturaFoto), findsNothing);
      });

      testWidgets('dia salvo gera o PDF', (tester) async {
        final enviados = <DiaObra>[];
        preparar(dias: [ontem]);
        await abrirDia(
          tester,
          Papel.membro,
          escuro: escuro,
          data: ontem.data,
          enviarPdf: (d) async => enviados.add(d),
        );
        await tester.tap(find.byTooltip('Gerar PDF'));
        await tester.pumpAndSettle();
        expect(enviados.single.id, 'd0');
      });

      testWidgets('histórico lista os dias', (tester) async {
        preparar(dias: [ontem]);
        await abrir(
          tester,
          DiarioScreen(obra: obraDe(Papel.membro)),
          escuro: escuro,
        );
        expect(find.textContaining('2 de novembro de 2026'), findsOneWidget);
        expect(find.text('5 pessoas · 1 atividade'), findsOneWidget);
        expect(find.text('Finalizado'), findsOneWidget);
        expect(find.text('Novo dia'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('histórico vazio convida a começar', (tester) async {
        preparar();
        await abrir(
          tester,
          DiarioScreen(obra: obraDe(Papel.membro)),
          escuro: escuro,
        );
        expect(find.text('Nenhum dia registrado'), findsOneWidget);
      });

      testWidgets('cliente não cria dia no histórico', (tester) async {
        preparar(dias: [ontem]);
        await abrir(
          tester,
          DiarioScreen(obra: obraDe(Papel.cliente)),
          escuro: escuro,
        );
        expect(find.text('Novo dia'), findsNothing);
      });

      testWidgets('obra mostra a entrada do diário', (tester) async {
        preparar();
        ObrasService.instance.definirParaTeste(obras: [obraDe(Papel.membro)]);
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Diário de obra'));
        expect(find.text('Hoje ainda não foi preenchido.'), findsOneWidget);
        expect(find.text('Preencher hoje'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cliente vê o diário sem preencher', (tester) async {
        preparar(dias: [ontem]);
        ObrasService.instance.definirParaTeste(obras: [obraDe(Papel.cliente)]);
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Diário de obra'));
        expect(find.text('Preencher hoje'), findsNothing);
        expect(find.text('Ver histórico (1)'), findsOneWidget);
      });
    });
  }

  group('PDF', () {
    test('sai um PDF, mesmo com texto fora do alfabeto comum', () async {
      final bytes = await pdfDoDia(
        obra: obraDe(Papel.admin),
        dia: ontem.copyWith(observacoes: 'Concreto – ok 👷 ção'),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(800));
    });

    test('dia cheio não quebra o layout', () async {
      final bytes = await pdfDoDia(
        obra: obraDe(Papel.admin),
        dia: ontem.copyWith(
          equipe: [
            for (var i = 0; i < 40; i++)
              ItemEquipe(funcao: 'Função $i', quantidade: i),
          ],
          atividades: [
            for (var i = 0; i < 40; i++)
              Atividade(descricao: 'Atividade longa número $i ' * 3),
          ],
          ocorrencias: const [
            Ocorrencia(
              tipo: TipoOcorrencia.seguranca,
              descricao: 'Sem capacete',
            ),
          ],
          materiais: const [
            MaterialDia(
              material: 'Cimento',
              quantidade: 10,
              unidade: 'saco',
              fornecedor: 'Operário',
            ),
          ],
          equipamentos: const [EquipamentoDia(equipamento: 'Betoneira')],
        ),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('nome do arquivo', () {
      expect(nomeDoPdf(ontem), 'diario-de-obra-2026-11-02.pdf');
    });
  });
}
