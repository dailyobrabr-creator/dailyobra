import 'package:dailyobra_parceiro/services/periodo_resultados.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meio do mês compara com o mesmo período', () {
    final p = periodoDoMes(
      DateTime(2026, 11, 20),
      DateTime(2026, 11, 3, 14, 30),
    );
    expect(p.de, DateTime(2026, 11));
    expect(p.ate, DateTime(2026, 12));
    expect(p.deAnterior, DateTime(2026, 10));
    expect(p.ateAnterior, DateTime(2026, 10, 3, 14, 30));
    expect(p.mesAtual, isTrue);
  });

  test('dia 31 com mês anterior curto', () {
    final p = periodoDoMes(DateTime(2026, 3), DateTime(2026, 3, 31, 10));
    expect(p.deAnterior, DateTime(2026, 2));
    expect(p.ateAnterior, DateTime(2026, 3));
  });

  test('janeiro compara com dezembro', () {
    final p = periodoDoMes(DateTime(2027, 1), DateTime(2027, 1, 15, 9));
    expect(p.deAnterior, DateTime(2026, 12));
    expect(p.ateAnterior, DateTime(2026, 12, 15, 9));
  });

  test('mês passado compara com o anterior inteiro', () {
    final p = periodoDoMes(DateTime(2026, 10), DateTime(2026, 11, 3));
    expect(p.de, DateTime(2026, 10));
    expect(p.ate, DateTime(2026, 11));
    expect(p.deAnterior, DateTime(2026, 9));
    expect(p.ateAnterior, DateTime(2026, 10));
    expect(p.mesAtual, isFalse);
  });

  test('nome do mês', () {
    expect(nomeDoMes(DateTime(2026, 11)), 'novembro de 2026');
    expect(nomeDoMes(DateTime(2027, 3)), 'março de 2027');
    expect(nomeSoDoMes(DateTime(2026, 11, 20)), 'novembro');
  });

  test('variação', () {
    final atual = periodoDoMes(DateTime(2026, 11), DateTime(2026, 11, 3));
    final passado = periodoDoMes(DateTime(2026, 10), DateTime(2026, 11, 3));
    expect(
      textoVariacao(atual, atual: 1184, anterior: 1000),
      '+18,4% sobre o mesmo período de outubro',
    );
    expect(
      textoVariacao(passado, atual: 1184, anterior: 1000),
      '+18,4% sobre setembro',
    );
    expect(
      textoVariacao(passado, atual: 948, anterior: 1000),
      '−5,2% sobre setembro',
    );
    expect(
      textoVariacao(passado, atual: 1000, anterior: 1000),
      '0,0% sobre setembro',
    );
    expect(
      textoVariacao(passado, atual: 999.9, anterior: 1000),
      '0,0% sobre setembro',
    );
    expect(
      textoVariacao(passado, atual: 500, anterior: 0),
      'sem vendas em setembro para comparar',
    );
    expect(variacao(5, 0), isNull);
    expect(variacao(1184, 1000), closeTo(0.184, 1e-9));
  });
}
