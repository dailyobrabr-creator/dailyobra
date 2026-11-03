import 'package:dailyobra/screens/quem_paga.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

/// O que a tela pediu às funções falsas.
class Chamadas {
  final documentos = <String>[];
  final links = <(String, String)>[];
  final abertos = <Uri>[];
  final saldos = <bool>[];
  final formas = <(FormaPagamento, String?)>[];
}

const pixDaLoja =
    '00020126360014br.gov.bcb.pix0114+55669999900005204000053039865406450.005802BR';

PedidoResumo pedido({
  Pagador? pagador,
  String? link,
  DateTime? documento,
  DateTime? informado,
  double total = 450,
  FormaPagamento? forma,
  String? prazo,
  StatusPrazo? prazoStatus,
}) => PedidoResumo(
  id: 'ped1',
  status: StatusPedido.confirmado,
  total: total,
  criadoEm: DateTime(2026, 11, 2),
  pagador: pagador,
  pagadorNome: pagador == Pagador.cliente ? 'Ana' : null,
  pagadorWhatsapp: pagador == Pagador.cliente ? '66999990000' : null,
  linkCodigo: link,
  documentoInformadoEm: documento,
  pagamentoInformadoEm: informado,
  formaPagamento: forma,
  prazo: prazo,
  prazoStatus: prazoStatus,
);

/// Pedido no "Eu pago" com o documento já confirmado.
PedidoResumo euPago({
  double total = 450,
  FormaPagamento? forma,
  String? prazo,
  StatusPrazo? prazoStatus,
}) => pedido(
  pagador: Pagador.proprio,
  documento: DateTime(2026, 11, 2),
  total: total,
  forma: forma,
  prazo: prazo,
  prazoStatus: prazoStatus,
);

