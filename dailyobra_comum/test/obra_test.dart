import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

LinhaResultado linha(EtapaId etapa, double total) =>
    LinhaResultado(etapa: etapa, nome: etapa.codigo, descricao: '', area: 1, custoM2: total, maoDeObra: 0, material: total, total: total);

void main() {
  test('lerNumero aceita formato brasileiro e ponto decimal', () {
    expect(lerNumero('153'), 153);
    expect(lerNumero('153,5'), 153.5);
    expect(lerNumero('1.153,5'), 1153.5);
    expect(lerNumero('153.5'), 153.5);
    expect(lerNumero('10.000'), 10000);
    expect(lerNumero('1.234.567'), 1234567);
    expect(lerNumero('1.000,50'), 1000.5);
    expect(lerNumero('10.50'), 10.5);
    expect(lerNumero('0.500'), .5);
    expect(lerNumero('1.5000'), 1.5);
    expect(lerNumero('').isNaN, isTrue);
    expect(lerNumero('abc').isNaN, isTrue);
  });

  test('parâmetros reproduzem o caso salvo na planilha', () {
    final c = Calculo.de(const ParametrosObra(area: '153', padrao: Padrao.alto, laje: true));
    expect(c.erro, isNull);
    expect(c.resultado!.etapas.length, 15);
    expect((c.resultado!.total - 472379.30).abs() < 0.01, isTrue);
  });

  test('só inclui adicionais marcados', () {
    final e = const ParametrosObra(area: '100', muroFrente: '12', muroTerreno: '300', jardimAtivo: true).paraEntrada();
    expect(e.muro, isNull);
    expect(e.jardim, TipoJardim.grama);
  });

  test('JSON é o mesmo formato do app web e volta igual', () {
    const p = ParametrosObra(
      area: '153,5', padrao: Padrao.mediaAlta, laje: false, cobertura: TipoCobertura.telhadoAparente, aguas: 3,
      muroAtivo: true, muroFrente: '12', muroTerreno: '300', muroAcabamento: AcabamentoMuro.reboco2Lados,
    );
    final j = p.toJson();
    expect(j['padrao'], 'media_alta');
    expect(j['cobertura'], 'telhado_aparente');
    expect((j['muro'] as Map)['acabamento'], 'reboco_2_lados');
    final volta = ParametrosObra.fromJson(j);
    expect(volta.toJson(), j);
  });

  test('JSON incompleto de obra antiga usa os padrões', () {
    final p = ParametrosObra.fromJson({'area': '90'});
    expect(p.area, '90');
    expect(p.padrao, Padrao.medio);
    expect(p.laje, isTrue);
    expect(p.muroAtivo, isFalse);
  });

  test('validarDados exige nome, cidade e UF', () {
    expect(validarDados(const DadosObra()).keys.toSet(), {'nome', 'cidade', 'uf'});
    expect(validarDados(const DadosObra(nome: 'Casa Silva', cidade: 'Maringá', uf: 'PR', inicioPrevisto: '2026-11-10')), isEmpty);
  });

  test('progresso pondera etapas concluídas pelo custo', () {
    final etapas = [linha(EtapaId.preparacao, 100), linha(EtapaId.alvenaria, 300)];
    expect(progresso(etapas, {}), 0);
    expect(progresso(etapas, {EtapaId.preparacao: StatusEtapa.concluida}), 25);
    expect(progresso(etapas, {EtapaId.preparacao: StatusEtapa.concluida, EtapaId.alvenaria: StatusEtapa.iniciada}), 25);
    expect(progresso(etapas, {EtapaId.preparacao: StatusEtapa.concluida, EtapaId.alvenaria: StatusEtapa.concluida}), 100);
  });

  test('etapaAtual prioriza bloqueada ou em andamento, depois a primeira não concluída', () {
    final etapas = [linha(EtapaId.preparacao, 1), linha(EtapaId.alvenaria, 1), linha(EtapaId.pintura, 1)];
    expect(etapaAtual(etapas, {})?.etapa, EtapaId.preparacao);
    expect(etapaAtual(etapas, {EtapaId.preparacao: StatusEtapa.concluida})?.etapa, EtapaId.alvenaria);
    expect(etapaAtual(etapas, {EtapaId.pintura: StatusEtapa.iniciada})?.etapa, EtapaId.pintura);
    expect(etapaAtual(etapas, {EtapaId.alvenaria: StatusEtapa.bloqueada, EtapaId.pintura: StatusEtapa.iniciada})?.etapa, EtapaId.alvenaria);
    expect(
      etapaAtual(etapas, {for (final e in etapas) e.etapa: StatusEtapa.concluida}),
      isNull,
    );
  });
}
