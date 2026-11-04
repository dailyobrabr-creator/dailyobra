import 'dart:typed_data';

import 'package:dailyobra/screens/compras_screen.dart';
import 'package:dailyobra/screens/dia_obra_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/services/carrinho_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra/services/compras_service.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/dinheiro_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

final dia = DateTime(2026, 11, 20);
const parametros = ParametrosObra(area: '120');
const parametrosAlto = ParametrosObra(area: '120', padrao: Padrao.alto);
final etapas = Calculo.de(parametros).resultado!.etapas;
final primeira = etapas[0];
final segunda = etapas[1];

Obra obraDe(FuncaoObra f, {ParametrosObra p = parametros}) => Obra(
  id: 'o1',
  papel: switch (f) {
    FuncaoObra.responsavel => Papel.admin,
    FuncaoObra.cliente => Papel.cliente,
    _ => Papel.membro,
  },
  funcao: f,
  dados: const DadosObra(nome: 'Residência Silva', cidade: 'Maringá', uf: 'PR'),
  parametros: p,
  statusEtapas: const {},
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

final cimentoNaLista = MaterialObra(
  id: 'm1',
  etapa: primeira.etapa,
  itemId: cimento.id,
  nome: cimento.nome,
  unidade: 'saco',
  quantidade: 50,
  precoBase: 30,
);
final tijoloNaLista = MaterialObra(
  id: 'm2',
  etapa: primeira.etapa,
  itemId: tijolo.id,
  nome: tijolo.nome,
  unidade: 'unidade',
  quantidade: 1000,
  precoBase: 1.2,
);
final escoraForaDoCatalogo = MaterialObra(
  id: 'm3',
  etapa: primeira.etapa,
  nome: 'Escora de eucalipto',
  unidade: 'und',
  quantidade: 12,
);
final doPedido = ItemDePedido(
  pedidoId: 'p1',
  loja: 'Casa do Construtor',
  situacao: 'confirmado',
  data: DateTime(2026, 11, 3),
  itemId: cimento.id,
  nome: cimento.nome,
  unidade: 'saco',
  quantidade: 20,
);

void preparar({
  List<MaterialObra> materiais = const [],
  List<ItemDePedido> pedidos = const [],
  List<Recebimento> recebimentos = const [],
  String? erro,
}) {
  ComprasService.instance.definirParaTeste(
    materiais: materiais,
    pedidos: pedidos,
    recebimentos: recebimentos,
    erro: erro,
  );
  DiarioService.instance.definirParaTeste();
  DinheiroService.instance.definirParaTeste();
  CatalogoService.instance.definirParaTeste(
    categorias: categoriasTeste,
    itens: itensTeste,
    lojas: const [lojaA, lojaB, lojaC],
    ofertas: ofertasTeste,
  );
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
  ParametrosObra p = parametros,
  bool escuro = false,
  Future<XFile?> Function(bool camera)? escolherFoto,
}) => abrir(
  tester,
  ComprasScreen(
    obra: obraDe(f, p: p),
    hoje: dia,
    escolherFoto: escolherFoto,
  ),
  escuro: escuro,
);

