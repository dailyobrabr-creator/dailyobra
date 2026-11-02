// Mesmos casos de src/lib/orcamento/test/orcamento.test.ts do app web.

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

void perto(double atual, double esperado, [double tol = 0.01]) =>
    expect((atual - esperado).abs() <= tol, isTrue, reason: 'esperado $esperado, obtido $atual');

void main() {
  // Caso salvo na própria planilha (aba Res1): 153 m², alto padrão, com laje, térrea, platibanda.
  test('bate com a planilha: 153 m², alto padrão, laje, térrea, platibanda', () {
    final r = calcularOrcamento(const EntradaOrcamento(areaConstruida: 153, padrao: Padrao.alto, laje: true));

    // etapa: [mão de obra (col E), material (col G), total (col I)]
    const esperado = <EtapaId, List<double>>{
      EtapaId.preparacao: [4892.050423716666, 4338.2333946166655, 9230.283818333332],
      EtapaId.aluguelEquipamentos: [13687.380000000001, 0, 13687.380000000001],
      EtapaId.fundacaoLaje: [7569.685165434617, 11354.527748151926, 18924.212913586543],
      EtapaId.estruturaLaje: [18177.917760000004, 27266.876640000002, 45444.794400000006],
      EtapaId.alvenaria: [11820.1374, 17730.2061, 29550.3435],
      EtapaId.calhasPlatibanda: [8281.1862, 8619.193800000001, 16900.38],
      EtapaId.coberturaPlatibanda: [30464.463455661586, 31707.910943647774, 62172.37439930936],
      EtapaId.eletrica: [13912.9326, 14480.807400000002, 28393.74],
      EtapaId.hidraulica: [10485.617130333334, 10913.601503, 21399.218633333334],
      EtapaId.forro: [12468.672, 10201.640727272727, 22670.312727272725],
      EtapaId.revestimentos: [24153.913192301716, 36230.86978845257, 60384.78298075429],
      EtapaId.pintura: [24412.637952676, 23455.279601590664, 47867.91755426666],
      EtapaId.esquadrias: [16888.905000000002, 25333.357500000002, 42222.262500000004],
      EtapaId.acabamentos: [13209, 30820.999999999996, 44030],
      EtapaId.limpeza: [6650.910000000001, 2850.3900000000003, 9501.300000000001],
    };

    expect(r.etapas.map((l) => l.etapa).toList(), esperado.keys.toList());
    for (final l in r.etapas) {
      final e = esperado[l.etapa]!;
      perto(l.maoDeObra, e[0]);
      perto(l.material, e[1]);
      perto(l.total, e[2]);
    }
    perto(r.totalEtapas, 472379.3034268563); // Res1!H38
  });

  test('adicionais batem com a planilha (muro, gourmet, jardim)', () {
    final r = calcularOrcamento(const EntradaOrcamento(
      areaConstruida: 153,
      padrao: Padrao.alto,
      laje: true,
      muro: Muro(frente: 12, areaTerreno: 290, acabamento: AcabamentoMuro.texturado),
      gourmet: TipoGourmet.churrasqueiraIlha,
      jardim: TipoJardim.gramaVegetacao,
    ));
    final por = {for (final a in r.adicionais) a.item: a};
    perto(por[ItemAdicional.muro]!.total, 39918.14928321808); // Res1!W40
    perto(por[ItemAdicional.gourmet]!.total, 16256.25); // Res1!V44
    perto(por[ItemAdicional.jardim]!.total, 11283.75); // Res1!V46
  });

  test('piscina de alvenaria tem preço (na planilha a fórmula dá #N/A)', () {
    final r = calcularOrcamento(const EntradaOrcamento(
      areaConstruida: 153,
      padrao: Padrao.alto,
      laje: true,
      piscina: Piscina(comprimento: 3, largura: 2, tipo: TipoPiscina.alvenaria),
    ));
    perto(r.adicionais.first.total, 10 * 2800);
  });

  test('sobrado: cobertura incide só sobre a área do térreo', () {
    final r = calcularOrcamento(const EntradaOrcamento(areaConstruida: 200, areaPisosSuperiores: 80, padrao: Padrao.medio, laje: true));
    expect(r.etapas.firstWhere((l) => l.etapa == EtapaId.coberturaPlatibanda).area, 120);
    expect(r.etapas.firstWhere((l) => l.etapa == EtapaId.alvenaria).area, 200);
  });

  test('sem laje usa fundação e estrutura simples', () {
    final ids = calcularOrcamento(const EntradaOrcamento(areaConstruida: 50, padrao: Padrao.economico, laje: false)).etapas.map((l) => l.etapa);
    expect(ids, containsAll([EtapaId.fundacao, EtapaId.estrutura]));
    expect(ids, isNot(contains(EtapaId.fundacaoLaje)));
    expect(ids, isNot(contains(EtapaId.estruturaLaje)));
  });

  test('telhado aparente usa calhas de telhado e o tipo de telhado pelas águas', () {
    const base = EntradaOrcamento(areaConstruida: 100, padrao: Padrao.medio, laje: false, cobertura: TipoCobertura.telhadoAparente);
    final duas = calcularOrcamento(base).etapas.map((l) => l.etapa);
    final tres = calcularOrcamento(const EntradaOrcamento(
      areaConstruida: 100, padrao: Padrao.medio, laje: false, cobertura: TipoCobertura.telhadoAparente, aguas: 3,
    )).etapas.map((l) => l.etapa);
    expect(duas, containsAll([EtapaId.calhasTelhado, EtapaId.telhadoAparente]));
    expect(tres, contains(EtapaId.telhado3Aguas));
  });

  test('mão de obra + material = total em toda etapa e padrão', () {
    for (final padrao in Padrao.values) {
      final r = calcularOrcamento(EntradaOrcamento(areaConstruida: 87.5, padrao: padrao, laje: true, cobertura: TipoCobertura.telhadoAparente, aguas: 1));
      for (final l in r.etapas) {
        perto(l.maoDeObra + l.material, l.total, 1e-6);
      }
    }
  });

  test('entradas inválidas são recusadas com mensagem', () {
    expect(() => calcularOrcamento(const EntradaOrcamento(areaConstruida: 0, padrao: Padrao.medio, laje: true)), throwsA(isA<EntradaInvalida>()));
    expect(() => calcularOrcamento(const EntradaOrcamento(areaConstruida: double.nan, padrao: Padrao.medio, laje: true)), throwsA(isA<EntradaInvalida>()));
    expect(
      () => calcularOrcamento(const EntradaOrcamento(areaConstruida: 100, areaPisosSuperiores: 100, padrao: Padrao.medio, laje: true)),
      throwsA(isA<EntradaInvalida>()),
    );
  });
}
