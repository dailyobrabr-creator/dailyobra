// Testes das telas num celular de 360 × 780: confirmam que abrem sem erro de layout (texto
// estourando, overflow) e mostram o que devem. Usam obras em memória, sem Supabase.

import 'package:dailyobra/screens/obra_form_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/screens/obras_screen.dart';
import 'package:dailyobra/screens/simulador_screen.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';

import 'apoio.dart' show rolarAte;

Obra obraExemplo({
  String id = 'a1',
  Papel papel = Papel.admin,
  Map<EtapaId, StatusEtapa> status = const {},
}) => Obra(
  id: id,
  papel: papel,
  dados: const DadosObra(
    nome: 'Residência Silva',
    cidade: 'Maringá',
    uf: 'PR',
    endereco: 'Rua das Flores, 120',
    responsavel: 'Eng. Ana Souza',
    inicioPrevisto: '2026-11-10',
  ),
  parametros: const ParametrosObra(
    area: '153',
    padrao: Padrao.alto,
    laje: true,
    muroAtivo: true,
    muroFrente: '12',
    muroTerreno: '290',
    muroAcabamento: AcabamentoMuro.texturado,
  ),
  statusEtapas: status,
  criadaEm: DateTime(2026, 10, 31),
  atualizadaEm: DateTime(2026, 10, 31),
);

/// Tema escuro ligado pelos testes do grupo 'escuro'
var escuro = false;

Future<void> abrir(WidgetTester tester, Widget tela) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
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

