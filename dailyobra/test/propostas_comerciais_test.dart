import 'dart:convert';
import 'dart:typed_data';

import 'package:dailyobra/screens/obra_form_screen.dart';
import 'package:dailyobra/screens/propostas_comerciais_screen.dart';
import 'package:dailyobra/services/marca_service.dart';
import 'package:dailyobra/services/pdf_proposta.dart';
import 'package:dailyobra/services/propostas_comerciais_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart' hide hoje;

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final hojeFixo = DateTime(2026, 11, 5);

const pronta = PropostaComercial(
  id: 'p1',
  numero: 7,
  cliente: 'Dona Lia',
  titulo: 'Residência Silva',
  area: 120,
  itens: [
    ItemComercial(descricao: 'Fundação', valor: 10000),
    ItemComercial(descricao: 'Alvenaria', valor: 20000),
  ],
  parcelas: [
    ParcelaComercial(descricao: 'Entrada', percentual: 40),
    ParcelaComercial(descricao: 'Final', percentual: 60, dias: 90),
  ],
);

PropostaComercial situacao(SituacaoComercial s, {String? obraId}) =>
    PropostaComercial(
      id: 'p2',
      numero: 8,
      cliente: 'Seu Zé',
      titulo: 'Reforma',
      itens: const [ItemComercial(descricao: 'Pintura', valor: 5000)],
      situacao: s,
      obraId: obraId,
    );

void preparar({List<PropostaComercial> propostas = const [], String? erro}) {
  PropostasComerciaisService.instance.definirParaTeste(
    propostas: propostas,
    erro: erro,
  );
  MarcaService.instance.definirParaTeste();
}

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

/// O rótulo de campo obrigatório vem com " *": procura pelo próprio campo.
Finder campo(String rotulo) => find.descendant(
  of: find.byWidgetPredicate((w) => w is CampoTexto && w.rotulo == rotulo),
  matching: find.byType(TextField),
);

Future<void> escrever(WidgetTester tester, String rotulo, String texto) async {
  await tester.ensureVisible(campo(rotulo));
  await tester.pumpAndSettle();
  await tester.enterText(campo(rotulo), texto);
  await tester.pumpAndSettle();
}

Future<void> abrirLista(
  WidgetTester tester, {
  bool escuro = false,
  Future<void> Function(PropostaComercial)? enviarPdf,
  Future<String?> Function(PropostaComercial)? criarObra,
}) => abrir(
  tester,
  PropostasComerciaisScreen(
    hoje: hojeFixo,
    enviarPdf: enviarPdf,
    criarObra: criarObra,
  ),
  escuro: escuro,
);

Future<void> preencher(WidgetTester tester) async {
  await tocar(tester, find.text('Nova proposta'));
  await escrever(tester, 'Nome do cliente', ' Dona Lia ');
  await escrever(tester, 'Nome da obra ou do serviço', ' Casa ');
  await tocar(tester, find.text('Adicionar item'));
  await escrever(tester, 'Item 1', 'Fundação');
  await escrever(tester, 'Valor 1', '10.000');
}

