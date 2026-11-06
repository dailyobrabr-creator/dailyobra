import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/componentes.dart';
import 'package:dailyobra_parceiro/screens/faturamento_screen.dart';
import 'package:dailyobra_parceiro/screens/layout_parceiros.dart';
import 'package:dailyobra_parceiro/screens/pedido_loja_screen.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/propostas_loja_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

final quando = DateTime(2026, 11, 5, 10);

PedidoResumo pedido(
  String id, {
  StatusPedido status = StatusPedido.emSeparacao,
  DateTime? criado,
  DateTime? pago,
  FormaPagamento? forma,
  StatusPrazo? prazo,
  DateTime? informado,
  String? numero,
  DateTime? lancado,
}) => PedidoResumo(
  id: '$id-0000-0000',
  status: status,
  total: 1500,
  criadoEm: criado ?? quando,
  pagamentoConfirmadoEm: pago,
  formaPagamento: forma,
  prazo: prazo == null ? null : '28/35',
  prazoStatus: prazo,
  pagamentoInformadoEm: informado,
  erpNumero: numero,
  erpLancadoEm: numero == null ? null : lancado ?? quando,
);

PropostaResumo proposta(PedidoResumo p) => PropostaResumo(
  id: 'prop-${p.id}',
  orcamentoId: 'o1',
  lojaId: 'l1',
  lojaNome: 'Loja',
  construtorId: 'c1',
  modo: ModoProposta.negociacao,
  status: StatusProposta.aceita,
  subtotalAnunciado: 1500,
  desconto: 0,
  frete: 0,
  total: 1500,
  cashbackPrevisto: 0,
  saldoAplicado: 0,
  validaAte: quando,
  criadaEm: quando,
  itens: const [],
  pedido: p,
);

final pago = pedido('aaaaaaaa', pago: quando, forma: FormaPagamento.pix);
final crediario = pedido(
  'bbbbbbbb',
  forma: FormaPagamento.crediario,
  prazo: StatusPrazo.aprovado,
);
final semPagar = pedido('cccccccc', forma: FormaPagamento.pix);
final prazoPendente = pedido(
  'dddddddd',
  forma: FormaPagamento.crediario,
  prazo: StatusPrazo.pendente,
);
final lancado = pedido(
  'eeeeeeee',
  pago: quando,
  forma: FormaPagamento.pix,
  numero: 'V-123',
);
final canceladoLancado = pedido(
  'ffffffff',
  status: StatusPedido.cancelado,
  pago: quando,
  numero: 'V-124',
  lancado: quando.add(const Duration(hours: 1)),
);
final cancelado = pedido(
  '11111111',
  status: StatusPedido.cancelado,
  pago: quando,
);

void preparar(List<PedidoResumo> pedidos) {
  LojaService.instance.definirParaTeste(loja: minhaLoja);
  PropostasLojaService.instance.definirParaTeste(
    propostas: [for (final p in pedidos) proposta(p)],
    construtores: const [
      Construtor(id: 'c1', nome: 'Ana Souza', empresa: 'Souza Obras'),
    ],
  );
}

Future<void> abrirFaturamento(
  WidgetTester tester, {
  double largura = 360,
  bool escuro = false,
}) => abrirLargura(tester, const FaturamentoScreen(), largura, escuro: escuro);

Future<void> irPara(WidgetTester tester, String aba) async {
  await tester.ensureVisible(find.textContaining(aba));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(aba));
  await tester.pumpAndSettle();
}

