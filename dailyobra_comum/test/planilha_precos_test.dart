import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ods_de_teste.dart';

const cimento = ItemCatalogo(
  id: 'cimento-cp2-50kg', nome: 'Cimento CP II 50 kg', unidade: 'saco', categoriaId: 'basico', tier: 1,
  sinonimos: ['cimento', 'cp2'],
);
const tijolo = ItemCatalogo(
  id: 'tijolo-8-furos', nome: 'Tijolo cerâmico 8 furos', unidade: 'unidade', categoriaId: 'alvenaria', tier: 1,
  sinonimos: ['tijolo', 'bloco ceramico'],
);
const ferro516 = ItemCatalogo(
  id: 'vergalhao-5-16', nome: 'Vergalhão CA-50 5/16" barra 12 m', unidade: 'barra', categoriaId: 'estrutura', tier: 1,
  sinonimos: ['ferro', 'vergalhao'],
);
const ferro38 = ItemCatalogo(
  id: 'vergalhao-3-8', nome: 'Vergalhão CA-50 3/8" barra 12 m', unidade: 'barra', categoriaId: 'estrutura', tier: 1,
  sinonimos: ['ferro', 'vergalhao'],
);
const piso = ItemCatalogo(
  id: 'revestimento-ceramico', nome: 'Revestimento cerâmico (piso e parede)', unidade: 'm²', categoriaId: 'acabamento', tier: 2,
  sinonimos: ['piso', 'ceramica', 'revestimento'],
);
const catalogo = [cimento, tijolo, ferro516, ferro38, piso];

Uint8List csv(String texto) => Uint8List.fromList(utf8.encode(texto));

List<LinhaImportacao> montar(String texto) {
  final linhas = lerCsv(texto);
  return montarImportacao(linhas, detectarColunas(linhas), catalogo);
}

/// .xlsx mínimo: texto compartilhado (um deles em dois pedaços), texto inline, números e células puladas.
Uint8List xlsxDeTeste() {
  final arquivo = Archive();
  void adicionar(String nome, String xml) => arquivo.addFile(ArchiveFile.bytes(nome, utf8.encode(xml)));
  const cabeca = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  adicionar('[Content_Types].xml', '$cabeca<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>');
  adicionar('xl/workbook.xml', '$cabeca<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Precos" sheetId="1" r:id="rId1"/></sheets></workbook>');
  adicionar('xl/_rels/workbook.xml.rels', '$cabeca<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>');
  adicionar('xl/sharedStrings.xml', '$cabeca<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3"><si><t>Produto</t></si><si><r><t>Pre</t></r><r><t>ço</t></r></si><si><t>CIMENTO CP II 50KG</t></si></sst>');
  adicionar('xl/worksheets/sheet1.xml', '$cabeca<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
      '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="inlineStr"><is><t>Un</t></is></c></row>'
      '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2"><v>45.9</v></c></row>'
      '<row r="3"><c r="B3"><v>1234</v></c></row>'
      '</sheetData></worksheet>');
  return ZipEncoder().encodeBytes(arquivo);
}