void main() {
  final servico = PropostasComerciaisService.instance;

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('monta e salva a proposta', (tester) async {
        preparar();
        await abrirLista(tester, escuro: escuro);
        expect(find.text('Nenhuma proposta'), findsOneWidget);
        await tocar(tester, find.text('Nova proposta'));
        await tocar(tester, find.text('Salvar'));
        expect(find.text('Diga quem é o cliente.'), findsOneWidget);
        expect(find.text('Diga o nome da obra ou do serviço.'), findsOneWidget);
        expect(servico.salvasDeTeste, isEmpty);
        await escrever(tester, 'Nome do cliente', ' Dona Lia ');
        await escrever(tester, 'Nome da obra ou do serviço', ' Casa ');
        await tocar(tester, find.text('Adicionar item'));
        await escrever(tester, 'Item 1', 'Fundação');
        await escrever(tester, 'Valor 1', '10.000');
        await escrever(tester, 'Desconto (R\$)', '500');
        expect(find.text(brl.format(9500)), findsOneWidget);
        await tocar(tester, find.text('Salvar'));
        final p = servico.salvasDeTeste.single;
        expect(
          (p.cliente, p.titulo, p.subtotal, p.total),
          ('Dona Lia', 'Casa', 10000, 9500),
        );
        expect(p.validade, DateTime(2026, 11, 20));
        expect(find.text('Nº 1 · Casa'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('valor errado não vira zero', (tester) async {
        preparar();
        await abrirLista(tester, escuro: escuro);
        await preencher(tester);
        await escrever(tester, 'Valor 1', 'abc');
        await tocar(tester, find.text('Salvar'));
        expect(find.text('Confira os valores digitados.'), findsOneWidget);
        expect(servico.salvasDeTeste, isEmpty);
      });

      testWidgets('valor sem descrição não some', (tester) async {
        preparar();
        await abrirLista(tester, escuro: escuro);
        await preencher(tester);
        await escrever(tester, 'Item 1', ' ');
        await tocar(tester, find.text('Salvar'));
        expect(find.text('Dê um nome a cada item.'), findsOneWidget);
        expect(servico.salvasDeTeste, isEmpty);
      });

      testWidgets('tira um item', (tester) async {
        preparar();
        await abrirLista(tester, escuro: escuro);
        await preencher(tester);
        await tocar(tester, find.byTooltip('Tirar o item 1'));
        expect(campo('Item 1'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('usa a estimativa com acréscimo', (tester) async {
        preparar();
        await abrirLista(tester, escuro: escuro);
        await tocar(tester, find.text('Nova proposta'));
        await tocar(tester, find.text('Usar a estimativa do app'));
        expect(
          find.text('Usar a estimativa'),
          findsNothing,
          reason: 'sem área',
        );
        await escrever(tester, 'Área (m²)', '120');
        await tocar(tester, find.text('Usar a estimativa do app'));
        await escrever(tester, 'Acréscimo sobre a estimativa (%)', '10');
        await tocar(tester, find.text('Usar'));
        final etapas = Calculo.de(const ParametrosObra(area: '120'))
            .resultado!
            .etapas;
        expect(
          tester.widget<TextField>(campo('Item 1')).controller!.text,
          etapas.first.nome,
        );
        expect(
          lerNumero(
            tester.widget<TextField>(campo('Valor 1')).controller!.text,
          ),
          closeTo(etapas.first.total * 1.1, .01),
        );
        expect(campo('Item ${etapas.length}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('confere antes de gerar o PDF', (tester) async {
        preparar();
        final enviadas = <PropostaComercial>[];
        await abrirLista(
          tester,
          escuro: escuro,
          enviarPdf: (p) async => enviadas.add(p),
        );
        await tocar(tester, find.text('Nova proposta'));
        await escrever(tester, 'Nome do cliente', 'Dona Lia');
        await escrever(tester, 'Nome da obra ou do serviço', 'Casa');
        await tocar(tester, find.text('Gerar PDF'));
        expect(find.text('Adicione pelo menos um item.'), findsOneWidget);
        await tocar(tester, find.text('Adicionar item'));
        await escrever(tester, 'Item 1', 'Fundação');
        await escrever(tester, 'Valor 1', '1000');
        await tocar(tester, find.text('Adicionar parcela'));
        await escrever(tester, 'Parcela 1', 'Entrada');
        await escrever(tester, '% da parcela 1', '30');
        expect(find.text('30%'), findsOneWidget);
        await tocar(tester, find.text('Gerar PDF'));
        expect(find.text('As parcelas precisam somar 100%.'), findsOneWidget);
        expect(enviadas, isEmpty);
        await escrever(tester, '% da parcela 1', '100');
        await tocar(tester, find.text('Gerar PDF'));
        expect(enviadas.single.numero, 1);
        expect(find.text('Proposta nº 1'), findsOneWidget);
        expect(servico.salvasDeTeste, hasLength(1));
        await tocar(tester, find.text('Gerar PDF'));
        expect(servico.salvasDeTeste.last.id, isNotNull);
        expect(enviadas.last.numero, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('aceita vira obra e leva as parcelas', (tester) async {
        preparar(propostas: const [pronta]);
        final recebidas = <PropostaComercial>[];
        await abrirLista(
          tester,
          escuro: escuro,
          criarObra: (p) async {
            recebidas.add(p);
            return 'o9';
          },
        );
        await tocar(tester, find.text('Nº 7 · Residência Silva'));
        expect(find.text('Criar a obra'), findsNothing);
        await tocar(tester, find.text('Rascunho'));
        await tocar(tester, find.text('Aceita').last);
        await tocar(tester, find.text('Criar a obra'));
        expect(recebidas.single.situacao, SituacaoComercial.aceita);
        expect(servico.viraramObraDeTeste, [('p1', 'o9')]);
        expect(
          find.text('Obra criada. As parcelas estão no caixa da obra.'),
          findsOneWidget,
        );
        expect(find.text('Abrir a obra'), findsOneWidget);
        expect(find.text('Criar a obra'), findsNothing);
        expect(find.text('Salvar'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('desistir do cadastro não liga nada', (tester) async {
        preparar(propostas: [situacao(SituacaoComercial.aceita)]);
        await abrirLista(tester, escuro: escuro, criarObra: (_) async => null);
        await tocar(tester, find.text('Nº 8 · Reforma'));
        await tocar(tester, find.text('Criar a obra'));
        expect(servico.viraramObraDeTeste, isEmpty);
        expect(find.text('Criar a obra'), findsOneWidget);
      });

      testWidgets('recusada não vira obra', (tester) async {
        preparar(propostas: [situacao(SituacaoComercial.recusada)]);
        await abrirLista(tester, escuro: escuro);
        expect(find.text('Recusada'), findsOneWidget);
        await tocar(tester, find.text('Nº 8 · Reforma'));
        expect(find.text('Criar a obra'), findsNothing);
      });

      testWidgets('proposta que virou obra só consulta e gera PDF', (
        tester,
      ) async {
        preparar(propostas: [situacao(SituacaoComercial.aceita, obraId: 'o1')]);
        final enviadas = <PropostaComercial>[];
        await abrirLista(
          tester,
          escuro: escuro,
          enviarPdf: (p) async => enviadas.add(p),
        );
        await tocar(tester, find.text('Nº 8 · Reforma'));
        expect(find.textContaining('virou obra'), findsOneWidget);
        expect(find.text('Salvar'), findsNothing);
        await tocar(tester, find.text('Gerar PDF'));
        expect(enviadas, hasLength(1));
        expect(servico.salvasDeTeste, isEmpty);
      });

      testWidgets('marca a proposta vencida', (tester) async {
        preparar(
          propostas: [
            PropostaComercial(
              id: 'p3',
              numero: 9,
              cliente: 'a',
              titulo: 'Antiga',
              validade: DateTime(2026, 10, 1),
              situacao: SituacaoComercial.enviada,
            ),
          ],
        );
        await abrirLista(tester, escuro: escuro);
        expect(find.text('Vencida'), findsOneWidget);
      });

      testWidgets('escolhe mostrar só o total', (tester) async {
        preparar(propostas: const [pronta]);
        await abrirLista(tester, escuro: escuro);
        await tocar(tester, find.text('Nº 7 · Residência Silva'));
        await tocar(tester, find.text('Mostrar o valor de cada item'));
        await tocar(tester, find.text('Salvar'));
        expect(servico.salvasDeTeste.single.mostrarValores, isFalse);
      });

      testWidgets('exclui', (tester) async {
        preparar(propostas: const [pronta]);
        await abrirLista(tester, escuro: escuro);
        await tocar(tester, find.text('Nº 7 · Residência Silva'));
        await tocar(tester, find.byTooltip('Excluir proposta'));
        await tocar(tester, find.text('Excluir'));
        expect(servico.excluidasDeTeste, ['p1']);
        expect(find.text('Nenhuma proposta'), findsOneWidget);
      });

      testWidgets('sem conexão oferece tentar de novo', (tester) async {
        preparar(erro: 'Sem conexão.');
        await abrirLista(tester, escuro: escuro);
        expect(find.text('Sem conexão.'), findsOneWidget);
        expect(find.text('Nova proposta'), findsNothing);
      });

      testWidgets('obra nasce com os dados da proposta', (tester) async {
        const p = PropostaComercial(
          cliente: 'a',
          titulo: 'Residência Silva',
          cidade: 'Cuiabá',
          uf: 'MT',
          area: 120,
          padrao: Padrao.alto,
        );
        await abrir(
          tester,
          ObraFormScreen(
            dadosIniciais: p.dadosDaObra,
            parametrosIniciais: p.parametrosDaObra,
          ),
          escuro: escuro,
        );
        expect(find.text('Residência Silva'), findsOneWidget);
        await rolarAte(tester, find.text('Cuiabá · MT'));
        expect(find.text('Cuiabá · MT'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('PDF', () {
    String inicio(Uint8List b) => String.fromCharCodes(b.take(4));
    const marca = MarcaEngenheiro(nome: 'Duarte', registro: 'CREA 1');

    test('sai completo', () async {
      const p = PropostaComercial(
        numero: 7,
        cliente: 'Dona Lia',
        contato: '65 9',
        titulo: 'Residência Silva',
        endereco: 'Rua A',
        cidade: 'Cuiabá',
        uf: 'MT',
        itens: [ItemComercial(descricao: 'Fundação', valor: 1000)],
        desconto: 100,
        parcelas: [
          ParcelaComercial(descricao: 'Entrada', percentual: 33.33),
          ParcelaComercial(descricao: 'Meio', percentual: 33.33, dias: 30),
          ParcelaComercial(descricao: 'Fim', percentual: 33.34, dias: 60),
        ],
        inclui: 'Mão de obra',
        naoInclui: 'Móveis',
        prazoDias: 180,
        observacoes: 'Reajuste após 30 dias',
      );
      final b = await pdfDaProposta(
        proposta: p,
        hoje: hojeFixo,
        marca: marca,
        logo: png,
      );
      expect(inicio(b), '%PDF');
    });

    test('sai só com o total e sem parcelas', () async {
      const p = PropostaComercial(
        numero: 8,
        cliente: 'a',
        titulo: 'b',
        itens: [ItemComercial(descricao: 'c', valor: 1)],
        mostrarValores: false,
      );
      expect(inicio(await pdfDaProposta(proposta: p, hoje: hojeFixo)), '%PDF');
    });

    test('proposta longa continua saindo', () async {
      final p = PropostaComercial(
        numero: 9,
        cliente: 'Cliente — “ok” 😀',
        titulo: 'Longa',
        itens: [
          for (var i = 0; i < 100; i++)
            ItemComercial(descricao: 'Serviço $i', valor: 1000),
        ],
        inclui: 'x' * 2000,
        observacoes: 'y' * 2000,
      );
      expect(inicio(await pdfDaProposta(proposta: p, hoje: hojeFixo)), '%PDF');
    });

    test('nome do arquivo', () {
      expect(nomeDaProposta(pronta), 'proposta-7.pdf');
    });
  });
}
