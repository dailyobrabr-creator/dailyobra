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
}

const pixDaLoja =
    '00020126360014br.gov.bcb.pix0114+55669999900005204000053039865406450.005802BR';

PedidoResumo pedido({
  Pagador? pagador,
  String? link,
  DateTime? documento,
  DateTime? informado,
  double total = 450,
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
);

Future<Chamadas> montar(
  WidgetTester tester, {
  required bool escuro,
  PedidoResumo? p,
  String? pix = pixDaLoja,
  Future<String?> Function()? carregarPix,
  String? documentoDoPerfil,
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
          documentoDoPerfil: documentoDoPerfil,
          pix: carregarPix ?? () async => pix,
          pagarEuMesmo: (doc) async => ch.documentos.add(doc),
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
                documentoDoPerfil: null,
                pix: () async => pixDaLoja,
                pagarEuMesmo: (_) async {},
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
    });
  }
}
