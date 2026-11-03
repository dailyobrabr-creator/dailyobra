import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/atualizar_estoque_screen.dart';
import 'package:dailyobra_parceiro/screens/importar_planilha_screen.dart';
import 'package:dailyobra_parceiro/screens/inicio_screen.dart';
import 'package:dailyobra_parceiro/screens/minha_loja_screen.dart';
import 'package:dailyobra_parceiro/screens/oferta_screen.dart';
import 'package:dailyobra_parceiro/screens/pedido_loja_screen.dart';
import 'package:dailyobra_parceiro/screens/produtos_screen.dart';
import 'package:dailyobra_parceiro/screens/proposta_loja_screen.dart';
import 'package:dailyobra_parceiro/screens/propostas_screen.dart';
import 'package:dailyobra_parceiro/services/cep_service.dart';
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

/// Pedido confirmado no "Eu pago", com a forma escolhida pelo construtor.
PropostaResumo comForma(
  FormaPagamento forma, {
  String? prazo,
  StatusPrazo? prazoStatus,
}) => proposta(
  'p3',
  status: StatusProposta.aceita,
  pedido: PedidoResumo(
    id: 'ped1',
    status: StatusPedido.confirmado,
    total: 500,
    criadoEm: DateTime.now().subtract(const Duration(minutes: 30)),
    pagador: Pagador.proprio,
    formaPagamento: forma,
    prazo: prazo,
    prazoStatus: prazoStatus,
  ),
);

