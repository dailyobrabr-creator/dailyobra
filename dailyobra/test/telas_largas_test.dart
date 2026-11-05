import 'package:dailyobra/screens/categoria_screen.dart';
import 'package:dailyobra/screens/loja_screen.dart';
import 'package:dailyobra/screens/obras_screen.dart';
import 'package:dailyobra/screens/orcamentos_screen.dart';
import 'package:dailyobra/screens/perfil_screen.dart';
import 'package:dailyobra/screens/produto_screen.dart';
import 'package:dailyobra/screens/proposta_screen.dart';
import 'package:dailyobra/screens/smart_list_screen.dart';
import 'package:dailyobra/services/carrinho_service.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra/services/negociacao_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

Future<void> abrirLargura(
  WidgetTester tester,
  Widget tela,
  double largura, {
  bool escuro = false,
}) async {
  tester.view.physicalSize = Size(largura, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro(ThemeData.light().textTheme),
      darkTheme: AppTheme.escuro(ThemeData.dark().textTheme),
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: tela,
    ),
  );
  await tester.pumpAndSettle();
}

/// Quantos cartões começam na mesma altura do primeiro (ou do cartão de [produto]).
int cartoesNaPrimeiraLinha(WidgetTester tester, {String? produto}) {
  final cartoes = find.byType(CartaoOferta);
  final topo = tester
      .getTopLeft(
        produto == null
            ? cartoes.first
            : find.ancestor(of: find.text(produto), matching: cartoes),
      )
      .dy;
  return cartoes
      .evaluate()
      .where((e) => tester.getTopLeft(find.byWidget(e.widget)).dy == topo)
      .length;
}

/// Oito produtos de alvenaria, todos com preço na loja A.
final blocos = [
  for (var i = 1; i <= 8; i++)
    ItemCatalogo(
      id: 'bloco-$i',
      nome: 'Bloco de concreto modelo $i',
      unidade: 'unidade',
      categoriaId: 'alvenaria',
      tier: 1,
    ),
];

const areia = ItemCatalogo(
  id: 'areia-media',
  nome: 'Areia média lavada',
  unidade: 'm³',
  categoriaId: 'basico',
  tier: 1,
  sinonimos: ['areia'],
);

Obra obra(String id, String nome, DateTime atualizada) => Obra(
  id: id,
  papel: Papel.admin,
  dados: DadosObra(
    nome: nome,
    cidade: 'Maringá',
    uf: 'PR',
    endereco: '',
    responsavel: '',
    inicioPrevisto: '',
  ),
  parametros: const ParametrosObra(area: '100', padrao: Padrao.economico),
  statusEtapas: const {},
  criadaEm: DateTime(2026, 9, 1),
  atualizadaEm: atualizada,
);

