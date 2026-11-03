import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/screens/configuracoes_screen.dart';
import 'package:dailyobra_parceiro/services/cep_service.dart';
import 'package:dailyobra_parceiro/services/loja_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio.dart';

const secoes = [
  'Perfil da loja',
  'Endereço e horário',
  'Entrega e pedido mínimo',
  'Pagamento',
  'Equipe',
  'Aparência',
  'Conta',
];

Finder campoDoEndereco(String nome) => find.descendant(
  of: find.byKey(Key('endereco-$nome')),
  matching: find.byType(TextField),
);

Finder campoRotulado(String rotulo) => find.descendant(
  of: find.widgetWithText(CampoTexto, rotulo),
  matching: find.byType(TextField),
);

Future<EnderecoCep?> buscarCepFalso(String cep) async => const EnderecoCep(
  logradouro: 'R. Fernando Corrêa da Costa',
  bairro: 'Vila Operária',
  cidade: 'Rondonópolis',
  uf: 'MT',
);

void preparar({
  PapelLoja papel = PapelLoja.dono,
  DadosLoja dados = const DadosLoja(cnpj: '11222333000181'),
}) => LojaService.instance.definirParaTeste(
  loja: minhaLoja,
  papel: papel,
  dados: dados,
);

Future<PreferenciaTema> abrirConfiguracoes(
  WidgetTester tester, {
  required bool escuro,
  String? secao,
}) async {
  SharedPreferences.setMockInitialValues({});
  final tema = await PreferenciaTema.carregar();
  await abrir(
    tester,
    ConfiguracoesScreen(tema: tema, buscarCep: buscarCepFalso),
    escuro: escuro,
  );
  if (secao != null) {
    await rolarAte(tester, find.text(secao));
    await tester.tap(find.text(secao));
    await tester.pumpAndSettle();
  }
  return tema;
}

Future<void> salvar(WidgetTester tester) async {
  await rolarAte(tester, find.widgetWithText(FilledButton, 'Salvar'));
  await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
  await tester.pump();
}

