import 'dart:typed_data';

import 'package:dailyobra/screens/dia_obra_screen.dart';
import 'package:dailyobra/screens/dinheiro_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/dinheiro_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'apoio.dart';

final orcamento = Calculo.de(const ParametrosObra(area: '120')).resultado!;
final primeira = orcamento.etapas[0];
final segunda = orcamento.etapas[1];

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

final areia = LancamentoObra(
  id: 'g1',
  descricao: 'Areia lavada',
  valor: 500,
  data: DateTime(2026, 11, 3),
  etapa: primeira.etapa,
  fornecedor: 'Depósito do Zé',
);
final pedido = LancamentoObra(
  id: 'p1',
  doPedido: true,
  descricao: 'Pedido na Operário',
  valor: 1000,
  data: DateTime(2026, 11, 2),
  fornecedor: 'Operário',
);

void preparar({
  List<LancamentoObra> lancamentos = const [],
  Map<EtapaId, double> orcado = const {},
  String? erro,
}) {
  DinheiroService.instance.definirParaTeste(
    lancamentos: lancamentos,
    orcado: orcado,
    erro: erro,
  );
  DiarioService.instance.definirParaTeste();
}

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

Future<void> abrirTela(
  WidgetTester tester,
  FuncaoObra f, {
  bool escuro = false,
  Future<XFile?> Function(bool camera)? escolherFoto,
}) => abrir(
  tester,
  DinheiroScreen(obra: obraDe(f), escolherFoto: escolherFoto),
  escuro: escuro,
);

/// O rótulo de campo obrigatório vem com " *": procura pelo próprio campo.
Finder campo(String rotulo) => find.descendant(
  of: find.byWidgetPredicate((w) => w is CampoTexto && w.rotulo == rotulo),
  matching: find.byType(TextField),
);