void main() {
  group('filas', () {
    final servico = PropostasLojaService.instance;
    List<String> ids(List<PropostaResumo> lista) => [
      for (final p in lista) p.pedido!.id.substring(0, 8),
    ];

    test('separa pronto, aguardando e lançado', () {
      preparar([
        pago,
        crediario,
        semPagar,
        prazoPendente,
        lancado,
        canceladoLancado,
        cancelado,
      ]);
      expect(ids(servico.paraFaturar), containsAll(['aaaaaaaa', 'bbbbbbbb']));
      expect(servico.paraFaturar, hasLength(2));
      expect(
        ids(servico.aguardandoPagamento),
        containsAll(['cccccccc', 'dddddddd']),
      );
      expect(servico.aguardandoPagamento, hasLength(2));
      expect(ids(servico.faturados), ['ffffffff', 'eeeeeeee']);
    });

    test('o pedido mais antigo vem primeiro na fila', () {
      preparar([
        pedido('aaaaaaaa', pago: quando, criado: quando),
        pedido(
          'bbbbbbbb',
          pago: quando,
          criado: quando.subtract(const Duration(days: 1)),
        ),
      ]);
      expect(ids(servico.paraFaturar), ['bbbbbbbb', 'aaaaaaaa']);
    });

    test('crediário com prazo recusado não fica pronto', () {
      final recusado = pedido(
        'aaaaaaaa',
        forma: FormaPagamento.crediario,
        prazo: StatusPrazo.recusado,
      );
      expect(recusado.prontoParaFaturar, isFalse);
    });
  });

  group('leitura do banco', () {
    Map<String, dynamic> linha(Object? faturamento) => {
      'id': 'p1',
      'status': 'confirmado',
      'total': 10,
      'criado_em': '2026-11-05T10:00:00Z',
      'pedido_faturamento': faturamento,
    };

    test('lê o número vindo como objeto', () {
      final p = PedidoResumo.fromJson(
        linha({'numero': 'V-1', 'lancado_em': '2026-11-05T11:00:00Z'}),
      );
      expect(p.erpNumero, 'V-1');
      expect(p.erpLancadoEm, isNotNull);
    });

    test('lê o número vindo como lista', () {
      final p = PedidoResumo.fromJson(
        linha([
          {'numero': 'V-2', 'lancado_em': '2026-11-05T11:00:00Z'},
        ]),
      );
      expect(p.erpNumero, 'V-2');
    });

    test('sem lançamento fica vazio', () {
      expect(PedidoResumo.fromJson(linha(null)).erpNumero, isNull);
      expect(PedidoResumo.fromJson(linha(<Object>[])).erpNumero, isNull);
    });
  });

  group('situação', () {
    test('explica cada pedido', () {
      expect(situacaoNoFaturamento(pago).$1, 'Pronto para lançar');
      expect(situacaoNoFaturamento(semPagar).$1, 'Aguardando pagamento');
      expect(situacaoNoFaturamento(prazoPendente).$1, 'Prazo para aprovar');
      expect(situacaoNoFaturamento(lancado).$1, 'Lançado');
      expect(
        situacaoNoFaturamento(canceladoLancado).$1,
        'Cancelado: estornar no Santri',
      );
      expect(
        situacaoNoFaturamento(
          pedido('aaaaaaaa', forma: FormaPagamento.pix, informado: quando),
        ).$1,
        'Cliente informou o pagamento',
      );
      expect(
        situacaoNoFaturamento(
          pedido(
            'aaaaaaaa',
            forma: FormaPagamento.crediario,
            prazo: StatusPrazo.recusado,
          ),
        ).$1,
        'Prazo recusado',
      );
    });

    test('mostra o prazo do crediário e a falta de forma', () {
      expect(textoDaForma(prazoPendente), 'Crediário: 28/35 dias');
      expect(textoDaForma(pedido('aaaaaaaa')), 'Forma não escolhida');
    });
  });

  group('tela', () {
    for (final escuro in [false, true]) {
      for (final largura in [360.0, 1366.0]) {
        testWidgets('mostra as filas em ${largura.toInt()} px '
            '(${escuro ? 'escuro' : 'claro'})', (tester) async {
          preparar([pago, semPagar, lancado]);
          await abrirFaturamento(tester, largura: largura, escuro: escuro);
          expect(find.text('Para lançar (1)'), findsOneWidget);
          expect(find.text('Lançados (1)'), findsOneWidget);
          expect(find.text('Lançar no Santri'), findsOneWidget);
          expect(find.text('#AAAAAAAA'), findsOneWidget);
          expect(find.text('Ana Souza'), findsOneWidget);
          await irPara(tester, 'Lançados');
          expect(find.textContaining('Venda nº V-123'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('sem pedido orienta', (tester) async {
      preparar(const []);
      await abrirFaturamento(tester);
      expect(find.text('Nenhum pedido para lançar'), findsOneWidget);
    });

    testWidgets('quem aguarda não tem o botão de lançar', (tester) async {
      preparar([semPagar]);
      await abrirFaturamento(tester);
      await irPara(tester, 'Aguardando');
      expect(find.text('Aguardando pagamento'), findsOneWidget);
      expect(find.text('Lançar no Santri'), findsNothing);
      expect(find.text('Ver pedido'), findsOneWidget);
    });

    testWidgets('lançar pede o número e registra', (tester) async {
      preparar([pago]);
      await abrirFaturamento(tester);
      await tester.tap(find.text('Lançar no Santri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o número da venda.'), findsOneWidget);
      expect(PropostasLojaService.instance.faturamentosDeTeste, isEmpty);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '  V-900 ',
      );
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(PropostasLojaService.instance.faturamentosDeTeste, [
        (pago.id, 'V-900'),
      ]);
      expect(find.text('Pedido lançado.'), findsOneWidget);
    });

    testWidgets('número longo demais não sai da janela', (tester) async {
      preparar([pago]);
      await abrirFaturamento(tester);
      await tester.tap(find.text('Lançar no Santri'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '9' * 41,
      );
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(find.text('Use no máximo 40 caracteres.'), findsOneWidget);
      expect(PropostasLojaService.instance.faturamentosDeTeste, isEmpty);
    });

    testWidgets('cancelar a janela não registra', (tester) async {
      preparar([pago]);
      await abrirFaturamento(tester);
      await tester.tap(find.text('Lançar no Santri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(PropostasLojaService.instance.faturamentosDeTeste, isEmpty);
    });

    testWidgets('desfazer pede confirmação', (tester) async {
      preparar([lancado]);
      await abrirFaturamento(tester);
      await irPara(tester, 'Lançados');
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(find.text('Desfazer o lançamento?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Desfazer'));
      await tester.pumpAndSettle();
      expect(PropostasLojaService.instance.faturamentosDeTeste, [
        (lancado.id, null),
      ]);
    });

    testWidgets('pedido cancelado depois de lançar avisa para estornar', (
      tester,
    ) async {
      preparar([canceladoLancado]);
      await abrirFaturamento(tester);
      await irPara(tester, 'Lançados');
      expect(find.text('Cancelado: estornar no Santri'), findsOneWidget);
    });

    testWidgets('ver pedido abre a tela dele com o número', (tester) async {
      preparar([lancado]);
      await abrirFaturamento(tester);
      await irPara(tester, 'Lançados');
      await tester.tap(find.text('Ver pedido'));
      await tester.pumpAndSettle();
      expect(find.byType(PedidoLojaScreen), findsOneWidget);
    });
  });

  group('menu', () {
    Future<void> montar(
      WidgetTester tester, {
      bool gere = true,
      double largura = 1366,
    }) => abrirLargura(
      tester,
      LayoutParceiros(
        aba: Aba.faturamento,
        onAba: (_) {},
        novas: 0,
        faturar: 4,
        gere: gere,
        loja: minhaLoja,
        conteudo: const Text('Conteúdo'),
      ),
      largura,
    );

    testWidgets('gerente vê com o número de pedidos', (tester) async {
      await montar(tester);
      expect(find.text('Faturamento / Caixa'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('vendedor não vê', (tester) async {
      await montar(tester, gere: false);
      expect(find.text('Faturamento / Caixa'), findsNothing);
      expect(find.text('4'), findsNothing);
    });

    testWidgets('no celular o número aparece em Mais', (tester) async {
      await montar(tester, largura: 360);
      expect(find.text('4'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
    });
  });
}
