// Mesmos casos de src/lib/orcamento/test/materiais.test.ts do app web.

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

void perto(double atual, double esperado, [double tol = 0.01]) =>
    expect((atual - esperado).abs() <= tol, isTrue, reason: 'esperado $esperado, obtido $atual');

double exato(EtapaMateriais e) => e.itens.fold(0, (s, i) => s + i.quantidadeExata * i.precoRef);

MateriaisDisponiveis disponivel(ResultadoMateriais r) {
  expect(r, isA<MateriaisDisponiveis>());
  return r as MateriaisDisponiveis;
}

void main() {
  // Casa de referência do padrão econômico: 50,84 m², térrea. Valores = material/m² gravado na planilha × área.
  test('bate com a planilha Projetos Calculos na casa de referência econômica', () {
    final r = disponivel(listarMateriais(const EntradaOrcamento(areaConstruida: 50.84, padrao: Padrao.economico, laje: true)));
    final por = {for (final e in r.etapas) e.etapa: e};
    perto(exato(por[EtapaId.preparacao]!), 14.059624967217411 * 50.84); // Obra.Cinza.eco!G1
    perto(exato(por[EtapaId.fundacaoLaje]!), 84.46701654537951 * 50.84); // Obra.Cinza.eco!G34
    perto(exato(por[EtapaId.alvenaria]!), 127.3917863775554 * 50.84); // Obra.Cinza.eco!G119
    perto(exato(por[EtapaId.coberturaPlatibanda]!), 119.82699393793506 * 50.84); // Obra.Cinza.eco!G142
    perto(exato(por[EtapaId.hidraulica]!), 66.66663024824847 * 50.84); // Eletrica.hidra.eco!G28
    // elétrica sem a mão de obra elétrica (R$ 3.000), que é serviço e não material
    perto(exato(por[EtapaId.eletrica]!), 166.6973176576374 * 50.84 - 3000);
  });

  test('itens fixos não escalam com a área', () {
    final r = disponivel(listarMateriais(const EntradaOrcamento(areaConstruida: 300, padrao: Padrao.alto, laje: true)));
    expect(r.consolidado.firstWhere((i) => i.item == 'Relógio de agua').quantidade, 1);
  });

  test('quantidade dobra quando a área dobra', () {
    double cimento(double area) => disponivel(listarMateriais(EntradaOrcamento(areaConstruida: area, padrao: Padrao.mediaAlta, laje: false)))
        .consolidado
        .firstWhere((i) => i.item == 'Cimento 50kg')
        .quantidadeExata;
    perto(cimento(200), 2 * cimento(100), 1e-9);
  });

  test('unidades inteiras arredondam para cima', () {
    final r = disponivel(listarMateriais(const EntradaOrcamento(
      areaConstruida: 87.3, padrao: Padrao.economico, laje: false, cobertura: TipoCobertura.telhadoAparente, aguas: 1,
    )));
    for (final i in r.consolidado) {
      expect(i.quantidade >= i.quantidadeExata - 1e-9, isTrue);
      if (['und', 'br', 'gl'].contains(i.unidade)) expect(i.quantidade, i.quantidade.ceilToDouble());
    }
  });

  test('telhado aparente usa a seção do número de águas', () {
    double telhado(int aguas) => disponivel(listarMateriais(EntradaOrcamento(
          areaConstruida: 100, padrao: Padrao.alto, laje: false, cobertura: TipoCobertura.telhadoAparente, aguas: aguas,
        ))).etapas.firstWhere((e) => e.etapa == EtapaId.telhadoAparente).totalRef;
    expect(telhado(1), isNot(telhado(2)));
  });

  test('padrão médio fica indisponível com motivo', () {
    expect(listarMateriais(const EntradaOrcamento(areaConstruida: 100, padrao: Padrao.medio, laje: true)), isA<MateriaisIndisponiveis>());
  });
}
