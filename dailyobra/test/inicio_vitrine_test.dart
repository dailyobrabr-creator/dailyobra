import 'package:dailyobra/screens/inicio_screen.dart';
import 'package:dailyobra/services/carrinho_service.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra/services/economia_service.dart';
import 'package:dailyobra/services/negociacao_service.dart';
import 'package:dailyobra/services/novidades_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

const parametros = ParametrosObra(area: '100', padrao: Padrao.economico);
const statusObra = {
  EtapaId.preparacao: StatusEtapa.concluida,
  EtapaId.fundacao: StatusEtapa.concluida,
  EtapaId.estrutura: StatusEtapa.iniciada,
};

Obra obraTeste() => Obra(
  id: 'o1',
  papel: Papel.admin,
  dados: const DadosObra(
    nome: 'Residência Silva',
    cidade: 'Maringá',
    uf: 'PR',
    endereco: '',
    responsavel: '',
    inicioPrevisto: '',
  ),
  parametros: parametros,
  statusEtapas: statusObra,
  criadaEm: DateTime(2026, 10, 1),
  atualizadaEm: DateTime(2026, 10, 30),
);

PropostaResumo proposta(
  String id, {
  StatusProposta status = StatusProposta.contraproposta,
  PedidoResumo? pedido,
  String lojaNome = 'Casa do Construtor',
}) => PropostaResumo(
  id: id,
  orcamentoId: 'o-$id',
  lojaId: 'a',
  lojaNome: lojaNome,
  loja: lojaA,
  modo: ModoProposta.negociacao,
  status: status,
  subtotalAnunciado: 450,
  desconto: 0,
  frete: 50,
  total: 450,
  cashbackPrevisto: 4,
  saldoAplicado: 0,
  validaAte: DateTime.now().add(const Duration(hours: 5, minutes: 10)),
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

List<EconomiaMes> economia({double atual = 1284}) => [
  for (var m = 6; m <= 11; m++)
    EconomiaMes(
      mes: DateTime(2026, m),
      comparando: m == 11 ? atual : 100.0 * (m - 5),
      negociando: 0,
      cashback: 0,
    ),
];

void preparar({
  List<Obra> obras = const [],
  List<PropostaResumo> propostas = const [],
  List<EconomiaMes> meses = const [],
  List<Loja> lojas = const [lojaA, lojaB, lojaC],
}) {
  CatalogoService.instance.definirParaTeste(
    categorias: categoriasTeste,
    itens: itensTeste,
    lojas: lojas,
    ofertas: ofertasTeste,
  );
  PerfilService.instance.definirParaTeste(
    nome: 'Ana Souza',
    cidade: 'Maringá',
    uf: 'PR',
  );
  CarteiraService.instance.definirParaTeste(disponivel: 125.5, pendente: 12.5);
  ObrasService.instance.definirParaTeste(obras: obras);
  NegociacaoService.instance.definirParaTeste(propostas: propostas);
  EconomiaService.instance.definirParaTeste(meses);
  NovidadesService.instance.definirParaTeste();
}

Future<void> abrirLargura(
  WidgetTester tester,
  double largura, {
  required bool escuro,
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
      home: const InicioScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CarrinhoService.instance.carregar();
  });
  tearDown(() {
    ObrasService.instance.definirParaTeste();
    NegociacaoService.instance.definirParaTeste();
  });

  for (final escuro in [false, true]) {
    for (final largura in [360.0, 800.0, 1366.0]) {
      group('${escuro ? 'escuro' : 'claro'} ${largura.toInt()} px', () {
        testWidgets('blocos com dados', (tester) async {
          preparar(
            obras: [obraTeste()],
            meses: economia(),
            propostas: [
              proposta('p1'),
              proposta(
                'p2',
                status: StatusProposta.aceita,
                lojaNome: 'Depósito Bom Preço',
                pedido: PedidoResumo(
                  id: 'd2',
                  status: StatusPedido.saiuEntrega,
                  total: 1250,
                  criadoEm: DateTime.now(),
                ),
              ),
            ],
          );
          await abrirLargura(tester, largura, escuro: escuro);
          expect(find.text('Contraproposta'), findsOneWidget);
          expect(find.textContaining('Responda em'), findsOneWidget);
          expect(find.text('Pedido saiu para entrega'), findsOneWidget);

          final etapas = Calculo.de(parametros).resultado!.etapas;
          final percentual = progresso(etapas, statusObra);
          await rolarAte(tester, find.text('$percentual% concluída'));
          await rolarAte(tester, find.text(brl.format(1284)));
          for (final m in ['jun', 'jul', 'ago', 'set', 'out', 'nov']) {
            expect(find.text(m), findsOneWidget, reason: m);
          }

          final barato = find.byKey(const Key('mais-barato'));
          await rolarAte(tester, barato);
          expect(
            find.descendant(
              of: barato,
              matching: find.text('de ${brl.format(38)} a ${brl.format(45)}'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: barato,
              matching: find.textContaining('Torneira'),
            ),
            findsNothing,
            reason: 'torneira só tem uma loja',
          );
          final lojas = find.byKey(const Key('lojas-perto'));
          await rolarAte(tester, lojas);
          if (largura >= 1024) {
            expect(
              tester.getTopLeft(lojas).dx,
              greaterThan(tester.getTopLeft(barato).dx + 100),
            );
          }
          await rolarAteOFim(tester);
          expect(tester.takeException(), isNull);
        });

        testWidgets('blocos vazios convidam ou somem', (tester) async {
          preparar(
            meses: economia(atual: 0)
                .map(
                  (e) => EconomiaMes(
                    mes: e.mes,
                    comparando: 0,
                    negociando: 0,
                    cashback: 0,
                  ),
                )
                .toList(),
          );
          await abrirLargura(tester, largura, escuro: escuro);
          expect(find.text('Contraproposta'), findsNothing);
          expect(find.text('Pedido saiu para entrega'), findsNothing);
          await rolarAte(tester, find.textContaining('Cadastre sua obra'));
          await rolarAte(
            tester,
            find.textContaining('Feche seu primeiro pedido'),
          );
          await rolarAteOFim(tester);
          expect(tester.takeException(), isNull);
        });
      });
    }

    testWidgets(
      'economia que não carregou avisa (${escuro ? 'escuro' : 'claro'})',
      (tester) async {
        preparar();
        EconomiaService.instance.definirParaTeste(
          const [],
          erro: 'Sem conexão com a internet.',
        );
        await abrirLargura(tester, 360, escuro: escuro);
        await rolarAte(
          tester,
          find.textContaining('Não deu para carregar a economia'),
        );
        expect(find.byType(EsqueletoBrilho), findsNothing);
      },
    );

    testWidgets(
      'várias contrapropostas viram um aviso só (${escuro ? 'escuro' : 'claro'})',
      (tester) async {
        preparar(propostas: [proposta('p1'), proposta('p2'), proposta('p3')]);
        await abrirLargura(tester, 360, escuro: escuro);
        expect(find.text('3 contrapropostas esperando você'), findsOneWidget);
      },
    );

    testWidgets(
      'nome de loja enorme não estoura (${escuro ? 'escuro' : 'claro'})',
      (tester) async {
        preparar(
          lojas: [
            Loja(
              id: 'z',
              nome: 'Z' * 70,
              cidade: 'Maringá',
              uf: 'PR',
              freteFixo: 1234567.89,
            ),
            lojaA,
          ],
        );
        await abrirLargura(tester, 360, escuro: escuro);
        await rolarAte(tester, find.byKey(const Key('lojas-perto')));
        await rolarAteOFim(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
