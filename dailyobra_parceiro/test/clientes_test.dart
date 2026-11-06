import 'dart:async';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/clientes_screen.dart';
import 'package:dailyobra_parceiro/screens/componentes.dart';
import 'package:dailyobra_parceiro/screens/configuracoes_screen.dart';
import 'package:dailyobra_parceiro/screens/inicio_screen.dart';
import 'package:dailyobra_parceiro/screens/navegacao_screen.dart';
import 'package:dailyobra_parceiro/services/clientes_service.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:dailyobra_parceiro/services/ofertas_service.dart';
import 'package:dailyobra_parceiro/services/propostas_loja_service.dart';
import 'package:dailyobra_parceiro/services/resultados_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

final ana = ClienteLoja(
  construtorId: 'c1',
  nome: 'Ana Souza',
  empresa: 'Souza Obras',
  telefone: '66999990001',
  cidade: 'Rondonópolis',
  uf: 'MT',
  propostas: 3,
  pedidos: 2,
  total: 1500,
  ultimoContato: DateTime(2026, 10, 20, 10),
);
final semNome = ClienteLoja(
  construtorId: 'c2',
  propostas: 1,
  pedidos: 0,
  total: 0,
  ultimoContato: DateTime(2026, 10, 25, 10),
);
final carlos = ClienteLoja(
  construtorId: 'c3',
  nome: 'Carlos Dias',
  propostas: 2,
  pedidos: 0,
  total: 0,
  ultimoContato: DateTime(2026, 10, 5, 10),
);

PropostaResumo propostaDe(String construtor, String id) => PropostaResumo(
  id: id,
  orcamentoId: 'o-$id',
  lojaId: 'l1',
  construtorId: construtor,
  lojaNome: 'Casa do Construtor',
  modo: ModoProposta.negociacao,
  status: StatusProposta.enviada,
  subtotalAnunciado: 450,
  desconto: 0,
  frete: 50,
  total: 500,
  cashbackPrevisto: 4.5,
  saldoAplicado: 0,
  validaAte: hoje.add(const Duration(days: 1)),
  criadaEm: hoje,
  itens: const [],
);

var buscas = 0;

void preparar(
  List<ClienteLoja> lista, {
  List<PropostaResumo> propostas = const [],
  PapelLoja papel = PapelLoja.dono,
}) {
  buscas = 0;
  LojaService.instance.definirParaTeste(loja: minhaLoja, papel: papel);
  PropostasLojaService.instance.definirParaTeste(propostas: propostas);
  ClientesService.instance.definirParaTeste(
    buscar: () async {
      buscas++;
      return lista;
    },
  );
}

Finder cartao(String nome) =>
    find.ancestor(of: find.text(nome), matching: find.byType(CartaoCliente));

