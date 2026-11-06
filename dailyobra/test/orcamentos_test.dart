import 'package:dailyobra/screens/orcamentos_screen.dart';
import 'package:dailyobra/screens/pedido_screen.dart';
import 'package:dailyobra/screens/proposta_screen.dart';
import 'package:dailyobra/services/carrinho_service.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra/services/negociacao_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

void preparar({List<Oferta>? ofertas, double saldo = 0}) {
  CatalogoService.instance.definirParaTeste(
    categorias: categoriasTeste,
    itens: itensTeste,
    lojas: const [lojaA, lojaB, lojaC],
    ofertas: ofertas ?? ofertasTeste,
  );
  PerfilService.instance.definirParaTeste(
    nome: 'Ana',
    cidade: 'Maringá',
    uf: 'PR',
  );
  CarteiraService.instance.definirParaTeste(disponivel: saldo);
  NegociacaoService.instance.definirParaTeste();
}

PropostaResumo proposta({
  StatusProposta status = StatusProposta.contraproposta,
  PedidoResumo? pedido,
}) => PropostaResumo(
  id: 'p1',
  orcamentoId: 'o1',
  lojaId: 'a',
  lojaNome: 'Casa do Construtor',
  loja: lojaA,
  modo: ModoProposta.negociacao,
  status: status,
  subtotalAnunciado: 450,
  desconto: 20,
  frete: 50,
  total: 450,
  cashbackPrevisto: 4,
  saldoAplicado: 0,
  mensagemLoja: 'Fecho em 42 e dou 20 de desconto',
  validaAte: DateTime.now().add(const Duration(hours: 20)),
  criadaEm: DateTime.now().subtract(const Duration(hours: 2)),
  itens: const [
    ItemProposta(
      itemId: 'cimento-cp2-50kg',
      nome: 'Cimento CP II 50 kg',
      unidade: 'saco',
      tier: 1,
      quantidade: 10,
      precoAnunciado: 45,
      precoOfertado: 42,
    ),
  ],
  pedido: pedido,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CarrinhoService.instance.carregar();
  });
  tearDown(() => CarrinhoService.instance.limpar());

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('cotação de 3 itens em 3 lojas', (tester) async {
        preparar();
        CarrinhoService.instance
          ..adicionar(tijolo.id, 1000)
          ..adicionar(argamassa.id, 10)
          ..adicionar(cimento.id, 20);
        await abrir(tester, const OrcamentosScreen(), escuro: escuro);
        // A: 1.200 + frete 50; B: 250 (promoção) + frete 30; C: 760 sem frete
        expect(find.text(brl.format(2290)), findsOneWidget);
        expect(find.text('Casa do Construtor'), findsOneWidget);
        await rolarAte(tester, find.text('Depósito Bom Preço'));
        await rolarAte(tester, find.text('Ferragens Sarandi'));
        await rolarAteOFim(tester);
      });

      testWidgets('melhor por loja mostra uma loja e o que ela não tem', (
        tester,
      ) async {
        preparar(
          ofertas: [
            for (final o in ofertasTeste)
              if (!(o.lojaId == 'a' && o.itemId == argamassa.id)) o,
          ],
        );
        CarrinhoService.instance
          ..adicionar(tijolo.id, 1000)
          ..adicionar(argamassa.id, 10)
          ..adicionar(torneira.id, 1);
        await abrir(tester, const OrcamentosScreen(), escuro: escuro);
        await tester.tap(find.text('Melhor por loja'));
        await tester.pumpAndSettle();
        await rolarAte(tester, find.text('Sem oferta nesta loja'));
        expect(find.text('Casa do Construtor'), findsOneWidget);
        expect(find.text('Depósito Bom Preço'), findsNothing);
        expect(find.text('Argamassa colante AC-I 20 kg'), findsOneWidget);
      });

      testWidgets('loja abaixo do mínimo trava o envio e diz quanto falta', (
        tester,
      ) async {
        preparar(
          ofertas: [Oferta(lojaId: 'a', itemId: tijolo.id, preco: 1.20)],
        );
        CarrinhoService.instance.adicionar(tijolo.id, 50);
        await abrir(tester, const OrcamentosScreen(), escuro: escuro);
        expect(find.textContaining('Faltam ${brl.format(40)}'), findsOneWidget);
        final fechar = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Fechar pedido'),
        );
        expect(fechar.onPressed, isNull);
        expect(find.textContaining('pedido mínimo'), findsWidgets);
      });

      testWidgets('orçamento vazio orienta', (tester) async {
        preparar();
        await abrir(tester, const OrcamentosScreen(), escuro: escuro);
        expect(find.text('Seu orçamento está vazio'), findsOneWidget);
      });

      testWidgets('envio com preço atualizado avisa o construtor', (
        tester,
      ) async {
        preparar();
        NegociacaoService.instance.definirParaTeste(
          resultadoEnvio: const ResultadoEnvio(
            orcamentoId: 'o1',
            precosAtualizados: true,
            lojas: 1,
          ),
        );
        CarrinhoService.instance.adicionar(torneira.id, 1);
        await abrir(tester, const OrcamentosScreen(), escuro: escuro);
        await tester.tap(find.widgetWithText(FilledButton, 'Fechar pedido'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Os preços foram atualizados pelas lojas'),
          findsOneWidget,
        );
        expect(CarrinhoService.instance.vazio, isTrue);
      });

      testWidgets('orçamento vai para a obra escolhida', (tester) async {
        preparar();
        ObrasService.instance.definirParaTeste(
          obras: [
            Obra(
              id: 'o1',
              papel: Papel.admin,
              dados: const DadosObra(nome: 'Residência Silva'),
              parametros: const ParametrosObra(area: '120'),
              statusEtapas: const {},
              criadaEm: DateTime(2026, 11),
              atualizadaEm: DateTime(2026, 11),
            ),
          ],
        );
        NegociacaoService.instance.definirParaTeste(
          resultadoEnvio: const ResultadoEnvio(
            orcamentoId: 'o1',
            precosAtualizados: false,
            lojas: 1,
          ),
        );
        CarrinhoService.instance.adicionar(torneira.id, 1);
        await abrir(tester, const OrcamentosScreen(), escuro: escuro);
        expect(find.text('Para qual obra'), findsOneWidget);
        await tester.tap(find.text('Sem obra'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Residência Silva').last);
        await tester.pumpAndSettle();
        expect(CarrinhoService.instance.obraId, 'o1');
        await tester.tap(find.widgetWithText(FilledButton, 'Fechar pedido'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
        await tester.pumpAndSettle();
        expect(NegociacaoService.instance.obraDeTeste, 'o1');
        expect(CarrinhoService.instance.obraId, isNull);
      });

      testWidgets('obra que saiu da conta não vai no orçamento', (
        tester,
      ) async {
        preparar();
        ObrasService.instance.definirParaTeste(obras: const []);
        NegociacaoService.instance.definirParaTeste(
          resultadoEnvio: const ResultadoEnvio(
            orcamentoId: 'o1',
            precosAtualizados: false,
            lojas: 1,
          ),
        );
        CarrinhoService.instance
          ..adicionar(torneira.id, 1)
          ..escolherObra('sumiu');
        await abrir(tester, const OrcamentosScreen(), escuro: escuro);
        expect(find.text('Para qual obra'), findsNothing);
        await tester.tap(find.widgetWithText(FilledButton, 'Fechar pedido'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
        await tester.pumpAndSettle();
        expect(NegociacaoService.instance.obraDeTeste, isNull);
      });

      testWidgets('cotação não oferece o saldo da carteira', (tester) async {
        preparar(saldo: 50);
        CarrinhoService.instance.adicionar(torneira.id, 1);
        await abrir(tester, const OrcamentosScreen(), escuro: escuro);
        expect(find.textContaining('Usar saldo da carteira'), findsNothing);
        expect(find.byType(SwitchListTile), findsNothing);
        await tester.tap(find.widgetWithText(FilledButton, 'Fechar pedido'));
        await tester.pumpAndSettle();
        expect(find.text('Fechar pedido?'), findsOneWidget);
        expect(find.textContaining('Usar saldo da carteira'), findsNothing);
      });

      testWidgets('contraproposta mostra anunciado × ofertado e as decisões', (
        tester,
      ) async {
        preparar();
        NegociacaoService.instance.definirParaTeste(propostas: [proposta()]);
        await abrir(tester, const PropostaScreen(id: 'p1'), escuro: escuro);
        final anunciado = tester.widget<Text>(find.text(brl.format(45)));
        expect(anunciado.style?.decoration, TextDecoration.lineThrough);
        expect(find.text(brl.format(42)), findsOneWidget);
        expect(find.text('Fecho em 42 e dou 20 de desconto'), findsOneWidget);
        await rolarAteOFim(tester);
        expect(find.widgetWithText(FilledButton, 'Aceitar'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Recusar'), findsOneWidget);
      });

      testWidgets('pedido sem pagamento pergunta quem paga', (tester) async {
        preparar();
        NegociacaoService.instance.definirParaTeste(
          propostas: [
            proposta(
              status: StatusProposta.aceita,
              pedido: PedidoResumo(
                id: 'ped1',
                status: StatusPedido.confirmado,
                total: 450,
                criadoEm: DateTime.now(),
              ),
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        expect(find.text('Quem paga este pedido?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('pedido pago não pergunta quem paga', (tester) async {
        preparar();
        NegociacaoService.instance.definirParaTeste(
          propostas: [
            proposta(
              status: StatusProposta.aceita,
              pedido: PedidoResumo(
                id: 'ped1',
                status: StatusPedido.confirmado,
                total: 450,
                criadoEm: DateTime.now(),
                pagamentoConfirmadoEm: DateTime.now(),
              ),
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        expect(find.text('Quem paga este pedido?'), findsNothing);
        expect(find.textContaining('Pagamento confirmado em'), findsOneWidget);
      });

      testWidgets('pedido saiu para entrega marca o terceiro passo', (
        tester,
      ) async {
        preparar();
        NegociacaoService.instance.definirParaTeste(
          propostas: [
            proposta(
              status: StatusProposta.aceita,
              pedido: PedidoResumo(
                id: 'ped1',
                status: StatusPedido.saiuEntrega,
                total: 450,
                criadoEm: DateTime.now(),
              ),
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        for (final passo in [
          'Confirmado',
          'Em separação',
          'Saiu para entrega',
          'Entregue',
        ]) {
          expect(find.text(passo), findsOneWidget);
        }
        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
        expect(find.text('Cancelar pedido'), findsNothing);
      });
    });
  }
}
