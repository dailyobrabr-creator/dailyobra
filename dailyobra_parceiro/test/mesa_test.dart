import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/componentes.dart';
import 'package:dailyobra_parceiro/screens/configuracoes_screen.dart';
import 'package:dailyobra_parceiro/screens/inicio_screen.dart';
import 'package:dailyobra_parceiro/screens/layout_parceiros.dart';
import 'package:dailyobra_parceiro/screens/mesa_screen.dart';
import 'package:dailyobra_parceiro/screens/proposta_loja_screen.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/ofertas_service.dart';
import 'package:dailyobra_parceiro/services/propostas_loja_service.dart';
import 'package:dailyobra_parceiro/services/resultados_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

PedidoResumo pedido({
  String id = 'pe1',
  StatusPrazo? prazo,
  StatusPedido status = StatusPedido.confirmado,
}) => PedidoResumo(
  id: id,
  status: status,
  total: 800,
  criadoEm: hoje,
  formaPagamento: prazo == null ? null : FormaPagamento.crediario,
  prazo: prazo == null ? null : '28/35',
  prazoStatus: prazo,
);

PropostaResumo proposta(
  String id, {
  String construtor = 'c1',
  StatusProposta status = StatusProposta.enviada,
  double? oferta = 840,
  StatusOferta? ofertaStatus = StatusOferta.pendente,
  String? mensagem = 'Fecho hoje',
  DateTime? ofertaEm,
  PedidoResumo? comPedido,
}) => PropostaResumo(
  id: id,
  orcamentoId: 'o-$id',
  lojaId: 'l1',
  construtorId: construtor,
  lojaNome: 'Casa do Construtor',
  modo: ModoProposta.negociacao,
  status: status,
  subtotalAnunciado: 1000,
  desconto: 0,
  frete: 50,
  total: 1050,
  cashbackPrevisto: 10,
  saldoAplicado: 0,
  validaAte: hoje.add(const Duration(hours: 40)),
  criadaEm: hoje,
  itens: const [
    ItemProposta(
      itemId: 'cimento-cp2-50kg',
      nome: 'Cimento CP II 50 kg',
      unidade: 'saco',
      tier: 1,
      quantidade: 10,
      precoAnunciado: 50,
    ),
    ItemProposta(
      itemId: 'tijolo-8-furos',
      nome: 'Tijolo cerâmico 8 furos',
      unidade: 'unidade',
      tier: 1,
      quantidade: 500,
      precoAnunciado: 1,
    ),
  ],
  ofertaValor: oferta,
  ofertaStatus: oferta == null ? null : ofertaStatus,
  ofertaMensagem: mensagem,
  ofertaEm: ofertaEm,
  pedido: comPedido,
);

final comPrazo = proposta(
  'p2',
  construtor: 'c2',
  status: StatusProposta.aceita,
  oferta: null,
  comPedido: pedido(prazo: StatusPrazo.pendente),
);

void preparar(
  List<PropostaResumo> propostas, {
  PapelLoja papel = PapelLoja.dono,
}) {
  LojaService.instance.definirParaTeste(loja: minhaLoja, papel: papel);
  PropostasLojaService.instance.definirParaTeste(
    propostas: propostas,
    construtores: const [
      Construtor(
        id: 'c1',
        nome: 'Ana Souza',
        empresa: 'Souza Obras',
        telefone: '44988887777',
      ),
      Construtor(id: 'c2', nome: 'Carlos Dias'),
    ],
  );
  OfertasService.instance.definirParaTeste(
    categorias: categoriasTeste,
    catalogo: catalogoTeste,
    minhas: const [Oferta(lojaId: 'l1', itemId: 'cimento-cp2-50kg', preco: 45)],
  );
  ResultadosService.instance.definirParaTeste(
    buscar: (_, _) async => const ResultadosPeriodo(),
  );
}

