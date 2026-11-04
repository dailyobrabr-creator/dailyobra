import 'package:dailyobra/screens/carteira_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/screens/perfil_screen.dart';
import 'package:dailyobra/services/carrinho_service.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra/services/economia_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CarrinhoService.instance.carregar();
    CatalogoService.instance.definirParaTeste(
      categorias: categoriasTeste,
      itens: itensTeste,
      lojas: const [lojaA, lojaB, lojaC],
      ofertas: ofertasTeste,
      planilha: {'Cimento 50kg|und': (cimento.id, 1.0)},
    );
    PerfilService.instance.definirParaTeste(
      nome: 'Ana Souza',
      cidade: 'Maringá',
      uf: 'PR',
    );
    EconomiaService.instance.definirParaTeste(const []);
  });
  tearDown(() {
    CarrinhoService.instance.limpar();
    ObrasService.instance.definirParaTeste();
  });

  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('carteira mostra disponível, a liberar e saque em breve', (
        tester,
      ) async {
        CarteiraService.instance.definirParaTeste(
          disponivel: 125.5,
          pendente: 50,
          extrato: [
            Lancamento(
              descricao: 'Cashback previsto do pedido',
              valor: 50,
              conta: 'pendente',
              tipo: 'cashback_previsto',
              data: DateTime(2026, 10, 30, 9, 15),
              loja: 'Casa do Construtor',
              tier: 4,
            ),
          ],
        );
        await abrir(tester, const CarteiraScreen(), escuro: escuro);
        expect(find.text(brl.format(125.5)), findsOneWidget);
        expect(find.textContaining(brl.format(50)), findsWidgets);
        final sacar = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Sacar'),
        );
        expect(sacar.onPressed, isNull);
        expect(find.textContaining('Em breve'), findsOneWidget);
        await rolarAte(tester, find.text('Cashback previsto do pedido'));
        expect(find.textContaining('Nível 4'), findsWidgets);
        await rolarAteOFim(tester);
      });

      testWidgets('carteira vazia explica como ganhar cashback', (
        tester,
      ) async {
        CarteiraService.instance.definirParaTeste();
        await abrir(tester, const CarteiraScreen(), escuro: escuro);
        final usar = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Usar no orçamento'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          ),
        );
        expect(usar.onPressed, isNull);
        await rolarAte(tester, find.text('Nenhum lançamento ainda'));
      });

      testWidgets('obra manda os materiais para o orçamento', (tester) async {
        ObrasService.instance.definirParaTeste(
          obras: [
            Obra(
              id: 'o1',
              papel: Papel.admin,
              dados: const DadosObra(
                nome: 'Casa Econômica',
                cidade: 'Maringá',
                uf: 'PR',
                endereco: '',
                responsavel: '',
                inicioPrevisto: '',
              ),
              parametros: const ParametrosObra(
                area: '100',
                padrao: Padrao.economico,
              ),
              statusEtapas: const {},
              criadaEm: DateTime(2026, 10, 31),
              atualizadaEm: DateTime(2026, 10, 31),
            ),
          ],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Cotar materiais desta obra'));
        await tester.tap(find.text('Cotar materiais desta obra'));
        await tester.pumpAndSettle();
        final itens = CarrinhoService.instance.itens;
        expect(itens.single.itemId, cimento.id);
        expect(itens.single.quantidade, greaterThan(1));
      });
    });
  }

  testWidgets('perfil recusa CPF ou CNPJ inválido', (tester) async {
    final tema = await PreferenciaTema.carregar();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppComTema(
        titulo: 'DailyObra',
        tema: tema,
        claro: AppTheme.claro(ThemeData.light().textTheme),
        escuro: AppTheme.escuro(ThemeData.dark().textTheme),
        home: PerfilScreen(tema: tema),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CPF ou CNPJ'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('perfil-documento')),
      '123',
    );
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    expect(
      find.text('CPF ou CNPJ inválido. Confira os números.'),
      findsOneWidget,
    );
  });

  testWidgets('perfil escolhe a região pelo CEP, sem digitar a cidade', (
    tester,
  ) async {
    final tema = await PreferenciaTema.carregar();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppComTema(
        titulo: 'DailyObra',
        tema: tema,
        claro: AppTheme.claro(ThemeData.light().textTheme),
        escuro: AppTheme.escuro(ThemeData.dark().textTheme),
        home: PerfilScreen(
          tema: tema,
          consultarCep: (_) async => const EnderecoCep(
            logradouro: '',
            bairro: '',
            cidade: 'Rondonópolis',
            uf: 'MT',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cidade'), findsNothing);
    expect(find.text('UF'), findsNothing);
    await tester.tap(find.text('Trocar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('regiao-cep')), '78720586');
    await tester.pumpAndSettle();
    expect(find.text('Rondonópolis · MT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('perfil troca o tema do app para escuro', (tester) async {
    final tema = await PreferenciaTema.carregar();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppComTema(
        titulo: 'DailyObra',
        tema: tema,
        claro: AppTheme.claro(ThemeData.light().textTheme),
        escuro: AppTheme.escuro(ThemeData.dark().textTheme),
        home: PerfilScreen(tema: tema),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Souza'), findsWidgets);
    await rolarAte(tester, find.text('Escuro'));
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(tema.value, ThemeMode.dark);
  });
}
