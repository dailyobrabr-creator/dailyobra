import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

final hoje = DateTime(2026, 11, 20);

DatasEtapa datas(String ip, String fp, {String? ir, String? fr}) => DatasEtapa(
  inicioPrevisto: DateTime.parse(ip),
  fimPrevisto: DateTime.parse(fp),
  inicioReal: ir == null ? null : DateTime.parse(ir),
  fimReal: fr == null ? null : DateTime.parse(fr),
);

LinhaResultado linha(EtapaId etapa, double total) =>
    LinhaResultado(etapa: etapa, nome: etapa.codigo, descricao: '', area: 100, custoM2: 1, maoDeObra: 0, material: 0, total: total);

void main() {
  test('lê as datas do banco', () {
    final d = DatasEtapa.fromJson(const {'inicio_previsto': '2026-11-01', 'fim_previsto': '2026-11-20', 'inicio_real': null, 'fim_real': null});
    expect(d.inicioPrevisto, DateTime(2026, 11, 1));
    expect(d.fimPrevisto, DateTime(2026, 11, 20));
    expect(d.inicioReal, isNull);
    expect(d.temPrevisto, isTrue);
    expect(const DatasEtapa().temPrevisto, isFalse);
  });

  test('prepara as datas para salvar', () {
    final d = datas('2026-11-01', '2026-11-20', ir: '2026-11-02');
    expect(d.paraSalvar(EtapaId.fundacao), {
      'etapa': 'fundacao',
      'inicio_previsto': '2026-11-01',
      'fim_previsto': '2026-11-20',
      'inicio_real': '2026-11-02',
      'fim_real': null,
    });
    expect(d.paraSalvar(EtapaId.fundacao, comReal: false), {'etapa': 'fundacao', 'inicio_previsto': '2026-11-01', 'fim_previsto': '2026-11-20'});
  });

  group('atraso', () {
    test('sem datas não há atraso', () {
      expect(diasDeAtraso(const DatasEtapa(), StatusEtapa.prevista, hoje), 0);
    });

    test('dentro do prazo não há atraso', () {
      expect(diasDeAtraso(datas('2026-11-15', '2026-11-30'), StatusEtapa.iniciada, hoje), 0);
    });

    test('no último dia ainda não atrasou', () {
      expect(diasDeAtraso(datas('2026-11-01', '2026-11-20'), StatusEtapa.iniciada, hoje), 0);
    });

    test('passou do fim sem concluir', () {
      expect(diasDeAtraso(datas('2026-11-01', '2026-11-15'), StatusEtapa.iniciada, hoje), 5);
    });

    test('bloqueada também atrasa', () {
      expect(diasDeAtraso(datas('2026-11-01', '2026-11-15'), StatusEtapa.bloqueada, hoje), 5);
    });

    test('devia ter começado e não começou', () {
      expect(diasDeAtraso(datas('2026-11-17', '2026-12-30'), StatusEtapa.prevista, hoje), 3);
    });

    test('concluída no prazo', () {
      expect(diasDeAtraso(datas('2026-11-01', '2026-11-15', fr: '2026-11-15'), StatusEtapa.concluida, hoje), 0);
    });

    test('concluída depois do prazo conta só até o dia em que terminou', () {
      expect(diasDeAtraso(datas('2026-11-01', '2026-11-15', fr: '2026-11-18'), StatusEtapa.concluida, hoje), 3);
    });

    test('atravessar o horário de verão não muda a conta', () {
      expect(diasEntre(DateTime(2026, 10, 1), DateTime(2026, 12, 1)), 61);
    });
  });

  test('resumo da obra conta só o que ainda está em aberto', () {
    final r = resumirCronograma(
      etapas: [EtapaId.fundacao, EtapaId.alvenaria, EtapaId.pintura, EtapaId.limpeza],
      datas: {
        EtapaId.fundacao: datas('2026-11-01', '2026-11-10', fr: '2026-11-12'),
        EtapaId.alvenaria: datas('2026-11-01', '2026-11-15'),
        EtapaId.pintura: datas('2026-11-10', '2026-12-20'),
      },
      status: const {EtapaId.fundacao: StatusEtapa.concluida},
      hoje: hoje,
    );
    expect(r.comDatas, 3);
    expect(r.atrasadas, 2);
    expect(r.maiorAtraso, 10);
    expect(r.emDia, isFalse);
    expect(r.texto, '2 etapas atrasadas');
  });

  test('resumo em dia e sem datas', () {
    final dia = resumirCronograma(etapas: [EtapaId.pintura], datas: {EtapaId.pintura: datas('2026-11-15', '2026-12-20')}, status: const {EtapaId.pintura: StatusEtapa.iniciada}, hoje: hoje);
    expect(dia.emDia, isTrue);
    expect(dia.texto, 'Em dia');
    final sem = resumirCronograma(etapas: [EtapaId.pintura], datas: const {}, status: const {}, hoje: hoje);
    expect(sem.comDatas, 0);
    expect(sem.texto, 'Sem datas ainda');
    final uma = resumirCronograma(etapas: [EtapaId.pintura], datas: {EtapaId.pintura: datas('2026-11-01', '2026-11-02')}, status: const {}, hoje: hoje);
    expect(uma.texto, '1 etapa atrasada');
  });

  group('sugestão de datas', () {
    final etapas = [linha(EtapaId.fundacao, 100), linha(EtapaId.alvenaria, 300), linha(EtapaId.pintura, 100)];

    test('etapas em sequência, do início ao fim da obra', () {
      final s = sugerirCronograma(etapas: etapas, inicio: DateTime(2026, 11, 1), fim: DateTime(2027, 1, 19));
      expect(s[EtapaId.fundacao]!.inicioPrevisto, DateTime(2026, 11, 1));
      expect(s[EtapaId.pintura]!.fimPrevisto, DateTime(2027, 1, 19));
      expect(s[EtapaId.alvenaria]!.inicioPrevisto, s[EtapaId.fundacao]!.fimPrevisto!.add(const Duration(days: 1)));
    });

    test('etapa mais cara fica com mais dias', () {
      final s = sugerirCronograma(etapas: etapas, inicio: DateTime(2026, 11, 1), fim: DateTime(2027, 1, 19));
      int dias(EtapaId e) => diasEntre(s[e]!.inicioPrevisto!, s[e]!.fimPrevisto!);
      expect(dias(EtapaId.alvenaria), greaterThan(dias(EtapaId.fundacao) * 2));
    });

    test('prazo curto dá pelo menos um dia a cada etapa e respeita o fim', () {
      final s = sugerirCronograma(etapas: etapas, inicio: DateTime(2026, 11, 1), fim: DateTime(2026, 11, 2));
      expect(s.length, 3);
      expect(s[EtapaId.pintura]!.fimPrevisto!.isBefore(DateTime(2026, 11, 4)), isTrue);
      for (final d in s.values) {
        expect(d.fimPrevisto!.isBefore(d.inicioPrevisto!), isFalse);
      }
    });

    test('mantém as datas reais que já existem', () {
      final s = sugerirCronograma(
        etapas: etapas,
        inicio: DateTime(2026, 11, 1),
        fim: DateTime(2027, 1, 19),
        atuais: {EtapaId.fundacao: datas('2026-01-01', '2026-02-01', ir: '2026-10-30')},
      );
      expect(s[EtapaId.fundacao]!.inicioReal, DateTime(2026, 10, 30));
    });

    test('duração estimada cresce com a área e fica dentro de um limite', () {
      expect(diasEstimados(120), 240);
      expect(diasEstimados(10), 90);
      expect(diasEstimados(5000), 720);
    });
  });

  group('pendência', () {
    test('lê do banco', () {
      final p = Pendencia.fromJson(const {
        'id': 'p1',
        'descricao': 'Trinca na parede',
        'etapa': 'alvenaria',
        'responsavel_id': 'u2',
        'responsavel_nome': 'João',
        'prazo': '2026-11-15',
        'foto_path': 'o1/a.jpg',
        'situacao': 'aberta',
        'posso_mexer': true,
      });
      expect(p.etapa, EtapaId.alvenaria);
      expect(p.responsavelNome, 'João');
      expect(p.prazo, DateTime(2026, 11, 15));
      expect(p.resolvida, isFalse);
      expect(p.possoMexer, isTrue);
    });

    test('prepara para salvar', () {
      final p = Pendencia(descricao: 'x', etapa: EtapaId.alvenaria, responsavelId: 'u2', prazo: DateTime(2026, 11, 15), fotoPath: 'o1/a.jpg');
      expect(p.paraSalvar(), {'descricao': 'x', 'etapa': 'alvenaria', 'responsavel_id': 'u2', 'prazo': '2026-11-15', 'foto_path': 'o1/a.jpg'});
      expect(const Pendencia(descricao: 'x').paraSalvar(), {'descricao': 'x', 'etapa': null, 'responsavel_id': null, 'prazo': null, 'foto_path': null});
    });

    test('dias vencida', () {
      expect(Pendencia(descricao: 'x', prazo: DateTime(2026, 11, 15)).diasVencida(hoje), 5);
      expect(Pendencia(descricao: 'x', prazo: DateTime(2026, 11, 20)).diasVencida(hoje), 0);
      expect(Pendencia(descricao: 'x', prazo: DateTime(2026, 11, 25)).diasVencida(hoje), 0);
      expect(const Pendencia(descricao: 'x').diasVencida(hoje), 0);
      expect(Pendencia(descricao: 'x', prazo: DateTime(2026, 11, 15), resolvida: true).diasVencida(hoje), 0);
    });
  });

  test('aviso da obra junta atraso e pendência vencida', () {
    const dois = ResumoCronograma(comDatas: 5, atrasadas: 2, maiorAtraso: 5);
    const um = ResumoCronograma(comDatas: 5, atrasadas: 1, maiorAtraso: 1);
    const emDia = ResumoCronograma(comDatas: 5, atrasadas: 0, maiorAtraso: 0);
    expect(alertaDaObra(dois, 0), '2 etapas atrasadas, a maior com 5 dias.');
    expect(alertaDaObra(um, 1), '1 etapa atrasada, a maior com 1 dia. 1 pendência vencida.');
    expect(alertaDaObra(emDia, 3), '3 pendências vencidas.');
    expect(alertaDaObra(emDia, 0), isNull);
  });

  test('obra sabe as pendências abertas e vencidas', () {
    final o = Obra(
      id: 'o1',
      papel: Papel.admin,
      dados: const DadosObra(nome: 'x'),
      parametros: const ParametrosObra(area: '100'),
      statusEtapas: const {},
      criadaEm: hoje,
      atualizadaEm: hoje,
      prazosAbertos: [null, DateTime(2026, 11, 15), DateTime(2026, 11, 25)],
    );
    expect(o.pendenciasAbertas, 3);
    expect(o.pendenciasVencidas(hoje), 1);
    final mudou = o.comStatus(EtapaId.alvenaria, StatusEtapa.concluida);
    expect(mudou.pendenciasAbertas, 3);
  });
}