void main() {
  testWidgets('editar um gasto de R\$ 10.000 mantém o valor', (tester) async {
    final grande = LancamentoObra(
      id: 'g9',
      descricao: 'Telhado',
      valor: 10000,
      data: DateTime(2026, 11, 3),
    );
    preparar(lancamentos: [grande]);
    await abrir(
      tester,
      GastoScreen(obra: obraDe(FuncaoObra.responsavel), gasto: grande),
    );
    await tocar(tester, find.text('Salvar'));
    expect(DinheiroService.instance.salvosDeTeste.single.valor, 10000);
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('responsável vê orçado x realizado por etapa', (
        tester,
      ) async {
        preparar(lancamentos: [areia, pedido]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(find.text('Realizado'), findsOneWidget);
        expect(find.text(brl.format(1500)), findsOneWidget);
        expect(
          find.text('de ${brl.format(orcamento.totalEtapas)} orçados'),
          findsOneWidget,
        );
        expect(find.text(primeira.nome), findsOneWidget);
        expect(
          find.textContaining('${brlInteiro.format(500)} de '),
          findsOneWidget,
        );
        await rolarAte(tester, find.text('Sem etapa'));
        expect(find.text(brl.format(1000)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('etapa que passou do orçado avisa quanto passou', (
        tester,
      ) async {
        final valor = primeira.total + 300;
        preparar(
          lancamentos: [
            LancamentoObra(
              descricao: 'x',
              valor: valor,
              data: DateTime(2026, 11, 3),
              etapa: primeira.etapa,
            ),
          ],
        );
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(find.text('1 etapa passou do orçado.'), findsOneWidget);
        expect(find.text('Passou ${brlInteiro.format(300)}'), findsOneWidget);
      });

      testWidgets('etapa perto do limite avisa', (tester) async {
        preparar(
          lancamentos: [
            LancamentoObra(
              descricao: 'x',
              valor: primeira.total * 0.95,
              data: DateTime(2026, 11, 3),
              etapa: primeira.etapa,
            ),
          ],
        );
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(find.text('Perto do limite'), findsOneWidget);
      });

      testWidgets('obra inteira estourada mostra o aviso geral', (
        tester,
      ) async {
        preparar(
          lancamentos: [
            LancamentoObra(
              descricao: 'x',
              valor: orcamento.totalEtapas + 1000,
              data: DateTime(2026, 11, 3),
            ),
          ],
        );
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(
          find.textContaining('A obra passou do orçado em'),
          findsOneWidget,
        );
        expect(find.text('Passou ${brl.format(1000)}'), findsOneWidget);
      });

      testWidgets('responsável troca a estimativa pelo valor dele', (
        tester,
      ) async {
        preparar();
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tocar(tester, find.text(primeira.nome));
        expect(find.textContaining('Estimativa do app'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '1.500,50');
        await tocar(tester, find.text('Salvar'));
        expect(DinheiroService.instance.orcadosDeTeste, [
          (primeira.etapa, 1500.5),
        ]);
        expect(find.textContaining('(seu valor)'), findsOneWidget);
      });

      testWidgets('valor orçado inválido fica na janela', (tester) async {
        preparar();
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tocar(tester, find.text(primeira.nome));
        await tester.enterText(find.byType(TextField), 'abc');
        await tocar(tester, find.text('Salvar'));
        expect(find.text('Digite um valor.'), findsOneWidget);
        expect(DinheiroService.instance.orcadosDeTeste, isEmpty);
      });

      testWidgets('volta para a estimativa', (tester) async {
        preparar(orcado: {primeira.etapa: 800});
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tocar(tester, find.text(primeira.nome));
        await tocar(tester, find.text('Usar a estimativa'));
        expect(DinheiroService.instance.orcadosDeTeste, [
          (primeira.etapa, null),
        ]);
      });

      testWidgets('lançamentos mostram gasto e pedido', (tester) async {
        preparar(lancamentos: [areia, pedido]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tester.tap(find.text('Lançamentos (2)'));
        await tester.pumpAndSettle();
        expect(find.text('Areia lavada'), findsOneWidget);
        expect(find.textContaining('Depósito do Zé'), findsOneWidget);
        expect(find.text('Pedido na Operário'), findsOneWidget);
        expect(find.textContaining('Pedido do app'), findsOneWidget);
      });

      testWidgets('responsável coloca o pedido em uma etapa', (tester) async {
        preparar(lancamentos: [pedido]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tester.tap(find.text('Lançamentos (1)'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Pedido na Operário'));
        await tocar(tester, find.text('Sem etapa').last);
        await tester.tap(find.text(segunda.nome).last);
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Salvar'));
        expect(DinheiroService.instance.classificadosDeTeste, [
          ('p1', segunda.etapa),
        ]);
      });

      testWidgets('lança gasto com valor em reais', (tester) async {
        preparar();
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tester.tap(find.text('Lançar gasto'));
        await tester.pumpAndSettle();
        await tester.enterText(campo('O que foi pago'), 'Diária do pedreiro');
        await tester.enterText(campo('Valor (R\$)'), '1.234,50');
        await tester.enterText(campo('Fornecedor'), 'João');
        await tocar(tester, find.text('Salvar'));
        final salvo = DinheiroService.instance.salvosDeTeste.single;
        expect(salvo.descricao, 'Diária do pedreiro');
        expect(salvo.valor, 1234.5);
        expect(salvo.fornecedor, 'João');
        expect(salvo.tipo, TipoGasto.material);
        expect(find.text('Diária do pedreiro'), findsOneWidget);
      });

      testWidgets('gasto sem descrição nem valor não salva', (tester) async {
        preparar();
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tester.tap(find.text('Lançar gasto'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Salvar'));
        expect(find.text('Diga o que foi pago.'), findsOneWidget);
        expect(find.text('Digite um valor maior que zero.'), findsOneWidget);
        expect(DinheiroService.instance.salvosDeTeste, isEmpty);
      });

      testWidgets('foto da nota entra no gasto', (tester) async {
        preparar();
        await abrirTela(
          tester,
          FuncaoObra.mestre,
          escuro: escuro,
          escolherFoto: (_) async =>
              XFile.fromData(Uint8List(100), name: 'a.jpg'),
        );
        await tester.tap(find.text('Lançar gasto'));
        await tester.pumpAndSettle();
        await tester.enterText(campo('O que foi pago'), 'Areia');
        await tester.enterText(campo('Valor (R\$)'), '100');
        await tocar(tester, find.text('Da galeria'));
        expect(find.byType(MiniaturaFoto), findsOneWidget);
        await tocar(tester, find.text('Salvar'));
        expect(
          DinheiroService.instance.salvosDeTeste.single.notaPath,
          'o1/nota-0.jpg',
        );
      });

      testWidgets('foto grande demais avisa', (tester) async {
        preparar();
        await abrirTela(
          tester,
          FuncaoObra.mestre,
          escuro: escuro,
          escolherFoto: (_) async =>
              XFile.fromData(Uint8List(6 * 1024 * 1024), name: 'a.jpg'),
        );
        await tester.tap(find.text('Lançar gasto'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Da galeria'));
        expect(find.textContaining('passou de 5 MB'), findsOneWidget);
      });

      testWidgets('altera um gasto', (tester) async {
        preparar(lancamentos: [areia]);
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tocar(tester, find.text('Areia lavada'));
        await tester.enterText(campo('Valor (R\$)'), '650');
        await tocar(tester, find.text('Salvar'));
        final salvo = DinheiroService.instance.salvosDeTeste.single;
        expect(salvo.id, 'g1');
        expect(salvo.valor, 650);
        expect(salvo.etapa, primeira.etapa);
      });

      testWidgets('exclui depois de confirmar', (tester) async {
        preparar(lancamentos: [areia]);
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tocar(tester, find.text('Areia lavada'));
        await tocar(tester, find.byTooltip('Excluir'));
        expect(DinheiroService.instance.excluidosDeTeste, isEmpty);
        await tocar(tester, find.text('Excluir'));
        expect(DinheiroService.instance.excluidosDeTeste, ['g1']);
        expect(find.text('Areia lavada'), findsNothing);
      });

      testWidgets('falha ao salvar fica na tela com o motivo', (tester) async {
        preparar();
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tester.tap(find.text('Lançar gasto'));
        await tester.pumpAndSettle();
        await tester.enterText(campo('O que foi pago'), 'Areia');
        await tester.enterText(campo('Valor (R\$)'), '100');
        DinheiroService.instance.definirParaTeste(erro: 'Sem conexão.');
        await tocar(tester, find.text('Salvar'));
        expect(find.text('Sem conexão.'), findsOneWidget);
        expect(find.byType(GastoScreen), findsOneWidget);
      });

      testWidgets('mestre vê só a lista dele, sem total', (tester) async {
        preparar(lancamentos: [areia]);
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        expect(find.textContaining('gastos que você lançou'), findsOneWidget);
        expect(find.text('Areia lavada'), findsOneWidget);
        expect(find.text('Realizado'), findsNothing);
        expect(find.text('Por etapa'), findsNothing);
      });

      testWidgets('sem gastos convida a lançar', (tester) async {
        preparar();
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        expect(find.text('Nenhum gasto lançado'), findsOneWidget);
      });

      testWidgets('falha ao carregar deixa tentar de novo', (tester) async {
        preparar(erro: 'Sem conexão.');
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(find.text('Sem conexão.'), findsOneWidget);
        expect(find.text('Tentar de novo'), findsOneWidget);
      });

      testWidgets('obra mostra a conta ao responsável', (tester) async {
        preparar(lancamentos: [areia]);
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.responsavel)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Dinheiro da obra'));
        expect(
          find.textContaining('${brlInteiro.format(500)} de '),
          findsOneWidget,
        );
      });

      testWidgets('obra avisa do estouro ao responsável', (tester) async {
        preparar(
          lancamentos: [
            LancamentoObra(
              descricao: 'x',
              valor: primeira.total + 10,
              data: DateTime(2026, 11, 3),
              etapa: primeira.etapa,
            ),
          ],
        );
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.responsavel)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Dinheiro da obra'));
        expect(find.text('1 etapa passou do orçado.'), findsOneWidget);
      });

      testWidgets('mestre vê o caminho para lançar, sem valores', (
        tester,
      ) async {
        preparar(lancamentos: [areia]);
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.mestre)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Gastos da obra'));
        expect(find.text('Lance o que foi pago na obra'), findsOneWidget);
      });

      for (final f in [
        FuncaoObra.estagiario,
        FuncaoObra.empreiteiro,
        FuncaoObra.cliente,
      ]) {
        testWidgets('${f.rotulo} não vê a entrada do dinheiro', (tester) async {
          preparar();
          ObrasService.instance.definirParaTeste(obras: [obraDe(f)]);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Equipe'));
          expect(find.text('Dinheiro da obra'), findsNothing);
          expect(find.text('Gastos da obra'), findsNothing);
        });
      }
    });
  }
}
