import 'package:dailyobra/screens/busca_screen.dart';
import 'package:dailyobra/screens/categoria_screen.dart';
import 'package:dailyobra/screens/inicio_screen.dart';
import 'package:dailyobra/screens/loja_screen.dart';
import 'package:dailyobra/screens/produto_screen.dart';
import 'package:dailyobra/screens/smart_list_screen.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

void preparar({
  List<Loja> lojas = const [lojaA, lojaB, lojaC],
  List<Oferta>? ofertas,
  String? erro,
}) {
  CatalogoService.instance.definirParaTeste(
    categorias: categoriasTeste,
    itens: itensTeste,
    lojas: lojas,
    ofertas: ofertas ?? ofertasTeste,
    erro: erro,
  );
  PerfilService.instance.definirParaTeste(
    nome: 'Ana Souza',
    cidade: 'Maringá',
    uf: 'PR',
  );
  CarteiraService.instance.definirParaTeste(disponivel: 125.5, pendente: 12.5);
  ObrasService.instance.definirParaTeste(obras: const []);
  NegociacaoService.instance.definirParaTeste();
  EconomiaService.instance.definirParaTeste(const []);
  NovidadesService.instance.definirParaTeste();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CarrinhoService.instance.carregar();
  });
  tearDown(() {
    CatalogoService.instance.definirParaTeste();
    CarrinhoService.instance.limpar();
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('início mostra saudação, clube, ofertas e lojas', (
        tester,
      ) async {
        preparar(lojas: const [lojaA, lojaB]);
        await abrir(tester, const InicioScreen(), escuro: escuro);
        expect(find.text('Olá, Ana'), findsOneWidget);
        expect(find.textContaining(brl.format(125.5)), findsOneWidget);
        expect(find.text('Cotar agora'), findsOneWidget);
        await rolarAte(tester, find.text('Ofertas do dia'));
        final lojasPerto = find.byKey(const Key('lojas-perto'));
        await rolarAte(tester, lojasPerto);
        expect(
          find.descendant(
            of: lojasPerto,
            matching: find.text('Casa do Construtor'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: lojasPerto,
            matching: find.text('Depósito Bom Preço'),
          ),
          findsOneWidget,
        );
        await rolarAteOFim(tester);
      });

      testWidgets('início avisa da obra atrasada', (tester) async {
        preparar();
        final etapa = Calculo.de(const ParametrosObra(area: '120'))
            .resultado!
            .etapas
            .first
            .etapa;
        ObrasService.instance.definirParaTeste(
          obras: [
            Obra(
              id: 'o1',
              papel: Papel.admin,
              dados: const DadosObra(nome: 'Residência Silva'),
              parametros: const ParametrosObra(area: '120'),
              statusEtapas: const {},
              cronograma: {
                etapa: DatasEtapa(
                  inicioPrevisto: DateTime(hoje.year, hoje.month, hoje.day - 9),
                  fimPrevisto: DateTime(hoje.year, hoje.month, hoje.day - 5),
                ),
              },
              criadaEm: DateTime(2026, 11),
              atualizadaEm: DateTime(2026, 11),
            ),
          ],
        );
        await abrir(tester, const InicioScreen(), escuro: escuro);
        await rolarAte(
          tester,
          find.text('1 etapa atrasada, a maior com 5 dias.'),
        );
        expect(
          find.text('1 etapa atrasada, a maior com 5 dias.'),
          findsOneWidget,
        );
      });

      testWidgets('início sem lojas orienta o construtor', (tester) async {
        preparar(lojas: const [], ofertas: const []);
        await abrir(tester, const InicioScreen(), escuro: escuro);
        await rolarAte(tester, find.text('Ainda não há lojas na sua cidade'));
        expect(find.text('Ofertas do dia'), findsNothing);
        await rolarAteOFim(tester);
      });

      testWidgets('falha de conexão mantém os dados e avisa', (tester) async {
        preparar(
          erro: 'Sem conexão. Mostrando os dados carregados por último.',
        );
        await abrir(tester, const InicioScreen(), escuro: escuro);
        expect(
          find.text('Sem conexão. Mostrando os dados carregados por último.'),
          findsOneWidget,
        );
      });

      testWidgets('smart list separa reconhecido e não reconhecido', (
        tester,
      ) async {
        preparar();
        await abrir(
          tester,
          const SmartListScreen(
            texto: '100 sacos de cimento\nparafuso sextavado',
          ),
          escuro: escuro,
        );
        expect(find.text('Cimento CP II 50 kg'), findsOneWidget);
        expect(find.text('Não reconhecido'), findsOneWidget);
        expect(find.text('parafuso sextavado'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(FilledButton, 'Adicionar 1 item ao orçamento'),
        );
        await tester.pumpAndSettle();
        expect(CarrinhoService.instance.itens.single.itemId, cimento.id);
        expect(CarrinhoService.instance.itens.single.quantidade, 100);
      });

      testWidgets('smart list pede para escolher entre parecidos', (
        tester,
      ) async {
        preparar();
        await abrir(
          tester,
          const SmartListScreen(texto: 'cimento argamassa'),
          escuro: escuro,
        );
        expect(find.text('Qual destes?'), findsOneWidget);
        await tester.tap(find.text('Cimento CP II 50 kg'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, 'Adicionar 1 item ao orçamento'),
          findsOneWidget,
        );
      });

      testWidgets('produto lista as lojas do menor para o maior preço', (
        tester,
      ) async {
        preparar();
        await abrir(
          tester,
          const ProdutoScreen(itemId: 'cimento-cp2-50kg'),
          escuro: escuro,
        );
        await rolarAte(tester, find.text('Casa do Construtor'));
        final c = tester.getTopLeft(find.text('Ferragens Sarandi')).dy;
        final b = tester.getTopLeft(find.text('Depósito Bom Preço')).dy;
        final a = tester.getTopLeft(find.text('Casa do Construtor')).dy;
        expect(
          c < b && b < a,
          isTrue,
          reason: 'C 38,00 < B 40,00 (promoção) < A 45,00',
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Adicionar ao orçamento'),
        );
        await tester.pumpAndSettle();
        expect(CarrinhoService.instance.itens.single.itemId, cimento.id);
        await rolarAteOFim(tester);
      });

      testWidgets('loja mostra frete, mínimo e os produtos dela', (
        tester,
      ) async {
        preparar();
        await abrir(tester, const LojaScreen(lojaId: 'a'), escuro: escuro);
        expect(find.text('Casa do Construtor'), findsWidgets);
        expect(find.textContaining('Pedido mínimo'), findsOneWidget);
        await rolarAte(tester, find.text('Torneira de banheiro cromada'));
        await tester.tap(find.byTooltip('Adicionar ao orçamento').first);
        await tester.pumpAndSettle();
        expect(CarrinhoService.instance.itens.single.lojaFixada, 'a');
        await rolarAteOFim(tester);
      });

      testWidgets('categoria vazia e busca sem resultado orientam', (
        tester,
      ) async {
        preparar();
        await abrir(
          tester,
          const CategoriaScreen(categoriaId: 'pintura', titulo: 'Pintura'),
          escuro: escuro,
        );
        expect(
          find.text('Nenhum produto nesta categoria ainda'),
          findsOneWidget,
        );
        await abrir(tester, const BuscaScreen(), escuro: escuro);
        await tester.enterText(find.byType(TextField), 'xyz');
        await tester.pumpAndSettle();
        expect(find.textContaining('Nada encontrado'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'cimen');
        await tester.pumpAndSettle();
        expect(find.text('Cimento CP II 50 kg'), findsOneWidget);
      });
    });
  }
}