Finder campo(String rotulo) => find.descendant(
  of: find.byWidgetPredicate((w) => w is CampoTexto && w.rotulo == rotulo),
  matching: find.byType(TextField),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CarrinhoService.instance.carregar();
  });
  tearDown(() => CarrinhoService.instance.limpar());

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('padrão médio explica e oferece as duas bases', (
        tester,
      ) async {
        preparar();
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(
          find.textContaining('A lista própria do padrão médio'),
          findsOneWidget,
        );
        expect(find.text('Usar a base Econômico'), findsOneWidget);
        expect(find.text('Usar a base Médio/Alto'), findsOneWidget);
        await tocar(tester, find.text('Usar a base Médio/Alto'));
        final salvos = ComprasService.instance.listasDeTeste.single;
        expect(salvos, isNotEmpty);
        expect(salvos.first.etapa, isNotNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('quem tem lista usa a do orçamento', (tester) async {
        preparar();
        await abrirTela(
          tester,
          FuncaoObra.responsavel,
          p: parametrosAlto,
          escuro: escuro,
        );
        await tocar(tester, find.text('Usar a lista do orçamento'));
        expect(ComprasService.instance.listasDeTeste.single, isNotEmpty);
      });

      testWidgets('quem não lidera espera a lista', (tester) async {
        preparar();
        await abrirTela(tester, FuncaoObra.estagiario, escuro: escuro);
        expect(
          find.text('A lista de materiais ainda não foi montada.'),
          findsOneWidget,
        );
        expect(find.text('Usar a base Médio/Alto'), findsNothing);
      });

      testWidgets('mostra o que comprar, com preço e alerta', (tester) async {
        preparar(materiais: [cimentoNaLista, escoraForaDoCatalogo]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(find.text(cimento.nome), findsOneWidget);
        expect(find.textContaining('Falta 50 saco'), findsOneWidget);
        expect(find.textContaining(brl.format(38)), findsOneWidget);
        expect(find.text('Subiu 27%'), findsOneWidget);
        expect(find.text('Escora de eucalipto'), findsOneWidget);
        expect(find.text('Fora do catálogo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('o que foi comprado sai da conta', (tester) async {
        preparar(materiais: [cimentoNaLista], pedidos: [doPedido]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(find.textContaining('Falta 30 saco'), findsOneWidget);
      });

      testWidgets('tudo comprado mostra lista vazia', (tester) async {
        preparar(
          materiais: [cimentoNaLista],
          recebimentos: [
            Recebimento(
              itemId: cimento.id,
              nome: cimento.nome,
              unidade: 'saco',
              quantidade: 50,
              data: dia,
            ),
          ],
        );
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        expect(find.text('Nada para comprar neste período'), findsOneWidget);
      });

      testWidgets('cotar leva os materiais e a obra para o orçamento', (
        tester,
      ) async {
        preparar(
          materiais: [cimentoNaLista, tijoloNaLista, escoraForaDoCatalogo],
        );
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await rolarAte(tester, find.text('Cotar estes materiais'));
        await tocar(tester, find.text('Cotar estes materiais'));
        final carrinho = CarrinhoService.instance;
        expect(
          carrinho.itens.map((i) => i.itemId),
          containsAll([cimento.id, tijolo.id]),
        );
        expect(carrinho.itens, hasLength(2));
        expect(carrinho.obraId, 'o1');
      });

      testWidgets('cotar pergunta antes de trocar o orçamento', (tester) async {
        preparar(materiais: [cimentoNaLista]);
        CarrinhoService.instance.adicionar(torneira.id, 1);
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tocar(tester, find.text('Cotar estes materiais'));
        expect(find.text('Trocar o orçamento atual?'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(CarrinhoService.instance.itens.single.itemId, torneira.id);
      });

      testWidgets('saldo mostra previsto, comprado e recebido', (tester) async {
        preparar(
          materiais: [cimentoNaLista],
          pedidos: [doPedido],
          recebimentos: [
            Recebimento(
              pedidoId: 'p1',
              itemId: cimento.id,
              nome: cimento.nome,
              unidade: 'saco',
              quantidade: 5,
              data: dia,
            ),
          ],
        );
        await abrirTela(tester, FuncaoObra.estagiario, escuro: escuro);
        await tester.tap(find.text('Saldo'));
        await tester.pumpAndSettle();
        expect(
          find.text('Previsto 50 · Comprado 20 · Recebido 5'),
          findsOneWidget,
        );
        expect(find.text('Falta 30 saco'), findsOneWidget);
        expect(find.text('A receber 15 saco'), findsOneWidget);
      });

      testWidgets('responsável edita a lista', (tester) async {
        preparar(materiais: [cimentoNaLista]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tester.tap(find.text('Saldo'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Editar lista'));
        await tocar(tester, find.text(cimento.nome));
        await tester.enterText(campo('Quantidade'), '75');
        await tocar(tester, find.text('Salvar'));
        final salvo = ComprasService.instance.materiaisDeTeste.single;
        expect(salvo.id, 'm1');
        expect(salvo.quantidade, 75);
        expect(salvo.etapa, primeira.etapa);
      });

      testWidgets('adiciona material escolhendo do catálogo', (tester) async {
        preparar(materiais: [cimentoNaLista]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tester.tap(find.text('Saldo'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Editar lista'));
        await tester.tap(find.text('Adicionar material'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('material')), 'torneira');
        await tester.pumpAndSettle();
        await tester.tap(find.text(torneira.nome).last);
        await tester.pumpAndSettle();
        await tester.enterText(campo('Quantidade'), '4');
        await tocar(tester, find.text('Salvar'));
        final salvo = ComprasService.instance.materiaisDeTeste.single;
        expect(salvo.itemId, torneira.id);
        expect(salvo.unidade, 'unidade');
        expect(
          salvo.precoBase,
          210,
          reason: 'a promoção do teste já venceu no dia fixado',
        );
      });

      testWidgets('material sem quantidade não salva', (tester) async {
        preparar(materiais: [cimentoNaLista]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tester.tap(find.text('Saldo'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Editar lista'));
        await tester.tap(find.text('Adicionar material'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('material')), 'Prego');
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Salvar'));
        expect(
          find.text('Digite uma quantidade maior que zero.'),
          findsOneWidget,
        );
        expect(ComprasService.instance.materiaisDeTeste, isEmpty);
      });

      testWidgets('exclui material depois de confirmar', (tester) async {
        preparar(materiais: [cimentoNaLista]);
        await abrirTela(tester, FuncaoObra.responsavel, escuro: escuro);
        await tester.tap(find.text('Saldo'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Editar lista'));
        await tocar(tester, find.byTooltip('Excluir ${cimento.nome}'));
        expect(ComprasService.instance.excluidosDeTeste, isEmpty);
        await tocar(tester, find.text('Excluir'));
        expect(ComprasService.instance.excluidosDeTeste, ['m1']);
      });

      testWidgets('estagiário não edita a lista', (tester) async {
        preparar(materiais: [cimentoNaLista]);
        await abrirTela(tester, FuncaoObra.estagiario, escuro: escuro);
        await tester.tap(find.text('Saldo'));
        await tester.pumpAndSettle();
        expect(find.text('Editar lista'), findsNothing);
      });

      testWidgets('registra o que chegou do pedido', (tester) async {
        preparar(materiais: [cimentoNaLista], pedidos: [doPedido]);
        await abrirTela(tester, FuncaoObra.estagiario, escuro: escuro);
        await tester.tap(find.text('Receber'));
        await tester.pumpAndSettle();
        expect(find.text('Pedido na Casa do Construtor'), findsOneWidget);
        expect(find.textContaining('0 de 20 saco'), findsOneWidget);
        await tocar(tester, find.text('Registrar o que chegou'));
        expect(find.text(cimento.nome), findsOneWidget);
        await tester.enterText(
          find.byKey(Key('quantidade-${cimento.id}')),
          '15',
        );
        await tester.enterText(
          find.byKey(const Key('observacao')),
          'Faltaram 5 sacos',
        );
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Salvar'));
        final (pedido, itens, _, observacao, _) =
            ComprasService.instance.recebimentosDeTeste.single;
        expect(pedido, 'p1');
        expect(itens.single.quantidade, 15);
        expect(observacao, 'Faltaram 5 sacos');
        expect(find.textContaining('15 de 20 saco'), findsOneWidget);
      });

      testWidgets('pedido todo recebido não pede de novo', (tester) async {
        preparar(
          pedidos: [doPedido],
          materiais: [cimentoNaLista],
          recebimentos: [
            Recebimento(
              id: 'r1',
              pedidoId: 'p1',
              itemId: cimento.id,
              nome: cimento.nome,
              unidade: 'saco',
              quantidade: 20,
              data: dia,
            ),
          ],
        );
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tester.tap(find.text('Receber'));
        await tester.pumpAndSettle();
        expect(find.text('Registrar o que chegou'), findsNothing);
        expect(find.text('Recebido'), findsOneWidget);
      });

      testWidgets('registra compra de fora do app', (tester) async {
        preparar(materiais: [cimentoNaLista]);
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tester.tap(find.text('Receber'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Comprei fora do app'));
        await tester.enterText(campo('Material'), 'Areia');
        await tester.enterText(campo('Unidade'), 'm3');
        await tester.enterText(campo('Quantidade'), '2,5');
        await tocar(tester, find.text('Salvar'));
        final (pedido, itens, _, _, _) =
            ComprasService.instance.recebimentosDeTeste.single;
        expect(pedido, isNull);
        expect(itens.single.nome, 'Areia');
        expect(itens.single.quantidade, 2.5);
      });

      testWidgets('recebimento sem quantidade avisa', (tester) async {
        preparar(materiais: [cimentoNaLista], pedidos: [doPedido]);
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tester.tap(find.text('Receber'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Registrar o que chegou'));
        await tester.enterText(find.byKey(Key('quantidade-${cimento.id}')), '');
        await tocar(tester, find.text('Salvar'));
        expect(find.text('Informe pelo menos um material.'), findsOneWidget);
        expect(ComprasService.instance.recebimentosDeTeste, isEmpty);
      });

      testWidgets('foto vai junto com o recebimento', (tester) async {
        preparar(materiais: [cimentoNaLista], pedidos: [doPedido]);
        await abrirTela(
          tester,
          FuncaoObra.mestre,
          escuro: escuro,
          escolherFoto: (_) async =>
              XFile.fromData(Uint8List(100), name: 'a.jpg'),
        );
        await tester.tap(find.text('Receber'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Registrar o que chegou'));
        await tocar(tester, find.text('Da galeria'));
        expect(find.byType(MiniaturaFoto), findsOneWidget);
        await tocar(tester, find.text('Salvar'));
        expect(
          ComprasService.instance.recebimentosDeTeste.single.$5,
          isNotNull,
        );
      });

      testWidgets('histórico mostra o que chegou e permite excluir', (
        tester,
      ) async {
        preparar(
          materiais: [cimentoNaLista],
          recebimentos: [
            Recebimento(
              id: 'r1',
              itemId: cimento.id,
              nome: cimento.nome,
              unidade: 'saco',
              quantidade: 5,
              data: dia,
              observacao: 'Chegou molhado',
            ),
          ],
        );
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        await tester.tap(find.text('Receber'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chegou molhado'), findsOneWidget);
        await tocar(
          tester,
          find.byTooltip('Excluir recebimento de ${cimento.nome}'),
        );
        await tocar(tester, find.text('Excluir'));
        expect(ComprasService.instance.recebimentosExcluidosDeTeste, ['r1']);
      });

      testWidgets('falha ao carregar deixa tentar de novo', (tester) async {
        preparar(erro: 'Sem conexão.');
        await abrirTela(tester, FuncaoObra.mestre, escuro: escuro);
        expect(find.text('Sem conexão.'), findsOneWidget);
        expect(find.text('Tentar de novo'), findsOneWidget);
      });

      testWidgets('obra mostra as compras da semana', (tester) async {
        preparar(materiais: [cimentoNaLista]);
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.mestre)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Compras da obra'));
        expect(find.text('1 material para os próximos 7 dias'), findsOneWidget);
      });

      testWidgets('obra sem lista convida a montar', (tester) async {
        preparar();
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.responsavel)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Compras da obra'));
        expect(find.text('Monte a lista de materiais'), findsOneWidget);
      });

      for (final f in [FuncaoObra.empreiteiro, FuncaoObra.cliente]) {
        testWidgets('${f.rotulo} não vê as compras', (tester) async {
          preparar();
          ObrasService.instance.definirParaTeste(obras: [obraDe(f)]);
          await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
          await rolarAte(tester, find.text('Equipe'));
          expect(find.text('Compras da obra'), findsNothing);
        });
      }
    });
  }
}