void main() {
  group('ClienteLoja', () {
    test('lê a resposta do banco', () {
      final c = ClienteLoja.fromJson({
        'construtor_id': 'c1',
        'nome': 'Ana Souza',
        'empresa': 'Souza Obras',
        'telefone': '66999990001',
        'cidade': 'Rondonópolis',
        'uf': 'MT',
        'propostas': 3,
        'pedidos': 2,
        'total': 1500.5,
        'ultimo_contato': '2026-10-20T14:00:00+00:00',
      });
      expect(c.construtorId, 'c1');
      expect(c.nome, 'Ana Souza');
      expect(c.empresa, 'Souza Obras');
      expect(c.telefone, '66999990001');
      expect(c.propostas, 3);
      expect(c.pedidos, 2);
      expect(c.total, 1500.5);
      expect(c.ultimoContato.isUtc, isFalse);
      expect(c.ultimoContato.toUtc(), DateTime.utc(2026, 10, 20, 14));
    });

    test('quem não tem nome aparece pela empresa', () {
      expect(ana.exibicao, 'Ana Souza');
      expect(
        ClienteLoja(
          construtorId: 'c',
          empresa: 'Souza Obras',
          propostas: 1,
          pedidos: 0,
          total: 0,
          ultimoContato: hoje,
        ).exibicao,
        'Souza Obras',
      );
      expect(semNome.exibicao, 'Construtor');
    });

    test('quem tem pedido é cliente; quem só cotou é lead', () {
      expect(ana.comprou, isTrue);
      expect(carlos.comprou, isFalse);
    });

    test('resumo das compras com singular e plural', () {
      expect(ana.resumo, 'Comprou ${brl.format(1500)} em 2 pedidos');
      expect(
        ClienteLoja(
          construtorId: 'c',
          propostas: 1,
          pedidos: 1,
          total: 500,
          ultimoContato: hoje,
        ).resumo,
        'Comprou ${brl.format(500)} em 1 pedido',
      );
      expect(semNome.resumo, '1 proposta, nenhum pedido');
      expect(carlos.resumo, '2 propostas, nenhum pedido');
    });

    test('linha com empresa e cidade pula o que falta', () {
      expect(ana.linha, 'Souza Obras · Rondonópolis · MT');
      expect(carlos.linha, '');
    });
  });

  group('filtrarClientes', () {
    final todos = [semNome, ana, carlos];

    test('por aba, mantendo a ordem', () {
      expect(filtrarClientes(todos, FiltroCliente.todos, ''), todos);
      expect(filtrarClientes(todos, FiltroCliente.clientes, ''), [ana]);
      expect(filtrarClientes(todos, FiltroCliente.leads, ''), [
        semNome,
        carlos,
      ]);
    });

    test('busca sem acento em nome, empresa e cidade', () {
      expect(filtrarClientes(todos, FiltroCliente.todos, 'ANA'), [ana]);
      expect(filtrarClientes(todos, FiltroCliente.todos, 'souza ob'), [ana]);
      expect(filtrarClientes(todos, FiltroCliente.todos, 'rondonopolis'), [
        ana,
      ]);
    });

    test('busca pelo telefone só com números', () {
      expect(filtrarClientes(todos, FiltroCliente.todos, '(66) 99999-0001'), [
        ana,
      ]);
      expect(filtrarClientes(todos, FiltroCliente.todos, 'dias'), [carlos]);
    });

    test('busca e aba juntas', () {
      expect(filtrarClientes(todos, FiltroCliente.leads, 'ana'), isEmpty);
    });
  });

  group('ClientesService', () {
    tearDown(ClientesService.instance.limpar);

    test('guarda a lista', () async {
      preparar([ana, carlos]);
      expect(ClientesService.instance.carregado, isFalse);
      await ClientesService.instance.carregar();
      expect(ClientesService.instance.carregado, isTrue);
      expect(ClientesService.instance.lista, [ana, carlos]);
      expect(ClientesService.instance.erro, isNull);
    });

    test('falha mantém a lista que já estava e mostra o erro', () async {
      var falhar = false;
      ClientesService.instance.definirParaTeste(
        buscar: () async {
          if (falhar) throw const FalhaComMensagem('Sem internet.');
          return [ana];
        },
      );
      await ClientesService.instance.carregar();
      falhar = true;
      await ClientesService.instance.carregar();
      expect(ClientesService.instance.lista, [ana]);
      expect(ClientesService.instance.erro, 'Sem internet.');
      falhar = false;
      await ClientesService.instance.carregar();
      expect(ClientesService.instance.erro, isNull);
    });

    test('resposta mais antiga é descartada', () async {
      final primeira = Completer<List<ClienteLoja>>();
      final respostas = [
        primeira.future,
        Future.value([carlos]),
      ];
      ClientesService.instance.definirParaTeste(
        buscar: () => respostas.removeAt(0),
      );
      final a = ClientesService.instance.carregar();
      final b = ClientesService.instance.carregar();
      primeira.complete([ana]);
      await Future.wait([a, b]);
      expect(ClientesService.instance.lista, [carlos]);
    });

    test('limpar esquece a loja anterior', () async {
      preparar([ana]);
      await ClientesService.instance.carregar();
      ClientesService.instance.limpar();
      expect(ClientesService.instance.lista, isEmpty);
      expect(ClientesService.instance.carregado, isFalse);
    });
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'tela no escuro' : 'tela no claro', () {
      tearDown(() {
        ClientesService.instance.limpar();
        abaAtual.value = Aba.inicio;
      });

      testWidgets('abas contadas e selo de cada um', (tester) async {
        preparar([semNome, ana, carlos]);
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        expect(find.text('Todos (3)'), findsOneWidget);
        expect(find.text('Clientes (1)'), findsOneWidget);
        expect(find.text('Leads (2)'), findsOneWidget);
        expect(
          find.descendant(
            of: cartao('Ana Souza'),
            matching: find.text('Cliente'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: cartao('Carlos Dias'),
            matching: find.text('Lead'),
          ),
          findsOneWidget,
        );
        expect(find.text('Construtor'), findsOneWidget);
        expect(
          find.text('Comprou ${brl.format(1500)} em 2 pedidos'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('nome e empresa compridos não estouram', (tester) async {
        preparar([
          ClienteLoja(
            construtorId: 'c9',
            nome: 'Maria Aparecida dos Santos Figueiredo de Albuquerque',
            empresa: 'Construtora e Incorporadora Figueiredo & Albuquerque',
            telefone: '66999990009',
            cidade: 'Rondonópolis',
            uf: 'MT',
            propostas: 12,
            pedidos: 11,
            total: 1234567.89,
            ultimoContato: hoje,
          ),
        ]);
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        expect(tester.takeException(), isNull);
      });

      testWidgets('aba Leads mostra só quem não comprou', (tester) async {
        preparar([semNome, ana, carlos]);
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        // A fonte dos testes é larga: a aba fica fora da tela e a barra precisa rolar
        await tester.ensureVisible(find.text('Leads (2)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leads (2)'));
        await tester.pumpAndSettle();
        expect(find.text('Ana Souza'), findsNothing);
        expect(find.text('Carlos Dias'), findsOneWidget);
      });

      testWidgets('busca filtra e recontagem aparece nas abas', (tester) async {
        preparar([semNome, ana, carlos]);
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        await tester.enterText(find.byType(TextField), 'souza');
        await tester.pumpAndSettle();
        expect(find.text('Todos (1)'), findsOneWidget);
        expect(find.text('Leads (0)'), findsOneWidget);
        expect(find.text('Carlos Dias'), findsNothing);
        await tester.enterText(find.byType(TextField), 'ninguém assim');
        await tester.pumpAndSettle();
        expect(find.text('Ninguém encontrado'), findsOneWidget);
      });

      testWidgets('loja sem proposta ainda', (tester) async {
        preparar(const []);
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        expect(find.text('Nenhum cliente ainda'), findsOneWidget);
      });

      testWidgets('erro antes de carregar não diz que está vazio', (
        tester,
      ) async {
        LojaService.instance.definirParaTeste(loja: minhaLoja);
        ClientesService.instance.definirParaTeste(
          buscar: () async => throw const FalhaComMensagem('Sem internet.'),
        );
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        expect(find.text('Sem internet.'), findsWidgets);
        expect(find.text('Nenhum cliente ainda'), findsNothing);
      });

      testWidgets('abre o cliente com números e histórico', (tester) async {
        preparar(
          [ana],
          propostas: [propostaDe('c1', 'p1'), propostaDe('c2', 'p2')],
        );
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        await tester.tap(find.text('Ana Souza'));
        await tester.pumpAndSettle();
        expect(find.byType(DetalheCliente), findsOneWidget);
        expect(find.text('Histórico'), findsOneWidget);
        expect(find.byType(CartaoPropostaLoja), findsOneWidget);
        expect(find.text(brl.format(1500)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('histórico avisa quando mostra só as recentes', (
        tester,
      ) async {
        preparar([ana], propostas: [propostaDe('c1', 'p1')]);
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        await tester.tap(find.text('Ana Souza'));
        await tester.pumpAndSettle();
        await rolarAte(tester, find.textContaining('mais recentes'));
        expect(find.textContaining('mais recentes'), findsOneWidget);
      });

      testWidgets('WhatsApp com a mensagem da loja', (tester) async {
        final links = <Uri>[];
        preparar([ana]);
        await abrir(
          tester,
          ClientesScreen(
            abrirLink: (uri) async {
              links.add(uri);
              return true;
            },
          ),
          escuro: escuro,
        );
        await tester.tap(find.text('Ana Souza'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chamar no WhatsApp'));
        await tester.pump();
        expect(links, hasLength(1));
        expect(links.single.host, 'wa.me');
        expect(links.single.path, '/5566999990001');
        expect(
          links.single.queryParameters['text'],
          'Olá, Ana! Aqui é da Casa do Construtor.',
        );
      });

      testWidgets('WhatsApp pelo cartão da lista', (tester) async {
        final links = <Uri>[];
        preparar([ana]);
        await abrir(
          tester,
          ClientesScreen(
            abrirLink: (uri) async {
              links.add(uri);
              return true;
            },
          ),
          escuro: escuro,
        );
        await tester.tap(find.byTooltip('Chamar no WhatsApp'));
        await tester.pump();
        expect(links, hasLength(1));
        expect(find.byType(DetalheCliente), findsNothing);
      });

      testWidgets('quem não tem telefone não mostra o botão', (tester) async {
        preparar([carlos]);
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        expect(find.byTooltip('Chamar no WhatsApp'), findsNothing);
        await tester.tap(find.text('Carlos Dias'));
        await tester.pumpAndSettle();
        expect(find.text('Chamar no WhatsApp'), findsNothing);
        expect(find.text('Sem telefone no cadastro.'), findsOneWidget);
      });

      testWidgets('avisa quando o WhatsApp não abre', (tester) async {
        preparar([ana]);
        await abrir(
          tester,
          ClientesScreen(abrirLink: (_) async => false),
          escuro: escuro,
        );
        await tester.tap(find.byTooltip('Chamar no WhatsApp'));
        await tester.pump();
        expect(find.text('Não deu para abrir o WhatsApp.'), findsOneWidget);
      });

      testWidgets('computador abre o cliente ao lado da lista', (tester) async {
        preparar([ana, carlos], propostas: [propostaDe('c1', 'p1')]);
        await abrirLargura(
          tester,
          const ClientesScreen(),
          1366,
          escuro: escuro,
        );
        expect(find.text('Escolha um cliente'), findsOneWidget);
        await tester.tap(find.text('Ana Souza'));
        await tester.pumpAndSettle();
        expect(find.text('Escolha um cliente'), findsNothing);
        expect(find.byType(DetalheCliente), findsOneWidget);
        expect(find.text('Carlos Dias'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('atualiza quando volta para a aba', (tester) async {
        preparar([ana]);
        await abrir(tester, const ClientesScreen(), escuro: escuro);
        expect(buscas, 1);
        abaAtual.value = Aba.clientes;
        await tester.pumpAndSettle();
        expect(buscas, 2);
        abaAtual.value = Aba.inicio;
        await tester.pumpAndSettle();
        expect(buscas, 2);
      });
    });
  }

  testWidgets('a aba só busca quando abre, e busca de novo a cada volta', (
    tester,
  ) async {
    preparar([ana]);
    OfertasService.instance.definirParaTeste(
      categorias: categoriasTeste,
      catalogo: catalogoTeste,
    );
    ResultadosService.instance.definirParaTeste(
      buscar: (_, _) async => const ResultadosPeriodo(),
    );
    SharedPreferences.setMockInitialValues({});
    final tema = await PreferenciaTema.carregar();
    await abrirLargura(tester, NavegacaoScreen(tema: tema), 1366);
    expect(buscas, 0);
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    expect(buscas, 1);
    expect(find.text('Ana Souza'), findsOneWidget);
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Souza'), findsNothing);
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    expect(buscas, 2);
    expect(tester.takeException(), isNull);
  });

  group('entrada no celular', () {
    tearDown(ClientesService.instance.limpar);

    Future<void> abrirConfiguracoes(WidgetTester tester, double largura) async {
      SharedPreferences.setMockInitialValues({});
      await abrirLargura(
        tester,
        ConfiguracoesScreen(tema: await PreferenciaTema.carregar()),
        largura,
      );
    }

    testWidgets('Configurações leva aos clientes, para o vendedor também', (
      tester,
    ) async {
      preparar([ana], papel: PapelLoja.vendedor);
      await abrirConfiguracoes(tester, 360);
      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      expect(find.byType(ClientesScreen), findsOneWidget);
      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('no tablet e no computador o menu já tem Clientes', (
      tester,
    ) async {
      preparar([ana]);
      await abrirConfiguracoes(tester, 800);
      expect(find.text('Clientes'), findsNothing);
      await abrirConfiguracoes(tester, 1366);
      expect(find.text('Clientes'), findsNothing);
    });
  });
}
