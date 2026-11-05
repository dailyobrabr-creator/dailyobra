import 'package:dailyobra/screens/busca_screen.dart';
import 'package:dailyobra/screens/categoria_screen.dart';
import 'package:dailyobra/screens/componentes.dart';
import 'package:dailyobra/screens/hoje_na_obra.dart';
import 'package:dailyobra/screens/inicio_screen.dart';
import 'package:dailyobra/screens/loja_screen.dart';
import 'package:dailyobra/screens/obra_form_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/screens/obras_screen.dart';
import 'package:dailyobra/screens/vitrine_do_inicio.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/catalogo_service.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/economia_service.dart';
import 'package:dailyobra/services/ia_service.dart';
import 'package:dailyobra/services/negociacao_service.dart';
import 'package:dailyobra/services/novidades_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart' hide hoje;

List<Categoria> categorias(int quantas) => [
  for (var i = 1; i <= quantas; i++)
    Categoria(id: 'c$i', nome: 'Categoria $i', ordem: i),
];

const lojaComBanner = Loja(
  id: 'b1',
  nome: 'Depósito Central',
  cidade: 'Maringá',
  uf: 'PR',
  bannerUrl: 'https://exemplo.test/banner.png',
);

Obra obraDe(String id, String nome) => Obra(
  id: id,
  papel: Papel.admin,
  funcao: FuncaoObra.responsavel,
  dados: DadosObra(nome: nome, cidade: 'Maringá', uf: 'PR'),
  parametros: const ParametrosObra(area: '120'),
  statusEtapas: const {EtapaId.preparacao: StatusEtapa.concluida},
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

void preparar({List<Obra> obras = const [], List<Loja> lojas = const []}) {
  SharedPreferences.setMockInitialValues({});
  CatalogoService.instance.definirParaTeste(
    categorias: categoriasTeste,
    itens: itensTeste,
    lojas: lojas,
    ofertas: const [],
  );
  PerfilService.instance.definirParaTeste(nome: 'Ana Souza');
  CarteiraService.instance.definirParaTeste(disponivel: 0);
  ObrasService.instance.definirParaTeste(obras: obras);
  DiarioService.instance.definirParaTeste(dias: const []);
  IaService.instance.definirParaTeste();
  NegociacaoService.instance.definirParaTeste(propostas: const []);
  EconomiaService.instance.definirParaTeste(const []);
  NovidadesService.instance.definirParaTeste();
  abaAtual.value = Aba.inicio;
}

Future<void> abrirGrade(
  WidgetTester tester,
  int quantas, {
  bool largo = false,
}) async {
  preparar();
  await abrir(
    tester,
    Scaffold(
      body: ListView(
        children: [GradeDeCategorias(categorias: categorias(quantas))],
      ),
    ),
  );
  if (largo) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
  }
}

Widget carrossel({List<Loja> lojas = const []}) => Scaffold(
  body: ListView(children: [CarrosselDeBanners(lojas: lojas)]),
);

const primeiro = 'Sua obra inteira em um só lugar';
const segundo = 'Compare antes de comprar';

