import 'package:dailyobra/screens/componentes.dart';
import 'package:dailyobra/screens/menu_da_conta.dart';
import 'package:dailyobra/screens/obras_screen.dart';
import 'package:dailyobra/screens/perfil_screen.dart';
import 'package:dailyobra/services/carteira_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra/services/perfil_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart' hide hoje;

Obra obra() => Obra(
  id: 'o1',
  papel: Papel.admin,
  funcao: FuncaoObra.responsavel,
  dados: const DadosObra(nome: 'Residência Silva', cidade: 'Maringá', uf: 'PR'),
  parametros: const ParametrosObra(area: '120'),
  statusEtapas: const {},
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

void preparar({List<Obra>? obras}) {
  PerfilService.instance.definirParaTeste(
    nome: 'Ana Souza',
    email: 'ana@obra.com',
    cidade: 'Maringá',
    uf: 'PR',
  );
  CarteiraService.instance.definirParaTeste(disponivel: 125.5);
  ObrasService.instance.definirParaTeste(obras: obras ?? [obra()]);
  abaAtual.value = Aba.inicio;
}

Future<void> tela(
  WidgetTester tester,
  Widget filho, {
  bool larga = false,
}) async {
  await abrir(tester, filho);
  if (larga) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
  }
}

Future<void> abrirMenu(WidgetTester tester) async {
  await tester.tap(find.byType(MenuDaConta));
  await tester.pumpAndSettle();
}

Widget comMenu() => Scaffold(appBar: AppBar(actions: const [MenuDaConta()]));

Future<PerfilScreen> telaDoPerfil() async {
  SharedPreferences.setMockInitialValues({});
  return PerfilScreen(tema: await PreferenciaTema.carregar());
}

void main() {
  group('menu da conta', () {
    testWidgets('mostra quem está logado e os caminhos', (tester) async {
      preparar();
      await tela(tester, comMenu());
      await abrirMenu(tester);
      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('ana@obra.com'), findsOneWidget);
      for (final item in [
        'Meu perfil',
        'Minhas obras',
        'Carteira',
        'Propostas comerciais',
        'Sua marca nos documentos',
        'Sair da conta',
      ]) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
      expect(find.text(brl.format(125.5)), findsOneWidget);
    });

    testWidgets('leva ao perfil', (tester) async {
      preparar();
      await tela(tester, comMenu());
      await abrirMenu(tester);
      await tester.tap(find.text('Meu perfil'));
      await tester.pumpAndSettle();
      expect(abaAtual.value, Aba.perfil);
    });

    for (final larga in [false, true]) {
      testWidgets('abre a lista de obras (larga: $larga)', (tester) async {
        preparar();
        await tela(tester, comMenu(), larga: larga);
        await abrirMenu(tester);
        await tester.tap(find.text('Minhas obras'));
        await tester.pumpAndSettle();
        expect(find.byType(ObrasScreen), findsOneWidget);
        expect(find.text('Residência Silva'), findsOneWidget);
      });
    }

    testWidgets('leva à carteira', (tester) async {
      preparar();
      await tela(tester, comMenu());
      await abrirMenu(tester);
      await tester.tap(find.text('Carteira'));
      await tester.pumpAndSettle();
      expect(abaAtual.value, Aba.carteira);
    });

    testWidgets('sair pede confirmação', (tester) async {
      preparar();
      await tela(tester, comMenu());
      await abrirMenu(tester);
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta?'), findsNothing);
    });

    testWidgets('sem nome ainda mostra um texto geral', (tester) async {
      preparar();
      PerfilService.instance.definirParaTeste(nome: '', email: 'ana@obra.com');
      await tela(tester, comMenu());
      await abrirMenu(tester);
      expect(find.text('Sua conta'), findsOneWidget);
    });
  });

  group('minhas obras', () {
    testWidgets('não repete a logo nem a conta', (tester) async {
      preparar();
      await tela(tester, const ObrasScreen(), larga: true);
      expect(find.byType(MarcaDailyObra), findsNothing);
      expect(find.byTooltip('Conta'), findsNothing);
      expect(find.text('Minhas obras'), findsOneWidget);
    });

    testWidgets('na tela larga a obra fica ao lado do resumo', (tester) async {
      preparar();
      await tela(tester, const ObrasScreen(), larga: true);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Nova obra'), findsOneWidget);
      final nome = tester.getTopLeft(find.text('Residência Silva'));
      final resumo = tester.getTopLeft(find.text('Resumo'));
      expect(resumo.dy, lessThan(nome.dy + 40));
      expect(resumo.dx, greaterThan(nome.dx));
      expect(find.text('Tenho um código de convite'), findsOneWidget);
      expect(find.text('Propostas comerciais'), findsOneWidget);
    });

    testWidgets('no celular a obra vem antes dos caminhos', (tester) async {
      preparar();
      await tela(tester, const ObrasScreen());
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Resumo'), findsNothing);
      await rolarAte(tester, find.text('Propostas comerciais'));
      expect(
        tester.getTopLeft(find.text('Propostas comerciais')).dy,
        greaterThan(tester.getTopLeft(find.text('Residência Silva')).dy),
      );
    });

    testWidgets('sem obra convida a cadastrar', (tester) async {
      preparar(obras: []);
      await tela(tester, const ObrasScreen(), larga: true);
      expect(find.text('Cadastrar primeira obra'), findsOneWidget);
    });
  });

  group('perfil', () {
    testWidgets('na tela larga a pessoa fica à esquerda', (tester) async {
      preparar();
      await tela(tester, await telaDoPerfil(), larga: true);
      final pessoa = tester.getTopLeft(find.text('ana@obra.com'));
      final dados = tester.getTopLeft(find.text('Seus dados'));
      expect(dados.dx, greaterThan(pessoa.dx));
      expect(find.text('Sair da conta'), findsOneWidget);
      expect(find.text('Salvar alterações'), findsOneWidget);
    });

    testWidgets('nome e empresa ficam lado a lado', (tester) async {
      preparar();
      await tela(tester, await telaDoPerfil(), larga: true);
      expect(
        tester.getTopLeft(find.text('Empresa')).dy,
        tester.getTopLeft(find.textContaining('Nome')).dy,
      );
    });

    testWidgets('no celular fica em uma coluna', (tester) async {
      preparar();
      await tela(tester, await telaDoPerfil());
      expect(
        tester.getTopLeft(find.text('Seus dados')).dy,
        greaterThan(tester.getTopLeft(find.text('ana@obra.com')).dy),
      );
    });

    testWidgets('mostra a cidade junto da pessoa', (tester) async {
      preparar();
      await tela(tester, await telaDoPerfil());
      expect(find.text('Maringá, PR'), findsOneWidget);
    });
  });
}
