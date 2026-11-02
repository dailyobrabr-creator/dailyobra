import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/inicio_screen.dart';
import 'package:dailyobra_parceiro/screens/minha_loja_screen.dart';
import 'package:dailyobra_parceiro/screens/oferta_screen.dart';
import 'package:dailyobra_parceiro/screens/pedido_loja_screen.dart';
import 'package:dailyobra_parceiro/screens/produtos_screen.dart';
import 'package:dailyobra_parceiro/screens/proposta_loja_screen.dart';
import 'package:dailyobra_parceiro/screens/propostas_screen.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/ofertas_service.dart';
import 'package:dailyobra_parceiro/services/propostas_loja_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

PropostaResumo proposta(
  String id, {
  StatusProposta status = StatusProposta.enviada,
  ModoProposta modo = ModoProposta.negociacao,
  PedidoResumo? pedido,
}) => PropostaResumo(
  id: id,
  orcamentoId: 'o-$id',
  lojaId: 'l1',
  construtorId: 'c1',
  lojaNome: 'Casa do Construtor',
  modo: modo,
  status: status,
  subtotalAnunciado: 450,
  desconto: 0,
  frete: 50,
  total: 500,
  cashbackPrevisto: 4.5,
  saldoAplicado: 0,
  mensagemConstrutor: 'Entrega na obra na sexta',
  validaAte: DateTime.now().add(const Duration(hours: 40)),
  criadaEm: DateTime.now().subtract(const Duration(hours: 1)),
  itens: const [
    ItemProposta(
      itemId: 'cimento-cp2-50kg',
      nome: 'Cimento CP II 50 kg',
      unidade: 'saco',
      tier: 1,
      quantidade: 10,
      precoAnunciado: 45,
    ),
  ],
  pedido: pedido,
);

PedidoResumo pedido(StatusPedido status) => PedidoResumo(
  id: 'ped1',
  status: status,
  total: 500,
  criadoEm: DateTime.now().subtract(const Duration(minutes: 30)),
  entregueEm: status == StatusPedido.entregue ? DateTime.now() : null,
);

void preparar({
  PapelLoja papel = PapelLoja.dono,
  List<PropostaResumo>? propostas,
}) {
  LojaService.instance.definirParaTeste(loja: minhaLoja, papel: papel);
  PropostasLojaService.instance.definirParaTeste(
    propostas:
        propostas ??
        [
          proposta('p1'),
          proposta('p2', modo: ModoProposta.pedido),
          proposta(
            'p3',
            status: StatusProposta.aceita,
            pedido: pedido(StatusPedido.confirmado),
          ),
        ],
    construtores: const [
      Construtor(
        id: 'c1',
        nome: 'Ana Souza',
        empresa: 'Souza Engenharia',
        telefone: '44988887777',
      ),
    ],
  );
  OfertasService.instance.definirParaTeste(
    categorias: categoriasTeste,
    catalogo: catalogoTeste,
    minhas: [
      const Oferta(lojaId: 'l1', itemId: 'cimento-cp2-50kg', preco: 45),
      const Oferta(
        lojaId: 'l1',
        itemId: 'tijolo-8-furos',
        preco: 1.2,
        pausada: true,
      ),
    ],
  );
}