Future<Chamadas> montar(
  WidgetTester tester, {
  required bool escuro,
  PedidoResumo? p,
  String? pix = pixDaLoja,
  Future<String?> Function()? carregarPix,
  String? documentoDoPerfil,
  double saldoDisponivel = 0,
  double saldoNoPedido = 0,
}) async {
  final ch = Chamadas();
  await abrir(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: QuemPaga(
          key: UniqueKey(),
          pedido: p ?? pedido(),
          nomeLoja: 'Casa do Construtor',
          nomeTitular: 'Marcos Silva',
          documentoDoPerfil: documentoDoPerfil,
          saldoDisponivel: saldoDisponivel,
          saldoNoPedido: saldoNoPedido,
          pix: carregarPix ?? () async => pix,
          pagarEuMesmo: (doc) async => ch.documentos.add(doc),
          usarSaldo: (usar) async => ch.saldos.add(usar),
          escolherPagamento: (forma, prazo) async =>
              ch.formas.add((forma, prazo)),
          criarLink: (nome, zap) async {
            ch.links.add((nome, zap));
            return 'COD';
          },
          abrirLink: (uri) async => ch.abertos.add(uri),
        ),
      ),
    ),
    escuro: escuro,
  );
  return ch;
}

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('eu pago pede o documento e mostra o pix', (tester) async {
        final ch = await montar(tester, escuro: escuro);
        expect(find.text('Quem paga este pedido?'), findsOneWidget);
        await tester.tap(find.text('Eu pago'));
        await tester.pumpAndSettle();
        expect(find.text('CPF ou CNPJ'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('documento')),
          '111.111.111-11',
        );
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(
          find.text('CPF ou CNPJ inválido. Confira os números.'),
          findsOneWidget,
        );
        expect(ch.documentos, isEmpty);
        await tester.enterText(
          find.byKey(const ValueKey('documento')),
          '529.982.247-25',
        );
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(ch.documentos, ['52998224725']);
        expect(find.text('PIX da loja (copia e cola)'), findsOneWidget);
        expect(find.text(pixDaLoja), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Copiar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('pedido já com eu pago mostra o pix sem pedir de novo', (
        tester,
      ) async {
        final ch = await montar(
          tester,
          escuro: escuro,
          p: pedido(pagador: Pagador.proprio, documento: DateTime(2026, 11, 2)),
        );
        expect(find.text(pixDaLoja), findsOneWidget);
        expect(find.byKey(const ValueKey('documento')), findsNothing);
        expect(ch.documentos, isEmpty);
      });

      testWidgets('enviar para o cliente abre o whatsapp', (tester) async {
        final ch = await montar(tester, escuro: escuro);
        await tester.tap(find.text('Enviar para o cliente'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('cliente-nome')),
          'Ana',
        );
        await tester.enterText(
          find.byKey(const ValueKey('cliente-whatsapp')),
          '(66) 99999-0000',
        );
        await tester.tap(find.text('Enviar pelo WhatsApp'));
        await tester.pumpAndSettle();
        expect(ch.links, [('Ana', '66999990000')]);
        final esperado = linkWhatsApp(
          '66999990000',
          mensagemDoLink(
            nome: 'Ana',
            loja: 'Casa do Construtor',
            total: 450,
            link: linkDePagamento('COD'),
          ),
        );
        expect(ch.abertos, [esperado]);
        expect(
          ch.abertos.single.toString(),
          startsWith('https://wa.me/5566999990000?text='),
        );
        expect(
          find.text('Link enviado. Aguardando o cliente informar os dados.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('situações do link e reenviar', (tester) async {
        final casos = [
          (
            pedido(pagador: Pagador.cliente, link: 'COD'),
            'Link enviado. Aguardando o cliente informar os dados.',
          ),
          (
            pedido(
              pagador: Pagador.cliente,
              link: 'COD',
              documento: DateTime(2026, 11, 2, 13),
            ),
            'Aguardando o pagamento do cliente.',
          ),
          (
            pedido(
              pagador: Pagador.cliente,
              link: 'COD',
              documento: DateTime(2026, 11, 2, 13),
              informado: DateTime(2026, 11, 2, 14, 32),
            ),
            'O cliente avisou que pagou. A loja vai conferir.',
          ),
        ];
        for (final (p, texto) in casos) {
          final ch = await montar(tester, escuro: escuro, p: p);
          expect(find.text(texto), findsOneWidget);
          expect(find.text('Trocar cliente'), findsOneWidget);
          await tester.tap(find.text('Reenviar link'));
          await tester.pumpAndSettle();
          expect(ch.links, isEmpty);
          expect(
            ch.abertos.single.toString(),
            contains(Uri.encodeComponent(linkDePagamento('COD'))),
          );
        }
      });

      testWidgets('loja sem chave pix', (tester) async {
        final ch = await montar(
          tester,
          escuro: escuro,
          pix: null,
          documentoDoPerfil: '52998224725',
        );
        final chip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Enviar para o cliente'),
        );
        expect(chip.onSelected, isNull);
        expect(
          find.text('A loja ainda não cadastrou a chave PIX.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Eu pago'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(ch.documentos, ['52998224725']);
        expect(find.text('Combine o pagamento com a loja.'), findsOneWidget);
      });

      testWidgets('falha ao buscar o pix mostra tentar de novo', (
        tester,
      ) async {
        var tentativas = 0;
        await montar(
          tester,
          escuro: escuro,
          carregarPix: () async {
            if (++tentativas == 1) {
              throw const FalhaComMensagem(
                'Sem conexão. Confira a internet e tente de novo.',
              );
            }
            return pixDaLoja;
          },
        );
        expect(
          find.text('Não deu para carregar o PIX da loja.'),
          findsOneWidget,
        );
        expect(
          find.text('A loja ainda não cadastrou a chave PIX.'),
          findsNothing,
        );
        await tester.tap(find.text('Tentar de novo'));
        await tester.pumpAndSettle();
        expect(tentativas, 2);
        final chip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Enviar para o cliente'),
        );
        expect(chip.onSelected, isNotNull);
      });

      testWidgets('trocar para eu pago depois do link pede confirmação', (
        tester,
      ) async {
        Future<Chamadas> trocar(PedidoResumo p) async {
          final ch = await montar(
            tester,
            escuro: escuro,
            p: p,
            documentoDoPerfil: '52998224725',
          );
          await tester.tap(find.text('Eu pago'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Confirmar'));
          await tester.pumpAndSettle();
          return ch;
        }

        // O cliente já tocou em "Já paguei": avisa do risco de pagar duas vezes
        var ch = await trocar(
          pedido(
            pagador: Pagador.cliente,
            link: 'COD',
            documento: DateTime(2026, 11, 2, 13),
            informado: DateTime(2026, 11, 2, 14, 32),
          ),
        );
        expect(find.text('O cliente já avisou que pagou'), findsOneWidget);
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
        expect(ch.documentos, isEmpty);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trocar para Eu pago'));
        await tester.pumpAndSettle();
        expect(ch.documentos, ['52998224725']);

        // Link enviado e ainda sem aviso: o link do cliente para de funcionar
        ch = await trocar(pedido(pagador: Pagador.cliente, link: 'COD'));
        expect(find.text('Trocar para "Eu pago"?'), findsOneWidget);
        expect(
          find.text('O link enviado para Ana vai parar de funcionar.'),
          findsOneWidget,
        );
      });

      testWidgets('pedido que muda em outro aparelho atualiza a tela', (
        tester,
      ) async {
        Future<void> com(PedidoResumo p) => abrir(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: QuemPaga(
                key: const ValueKey('quem-paga'),
                pedido: p,
                nomeLoja: 'Casa do Construtor',
                nomeTitular: 'Marcos Silva',
                documentoDoPerfil: null,
                saldoDisponivel: 0,
                saldoNoPedido: 0,
                pix: () async => pixDaLoja,
                pagarEuMesmo: (_) async {},
                usarSaldo: (_) async {},
                escolherPagamento: (_, _) async {},
                criarLink: (_, _) async => 'COD',
                abrirLink: (_) async {},
              ),
            ),
          ),
          escuro: escuro,
        );
        await com(pedido());
        expect(find.text(pixDaLoja), findsNothing);
        await com(
          pedido(pagador: Pagador.proprio, documento: DateTime(2026, 11, 2)),
        );
        expect(find.text(pixDaLoja), findsOneWidget);
        await com(pedido(pagador: Pagador.cliente, link: 'COD'));
        expect(
          find.text('Link enviado. Aguardando o cliente informar os dados.'),
          findsOneWidget,
        );
      });

      testWidgets('pedido coberto pelo saldo não tem nada a pagar', (
        tester,
      ) async {
        final ch = await montar(
          tester,
          escuro: escuro,
          p: pedido(total: 0),
          pix: null,
          documentoDoPerfil: '52998224725',
        );
        expect(
          find.text(
            'O saldo DailyObra cobriu este pedido. Não há nada a pagar.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('A loja ainda não cadastrou a chave PIX.'),
          findsNothing,
        );
        final chip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Enviar para o cliente'),
        );
        expect(chip.onSelected, isNull);
        await tester.tap(find.text('Eu pago'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(ch.documentos, ['52998224725']);
        expect(find.text('Combine o pagamento com a loja.'), findsNothing);
        expect(find.text('A nota sai no seu nome.'), findsWidgets);
      });

      testWidgets('eu pago mostra o titular da nota', (tester) async {
        await montar(
          tester,
          escuro: escuro,
          p: euPago(),
          documentoDoPerfil: '52998224725',
        );
        expect(find.text('Nota no nome de Marcos Silva'), findsOneWidget);
        expect(find.text('529.982.247-25'), findsOneWidget);
        await tester.tap(find.text('Alterar'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('documento')), findsOneWidget);
      });

      testWidgets('interruptor do saldo', (tester) async {
        final titulo = 'Usar saldo da carteira (${brl.format(30)})';
        var ch = await montar(
          tester,
          escuro: escuro,
          p: euPago(),
          saldoDisponivel: 30,
        );
        expect(find.text(titulo), findsOneWidget);
        await tester.tap(find.text(titulo));
        await tester.pumpAndSettle();
        expect(ch.saldos, [true]);

        ch = await montar(
          tester,
          escuro: escuro,
          p: euPago(total: 420),
          saldoNoPedido: 30,
        );
        expect(
          find.text('Abate ${brl.format(30)} neste pedido.'),
          findsOneWidget,
        );
        await tester.tap(find.text(titulo));
        await tester.pumpAndSettle();
        expect(ch.saldos, [false]);

        await montar(tester, escuro: escuro, p: euPago());
        expect(find.textContaining('Usar saldo da carteira'), findsNothing);
      });

      testWidgets('formas de pagamento', (tester) async {
        final ch = await montar(tester, escuro: escuro, p: euPago());
        await rolarAte(tester, find.text('Cartão na loja'));
        await tester.tap(find.text('Cartão na loja'));
        await tester.pumpAndSettle();
        expect(ch.formas, [(FormaPagamento.cartao, null)]);
        expect(
          find.text('Pague na maquininha da loja na entrega ou retirada.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Crediário da loja'));
        await tester.pumpAndSettle();
        expect(ch.formas, hasLength(1));
        expect(find.text('28 dias'), findsOneWidget);
        expect(find.text('28/35 dias'), findsOneWidget);
        expect(find.text('28/35/42 dias'), findsOneWidget);
        await rolarAte(tester, find.text('28/35 dias'));
        await tester.tap(find.text('28/35 dias'));
        await tester.pumpAndSettle();
        await rolarAte(tester, find.text('Pedir prazo'));
        await tester.tap(find.text('Pedir prazo'));
        await tester.pumpAndSettle();
        expect(ch.formas.last, (FormaPagamento.crediario, '28/35'));
      });

      testWidgets('estados do prazo', (tester) async {
        final casos = [
          (StatusPrazo.pendente, 'Aguardando a loja aprovar o prazo.'),
          (StatusPrazo.aprovado, 'Prazo aprovado: 28/35/42 dias.'),
          (
            StatusPrazo.recusado,
            'A loja recusou o prazo. Escolha PIX ou cartão.',
          ),
        ];
        for (final (status, texto) in casos) {
          await montar(
            tester,
            escuro: escuro,
            p: euPago(
              forma: FormaPagamento.crediario,
              prazo: '28/35/42',
              prazoStatus: status,
            ),
          );
          expect(find.text(texto), findsOneWidget);
        }
      });

      testWidgets('total a pagar e PIX novo quando o total muda', (
        tester,
      ) async {
        var buscas = 0;
        Future<void> com(double total) => abrir(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: QuemPaga(
                key: const ValueKey('quem-paga'),
                pedido: euPago(total: total),
                nomeLoja: 'Casa do Construtor',
                nomeTitular: 'Marcos Silva',
                documentoDoPerfil: '52998224725',
                saldoDisponivel: 0,
                saldoNoPedido: 0,
                pix: () async {
                  buscas++;
                  return pixDaLoja;
                },
                pagarEuMesmo: (_) async {},
                usarSaldo: (_) async {},
                escolherPagamento: (_, _) async {},
                criarLink: (_, _) async => 'COD',
                abrirLink: (_) async {},
              ),
            ),
          ),
          escuro: escuro,
        );
        await com(450);
        expect(find.text('Total a pagar'), findsOneWidget);
        expect(find.text(brl.format(450)), findsOneWidget);
        await com(420);
        expect(buscas, 2);
        expect(find.text(brl.format(420)), findsOneWidget);
      });

      testWidgets('saldo cobriu o pedido', (tester) async {
        await montar(
          tester,
          escuro: escuro,
          p: euPago(total: 0),
          pix: null,
          saldoNoPedido: 80,
        );
        expect(
          find.text(
            'O saldo DailyObra cobriu este pedido. Não há nada a pagar.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Abate ${brl.format(80)} neste pedido.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(ChoiceChip, 'PIX'), findsNothing);
      });
    });
  }
}
