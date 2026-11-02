import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('contraste do texto nos dois temas é pelo menos 4,5:1', () {
    for (final c in [CoresDailyObra.claro, CoresDailyObra.escuro]) {
      expect(contraste(c.texto, c.fundo), greaterThanOrEqualTo(4.5));
      expect(contraste(c.texto, c.superficie), greaterThanOrEqualTo(4.5));
      expect(contraste(c.textoSuave, c.superficie), greaterThanOrEqualTo(4.5));
      expect(contraste(c.textoSuave, c.superficieSutil), greaterThanOrEqualTo(4.5));
      expect(contraste(c.textoSobreAcao, c.acao), greaterThanOrEqualTo(4.5));
      expect(contraste(c.erro, c.superficie), greaterThanOrEqualTo(4.5));
      expect(contraste(c.sucesso, c.superficie), greaterThanOrEqualTo(4.5));
    }
  });

  test('contraste de branco sobre preto é 21', () {
    expect(contraste(Colors.white, Colors.black), closeTo(21, 0.01));
  });

  test('tema escuro usa o laranja da marca no botão principal', () {
    final escuro = AppTheme.escuro(ThemeData.dark().textTheme);
    expect(escuro.brightness, Brightness.dark);
    expect(escuro.colorScheme.primary, CoresDailyObra.escuro.acao);
    expect(escuro.extension<CoresDailyObra>(), CoresDailyObra.escuro);
    final claro = AppTheme.claro(ThemeData.light().textTheme);
    expect(claro.colorScheme.primary, const Color(0xFFA43F05));
  });

  testWidgets('campo de senha tem o olho para mostrar e esconder', (tester) async {
    final controle = TextEditingController(text: 'segredo123');
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro(ThemeData.light().textTheme),
      home: Scaffold(body: CampoTexto(rotulo: 'Senha', controller: controle, senha: true)),
    ));
    bool escondida() => tester.widget<EditableText>(find.byType(EditableText)).obscureText;
    expect(escondida(), isTrue);
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(escondida(), isFalse);
    await tester.tap(find.byTooltip('Esconder senha'));
    await tester.pump();
    expect(escondida(), isTrue);
  });

  testWidgets('campo comum não tem o olho', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CampoTexto(rotulo: 'Nome', controller: TextEditingController())),
    ));
    expect(find.byTooltip('Mostrar senha'), findsNothing);
  });

  testWidgets('PreferenciaTema guarda a escolha', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final p = await PreferenciaTema.carregar();
    expect(p.value, ThemeMode.system);
    await p.definir(ThemeMode.dark);
    final deNovo = await PreferenciaTema.carregar();
    expect(deNovo.value, ThemeMode.dark);
  });

  group('vitrine', () {
    test('cores novas passam de 4,5:1 nos dois temas', () {
      for (final c in [CoresDailyObra.claro, CoresDailyObra.escuro]) {
        expect(contraste(c.textoSobreTopo, c.topo), greaterThanOrEqualTo(4.5));
        expect(contraste(c.textoCartaoEscuro, c.cartaoEscuro), greaterThanOrEqualTo(4.5));
        expect(contraste(c.textoCartaoEscuroSuave, c.cartaoEscuro), greaterThanOrEqualTo(4.5));
        expect(contraste(c.acao, c.destaqueSuave), greaterThanOrEqualTo(4.5));
      }
      expect(CoresDailyObra.claro.topo, const Color(0xFFF36E21));
      expect(CoresDailyObra.escuro.topo, const Color(0xFFF36E21));
    });

    test('as 10 categorias têm cor própria e contraste nos dois temas', () {
      const ids = ['basico', 'estrutura', 'alvenaria', 'cobertura', 'hidraulica', 'eletrica', 'acabamento', 'pintura', 'loucas-metais', 'ferramentas'];
      for (final brilho in Brightness.values) {
        final fundos = <Color>{};
        for (final id in ids) {
          final cor = coresDaCategoria(id, brilho);
          expect(contraste(cor.icone, cor.fundo), greaterThanOrEqualTo(4.5), reason: '$id $brilho');
          fundos.add(cor.fundo);
        }
        expect(fundos.length, 10, reason: 'cada categoria com fundo diferente');
      }
      expect(coresDaCategoria('xyz', Brightness.light).fundo, coresDaCategoria('basico', Brightness.light).fundo);
      expect(coresDaCategoria('hidraulica', Brightness.light).fundo, const Color(0xFFDCEBFB));
    });

    test('arquivos da marca existem e são PNG', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final nome in ['simbolo.png', 'simbolo_claro.png', 'logo_tela.png']) {
        final dados = await rootBundle.load('assets/marca/$nome');
        expect(dados.getUint32(0), 0x89504E47, reason: nome);
      }
    });
  });
}