void main() {
  group('lerCsv', () {
    test('ponto e vírgula, aspas com separador dentro, BOM e quebra do Windows', () {
      expect(lerCsv('﻿Produto;Preço\r\n"Cal; 20 kg";12,5\r\n'), [['Produto', 'Preço'], ['Cal; 20 kg', '12,5']]);
    });

    test('vírgula e tabulação', () {
      expect(lerCsv('Produto,Preço\n"Cal, 20 kg","12,5"\n'), [['Produto', 'Preço'], ['Cal, 20 kg', '12,5']]);
      expect(lerCsv('Produto\tPreço\nCal\t12,5\n'), [['Produto', 'Preço'], ['Cal', '12,5']]);
    });

    test('aspa de polegada no meio do texto não abre citação', () {
      expect(lerCsv('Produto;Preço\nTUBO PVC 3/4";12,50\nREGISTRO 1/2";30\n'),
          [['Produto', 'Preço'], ['TUBO PVC 3/4"', '12,50'], ['REGISTRO 1/2"', '30']]);
    });

    test('aspas duplas dentro do texto', () {
      expect(lerCsv('Produto;Preço\n"Tubo ""100""";30\n')[1], ['Tubo "100"', '30']);
    });
  });

  group('lerPreco', () {
    test('formatos brasileiros, ponto decimal, milhar e texto junto', () {
      expect(lerPreco('R\$ 1.234,56'), 1234.56);
      expect(lerPreco('1234,56'), 1234.56);
      expect(lerPreco('45.90'), 45.9);
      expect(lerPreco('1.234'), 1234);
      expect(lerPreco('45,90 / sc'), 45.9);
      expect(lerPreco('45,9'), 45.9);
    });

    test('ponto decimal com três casas começando em zero não é milhar', () {
      expect(lerPreco('0.125'), 0.125);
      expect(lerPreco('0.350'), 0.35);
    });

    test('sem número ou zero é inválido', () {
      expect(lerPreco('0'), isNull);
      expect(lerPreco(''), isNull);
      expect(lerPreco('sob consulta'), isNull);
    });
  });

  group('detectarColunas', () {
    test('nomes variados no cabeçalho', () {
      final c = detectarColunas([['SKU', 'Descrição', 'UN', 'Valor unitário', 'Preço promocional']]);
      expect([c.codigo, c.nome, c.unidade, c.preco, c.promocao, c.linhaCabecalho], [0, 1, 2, 3, 4, 0]);
      expect(c.completas, isTrue);
    });

    test('coluna Item numerada não vira o nome quando há Descrição', () {
      final c = detectarColunas([['Item', 'Código', 'Descrição', 'Un', 'Valor']]);
      expect([c.nome, c.codigo, c.unidade, c.preco], [2, 1, 3, 4]);
    });

    test('título e linha vazia antes do cabeçalho', () {
      final c = detectarColunas([['Tabela de preços - novembro'], [''], ['Produto', 'Preço']]);
      expect([c.linhaCabecalho, c.nome, c.preco], [2, 0, 1]);
    });

    test('cabeçalho desconhecido fica para a loja escolher', () {
      final c = detectarColunas([['Mercadoria', 'Custo']]);
      expect(c.completas, isFalse);
      expect(c.copyWith(nome: 0, preco: 1).completas, isTrue);
    });
  });

  group('lerXlsx e lerPlanilha', () {
    test('primeira planilha com texto compartilhado, inline, número e célula pulada', () async {
      const esperado = [['Produto', 'Preço', 'Un'], ['CIMENTO CP II 50KG', '45,9'], ['', '1234']];
      expect(lerXlsx(xlsxDeTeste()), esperado);
      expect(await lerPlanilha('tabela.xlsx', xlsxDeTeste()), esperado);
    });

    test('ods também', () async {
      final ods = odsDeTeste('${linhaOds('${celulaOds('Produto')}${celulaOds('Preço')}')}${linhaOds('${celulaOds('CAL')}${celulaOds('12')}')}');
      expect(await lerPlanilha('tabela.ods', ods), [['Produto', 'Preço'], ['CAL', '12']]);
    });

    test('formato desconhecido', () async {
      await expectLater(lerPlanilha('lista.pdf', Uint8List(3)),
          throwsA(isA<PlanilhaInvalida>().having((e) => e.mensagem, 'mensagem', 'Envie um arquivo .csv, .xlsx ou .ods.')));
    });

    test('linhas vazias no meio e no fim são descartadas', () async {
      expect(await lerPlanilha('a.csv', csv('Produto;Preço\n\nCAL;12\n;\n')), [['Produto', 'Preço'], ['CAL', '12']]);
    });

    test('CSV salvo pelo Excel em Latin-1 mantém os acentos', () async {
      expect((await lerPlanilha('a.csv', Uint8List.fromList(latin1.encode('Produto;Preço\nCAL;12\n'))))[0], ['Produto', 'Preço']);
    });

    test('vazia e só com cabeçalho', () async {
      Matcher msg(String m) => throwsA(isA<PlanilhaInvalida>().having((e) => e.mensagem, 'mensagem', m));
      await expectLater(lerPlanilha('a.csv', csv('')), msg('A planilha está vazia.'));
      await expectLater(lerPlanilha('a.csv', csv('Produto;Preço\n')), msg('A planilha só tem o cabeçalho.'));
    });

    test('até 3.000 produtos', () async {
      String linhas(int n) => 'Produto;Preço\n${List.generate(n, (i) => 'Item $i;1,00').join('\n')}\n';
      expect((await lerPlanilha('a.csv', csv(linhas(maxLinhasImportacao)))).length, maxLinhasImportacao + 1);
      await expectLater(lerPlanilha('a.csv', csv(linhas(maxLinhasImportacao + 1))),
          throwsA(isA<PlanilhaInvalida>().having((e) => e.mensagem, 'mensagem', 'A planilha passa de 3.000 produtos. Divida em partes.')));
    });
  });

  group('montarImportacao', () {
    test('ligado marcado, escolher e fora desmarcados', () {
      final l = montar('Produto;Preço\nCIMENTO CP II 50KG VOTORAN;45,90\nVERGALHAO CA-50 BARRA 12M;52,00\nMANGUEIRA DE JARDIM 20M;30,00\n');
      expect([l[0].grupo, l[0].item?.id, l[0].preco, l[0].marcada, l[0].numero], [GrupoImportacao.ligado, cimento.id, 45.9, true, 2]);
      expect([l[1].grupo, l[1].marcada, l[1].candidatos.length], [GrupoImportacao.escolher, false, 2]);
      expect([l[2].grupo, l[2].marcada], [GrupoImportacao.fora, false]);
    });

    test('começa depois do cabeçalho achado', () {
      final l = montar('Tabela de preços\n\nProduto;Preço\nCIMENTO CP II 50KG;45,90\n');
      expect(l.length, 1);
      expect(l.single.numero, 4);
    });

    test('unidade diferente vem desmarcada', () {
      final l = montar('Produto;Preço;Unidade\nCIMENTO CP II 50KG;45,90;CX\nTIJOLO 8 FUROS;1,35;UN\n');
      expect(l[0].avisos, contains(AvisoImportacao.unidadeDiferente));
      expect(l[0].marcada, isFalse);
      expect(l[0].unidadePlanilha, 'CX');
      expect(l[1].marcada, isTrue);
    });

    test('repetidos: só o mais barato fica marcado', () {
      final l = montar('Produto;Preço\nCIMENTO CP II 50KG VOTORAN;45,90\nCIMENTO CP II 50KG CAUE;44,50\n');
      expect([l[0].marcada, l[0].avisos.contains(AvisoImportacao.repetido)], [false, true]);
      expect(l[1].marcada, isTrue);
    });

    test('preço inválido vem desmarcado e volta ao corrigir', () {
      final l = montar('Produto;Preço\nTIJOLO 8 FUROS;sob consulta\n').single;
      expect([l.preco, l.marcada, l.avisos.contains(AvisoImportacao.precoInvalido)], [null, false, true]);
      expect(l.copyWith(preco: 1.4, marcada: true).avisos, isNot(contains(AvisoImportacao.precoInvalido)));
    });

    test('promoção maior ou igual ao preço é ignorada', () {
      final l = montar('Produto;Preço;Preço promocional\nCIMENTO CP II 50KG;45,00;50,00\nTIJOLO 8 FUROS;1,35;1,20\n');
      expect([l[0].promocao, l[0].avisos.contains(AvisoImportacao.promocaoIgnorada)], [null, true]);
      expect(l[1].promocao, 1.2);
    });

    test('escolher o candidato confere a unidade de novo', () {
      final l = montar('Produto;Preço;Unidade\nVERGALHAO CA-50 BARRA 12M;52,00;KG\n').single;
      final escolhida = l.copyWith(item: ferro516);
      expect(escolhida.item?.id, ferro516.id);
      expect(escolhida.avisos, contains(AvisoImportacao.unidadeDiferente));
    });

    test('linha com menos colunas que o cabeçalho é lida sem erro', () {
      final l = montar('Produto;Preço;Unidade\nCIMENTO CP II 50KG;45,90\n').single;
      expect([l.preco, l.unidadePlanilha, l.marcada], [45.9, null, true]);
    });
  });

  group('ofertasDaImportacao', () {
    test('só as marcadas, com a loja; promoção só com validade', () {
      final l = montar('Produto;Preço;Promoção\nCIMENTO CP II 50KG;45,90;42,00\nVERGALHAO CA-50 BARRA 12M;52,00;\n');
      final sem = ofertasDaImportacao(l, lojaId: 'l1');
      expect(sem.map((o) => (o.lojaId, o.itemId, o.preco, o.precoPromocional)), [('l1', cimento.id, 45.9, null)]);
      final ate = DateTime(2026, 11, 9);
      final com = ofertasDaImportacao([l[0], l[1].copyWith(item: ferro516, marcada: true)], lojaId: 'l1', promoAte: ate);
      expect(com.map((o) => (o.itemId, o.precoPromocional, o.promoAte)), [(cimento.id, 42.0, ate), (ferro516.id, null, null)]);
    });

    test('repetido marcado de novo pela loja não duplica a oferta', () {
      final l = montar('Produto;Preço\nCIMENTO CP II 50KG VOTORAN;45,90\nCIMENTO CP II 50KG CAUE;44,50\n');
      final ofertas = ofertasDaImportacao([l[0].copyWith(marcada: true), l[1]], lojaId: 'l1');
      expect(ofertas.map((o) => (o.itemId, o.preco)), [(cimento.id, 44.5)]);
    });
  });
}