Future<void> esperarOBanner(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  group('grade de categorias', () {
    testWidgets('dez cabem inteiras, cinco por linha', (tester) async {
      await abrirGrade(tester, 10);
      expect(find.text('Categoria 10'), findsOneWidget);
      expect(find.text('Ver mais'), findsNothing);
      final primeira = tester.getTopLeft(find.text('Categoria 1'));
      expect(tester.getTopLeft(find.text('Categoria 5')).dy, primeira.dy);
      expect(
        tester.getTopLeft(find.text('Categoria 6')).dy,
        greaterThan(primeira.dy),
      );
    });

    testWidgets('com onze, a última casa leva a todas', (tester) async {
      await abrirGrade(tester, 11);
      expect(find.text('Categoria 9'), findsOneWidget);
      expect(find.text('Categoria 10'), findsNothing);
      await tester.tap(find.text('Ver mais'));
      await tester.pumpAndSettle();
      expect(abaAtual.value, Aba.busca);
    });

    testWidgets('na tela larga fica em uma linha', (tester) async {
      await abrirGrade(tester, 10, largo: true);
      expect(
        tester.getTopLeft(find.text('Categoria 10')).dy,
        tester.getTopLeft(find.text('Categoria 1')).dy,
      );
    });

    testWidgets('tocar abre a categoria', (tester) async {
      await abrirGrade(tester, 3);
      await tester.tap(find.text('Categoria 2'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CategoriaScreen>(find.byType(CategoriaScreen))
            .categoriaId,
        'c2',
      );
    });
  });

  group('banners', () {
    testWidgets('sem campanha de loja mostra os do DailyObra', (tester) async {
      preparar();
      await abrir(tester, carrossel());
      expect(find.text(primeiro), findsOneWidget);
      expect(find.byKey(const Key('marca-2')), findsOneWidget);
      expect(find.byKey(const Key('marca-3')), findsNothing);
    });

    testWidgets('a campanha da loja vem primeiro e abre a loja', (
      tester,
    ) async {
      preparar(lojas: const [lojaComBanner]);
      await abrir(tester, carrossel(lojas: const [lojaComBanner]));
      expect(find.text(primeiro), findsNothing);
      expect(find.byKey(const Key('marca-3')), findsOneWidget);
      await tester.tap(find.byType(CarrosselDeBanners));
      await tester.pumpAndSettle();
      expect(find.byType(LojaScreen), findsOneWidget);
    });

    testWidgets('mostra no máximo cinco campanhas', (tester) async {
      preparar();
      await abrir(tester, carrossel(lojas: List.filled(8, lojaComBanner)));
      expect(find.byKey(const Key('marca-7')), findsOneWidget);
      expect(find.byKey(const Key('marca-8')), findsNothing);
    });

    testWidgets('passa sozinho e volta ao primeiro', (tester) async {
      preparar();
      await abrir(tester, carrossel());
      await esperarOBanner(tester);
      expect(find.text(segundo), findsOneWidget);
      expect(find.text(primeiro), findsNothing);
      await esperarOBanner(tester);
      await esperarOBanner(tester);
      expect(find.text(primeiro), findsOneWidget);
    });

    testWidgets('fica parado para quem reduziu o movimento', (tester) async {
      preparar();
      await abrir(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: carrossel(),
          ),
        ),
      );
      await esperarOBanner(tester);
      expect(find.text(primeiro), findsOneWidget);
    });

    testWidgets('fica parado em outra aba', (tester) async {
      preparar();
      await abrir(tester, TickerMode(enabled: false, child: carrossel()));
      await esperarOBanner(tester);
      expect(find.text(primeiro), findsOneWidget);
    });

    testWidgets('o traço leva ao banner', (tester) async {
      preparar();
      await abrir(tester, carrossel());
      await tester.tap(find.byKey(const Key('marca-1')));
      await tester.pumpAndSettle();
      expect(find.text(segundo), findsOneWidget);
    });

    testWidgets('o banner da obra leva à aba Obras', (tester) async {
      preparar();
      await abrir(tester, carrossel());
      await tester.tap(find.text('Abrir Obras'));
      await tester.pumpAndSettle();
      expect(abaAtual.value, Aba.obras);
    });

    testWidgets('funciona no tema escuro', (tester) async {
      preparar();
      await abrir(tester, carrossel(), escuro: true);
      expect(tester.takeException(), isNull);
    });
  });

  group('Início', () {
    testWidgets('não repete o painel da obra', (tester) async {
      preparar(obras: [obraDe('o1', 'Residência Silva')]);
      await abrir(tester, const InicioScreen());
      expect(find.byType(HojeNaObra), findsNothing);
      expect(find.byType(GradeDeCategorias), findsOneWidget);
      expect(find.byType(CarrosselDeBanners), findsOneWidget);
    });

    testWidgets('a faixa mostra a obra e abre ela', (tester) async {
      preparar(obras: [obraDe('o1', 'Residência Silva')]);
      await abrir(tester, const InicioScreen());
      final faixa = find.textContaining('Residência Silva:');
      expect(tester.widget<Text>(faixa).data, contains('% concluída'));
      await tester.tap(faixa);
      await tester.pumpAndSettle();
      expect(find.byType(ObraScreen), findsOneWidget);
    });

    testWidgets('sem obra a faixa abre o cadastro', (tester) async {
      preparar();
      await abrir(tester, const InicioScreen());
      await tester.tap(find.text('Cadastre sua obra e organize o dia a dia'));
      await tester.pumpAndSettle();
      expect(find.byType(ObraFormScreen), findsOneWidget);
    });
  });

  group('aba Obras', () {
    testWidgets('sem obra convida a cadastrar', (tester) async {
      preparar();
      await abrir(tester, const ObrasScreen());
      expect(find.text('Obras'), findsOneWidget);
      expect(find.text('Cadastrar primeira obra'), findsOneWidget);
    });

    testWidgets('com obra mostra a lista, não o painel', (tester) async {
      preparar(obras: [obraDe('o1', 'Residência Silva')]);
      await abrir(tester, const ObrasScreen());
      expect(find.text('Residência Silva'), findsOneWidget);
      expect(find.text('Cadastrar obra'), findsOneWidget);
      expect(find.byType(HojeNaObra), findsNothing);
    });

    testWidgets('a obra abre com tudo dentro dela', (tester) async {
      preparar(obras: [obraDe('o1', 'Residência Silva')]);
      await abrir(tester, const ObrasScreen());
      await tester.tap(find.text('Residência Silva'));
      await tester.pumpAndSettle();
      expect(find.byType(ObraScreen), findsOneWidget);
      expect(find.text('Hoje na obra'), findsOneWidget);
      expect(find.text('Ditar o dia'), findsOneWidget);
      expect(find.text('Tudo da obra'), findsOneWidget);
      expect(find.text('Cronograma'), findsOneWidget);
    });

    testWidgets('uma obra só dispensa os filtros', (tester) async {
      preparar(obras: [obraDe('o1', 'Residência Silva')]);
      await abrir(tester, const ObrasScreen());
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('organiza pela situação', (tester) async {
      final parada = Obra(
        id: 'o3',
        papel: Papel.admin,
        funcao: FuncaoObra.responsavel,
        dados: const DadosObra(
          nome: 'Casa Parada',
          cidade: 'Maringá',
          uf: 'PR',
        ),
        parametros: const ParametrosObra(area: '120'),
        statusEtapas: const {},
        criadaEm: DateTime(2026, 11),
        atualizadaEm: DateTime(2026, 11),
      );
      preparar(
        obras: [
          obraDe('o1', 'Residência Silva'),
          obraDe('o2', 'Casa Nova'),
          parada,
        ],
      );
      await abrir(tester, const ObrasScreen());
      expect(find.text('Todas 3'), findsOneWidget);
      expect(find.text('Em obra 2'), findsOneWidget);
      expect(find.text('Planejamento 1'), findsOneWidget);
      expect(
        find.textContaining('Concluídas'),
        findsNothing,
        reason: 'filtro sem obra não aparece',
      );
      await tester.ensureVisible(find.text('Planejamento 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planejamento 1'));
      await tester.pumpAndSettle();
      expect(find.text('Casa Parada'), findsOneWidget);
      expect(find.text('Casa Nova'), findsNothing);
    });

    testWidgets('filtro que ficou vazio volta para todas', (tester) async {
      preparar(
        obras: [obraDe('o1', 'Residência Silva'), obraDe('o2', 'Casa Nova')],
      );
      await abrir(tester, const ObrasScreen());
      await tester.tap(find.text('Em obra 2'));
      await tester.pumpAndSettle();
      ObrasService.instance.definirParaTeste(obras: const []);
      await tester.pumpAndSettle();
      expect(find.text('Cadastrar primeira obra'), findsOneWidget);
    });

    testWidgets('cadastra outra obra pelo botão da aba', (tester) async {
      preparar(obras: [obraDe('o1', 'Residência Silva')]);
      await abrir(tester, const ObrasScreen());
      await tester.tap(find.text('Cadastrar obra'));
      await tester.pumpAndSettle();
      expect(find.byType(ObraFormScreen), findsOneWidget);
    });

    testWidgets('funciona no tema escuro', (tester) async {
      preparar(
        obras: [obraDe('o1', 'Residência Silva'), obraDe('o2', 'Casa Nova')],
      );
      await abrir(tester, const ObrasScreen(), escuro: true);
      expect(tester.takeException(), isNull);
    });
  });

  group('aba Busca', () {
    testWidgets('não abre o teclado sozinha e mostra as categorias', (
      tester,
    ) async {
      preparar();
      await abrir(tester, const BuscaScreen(naAba: true));
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      expect(find.text('Categorias'), findsOneWidget);
      for (final categoria in categoriasTeste) {
        expect(find.text(categoria.nome), findsOneWidget);
      }
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('com mais de dez categorias mostra todas', (tester) async {
      preparar();
      CatalogoService.instance.definirParaTeste(
        categorias: categorias(12),
        itens: itensTeste,
      );
      await abrir(tester, const BuscaScreen(naAba: true));
      await rolarAte(tester, find.text('Categoria 12'));
      expect(find.text('Ver mais'), findsNothing);
    });

    testWidgets('digitar troca as categorias pelos produtos', (tester) async {
      preparar();
      await abrir(tester, const BuscaScreen(naAba: true));
      await tester.enterText(find.byType(TextField), 'cimen');
      await tester.pumpAndSettle();
      expect(find.text('Categorias'), findsNothing);
      expect(find.text('Cimento CP II 50 kg'), findsOneWidget);
    });

    testWidgets('fora da aba o teclado abre sozinho', (tester) async {
      preparar();
      await abrir(tester, const BuscaScreen());
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TextField>(),
        isNotNull,
      );
    });
  });

  group('bloco da obra', () {
    Widget entrada({bool alerta = false}) => EntradaDaObra(
      icone: Icons.task_alt,
      titulo: 'Pendências',
      detalhe: '2 vencidas',
      alerta: alerta,
      aoTocar: () {},
    );

    testWidgets('mostra o alerta dentro da grade', (tester) async {
      await abrir(
        tester,
        Scaffold(
          body: BlocoDaObra(tom: 'basico', child: entrada(alerta: true)),
        ),
      );
      expect(find.byType(Painel), findsNothing);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('fora da grade continua em linha', (tester) async {
      await abrir(tester, Scaffold(body: entrada()));
      expect(find.byType(Painel), findsOneWidget);
    });
  });
}
