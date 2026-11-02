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
}) => PedidoResumo(
  id: 'ped1',
  status: StatusPedido.confirmado,
  total: 450,
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
          pix: () async => pix,
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
    });
  }
}