void main() {
  group('serviço', () {
    test('filas da mesa', () {
      final antiga = hoje.subtract(const Duration(hours: 5));
      preparar([
        proposta('p1', ofertaEm: hoje),
        proposta('p3', ofertaEm: antiga),
        proposta('fechada', status: StatusProposta.expirada),
        proposta('sem', oferta: null),
        proposta('recusada', ofertaStatus: StatusOferta.recusada),
        comPrazo,
        proposta(
          'p4',
          status: StatusProposta.aceita,
          oferta: null,
          comPedido: pedido(
            id: 'pe4',
            prazo: StatusPrazo.pendente,
            status: StatusPedido.cancelado,
          ),
        ),
      ]);
      final s = PropostasLojaService.instance;
      expect(s.ofertasPendentes.map((p) => p.id), ['p3', 'p1']);
      expect(s.prazosPendentes.map((p) => p.id), ['p2']);
      expect(s.naMesa, 3);
    });

    test('compras do cliente sem pedido cancelado', () {
      preparar([
        proposta(
          'a',
          status: StatusProposta.aceita,
          oferta: null,
          comPedido: pedido(id: 'x'),
        ),
        proposta(
          'b',
          status: StatusProposta.aceita,
          oferta: null,
          comPedido: pedido(id: 'y', status: StatusPedido.cancelado),
        ),
        proposta('c'),
      ]);
      final c = PropostasLojaService.instance.comprasDe('c1');
      expect(c.pedidos, 1);
      expect(c.total, 1050);
      expect(PropostasLojaService.instance.comprasDe('c9').pedidos, 0);
    });
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      tearDown(() => abaAtual.value = Aba.inicio);

      testWidgets('cartão da oferta mostra o que o gerente precisa', (
        tester,
      ) async {
        preparar([proposta('p1')]);
        await abrir(tester, const MesaScreen(), escuro: escuro);
        expect(find.text('Oferta do cliente'), findsWidgets);
        expect(find.text('Ana Souza'), findsOneWidget);
        expect(find.textContaining('Souza Obras'), findsOneWidget);
        expect(find.text(brl.format(1050)), findsOneWidget);
        expect(find.text(brl.format(840)), findsOneWidget);
        expect(find.text('- ${brl.format(210)} (20%)'), findsOneWidget);
        expect(find.textContaining('Cimento CP II 50 kg'), findsOneWidget);
        expect(find.textContaining('Fecho hoje'), findsOneWidget);
        expect(find.textContaining('Primeira compra'), findsOneWidget);
        await rolarAte(tester, find.text('Aprovar negociação'));
        expect(find.text('Recusar oferta'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cliente que já comprou mostra o histórico', (tester) async {
        preparar([
          proposta('p1'),
          proposta(
            'a',
            status: StatusProposta.aceita,
            oferta: null,
            comPedido: pedido(id: 'x'),
          ),
        ]);
        await abrir(tester, const MesaScreen(), escuro: escuro);
        expect(
          find.textContaining('1 pedido com a loja · ${brl.format(1050)}'),
          findsOneWidget,
        );
      });

      testWidgets('aprovar pede confirmação e manda a resposta', (
        tester,
      ) async {
        preparar([proposta('p1')]);
        await abrir(tester, const MesaScreen(), escuro: escuro);
        await rolarAte(tester, find.text('Aprovar negociação'));
        await tester.tap(find.text('Aprovar negociação'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Vira pedido de'), findsOneWidget);
        expect(PropostasLojaService.instance.ofertasDeTeste, isEmpty);
        await tester.tap(find.text('Aprovar').last);
        await tester.pumpAndSettle();
        expect(PropostasLojaService.instance.ofertasDeTeste, [
          ('p1', true, null),
        ]);
      });

      testWidgets('voltar na confirmação não aprova', (tester) async {
        preparar([proposta('p1')]);
        await abrir(tester, const MesaScreen(), escuro: escuro);
        await rolarAte(tester, find.text('Aprovar negociação'));
        await tester.tap(find.text('Aprovar negociação'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
        expect(PropostasLojaService.instance.ofertasDeTeste, isEmpty);
      });

      testWidgets('recusar pede o motivo', (tester) async {
        preparar([proposta('p1')]);
        await abrir(tester, const MesaScreen(), escuro: escuro);
        await rolarAte(tester, find.text('Recusar oferta'));
        await tester.tap(find.text('Recusar oferta'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Recusar oferta'));
        await tester.pumpAndSettle();
        expect(find.text('Informe o motivo da recusa.'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Abaixo do que podemos');
        await tester.tap(find.widgetWithText(FilledButton, 'Recusar oferta'));
        await tester.pumpAndSettle();
        expect(PropostasLojaService.instance.ofertasDeTeste, [
          ('p1', false, 'Abaixo do que podemos'),
        ]);
      });

      testWidgets('prazo do crediário na mesma fila', (tester) async {
        preparar([comPrazo]);
        await abrir(tester, const MesaScreen(), escuro: escuro);
        expect(find.text('Prazo do crediário'), findsOneWidget);
        expect(find.text('Carlos Dias'), findsOneWidget);
        expect(find.textContaining('28/35 dias'), findsOneWidget);
        await rolarAte(tester, find.text('Aprovar prazo'));
        await tester.tap(find.text('Aprovar prazo'));
        await tester.pumpAndSettle();
        expect(PropostasLojaService.instance.prazosDeTeste, [('pe1', true)]);
      });

      testWidgets('recusar o prazo', (tester) async {
        preparar([comPrazo]);
        await abrir(tester, const MesaScreen(), escuro: escuro);
        await rolarAte(tester, find.text('Recusar prazo'));
        await tester.tap(find.text('Recusar prazo'));
        await tester.pumpAndSettle();
        expect(PropostasLojaService.instance.prazosDeTeste, [('pe1', false)]);
      });

      testWidgets('nada esperando', (tester) async {
        preparar(const []);
        await abrir(tester, const MesaScreen(), escuro: escuro);
        expect(find.text('Nada esperando você'), findsOneWidget);
      });

      testWidgets('computador fica numa coluna', (tester) async {
        preparar([proposta('p1'), comPrazo]);
        await abrirLargura(tester, const MesaScreen(), 1366, escuro: escuro);
        expect(
          tester.getSize(find.byType(CartaoDaOferta)).width,
          lessThanOrEqualTo(760),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('proposta com oferta troca as respostas para o gerente', (
        tester,
      ) async {
        preparar([proposta('p1')]);
        await abrir(tester, const PropostaLojaScreen(id: 'p1'), escuro: escuro);
        expect(
          find.textContaining('ofereceu ${brl.format(840)}'),
          findsOneWidget,
        );
        expect(find.text('Oferta do cliente'), findsWidgets);
        expect(find.widgetWithText(FilledButton, 'Aceitar'), findsNothing);
        expect(find.text('Mandar contraproposta'), findsNothing);
        expect(find.text('Aprovar negociação'), findsOneWidget);
        expect(find.text('Recusar oferta'), findsOneWidget);
      });

      testWidgets('vendedor vê a oferta mas não responde', (tester) async {
        preparar([proposta('p1')], papel: PapelLoja.vendedor);
        await abrir(tester, const PropostaLojaScreen(id: 'p1'), escuro: escuro);
        expect(
          find.textContaining('ofereceu ${brl.format(840)}'),
          findsOneWidget,
        );
        expect(find.text('Aprovar negociação'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Aceitar'), findsNothing);
      });

      testWidgets('oferta recusada devolve as respostas normais', (
        tester,
      ) async {
        preparar([proposta('p1', ofertaStatus: StatusOferta.recusada)]);
        await abrir(tester, const PropostaLojaScreen(id: 'p1'), escuro: escuro);
        expect(find.widgetWithText(FilledButton, 'Aceitar'), findsOneWidget);
        expect(find.text('Aprovar negociação'), findsNothing);
      });

      testWidgets('Início leva à mesa', (tester) async {
        preparar([proposta('p1'), comPrazo]);
        await abrir(tester, const InicioScreen(), escuro: escuro);
        await rolarAte(tester, find.text('Mesa do Gerente'));
        expect(find.text('2 esperando sua decisão'), findsOneWidget);
        await tester.tap(find.text('Mesa do Gerente'));
        await tester.pump();
        expect(abaAtual.value, Aba.mesa);
      });

      testWidgets('Início do vendedor não mostra a mesa', (tester) async {
        preparar([proposta('p1')], papel: PapelLoja.vendedor);
        await abrir(tester, const InicioScreen(), escuro: escuro);
        expect(find.text('Mesa do Gerente'), findsNothing);
      });
    });
  }

  group('menu', () {
    Future<List<Aba>> montar(
      WidgetTester tester,
      double largura, {
      bool gere = true,
      Aba aba = Aba.inicio,
    }) async {
      final abas = <Aba>[];
      await abrirLargura(
        tester,
        LayoutParceiros(
          aba: aba,
          onAba: abas.add,
          novas: 0,
          mesa: 2,
          gere: gere,
          loja: minhaLoja,
          conteudo: const Text('Conteúdo'),
        ),
        largura,
      );
      return abas;
    }

    testWidgets('computador tem a mesa com o número', (tester) async {
      final abas = await montar(tester, 1366);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('Mesa do Gerente'));
      await tester.pump();
      expect(abas, [Aba.mesa]);
    });

    testWidgets('vendedor não tem a mesa no computador', (tester) async {
      await montar(tester, 1366, gere: false);
      expect(find.text('Mesa do Gerente'), findsNothing);
    });

    testWidgets('tablet do vendedor segue marcando a aba certa', (
      tester,
    ) async {
      final abas = await montar(tester, 800, gere: false, aba: Aba.clientes);
      final trilho = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(trilho.destinations, hasLength(6));
      expect(trilho.selectedIndex, 4);
      await tester.tap(find.byTooltip('Produtos'));
      await tester.pump();
      expect(abas, [Aba.produtos]);
    });

    testWidgets('celular mostra o número em Mais e marca Mais na mesa', (
      tester,
    ) async {
      await montar(tester, 360, aba: Aba.mesa);
      expect(find.text('2'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('celular do vendedor não mostra número em Mais', (
      tester,
    ) async {
      await montar(tester, 360, gere: false);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('Mais leva à mesa no celular, só para quem gere', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      preparar([proposta('p1')]);
      await abrirLargura(
        tester,
        ConfiguracoesScreen(tema: await PreferenciaTema.carregar()),
        360,
      );
      expect(find.text('1 esperando sua decisão'), findsOneWidget);
      await tester.tap(find.text('Mesa do Gerente'));
      await tester.pump();
      expect(abaAtual.value, Aba.mesa);
      abaAtual.value = Aba.inicio;

      preparar([proposta('p1')], papel: PapelLoja.vendedor);
      await abrirLargura(
        tester,
        ConfiguracoesScreen(tema: await PreferenciaTema.carregar()),
        360,
      );
      expect(find.text('Mesa do Gerente'), findsNothing);
    });
  });
}