/// Deixa o aviso rápido sair da tela antes de o teste terminar.
Future<void> esperarAviso(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  for (final escuro in [false, true]) {
    group(escuro ? 'escuro' : 'claro', () {
      testWidgets('lista as seções para o dono', (tester) async {
        preparar();
        await abrirConfiguracoes(tester, escuro: escuro);
        for (final secao in secoes) {
          await rolarAte(tester, find.text(secao));
          expect(find.text(secao), findsOneWidget);
        }
      });

      testWidgets('perfil salva só nome, descrição e WhatsApp', (tester) async {
        preparar();
        await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Perfil da loja',
        );
        await tester.enterText(campoRotulado('Nome da loja *'), 'Casa Nova');
        await tester.enterText(campoRotulado('Sobre a loja'), 'Tudo para obra');
        await salvar(tester);
        await tester.pumpAndSettle();
        expect(LojaService.instance.atualizacoesDeTeste.single, {
          'nome': 'Casa Nova',
          'descricao': 'Tudo para obra',
          'whatsapp': minhaLoja.whatsapp,
        });
      });

      testWidgets('perfil pede o nome', (tester) async {
        preparar();
        await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Perfil da loja',
        );
        await tester.enterText(campoRotulado('Nome da loja *'), 'A');
        await salvar(tester);
        expect(find.text('Informe o nome da loja.'), findsOneWidget);
        expect(LojaService.instance.atualizacoesDeTeste, isEmpty);
        await esperarAviso(tester);
      });

      testWidgets('entrega salva frete e pedido mínimo', (tester) async {
        preparar();
        await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Entrega e pedido mínimo',
        );
        await tester.enterText(campoRotulado('Frete (R\$)'), '35,50');
        await tester.enterText(campoRotulado('Pedido mínimo (R\$)'), '200');
        await salvar(tester);
        await tester.pumpAndSettle();
        expect(LojaService.instance.atualizacoesDeTeste.single, {
          'frete_fixo': 35.5,
          'pedido_minimo': 200.0,
        });
      });

      testWidgets('entrega recusa valor inválido', (tester) async {
        preparar();
        await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Entrega e pedido mínimo',
        );
        await tester.enterText(campoRotulado('Frete (R\$)'), 'abc');
        await salvar(tester);
        expect(find.text('Confira o frete e o pedido mínimo.'), findsOneWidget);
        expect(LojaService.instance.atualizacoesDeTeste, isEmpty);
        await esperarAviso(tester);
      });

      testWidgets('pagamento salva a chave pix em loja_pix', (tester) async {
        preparar();
        await abrirConfiguracoes(tester, escuro: escuro, secao: 'Pagamento');
        final campo = find.byKey(const ValueKey('chave-pix'));
        await tester.enterText(campo, '66999990000');
        await salvar(tester);
        expect(
          find.text(
            'Chave PIX inválida. Use CPF, CNPJ, e-mail, celular com +55 ou chave aleatória.',
          ),
          findsOneWidget,
        );
        expect(LojaService.instance.chavesDeTeste, isEmpty);
        await esperarAviso(tester);
        await tester.enterText(campo, '+5566999990000');
        await salvar(tester);
        await tester.pumpAndSettle();
        // A chave vai para loja_pix (só a equipe lê), não para a linha da loja
        expect(LojaService.instance.chavesDeTeste, ['+5566999990000']);
        expect(LojaService.instance.atualizacoesDeTeste, isEmpty);
      });

      testWidgets('pagamento mostra a chave salva', (tester) async {
        preparar(
          dados: const DadosLoja(
            cnpj: '11222333000181',
            chavePix: '+5566999990000',
          ),
        );
        await abrirConfiguracoes(tester, escuro: escuro, secao: 'Pagamento');
        expect(find.text('+5566999990000'), findsOneWidget);
      });

      testWidgets('chave pix com pontuação é salva só com números', (
        tester,
      ) async {
        preparar();
        await abrirConfiguracoes(tester, escuro: escuro, secao: 'Pagamento');
        await tester.enterText(
          find.byKey(const ValueKey('chave-pix')),
          '11.222.333/0001-81',
        );
        await salvar(tester);
        await tester.pumpAndSettle();
        expect(LojaService.instance.chavesDeTeste, ['11222333000181']);
      });

      testWidgets('salva endereço e horário', (tester) async {
        preparar(
          dados: const DadosLoja(
            cnpj: '11222333000181',
            endereco: 'Lojas Vila Operária (matriz)',
            horario: 'Seg a sex 7h às 18h',
          ),
        );
        await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Endereço e horário',
        );
        expect(
          find.text('Endereço atual: Lojas Vila Operária (matriz)'),
          findsOneWidget,
        );
        await tester.enterText(campoDoEndereco('cep'), '78700000');
        await tester.pumpAndSettle();
        await tester.enterText(campoDoEndereco('numero'), '1500');
        await rolarAte(tester, find.byKey(const Key('horario-6')));
        await tester.tap(find.byKey(const Key('horario-6')));
        await tester.pumpAndSettle();
        await salvar(tester);
        await tester.pumpAndSettle();
        final enviado = LojaService.instance.atualizacoesDeTeste.single;
        expect(enviado['cep'], '78700000');
        expect(enviado['logradouro'], 'R. Fernando Corrêa da Costa');
        expect(enviado['numero'], '1500');
        expect(enviado['cidade'], 'Rondonópolis');
        expect(enviado['uf'], 'MT');
        expect(enviado['horario'], 'Seg a sex 7h às 18h; sáb 8h às 18h');
        expect(enviado.containsKey('endereco'), isFalse);
      });

      testWidgets('sem mexer no endereço e no horário, nada é gravado', (
        tester,
      ) async {
        preparar(
          dados: const DadosLoja(
            cnpj: '11222333000181',
            endereco: 'Lojas Vila Operária (matriz)',
            horario: 'Comercial',
          ),
        );
        await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Endereço e horário',
        );
        await salvar(tester);
        expect(find.text('Nada mudou.'), findsOneWidget);
        expect(LojaService.instance.atualizacoesDeTeste, isEmpty);
        await esperarAviso(tester);
      });

      testWidgets('loja antiga que muda só a cidade precisa do CEP', (
        tester,
      ) async {
        preparar(
          dados: const DadosLoja(
            cnpj: '11222333000181',
            endereco: 'Lojas Vila Operária (matriz)',
          ),
        );
        await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Endereço e horário',
        );
        await rolarAte(tester, campoDoEndereco('cidade'));
        await tester.enterText(campoDoEndereco('cidade'), 'Rondonópolis');
        await salvar(tester);
        expect(LojaService.instance.atualizacoesDeTeste, isEmpty);
        expect(find.text('Informe o CEP com 8 números.'), findsWidgets);
        await esperarAviso(tester);
      });

      testWidgets('abre com o endereço em campos', (tester) async {
        preparar(
          dados: const DadosLoja(
            cnpj: '11222333000181',
            endereco: 'R. Fernando Corrêa da Costa, 1500 – Vila Operária, CEP 78700-000',
            cep: '78700000',
            logradouro: 'R. Fernando Corrêa da Costa',
            numero: '1500',
            bairro: 'Vila Operária',
          ),
        );
        await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Endereço e horário',
        );
        expect(find.textContaining('Endereço atual'), findsNothing);
        String valor(String nome) =>
            tester.widget<TextField>(campoDoEndereco(nome)).controller!.text;
        expect(valor('cep'), '78700-000');
        expect(valor('rua'), 'R. Fernando Corrêa da Costa');
        expect(valor('numero'), '1500');
      });

      testWidgets('aparência troca o tema', (tester) async {
        preparar();
        final tema = await abrirConfiguracoes(
          tester,
          escuro: escuro,
          secao: 'Aparência',
        );
        await tester.tap(find.text('Escuro'));
        await tester.pumpAndSettle();
        expect(tema.value, ThemeMode.dark);
      });

      testWidgets('conta confirma antes de sair', (tester) async {
        preparar();
        await abrirConfiguracoes(tester, escuro: escuro, secao: 'Conta');
        await tester.tap(find.text('Sair da conta'));
        await tester.pumpAndSettle();
        expect(find.text('Sair da conta?'), findsOneWidget);
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
      });

      testWidgets('vendedor vê a loja sem editar', (tester) async {
        preparar(papel: PapelLoja.vendedor);
        await abrirConfiguracoes(tester, escuro: escuro);
        await rolarAteOFim(tester);
        expect(find.text('Equipe'), findsNothing);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Perfil da loja'));
        await tester.pumpAndSettle();
        expect(
          find.text('Só o dono ou o gerente altera os dados da loja.'),
          findsOneWidget,
        );
        expect(find.byTooltip('Trocar logo'), findsNothing);
        await rolarAteOFim(tester);
        expect(find.text('Salvar'), findsNothing);
      });

      testWidgets('no computador a seção abre ao lado da lista', (
        tester,
      ) async {
        preparar();
        SharedPreferences.setMockInitialValues({});
        final tema = await PreferenciaTema.carregar();
        await abrirLargura(
          tester,
          ConfiguracoesScreen(tema: tema, buscarCep: buscarCepFalso),
          1366,
          escuro: escuro,
        );
        expect(find.byKey(const ValueKey('chave-pix')), findsNothing);
        await tester.tap(find.text('Pagamento').first);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('chave-pix')), findsOneWidget);
        // A lista continua na tela: a seção abriu ao lado, não por cima
        expect(find.text('Aparência'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