/// Rola a lista até o fim, para o layout de todos os blocos ser montado e conferido
Future<void> rolarAteOFim(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

final campoCep = find.descendant(
  of: find.byKey(const Key('endereco-cep')),
  matching: find.byType(TextField),
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  tearDown(() => ObrasService.instance.definirParaTeste());

  // Todas as telas nos dois temas
  for (final modo in [false, true]) {
    group(modo ? 'escuro' : 'claro', () {
      setUp(() => escuro = modo);

      testWidgets('login: valida o e-mail antes de enviar', (tester) async {
        await abrir(tester, const LoginScreen());
        expect(find.text('Entrar'), findsWidgets);
        // Marca que se adapta ao tema (a logo horizontal tem texto escuro e 6 mil px)
        expect(find.byType(MarcaDailyObra), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
        await tester.pump();
        expect(find.text('Informe um e-mail válido.'), findsOneWidget);

        await tester.tap(find.text('Sou novo aqui'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, 'Criar conta'),
          findsOneWidget,
        );
      });

      testWidgets('lista vazia convida a cadastrar', (tester) async {
        ObrasService.instance.definirParaTeste(obras: []);
        await abrir(tester, const ObrasScreen());
        expect(find.text('Nenhuma obra cadastrada'), findsOneWidget);
        expect(find.byType(MarcaDailyObra), findsOneWidget);
        expect(find.text('Cadastrar primeira obra'), findsOneWidget);
      });

      testWidgets('lista mostra o cartão com total e etapa atual', (
        tester,
      ) async {
        ObrasService.instance.definirParaTeste(
          obras: [
            obraExemplo(
              status: {
                EtapaId.preparacao: StatusEtapa.concluida,
                EtapaId.aluguelEquipamentos: StatusEtapa.iniciada,
              },
            ),
            obraExemplo(id: 'b2'),
          ],
        );
        await abrir(tester, const ObrasScreen());
        expect(find.text('Residência Silva'), findsNWidgets(2));
        expect(find.text('Em obra'), findsOneWidget);
        expect(find.text('Planejamento'), findsOneWidget);
        expect(find.textContaining('Aluguel de equipamentos'), findsOneWidget);
        await rolarAteOFim(tester);
      });

      testWidgets('erro de carregamento aparece em texto', (tester) async {
        ObrasService.instance.definirParaTeste(
          erro: 'Não foi possível carregar as obras.',
        );
        await abrir(tester, const ObrasScreen());
        expect(
          find.text('Não foi possível carregar as obras.'),
          findsOneWidget,
        );
      });

      testWidgets('obra: total da planilha, andamento, etapas e materiais', (
        tester,
      ) async {
        ObrasService.instance.definirParaTeste(
          obras: [
            obraExemplo(status: {EtapaId.preparacao: StatusEtapa.concluida}),
          ],
        );
        await abrir(tester, const ObraScreen(id: 'a1'));
        // 153 m² alto padrão = R$ 472.379,30 nas etapas + muro texturado R$ 39.918,15
        await rolarAte(tester, find.textContaining('512.297,45'));
        expect(find.textContaining('512.297,45'), findsOneWidget);
        await rolarAte(tester, find.text('Andamento da obra'));
        expect(find.text('Andamento da obra'), findsOneWidget);
        expect(find.text('2%'), findsOneWidget);
        expect(find.byTooltip('Mais opções'), findsOneWidget);
        await rolarAteOFim(tester);
        expect(find.text('Lista de materiais estimada'), findsOneWidget);
        expect(find.text('Total de referência'), findsOneWidget);
      });

      testWidgets('obra: cliente só acompanha, sem editar nem excluir', (
        tester,
      ) async {
        DiarioService.instance.definirParaTeste();
        ObrasService.instance.definirParaTeste(
          obras: [obraExemplo(papel: Papel.cliente)],
        );
        await abrir(tester, const ObraScreen(id: 'a1'));
        expect(
          find.textContaining('acesso a esta obra é de acompanhamento'),
          findsOneWidget,
        );
        expect(find.byTooltip('Mais opções'), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('obra inexistente mostra aviso', (tester) async {
        ObrasService.instance.definirParaTeste(obras: []);
        await abrir(tester, const ObraScreen(id: 'nao-existe'));
        expect(find.textContaining('Obra não encontrada'), findsOneWidget);
      });

      testWidgets('cadastro: mostra o que falta e não salva vazio', (
        tester,
      ) async {
        await abrir(tester, const ObraFormScreen());
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pumpAndSettle();
        expect(
          find.text('Dê um nome à obra com pelo menos 3 letras.'),
          findsOneWidget,
        );
        expect(find.text('Informe a cidade.'), findsOneWidget);
        await rolarAteOFim(tester);
      });

      testWidgets('cadastro: CEP preenche cidade, estado e endereço', (
        tester,
      ) async {
        await abrir(
          tester,
          ObraFormScreen(
            consultarCep: (_) async => const EnderecoCep(
              logradouro: 'Av. João Ponce de Arruda',
              bairro: 'Vila Operária',
              cidade: 'Rondonópolis',
              uf: 'MT',
            ),
          ),
        );
        expect(find.text('Estado *'), findsNothing);
        await tester.enterText(campoCep, '78720586');
        await tester.pumpAndSettle();
        expect(find.text('Rondonópolis · MT'), findsOneWidget);
        expect(find.text('Av. João Ponce de Arruda'), findsOneWidget);
        expect(find.text('Vila Operária'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pumpAndSettle();
        expect(find.text('Informe a cidade.'), findsNothing);
        expect(find.text('Escolha o estado.'), findsNothing);
      });

      testWidgets('edição: obra antiga mantém o endereço na rua', (
        tester,
      ) async {
        await abrir(tester, ObraFormScreen(obra: obraExemplo()));
        expect(find.text('Rua das Flores, 120'), findsOneWidget);
        expect(find.text('Maringá · PR'), findsOneWidget);
      });

      testWidgets('edição: abre com os dados da obra', (tester) async {
        await abrir(tester, ObraFormScreen(obra: obraExemplo()));
        expect(find.text('Editar obra'), findsOneWidget);
        expect(find.text('Residência Silva'), findsOneWidget);
        expect(find.textContaining('512.297,45'), findsOneWidget);
        await rolarAteOFim(tester);
      });

      testWidgets('simulador: total muda com o padrão', (tester) async {
        await abrir(tester, const SimuladorScreen(podeSalvar: false));
        expect(find.textContaining('273.966,79'), findsWidgets);
        await tester.tap(find.text('Alto padrão'));
        await tester.pumpAndSettle();
        expect(find.textContaining('273.966,79'), findsNothing);
        await rolarAteOFim(tester);
      });
    });
  }
}