Finder valorDo(String rotulo, String valor) => find.descendant(
  of: find.widgetWithText(Indicador, rotulo),
  matching: find.text(valor),
);

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('início conta propostas novas e pedidos em andamento', (
        tester,
      ) async {
        preparar();
        await abrir(tester, const InicioScreen(), escuro: escuro);
        expect(find.text('Casa do Construtor'), findsWidgets);
        expect(valorDo('Propostas novas', '2'), findsOneWidget);
        expect(valorDo('Pedidos em andamento', '1'), findsOneWidget);
        expect(valorDo('Produtos com preço', '1'), findsOneWidget);
        await rolarAteOFim(tester);
      });

      testWidgets('lista de propostas separa novas e pedidos', (tester) async {
        preparar();
        await abrir(tester, const PropostasScreen(), escuro: escuro);
        expect(find.text('Ana Souza'), findsNWidgets(2));
        await tester.ensureVisible(find.textContaining('Pedidos'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Pedidos'));
        await tester.pumpAndSettle();
        expect(find.text('Confirmado'), findsOneWidget);
      });

      testWidgets('contraproposta acima do anunciado não é enviada', (
        tester,
      ) async {
        preparar();
        var chamadas = 0;
        Map<String, double>? enviados;
        double? descontoEnviado;
        await abrir(
          tester,
          ContrapropostaScreen(
            propostaId: 'p1',
            enviar: (precos, desconto, validade, mensagem) async {
              chamadas++;
              enviados = precos;
              descontoEnviado = desconto;
            },
          ),
          escuro: escuro,
        );
        await tester.enterText(find.byType(TextField).first, '50');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Enviar contraproposta'),
        );
        await tester.pumpAndSettle();
        expect(find.text('O preço só pode baixar.'), findsOneWidget);
        expect(chamadas, 0);

        await tester.enterText(find.byType(TextField).first, '42');
        await tester.enterText(find.byType(TextField).at(1), '20');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Enviar contraproposta'),
        );
        await tester.pumpAndSettle();
        expect(chamadas, 1);
        expect(enviados, {'cimento-cp2-50kg': 42.0});
        expect(descontoEnviado, 20);
      });

      testWidgets('recusa sem motivo pede o motivo', (tester) async {
        preparar();
        await abrir(tester, const PropostaLojaScreen(id: 'p1'), escuro: escuro);
        expect(find.text('Ana Souza'), findsOneWidget);
        expect(find.text('Entrega na obra na sexta'), findsOneWidget);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Recusar'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Recusar proposta'));
        await tester.pumpAndSettle();
        expect(find.text('Informe o motivo da recusa.'), findsOneWidget);
      });

      testWidgets('vendedor não edita preço', (tester) async {
        preparar(papel: PapelLoja.vendedor);
        await abrir(tester, const ProdutosScreen(), escuro: escuro);
        expect(find.text('Cimento CP II 50 kg'), findsOneWidget);
        expect(find.byTooltip('Editar preço'), findsNothing);
      });

      testWidgets('dono edita preço e busca sem resultado orienta', (
        tester,
      ) async {
        preparar();
        await abrir(tester, const ProdutosScreen(), escuro: escuro);
        expect(find.byTooltip('Editar preço'), findsWidgets);
        await tester.enterText(find.byType(TextField), 'xyz');
        await tester.pumpAndSettle();
        expect(find.text('Nenhum produto encontrado'), findsOneWidget);
      });

      testWidgets(
        'pedido mostra o próximo passo e o pagamento conforme o papel',
        (tester) async {
          preparar(
            propostas: [
              proposta(
                'p3',
                status: StatusProposta.aceita,
                pedido: pedido(StatusPedido.entregue),
              ),
            ],
          );
          await abrir(
            tester,
            const PedidoLojaScreen(pedidoId: 'ped1'),
            escuro: escuro,
          );
          expect(
            find.widgetWithText(FilledButton, 'Confirmar pagamento'),
            findsOneWidget,
          );

          preparar(
            papel: PapelLoja.vendedor,
            propostas: [
              proposta(
                'p3',
                status: StatusProposta.aceita,
                pedido: pedido(StatusPedido.confirmado),
              ),
            ],
          );
          await abrir(
            tester,
            const PedidoLojaScreen(pedidoId: 'ped1'),
            escuro: escuro,
          );
          expect(
            find.widgetWithText(FilledButton, 'Marcar como em separação'),
            findsOneWidget,
          );
          expect(find.text('Confirmar pagamento'), findsNothing);
        },
      );

      testWidgets('promoção maior que o preço não é salva', (tester) async {
        preparar();
        var salvou = 0;
        await abrir(
          tester,
          OfertaScreen(
            itemId: 'cimento-cp2-50kg',
            salvar: (_) async => salvou++,
          ),
          escuro: escuro,
        );
        await tester.tap(find.text('Em promoção'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(1), '50');
        await tester.tap(find.widgetWithText(FilledButton, 'Salvar preço'));
        await tester.pumpAndSettle();
        expect(
          find.text('A promoção precisa ser menor que o preço normal.'),
          findsOneWidget,
        );
        expect(salvou, 0);
      });

      testWidgets('horário traz um exemplo no formato que o app lê', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        preparar();
        await abrir(tester, MinhaLojaScreen(tema: tema), escuro: escuro);
        const exemplo = 'Seg a sex 7h às 18h; sáb 7h às 12h';
        await rolarAte(tester, find.textContaining('Escreva assim'));
        expect(find.textContaining('Escreva assim: $exemplo'), findsOneWidget);
        expect(lerHorario(exemplo), isNotNull);
      });

      testWidgets('vendedor vê a loja sem editar', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        preparar(papel: PapelLoja.vendedor);
        await abrir(tester, MinhaLojaScreen(tema: tema), escuro: escuro);
        expect(
          find.text('Só o dono ou o gerente altera os dados da loja.'),
          findsOneWidget,
        );
        expect(find.byTooltip('Trocar logo'), findsNothing);
        await rolarAteOFim(tester);
        expect(find.text('Salvar dados'), findsNothing);
        expect(find.text('Equipe'), findsNothing);
      });
    });
  }
}
