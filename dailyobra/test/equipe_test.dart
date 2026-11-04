import 'package:dailyobra/screens/convite_screen.dart';
import 'package:dailyobra/screens/dia_obra_screen.dart';
import 'package:dailyobra/screens/equipe_screen.dart';
import 'package:dailyobra/screens/obra_screen.dart';
import 'package:dailyobra/screens/obras_screen.dart';
import 'package:dailyobra/services/diario_service.dart';
import 'package:dailyobra/services/equipe_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio.dart';

Obra obraDe(FuncaoObra f, {int pessoas = 1}) => Obra(
  id: 'o1',
  papel: switch (f) {
    FuncaoObra.responsavel => Papel.admin,
    FuncaoObra.cliente => Papel.cliente,
    _ => Papel.membro,
  },
  funcao: f,
  pessoas: pessoas,
  dados: const DadosObra(nome: 'Residência Silva', cidade: 'Maringá', uf: 'PR'),
  parametros: const ParametrosObra(area: '120'),
  statusEtapas: const {},
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

const marina = MembroObra(
  id: 'u1',
  nome: 'Marina Duarte',
  funcao: FuncaoObra.responsavel,
  eu: true,
);
const chefe = MembroObra(
  id: 'u1',
  nome: 'Marina Duarte',
  funcao: FuncaoObra.responsavel,
);
const joao = MembroObra(
  id: 'u2',
  nome: 'João Mestre',
  funcao: FuncaoObra.mestre,
);
const ana = MembroObra(
  id: 'u3',
  nome: 'Ana Lima',
  funcao: FuncaoObra.estagiario,
);
final convite = ConviteObra(
  id: 'c1',
  codigo: 'AB12C-3DE45',
  funcao: FuncaoObra.cliente,
  expiraEm: DateTime(2099, 11, 11),
);
const previa = PreviaConvite(
  obra: 'Residência Silva',
  funcao: FuncaoObra.mestre,
  convidadoPor: 'Marina Duarte',
  jaParticipa: false,
);

void preparar({
  List<MembroObra> membros = const [marina, joao, ana],
  List<ConviteObra> convites = const [],
  PreviaConvite? previaDoConvite,
  String? erro,
}) => EquipeService.instance.definirParaTeste(
  membros: membros,
  convites: convites,
  previa: previaDoConvite,
  erro: erro,
);

/// A tela e as janelas são maiores que o celular do teste: rola até o alvo antes de tocar.
Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('lista a equipe com a função de cada um', (tester) async {
        preparar();
        await abrir(
          tester,
          EquipeScreen(obra: obraDe(FuncaoObra.responsavel)),
          escuro: escuro,
        );
        expect(find.text('Marina Duarte (você)'), findsOneWidget);
        expect(find.text('João Mestre'), findsOneWidget);
        expect(find.text('Mestre de obras'), findsOneWidget);
        expect(find.text('Estagiário'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('responsável convida e o convite sai pronto para enviar', (
        tester,
      ) async {
        final enviados = <String>[];
        preparar();
        await abrir(
          tester,
          EquipeScreen(
            obra: obraDe(FuncaoObra.responsavel),
            compartilhar: (t) async => enviados.add(t),
          ),
          escuro: escuro,
        );
        await tester.tap(find.text('Convidar'));
        await tester.pumpAndSettle();
        for (final f in FuncaoObra.convidaveis) {
          expect(find.text(f.descricao), findsOneWidget, reason: f.name);
        }
        await tocar(tester, find.text('Cliente'));
        await tocar(tester, find.text('Criar convite'));
        expect(EquipeService.instance.convidadosDeTeste, [FuncaoObra.cliente]);
        expect(enviados.single, contains('Residência Silva'));
        expect(enviados.single, contains('como Cliente'));
        expect(find.textContaining('TESTE-00001'), findsOneWidget);
      });

      testWidgets('convite aberto reenvia, copia e cancela', (tester) async {
        final enviados = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              SystemChannels.platform,
              (_) async => null,
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );
        preparar(convites: [convite]);
        await abrir(
          tester,
          EquipeScreen(
            obra: obraDe(FuncaoObra.responsavel),
            compartilhar: (t) async => enviados.add(t),
          ),
          escuro: escuro,
        );
        expect(find.text('AB12C-3DE45'), findsOneWidget);
        expect(find.text('Cliente · vale até 11/11'), findsOneWidget);
        await tocar(tester, find.text('Enviar'));
        expect(enviados.single, contains('AB12C-3DE45'));
        await tocar(tester, find.text('Copiar'));
        expect(find.text('Convite copiado.'), findsOneWidget);
        await tocar(tester, find.text('Cancelar'));
        expect(EquipeService.instance.canceladosDeTeste, ['c1']);
        expect(find.text('AB12C-3DE45'), findsNothing);
      });

      testWidgets('responsável muda a função de alguém', (tester) async {
        preparar();
        await abrir(
          tester,
          EquipeScreen(obra: obraDe(FuncaoObra.responsavel)),
          escuro: escuro,
        );
        await tocar(tester, find.byTooltip('Opções de João Mestre'));
        await tocar(tester, find.text('Mudar função'));
        await tocar(tester, find.text('Empreiteiro'));
        await tocar(tester, find.text('Salvar'));
        expect(EquipeService.instance.mudancasDeTeste, [
          ('u2', FuncaoObra.empreiteiro),
        ]);
        expect(find.text('Empreiteiro'), findsOneWidget);
      });

      testWidgets('responsável remove alguém depois de confirmar', (
        tester,
      ) async {
        preparar();
        await abrir(
          tester,
          EquipeScreen(obra: obraDe(FuncaoObra.responsavel)),
          escuro: escuro,
        );
        await tocar(tester, find.byTooltip('Opções de Ana Lima'));
        await tocar(tester, find.text('Remover da obra'));
        expect(EquipeService.instance.removidosDeTeste, isEmpty);
        await tocar(tester, find.text('Remover'));
        expect(EquipeService.instance.removidosDeTeste, ['u3']);
        expect(find.text('Ana Lima'), findsNothing);
      });

      testWidgets('responsável não tem opções sobre si mesmo nem sai da obra', (
        tester,
      ) async {
        preparar();
        await abrir(
          tester,
          EquipeScreen(obra: obraDe(FuncaoObra.responsavel)),
          escuro: escuro,
        );
        expect(find.byTooltip('Opções de Marina Duarte'), findsNothing);
        expect(find.text('Sair da obra'), findsNothing);
      });

      testWidgets('quem não é responsável vê a equipe, sem convidar', (
        tester,
      ) async {
        preparar(
          membros: const [
            chefe,
            MembroObra(
              id: 'u2',
              nome: 'João Mestre',
              funcao: FuncaoObra.mestre,
              eu: true,
            ),
          ],
          convites: [convite],
        );
        await abrir(
          tester,
          EquipeScreen(obra: obraDe(FuncaoObra.mestre)),
          escuro: escuro,
        );
        expect(find.text('João Mestre (você)'), findsOneWidget);
        expect(find.text('Convidar'), findsNothing);
        expect(find.text('AB12C-3DE45'), findsNothing);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
      });

      testWidgets('cada pessoa pode sair da obra', (tester) async {
        preparar(
          membros: const [
            chefe,
            MembroObra(
              id: 'u2',
              nome: 'João Mestre',
              funcao: FuncaoObra.mestre,
              eu: true,
            ),
          ],
        );
        await abrir(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EquipeScreen(obra: obraDe(FuncaoObra.mestre)),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
          escuro: escuro,
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tocar(tester, find.text('Sair da obra'));
        await tocar(tester, find.text('Sair'));
        expect(EquipeService.instance.removidosDeTeste, ['u2']);
        expect(find.text('abrir'), findsOneWidget);
      });

      testWidgets('falha ao carregar mostra aviso e deixa tentar de novo', (
        tester,
      ) async {
        preparar(erro: 'Sem conexão.');
        await abrir(
          tester,
          EquipeScreen(obra: obraDe(FuncaoObra.responsavel)),
          escuro: escuro,
        );
        expect(find.text('Sem conexão.'), findsOneWidget);
        expect(find.text('Tentar de novo'), findsOneWidget);
      });

      testWidgets('quem tem código vê a prévia antes de entrar', (
        tester,
      ) async {
        preparar(previaDoConvite: previa);
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.mestre)],
        );
        await abrir(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => entrarComConvite(context),
                child: const Text('abrir'),
              ),
            ),
          ),
          escuro: escuro,
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'ab12c3de45');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Marina Duarte convidou você'),
          findsOneWidget,
        );
        expect(find.text('Residência Silva'), findsOneWidget);
        expect(find.text('Mestre de obras'), findsOneWidget);
        expect(EquipeService.instance.aceitosDeTeste, isEmpty);
        await tester.tap(find.text('Entrar na obra'));
        await tester.pumpAndSettle();
        expect(EquipeService.instance.aceitosDeTeste, ['ab12c3de45']);
        expect(find.byType(ObraScreen), findsOneWidget);
      });

      testWidgets('código errado fica na janela com o motivo', (tester) async {
        preparar(erro: 'Código não encontrado. Confira e tente de novo.');
        await abrir(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => entrarComConvite(context),
                child: const Text('abrir'),
              ),
            ),
          ),
          escuro: escuro,
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'errado');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(
          find.text('Código não encontrado. Confira e tente de novo.'),
          findsOneWidget,
        );
        expect(find.text('Entrar na obra'), findsNothing);
      });

      testWidgets('quem digita o código de uma obra sua é avisado', (
        tester,
      ) async {
        preparar(
          previaDoConvite: const PreviaConvite(
            obra: 'x',
            funcao: FuncaoObra.mestre,
            convidadoPor: 'y',
            jaParticipa: true,
          ),
        );
        await abrir(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => entrarComConvite(context),
                child: const Text('abrir'),
              ),
            ),
          ),
          escuro: escuro,
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'ab12c3de45');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.text('Você já participa desta obra.'), findsOneWidget);
      });

      testWidgets('link do convite abre direto na prévia', (tester) async {
        preparar(previaDoConvite: previa);
        await abrir(
          tester,
          const AbreConvite(
            codigo: 'AB12C-3DE45',
            child: Scaffold(body: Text('app')),
          ),
          escuro: escuro,
        );
        expect(find.text('Entrar na obra'), findsOneWidget);
      });

      testWidgets('reabrir o link de uma obra sua não incomoda', (
        tester,
      ) async {
        preparar(
          previaDoConvite: const PreviaConvite(
            obra: 'x',
            funcao: FuncaoObra.mestre,
            convidadoPor: 'y',
            jaParticipa: true,
          ),
        );
        await abrir(
          tester,
          const AbreConvite(
            codigo: 'AB12C-3DE45',
            child: Scaffold(body: Text('app')),
          ),
          escuro: escuro,
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('app'), findsOneWidget);
      });

      testWidgets('sem link não abre nada', (tester) async {
        preparar();
        await abrir(
          tester,
          const AbreConvite(codigo: null, child: Scaffold(body: Text('app'))),
          escuro: escuro,
        );
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('lista de obras tem entrada para o código', (tester) async {
        preparar();
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.responsavel)],
        );
        await abrir(tester, const ObrasScreen(), escuro: escuro);
        await rolarAte(tester, find.text('Tenho um código de convite'));
        expect(find.text('Tenho um código de convite'), findsOneWidget);
      });

      testWidgets('lista vazia também aceita o código', (tester) async {
        preparar();
        ObrasService.instance.definirParaTeste(obras: []);
        await abrir(tester, const ObrasScreen(), escuro: escuro);
        expect(find.text('Tenho um código de convite'), findsOneWidget);
      });

      testWidgets('obra mostra a entrada da equipe', (tester) async {
        DiarioService.instance.definirParaTeste();
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.responsavel, pessoas: 3)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.text('Equipe'));
        expect(find.text('3 pessoas'), findsOneWidget);
      });

      testWidgets('empreiteiro vê o andamento e não vê valores', (
        tester,
      ) async {
        DiarioService.instance.definirParaTeste();
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.empreiteiro)],
        );
        await abrir(tester, const ObraScreen(id: 'o1'), escuro: escuro);
        await rolarAte(tester, find.byType(FaixaObra));
        expect(find.text('Andamento da obra'), findsOneWidget);
        await tester.tap(find.byType(FaixaObra));
        await tester.pumpAndSettle();
        await rolarAteOFim(tester);
        expect(find.byType(BlocoTotal), findsNothing);
        expect(find.textContaining('R\$'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empreiteiro não vê o total na lista de obras', (
        tester,
      ) async {
        ObrasService.instance.definirParaTeste(
          obras: [obraDe(FuncaoObra.empreiteiro)],
        );
        await abrir(tester, const ObrasScreen(), escuro: escuro);
        expect(find.textContaining('R\$'), findsNothing);
        expect(find.text('Residência Silva'), findsOneWidget);
      });

      testWidgets('estagiário salva rascunho e não finaliza', (tester) async {
        DiarioService.instance.definirParaTeste();
        await abrir(
          tester,
          DiaObraScreen(
            obra: obraDe(FuncaoObra.estagiario),
            data: DateTime(2026, 11, 3),
          ),
          escuro: escuro,
        );
        expect(find.text('Salvar rascunho'), findsOneWidget);
        expect(find.text('Finalizar o dia'), findsNothing);
      });

      testWidgets('empreiteiro salva rascunho e não finaliza', (tester) async {
        DiarioService.instance.definirParaTeste();
        await abrir(
          tester,
          DiaObraScreen(
            obra: obraDe(FuncaoObra.empreiteiro),
            data: DateTime(2026, 11, 3),
          ),
          escuro: escuro,
        );
        expect(find.text('Salvar rascunho'), findsOneWidget);
        expect(find.text('Finalizar o dia'), findsNothing);
      });

      testWidgets('mestre finaliza', (tester) async {
        DiarioService.instance.definirParaTeste();
        await abrir(
          tester,
          DiaObraScreen(
            obra: obraDe(FuncaoObra.mestre),
            data: DateTime(2026, 11, 3),
          ),
          escuro: escuro,
        );
        expect(find.text('Finalizar o dia'), findsOneWidget);
      });
    });
  }
}