PropostaResumo contraproposta() => PropostaResumo(
  id: 'p1',
  orcamentoId: 'o1',
  lojaId: 'a',
  lojaNome: 'Casa do Construtor',
  loja: lojaA,
  modo: ModoProposta.negociacao,
  status: StatusProposta.contraproposta,
  subtotalAnunciado: 450,
  desconto: 20,
  frete: 50,
  total: 450,
  cashbackPrevisto: 4,
  saldoAplicado: 0,
  validaAte: DateTime.now().add(const Duration(hours: 5)),
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
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CarrinhoService.instance.carregar();
    CatalogoService.instance.definirParaTeste(
      categorias: categoriasTeste,
      itens: [...itensTeste, areia, ...blocos],
      lojas: const [lojaA, lojaB, lojaC],
      ofertas: [
        ...ofertasTeste,
        for (final (i, b) in blocos.indexed)
          Oferta(lojaId: 'a', itemId: b.id, preco: 4.0 + i),
      ],
    );
    PerfilService.instance.definirParaTeste(
      nome: 'Ana Souza',
      cidade: 'Maringá',
      uf: 'PR',
    );
    CarteiraService.instance.definirParaTeste(disponivel: 0, pendente: 0);
    NegociacaoService.instance.definirParaTeste();
  });
  tearDown(() {
    CarrinhoService.instance.limpar();
    ObrasService.instance.definirParaTeste();
    NegociacaoService.instance.definirParaTeste();
  });

  void encherCarrinho() {
    final carrinho = CarrinhoService.instance;
    carrinho.adicionar(tijolo.id, 100);
    carrinho.adicionar(argamassa.id, 4);
    carrinho.adicionar(cimento.id, 10);
  }

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('orçamentos com 3 lojas: resumo fixo à direita', (
        tester,
      ) async {
        encherCarrinho();
        await abrirLargura(
          tester,
          const OrcamentosScreen(),
          1366,
          escuro: escuro,
        );
        final resumo = find.byKey(const Key('resumo-cotacao'));
        expect(resumo, findsOneWidget);
        for (final texto in ['Total', 'Proposta', 'Fechar pedido']) {
          expect(
            find.descendant(of: resumo, matching: find.text(texto)),
            findsOneWidget,
            reason: texto,
          );
        }
        expect(find.byType(RodapeTotal), findsNothing);
        final grupo = find.descendant(
          of: find.byKey(const Key('grupos-cotacao')),
          matching: find.text(lojaA.nome),
        );
        expect(
          tester.getTopLeft(resumo).dx,
          greaterThan(tester.getTopLeft(grupo).dx + 300),
        );
        await rolarAteOFim(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('proposta abre no meio da tela no computador', (
        tester,
      ) async {
        encherCarrinho();
        await abrirLargura(
          tester,
          const OrcamentosScreen(),
          1366,
          escuro: escuro,
        );
        await tester.tap(find.text('Proposta'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        final superficie = find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first;
        expect(tester.getSize(superficie).width, lessThanOrEqualTo(560));
        expect(find.text('Enviar para 3 lojas'), findsOneWidget);
      });

      testWidgets('enviados mostra o detalhe ao lado, sem trocar de tela', (
        tester,
      ) async {
        NegociacaoService.instance.definirParaTeste(
          propostas: [contraproposta()],
        );
        await abrirLargura(
          tester,
          const OrcamentosScreen(),
          1366,
          escuro: escuro,
        );
        await tester.tap(find.text('Enviados'));
        await tester.pumpAndSettle();
        final cartao = find.text('Casa do Construtor');
        await tester.tap(cartao.first);
        await tester.pumpAndSettle();
        expect(find.byType(OrcamentosScreen), findsOneWidget);
        expect(find.byType(PropostaScreen), findsOneWidget);
        expect(find.text('Aceitar'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(PropostaScreen)).dx,
          greaterThan(tester.getTopLeft(cartao.first).dx + 300),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('loja com 9 de alvenaria: 4 cartões na primeira linha', (
        tester,
      ) async {
        await abrirLargura(
          tester,
          const LojaScreen(lojaId: 'a'),
          1366,
          escuro: escuro,
        );
        await rolarAte(tester, find.text('Bloco de concreto modelo 1'));
        expect(find.text('Alvenaria · 9'), findsOneWidget);
        expect(
          cartoesNaPrimeiraLinha(tester, produto: 'Bloco de concreto modelo 1'),
          4,
        );
        await rolarAteOFim(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('loja no tablet: 3 cartões na primeira linha', (
        tester,
      ) async {
        await abrirLargura(
          tester,
          const LojaScreen(lojaId: 'a'),
          800,
          escuro: escuro,
        );
        await rolarAte(tester, find.text('Bloco de concreto modelo 1'));
        expect(
          cartoesNaPrimeiraLinha(tester, produto: 'Bloco de concreto modelo 1'),
          3,
        );
        await rolarAteOFim(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('categoria em grade, com só com oferta e menor preço', (
        tester,
      ) async {
        await abrirLargura(
          tester,
          const CategoriaScreen(categoriaId: 'basico', titulo: 'Básico'),
          1366,
          escuro: escuro,
        );
        expect(find.byType(CartaoOferta), findsNWidgets(3));
        expect(find.text('Sem oferta no momento'), findsOneWidget);
        await tester.tap(find.text('Menor preço'));
        await tester.pumpAndSettle();
        final x = {
          for (final i in [areia, argamassa, cimento])
            i.id: tester.getTopLeft(find.text(i.nome)).dx,
        };
        expect(x[argamassa.id], lessThan(x[cimento.id]!), reason: '25 < 38');
        expect(
          x[cimento.id],
          lessThan(x[areia.id]!),
          reason: 'sem oferta no fim',
        );
        await tester.tap(find.text('Só com oferta'));
        await tester.pumpAndSettle();
        expect(find.byType(CartaoOferta), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('lista inteligente: texto colado ao lado dos itens', (
        tester,
      ) async {
        await abrirLargura(
          tester,
          const SmartListScreen(texto: '10 sacos de cimento\n500 tijolos'),
          1366,
          escuro: escuro,
        );
        final campo = find.byType(TextField);
        expect(campo, findsOneWidget);
        expect(
          tester.getTopLeft(find.text(cimento.nome)).dx,
          greaterThan(tester.getTopLeft(campo).dx + 300),
        );
        expect(find.text(tijolo.nome), findsOneWidget);
        await tester.enterText(campo, '10 sacos de cimento');
        await tester.pumpAndSettle();
        expect(find.text(tijolo.nome), findsNothing);
        expect(find.text('Adicionar 1 item ao orçamento'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('perfil centralizado com a escolha da obra ativa', (
        tester,
      ) async {
        ObrasService.instance.definirParaTeste(
          obras: [
            obra('o1', 'Residência Silva', DateTime(2026, 10, 30)),
            obra('o2', 'Sobrado Lima', DateTime(2026, 10, 1)),
          ],
        );
        final tema = await PreferenciaTema.carregar();
        await abrirLargura(
          tester,
          PerfilScreen(tema: tema),
          1366,
          escuro: escuro,
        );
        await rolarAte(tester, find.text('Obra ativa'));
        expect(ObrasService.instance.obraAtiva!.id, 'o1');
        await tester.tap(find.text('Sobrado Lima'));
        await tester.pumpAndSettle();
        expect(ObrasService.instance.obraAtiva!.id, 'o2');
        expect(
          tester.getSize(find.byType(Painel).first).width,
          lessThanOrEqualTo(720),
        );
        await rolarAteOFim(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('produto: preços à direita e adicionar sempre à vista', (
        tester,
      ) async {
        await abrirLargura(
          tester,
          ProdutoScreen(itemId: cimento.id),
          1366,
          escuro: escuro,
        );
        final adicionar = find.text('Adicionar ao orçamento');
        expect(adicionar, findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Preço nas lojas')).dx,
          greaterThan(tester.getTopLeft(adicionar).dx + 300),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('minhas obras em lista', (tester) async {
        ObrasService.instance.definirParaTeste(
          obras: [
            obra('o1', 'Residência Silva', DateTime(2026, 10, 30)),
            obra('o2', 'Sobrado Lima', DateTime(2026, 10, 1)),
          ],
        );
        await abrirLargura(tester, const ObrasScreen(), 1366, escuro: escuro);
        expect(
          tester.getTopLeft(find.text('Sobrado Lima')).dx,
          tester.getTopLeft(find.text('Residência Silva')).dx,
        );
        expect(
          tester.getTopLeft(find.text('Sobrado Lima')).dy,
          greaterThan(tester.getTopLeft(find.text('Residência Silva')).dy),
        );
        await rolarAteOFim(tester);
        expect(tester.takeException(), isNull);
      });
    });
  }

  for (final largura in [360.0, 1366.0]) {
    testWidgets(
      'página da loja mostra endereço, horário e situação em ${largura.toInt()} px',
      (tester) async {
        CatalogoService.instance.definirParaTeste(
          categorias: categoriasTeste,
          itens: itensTeste,
          lojas: const [
            Loja(
              id: 'c',
              nome: 'Comapa Materiais de Construção',
              cidade: 'Rondonópolis',
              uf: 'MT',
              endereco: 'R. Fernando Corrêa da Costa, 2623 - Vila Andréia',
              horario: 'Seg a sex 7h às 17h30; sáb 7h às 12h30',
              freteACombinar: true,
            ),
          ],
          ofertas: const [],
        );
        await abrirLargura(tester, const LojaScreen(lojaId: 'c'), largura);
        expect(
          find.textContaining('R. Fernando Corrêa da Costa, 2623'),
          findsOneWidget,
        );
        expect(find.textContaining('Seg a sex 7h às 17h30'), findsOneWidget);
        expect(find.byType(SeloSituacao), findsOneWidget);
        expect(find.textContaining('Frete a combinar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('loja que pausou os pedidos avisa na página e no produto', (
    tester,
  ) async {
    CatalogoService.instance.definirParaTeste(
      categorias: categoriasTeste,
      itens: itensTeste,
      lojas: [
        Loja(
          id: 'a',
          nome: lojaA.nome,
          cidade: lojaA.cidade,
          uf: lojaA.uf,
          aberta: false,
        ),
        lojaB,
      ],
      ofertas: ofertasTeste,
    );
    await abrirLargura(tester, const LojaScreen(lojaId: 'a'), 360);
    expect(find.textContaining('pausou os pedidos'), findsOneWidget);
    await abrirLargura(tester, ProdutoScreen(itemId: tijolo.id), 360);
    expect(find.textContaining('Pedidos pausados'), findsOneWidget);
  });

  testWidgets('cotação mostra frete a combinar em vez de grátis', (
    tester,
  ) async {
    CatalogoService.instance.definirParaTeste(
      categorias: categoriasTeste,
      itens: itensTeste,
      lojas: [
        Loja(
          id: 'a',
          nome: lojaA.nome,
          cidade: lojaA.cidade,
          uf: lojaA.uf,
          pedidoMinimo: 100,
          freteACombinar: true,
        ),
        lojaB,
        lojaC,
      ],
      ofertas: ofertasTeste,
    );
    encherCarrinho();
    await abrirLargura(tester, const OrcamentosScreen(), 360);
    expect(find.text('Frete a combinar'), findsOneWidget);
    expect(find.text('A combinar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categoria escolhida que some da busca não prende a grade', (
    tester,
  ) async {
    var itens = [cimento, tijolo];
    late StateSetter trocar;
    await abrirLargura(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            trocar = setState;
            return ListaProdutos(itens: itens, filtrarCategoria: true);
          },
        ),
      ),
      1366,
    );
    await tester.tap(find.text('Alvenaria'));
    await tester.pumpAndSettle();
    expect(find.byType(CartaoOferta), findsOneWidget);
    // Nova busca sem nada de alvenaria
    trocar(() => itens = [cimento, argamassa]);
    await tester.pumpAndSettle();
    expect(find.byType(CartaoOferta), findsNWidgets(2));
  });

  testWidgets('no celular a proposta continua subindo de baixo', (
    tester,
  ) async {
    encherCarrinho();
    await abrirLargura(tester, const OrcamentosScreen(), 360);
    expect(find.byType(RodapeTotal), findsOneWidget);
    await tester.tap(find.text('Proposta'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });
}