void preparar({
  PapelLoja papel = PapelLoja.dono,
  List<PropostaResumo>? propostas,
  Map<String, String> documentos = const {},
}) {
  LojaService.instance.definirParaTeste(loja: minhaLoja, papel: papel);
  PropostasLojaService.instance.definirParaTeste(
    documentos: documentos,
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

Finder campoDoEndereco(String nome) => find.descendant(
  of: find.byKey(Key('endereco-$nome')),
  matching: find.byType(TextField),
);

Future<EnderecoCep?> buscarCepFalso(String cep) async => const EnderecoCep(
  logradouro: 'R. Fernando Corrêa da Costa',
  bairro: 'Vila Operária',
  cidade: 'Rondonópolis',
  uf: 'MT',
);

/// Cartão da lista pelo selo (`Proposta nova` é a p1; `Pedido novo`, a p2).
Finder cartao(String selo) => find.ancestor(
  of: find.text(selo),
  matching: find.byType(CartaoPropostaLoja),
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

      testWidgets('produtos mostra atualizar pelo santri para quem gere', (
        tester,
      ) async {
        preparar();
        final hoje = DateTime.now();
        LojaService.instance.definirParaTeste(
          loja: minhaLoja,
          dados: DadosLoja(
            cnpj: '11222333000181',
            estoqueAtualizadoEm: DateTime(
              hoje.year,
              hoje.month,
              hoje.day,
              7,
              30,
            ),
          ),
        );
        await abrir(tester, const ProdutosScreen(), escuro: escuro);
        expect(find.byTooltip('Atualizar pelo Santri'), findsOneWidget);
        expect(
          find.text('Estoque atualizado pelo Santri às 07:30'),
          findsOneWidget,
        );

        preparar();
        await abrir(tester, const ProdutosScreen(), escuro: escuro);
        expect(
          find.text('Estoque ainda não atualizado pelo Santri'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Atualizar pelo Santri'));
        await tester.pumpAndSettle();
        expect(find.byType(AtualizarEstoqueScreen), findsOneWidget);
      });

      testWidgets('vendedor não vê atualizar pelo santri', (tester) async {
        preparar(papel: PapelLoja.vendedor);
        await abrir(tester, const ProdutosScreen(), escuro: escuro);
        expect(find.byTooltip('Atualizar pelo Santri'), findsNothing);
        expect(find.textContaining('pelo Santri'), findsNothing);
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

      testWidgets('pedido mostra os dados para a nota', (tester) async {
        preparar(
          propostas: [
            proposta(
              'p3',
              status: StatusProposta.aceita,
              pedido: PedidoResumo(
                id: 'ped1',
                status: StatusPedido.confirmado,
                total: 500,
                criadoEm: DateTime.now(),
                pagador: Pagador.cliente,
                pagadorNome: 'Ana Paula',
                pagadorWhatsapp: '66999990000',
                linkCodigo: 'COD',
                documentoInformadoEm: DateTime.now(),
              ),
            ),
          ],
          documentos: {'ped1': '52998224725'},
        );
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        await rolarAte(tester, find.text('529.982.247-25'));
        expect(find.text('Dados para a nota'), findsOneWidget);
        expect(find.text('Cliente do construtor'), findsOneWidget);
        expect(find.text('Ana Paula'), findsOneWidget);
        expect(find.text('529.982.247-25'), findsOneWidget);

        preparar(
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
        await rolarAte(
          tester,
          find.text('O construtor ainda não escolheu quem paga.'),
        );
        expect(
          find.text('O construtor ainda não escolheu quem paga.'),
          findsOneWidget,
        );
      });

      testWidgets('aviso de pagamento informado', (tester) async {
        final hoje = DateTime.now();
        final informado = DateTime(hoje.year, hoje.month, hoje.day, 14, 32);
        PedidoResumo pedidoInformado({DateTime? confirmado}) => PedidoResumo(
          id: 'ped1',
          status: StatusPedido.confirmado,
          total: 500,
          criadoEm: DateTime(hoje.year, hoje.month, hoje.day, 9),
          pagador: Pagador.cliente,
          pagadorNome: 'Ana Paula',
          documentoInformadoEm: DateTime(hoje.year, hoje.month, hoje.day, 14),
          pagamentoInformadoEm: informado,
          pagamentoConfirmadoEm: confirmado,
        );
        preparar(
          propostas: [
            proposta(
              'p3',
              status: StatusProposta.aceita,
              pedido: pedidoInformado(),
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        expect(
          find.text('Cliente informou o pagamento às 14:32, confira no banco.'),
          findsOneWidget,
        );

        preparar(
          propostas: [
            proposta(
              'p3',
              status: StatusProposta.aceita,
              pedido: pedidoInformado(confirmado: hoje),
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        expect(
          find.textContaining('Cliente informou o pagamento'),
          findsNothing,
        );
      });

      testWidgets('aviso de pagamento de outro dia mostra a data', (
        tester,
      ) async {
        final d = DateTime.now().subtract(const Duration(days: 3));
        String dois(int n) => n.toString().padLeft(2, '0');
        preparar(
          propostas: [
            proposta(
              'p3',
              status: StatusProposta.aceita,
              pedido: PedidoResumo(
                id: 'ped1',
                status: StatusPedido.confirmado,
                total: 500,
                criadoEm: d,
                pagador: Pagador.cliente,
                pagadorNome: 'Ana Paula',
                documentoInformadoEm: d,
                pagamentoInformadoEm: d,
              ),
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        expect(
          find.text(
            'Cliente informou o pagamento em ${dois(d.day)}/${dois(d.month)} às ${dois(d.hour)}:${dois(d.minute)}, confira no banco.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('pagamento pelo cliente explica o pix no painel', (
        tester,
      ) async {
        preparar(
          propostas: [
            proposta(
              'p3',
              status: StatusProposta.aceita,
              pedido: PedidoResumo(
                id: 'ped1',
                status: StatusPedido.confirmado,
                total: 500,
                criadoEm: DateTime.now(),
                pagador: Pagador.cliente,
                pagadorNome: 'Ana Paula',
                linkCodigo: 'COD',
              ),
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        const texto =
            'O cliente do construtor paga por PIX direto à loja. Confirme aqui quando receber.';
        await rolarAte(tester, find.text(texto));
        expect(find.text(texto), findsOneWidget);
        expect(
          find.text('Combine com o construtor e confirme aqui quando receber.'),
          findsNothing,
        );
      });

      testWidgets('pedido mostra a forma de pagamento', (tester) async {
        preparar(propostas: [comForma(FormaPagamento.cartao)]);
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        await rolarAte(tester, find.text('Cartão na loja'));
        expect(find.text('Cartão na loja'), findsOneWidget);

        preparar(
          propostas: [
            comForma(
              FormaPagamento.crediario,
              prazo: '28/35',
              prazoStatus: StatusPrazo.aprovado,
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        await rolarAte(tester, find.text('Prazo aprovado.'));
        expect(find.text('Crediário: 28/35 dias'), findsOneWidget);
        expect(find.text('Prazo aprovado.'), findsOneWidget);
        expect(find.text('Aprovar prazo'), findsNothing);
      });

      testWidgets('gerente aprova ou recusa o prazo', (tester) async {
        preparar(
          propostas: [
            comForma(
              FormaPagamento.crediario,
              prazo: '28',
              prazoStatus: StatusPrazo.pendente,
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        await rolarAte(tester, find.text('Aprovar prazo'));
        expect(find.text('Crediário: 28 dias'), findsOneWidget);
        await tester.tap(find.text('Aprovar prazo'));
        await tester.pumpAndSettle();
        expect(PropostasLojaService.instance.prazosDeTeste, [('ped1', true)]);
        await rolarAte(tester, find.text('Recusar'));
        await tester.tap(find.text('Recusar'));
        await tester.pumpAndSettle();
        expect(PropostasLojaService.instance.prazosDeTeste, [
          ('ped1', true),
          ('ped1', false),
        ]);
      });

      testWidgets('vendedor não responde ao prazo', (tester) async {
        preparar(
          papel: PapelLoja.vendedor,
          propostas: [
            comForma(
              FormaPagamento.crediario,
              prazo: '28',
              prazoStatus: StatusPrazo.pendente,
            ),
          ],
        );
        await abrir(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          escuro: escuro,
        );
        const aguardando = 'Aguardando o gerente aprovar o prazo.';
        await rolarAte(tester, find.text(aguardando));
        expect(find.text(aguardando), findsOneWidget);
        expect(find.text('Aprovar prazo'), findsNothing);
        expect(find.text('Recusar'), findsNothing);
      });

      testWidgets('lista mostra prazo para aprovar', (tester) async {
        preparar(
          propostas: [
            proposta('p1'),
            comForma(
              FormaPagamento.crediario,
              prazo: '28',
              prazoStatus: StatusPrazo.pendente,
            ),
          ],
        );
        await abrir(tester, const PropostasScreen(), escuro: escuro);
        await tester.ensureVisible(find.textContaining('Pedidos'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Pedidos'));
        await tester.pumpAndSettle();
        expect(find.text('Prazo para aprovar'), findsOneWidget);
        expect(find.text('Confirmado'), findsNothing);
      });

      testWidgets('propostas no computador abrem ao lado', (tester) async {
        preparar();
        await abrirLargura(
          tester,
          const PropostasScreen(),
          1366,
          escuro: escuro,
        );
        expect(find.text('Escolha uma proposta ou pedido'), findsOneWidget);
        await tester.tap(find.byType(CartaoPropostaLoja).first);
        await tester.pumpAndSettle();
        expect(find.byType(PropostaLojaScreen), findsOneWidget);
        expect(find.text('Escolha uma proposta ou pedido'), findsNothing);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Recusar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('pedido aberto ao lado tem as ações no pé', (tester) async {
        preparar();
        await abrirLargura(
          tester,
          const PropostasScreen(),
          1366,
          escuro: escuro,
        );
        await tester.tap(find.textContaining('Pedidos'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CartaoPropostaLoja).first);
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, 'Marcar como em separação'),
          findsOneWidget,
        );
        expect(find.byType(AppBar), findsOneWidget);
        // A lista continua na tela: o pedido abriu ao lado, não por cima
        expect(find.byType(PropostasScreen), findsOneWidget);
      });

      testWidgets('aceitar abre o pedido na mesma coluna', (tester) async {
        preparar();
        await abrirLargura(
          tester,
          const PropostasScreen(),
          1366,
          escuro: escuro,
        );
        await tester.tap(cartao('Proposta nova').first);
        await tester.pumpAndSettle();
        preparar(
          propostas: [
            proposta(
              'p1',
              status: StatusProposta.aceita,
              pedido: pedido(StatusPedido.confirmado),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.byType(PedidoLojaScreen), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Marcar como em separação'),
          findsOneWidget,
        );
      });

      testWidgets('proposta que some da lista volta ao aviso', (tester) async {
        preparar();
        await abrirLargura(
          tester,
          const PropostasScreen(),
          1366,
          escuro: escuro,
        );
        await tester.tap(cartao('Proposta nova').first);
        await tester.pumpAndSettle();
        preparar(propostas: [proposta('p2', modo: ModoProposta.pedido)]);
        await tester.pumpAndSettle();
        expect(find.text('Escolha uma proposta ou pedido'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('no celular a proposta abre em tela cheia', (tester) async {
        preparar();
        await abrir(tester, const PropostasScreen(), escuro: escuro);
        await tester.tap(cartao('Proposta nova').first);
        await tester.pumpAndSettle();
        expect(find.byType(PropostaLojaScreen), findsOneWidget);
        expect(find.byType(PropostasScreen), findsNothing);
      });

      testWidgets('tela aberta por cima fica numa coluna no computador', (
        tester,
      ) async {
        preparar();
        await abrirLargura(
          tester,
          const PedidoLojaScreen(pedidoId: 'ped1'),
          1366,
          escuro: escuro,
        );
        expect(
          tester.getSize(find.byType(ListView).first).width,
          lessThanOrEqualTo(760),
        );
        expect(
          tester
              .getSize(
                find.widgetWithText(FilledButton, 'Marcar como em separação'),
              )
              .width,
          lessThanOrEqualTo(760),
        );
      });

      testWidgets('oferta e importação ficam numa coluna no computador', (
        tester,
      ) async {
        preparar();
        await abrirLargura(
          tester,
          OfertaScreen(itemId: 'cimento-cp2-50kg', salvar: (_) async {}),
          1366,
          escuro: escuro,
        );
        expect(
          tester.getSize(find.byType(ListView).first).width,
          lessThanOrEqualTo(760),
        );
        expect(
          tester
              .getSize(find.widgetWithText(FilledButton, 'Salvar preço'))
              .width,
          lessThanOrEqualTo(760),
        );
        await abrirLargura(
          tester,
          ImportarPlanilhaScreen(escolher: () async => null),
          1366,
          escuro: escuro,
        );
        expect(
          tester.getSize(find.byType(ListView).first).width,
          lessThanOrEqualTo(760),
        );
      });

      testWidgets('minha loja salva a chave pix', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        preparar();
        await abrir(tester, MinhaLojaScreen(tema: tema), escuro: escuro);
        final campo = find.byKey(const ValueKey('chave-pix'));
        await rolarAte(tester, campo);
        await tester.enterText(campo, '66999990000');
        await rolarAte(tester, find.text('Salvar dados'));
        await tester.tap(find.text('Salvar dados'));
        await tester.pump();
        expect(
          find.text(
            'Chave PIX inválida. Use CPF, CNPJ, e-mail, celular com +55 ou chave aleatória.',
          ),
          findsOneWidget,
        );
        expect(LojaService.instance.atualizacoesDeTeste, isEmpty);
        expect(LojaService.instance.chavesDeTeste, isEmpty);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await rolarAte(tester, campo);
        await tester.enterText(campo, '+5566999990000');
        await rolarAte(tester, find.text('Salvar dados'));
        await tester.tap(find.text('Salvar dados'));
        await tester.pumpAndSettle();
        // A chave vai para loja_pix (só a equipe lê), não para a linha da loja
        expect(LojaService.instance.chavesDeTeste, ['+5566999990000']);
        expect(
          LojaService.instance.atualizacoesDeTeste.single.containsKey(
            'chave_pix',
          ),
          isFalse,
        );
      });

      testWidgets('minha loja mostra a chave pix salva', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        preparar();
        LojaService.instance.definirParaTeste(
          loja: minhaLoja,
          dados: const DadosLoja(
            cnpj: '11222333000181',
            chavePix: '+5566999990000',
          ),
        );
        await abrir(tester, MinhaLojaScreen(tema: tema), escuro: escuro);
        await rolarAte(tester, find.byKey(const ValueKey('chave-pix')));
        expect(find.text('+5566999990000'), findsOneWidget);
      });

      testWidgets('chave pix com pontuação é salva só com números', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        preparar();
        await abrir(tester, MinhaLojaScreen(tema: tema), escuro: escuro);
        final campo = find.byKey(const ValueKey('chave-pix'));
        await rolarAte(tester, campo);
        await tester.enterText(campo, '11.222.333/0001-81');
        await rolarAte(tester, find.text('Salvar dados'));
        await tester.tap(find.text('Salvar dados'));
        await tester.pumpAndSettle();
        expect(LojaService.instance.chavesDeTeste, ['11222333000181']);
      });

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

      testWidgets('minha loja salva endereço e horário', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        preparar();
        LojaService.instance.definirParaTeste(
          loja: minhaLoja,
          dados: const DadosLoja(
            cnpj: '11222333000181',
            endereco: 'Lojas Vila Operária (matriz)',
            horario: 'Seg a sex 7h às 18h',
          ),
        );
        await abrir(
          tester,
          MinhaLojaScreen(tema: tema, buscarCep: buscarCepFalso),
          escuro: escuro,
        );
        const atual = 'Endereço atual: Lojas Vila Operária (matriz)';
        await rolarAte(tester, find.text(atual));
        expect(find.text(atual), findsOneWidget);
        await rolarAte(tester, campoDoEndereco('cep'));
        await tester.enterText(campoDoEndereco('cep'), '78700000');
        await tester.pumpAndSettle();
        await tester.enterText(campoDoEndereco('numero'), '1500');
        await rolarAte(tester, find.byKey(const Key('horario-6')));
        await tester.tap(find.byKey(const Key('horario-6')));
        await tester.pumpAndSettle();
        await rolarAte(tester, find.text('Salvar dados'));
        await tester.tap(find.text('Salvar dados'));
        await tester.pumpAndSettle();
        final enviado = LojaService.instance.atualizacoesDeTeste.single;
        expect(enviado['cep'], '78700000');
        expect(enviado['logradouro'], 'R. Fernando Corrêa da Costa');
        expect(enviado['numero'], '1500');
        expect(enviado['cidade'], 'Rondonópolis');
        expect(enviado['uf'], 'MT');
        expect(enviado['horario'], 'Seg a sex 7h às 18h; sáb 8h às 18h');
        expect(enviado.containsKey('endereco'), isFalse);
      });

      testWidgets('loja antiga salva sem mexer no endereço nem no horário', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        preparar();
        LojaService.instance.definirParaTeste(
          loja: minhaLoja,
          dados: const DadosLoja(
            cnpj: '11222333000181',
            endereco: 'Lojas Vila Operária (matriz)',
            horario: 'Comercial',
          ),
        );
        await abrir(
          tester,
          MinhaLojaScreen(tema: tema, buscarCep: buscarCepFalso),
          escuro: escuro,
        );
        final sobre = find.descendant(
          of: find.widgetWithText(CampoTexto, 'Sobre a loja'),
          matching: find.byType(TextField),
        );
        await rolarAte(tester, sobre);
        await tester.enterText(sobre, 'Materiais de construção');
        await rolarAte(tester, find.text('Salvar dados'));
        await tester.tap(find.text('Salvar dados'));
        await tester.pumpAndSettle();
        final enviado = LojaService.instance.atualizacoesDeTeste.single;
        expect(enviado['descricao'], 'Materiais de construção');
        for (final campo in ['cep', 'logradouro', 'endereco', 'horario']) {
          expect(enviado.containsKey(campo), isFalse, reason: campo);
        }
      });

      testWidgets('minha loja abre com o endereço em campos', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        preparar();
        LojaService.instance.definirParaTeste(
          loja: minhaLoja,
          dados: const DadosLoja(
            cnpj: '11222333000181',
            endereco: 'R. Fernando Corrêa da Costa, 1500 – Vila Operária, CEP 78700-000',
            cep: '78700000',
            logradouro: 'R. Fernando Corrêa da Costa',
            numero: '1500',
            bairro: 'Vila Operária',
          ),
        );
        await abrir(
          tester,
          MinhaLojaScreen(tema: tema, buscarCep: buscarCepFalso),
          escuro: escuro,
        );
        await rolarAte(tester, campoDoEndereco('cep'));
        expect(find.textContaining('Endereço atual'), findsNothing);
        String valor(String nome) =>
            tester.widget<TextField>(campoDoEndereco(nome)).controller!.text;
        expect(valor('cep'), '78700-000');
        expect(valor('rua'), 'R. Fernando Corrêa da Costa');
        expect(valor('numero'), '1500');
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
