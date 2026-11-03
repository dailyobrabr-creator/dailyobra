import 'dart:convert';
import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ods_de_teste.dart';

void main() {
  test('lê células, repetições e células cobertas', () async {
    const numero = '<table:table-cell office:value-type="float" office:value="12"><text:p>12,000</text:p></table:table-cell>';
    final ods = odsDeTeste([
      linhaOds(celulaOds('Santri ADM')),
      linhaOds('${celulaOds('Produto')}${celulaOds('Nome')}${celulaOds('Disponível')}'),
      linhaOds('${celulaOds('65.097')}${celulaOds('ABAFADOR<text:s/>DE RUIDOS')}$numero'),
      linhaOds('${celulaOds('x', repetir: 2)}<table:covered-table-cell/>'),
      '<table:table-row table:number-rows-repeated="1048000"><table:table-cell table:number-columns-repeated="16384"/></table:table-row>',
    ].join());
    expect(await lerOds(ods), [['Santri ADM'], ['Produto', 'Nome', 'Disponível'], ['65.097', 'ABAFADOR DE RUIDOS', '12'], ['x', 'x']]);
  });

  test('número sai no formato brasileiro, como no .xlsx', () async {
    String numero(String valor) =>
        '<table:table-cell office:value-type="currency" office:value="$valor"><text:p>R\$ x</text:p></table:table-cell>';
    final linha = (await lerOds(odsDeTeste(linhaOds('${numero('2.375')}${numero('1234.5')}${numero('62')}${numero('-3.5')}')))).single;
    expect(linha, ['2,375', '1234,5', '62', '-3,5']);
    expect(lerPreco(linha.first), 2.375);
  });

  test('lê 5.000 linhas', () async {
    final linhas = List.generate(5000, (i) => linhaOds('${celulaOds('$i')}${celulaOds('1,000')}')).join();
    final ods = odsDeTeste('${linhaOds('${celulaOds('Produto')}${celulaOds('Disponível')}')}$linhas');
    expect((await lerOds(ods)).length, 5001);
  });

  group('lerLinhas', () {
    Matcher msg(String m) => throwsA(isA<PlanilhaInvalida>().having((e) => e.mensagem, 'mensagem', m));

    test('lê o arquivo pela extensão sem limite', () async {
      expect(await lerLinhas('estoque.ods', odsDeTeste('${linhaOds(celulaOds('Produto'))}${linhaOds(celulaOds('1'))}')), [['Produto'], ['1']]);
      final csv = 'Produto;Preço\n${List.generate(3001, (i) => 'Item $i;1,00').join('\n')}\n';
      expect((await lerLinhas('a.csv', Uint8List.fromList(utf8.encode(csv)))).length, 3002);
      await expectLater(lerLinhas('lista.pdf', Uint8List(3)), msg('Envie um arquivo .csv, .xlsx ou .ods.'));
    });

    test('arquivo que não abre', () async {
      await expectLater(lerLinhas('a.ods', Uint8List.fromList([1, 2, 3])),
          msg('Não deu para ler o arquivo. Abra no Excel, salve de novo como .xlsx ou .csv e tente outra vez.'));
    });
  });
}
