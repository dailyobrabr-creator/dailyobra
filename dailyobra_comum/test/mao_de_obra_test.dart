import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

LinhaDinheiro linha(EtapaId e, double orcado, [double realizado = 0]) => LinhaDinheiro(etapa: e, nome: e.codigo, estimado: orcado, orcado: orcado, proprio: false, realizado: realizado);

ResumoDinheiro resumo(List<LinhaDinheiro> linhas, {double semEtapa = 0, double adicionais = 0, double mudancas = 0}) => ResumoDinheiro(linhas: linhas, semEtapa: semEtapa, adicionais: adicionais, mudancas: mudancas);

const contrato = Contrato(id: 'c1', empreiteiro: 'João', servico: 'Reboco', etapa: EtapaId.alvenaria, valor: 10000);

Medicao medicao(int n, double pct, double valor, {bool aprovada = true, bool paga = false}) => Medicao(id: 'm$n', contratoId: 'c1', numero: n, data: DateTime(2026, 11, n), percentual: pct, valor: valor, aprovada: aprovada, paga: paga);

void main() {
  final hoje = DateTime(2026, 11, 4);

  group('diárias', () {
    const ze = Diarista(id: 'd1', nome: 'Zé', diaria: 200);
    const ana = Diarista(id: 'd2', nome: 'Ana', diaria: 0);
    const bia = Diarista(id: 'd3', nome: 'Bia');

    test('lê do banco', () {
      final d = Diarista.fromJson(const {'id': 'd1', 'nome': 'Zé', 'funcao': null, 'diaria': 200.5, 'ativo': false});
      expect((d.nome, d.funcao, d.diaria, d.ativo), ('Zé', '', 200.5, false));
      final p = Presenca.fromJson(const {'diarista_id': 'd1', 'data': '2026-11-03', 'dias': 0.5, 'pago': true});
      expect((p.diaristaId, p.data, p.dias, p.pago), ('d1', DateTime(2026, 11, 3), 0.5, true));
    });

    test('texto dos dias', () {
      expect(textoDeDias(1), '1 dia');
      expect(textoDeDias(0.5), '0,5 dias');
      expect(textoDeDias(3), '3 dias');
      expect(textoDeDias(2.5), '2,5 dias');
    });

    test('soma só o que não foi pago', () {
      final r = diariasEmAberto(
        [ze, ana],
        [
          Presenca(diaristaId: 'd1', data: hoje, dias: 1),
          Presenca(diaristaId: 'd1', data: DateTime(2026, 11, 3), dias: 0.5),
          Presenca(diaristaId: 'd1', data: DateTime(2026, 11, 2), dias: 1, pago: true),
        ],
      );
      expect(r.single.diarista.nome, 'Zé');
      expect(r.single.dias, 1.5);
      expect(r.single.valor, 300);
    });

    test('quem já saiu da lista continua a receber', () {
      final r = diariasEmAberto([const Diarista(id: 'd1', nome: 'Zé', diaria: 100, ativo: false)], [Presenca(diaristaId: 'd1', data: hoje, dias: 1)]);
      expect(r.single.valor, 100);
    });

    test('sem valor definido, ou sem ver valores, não entra na soma', () {
      final r = diariasEmAberto([ze, ana, bia], [Presenca(diaristaId: 'd1', data: hoje, dias: 1), Presenca(diaristaId: 'd2', data: hoje, dias: 1), Presenca(diaristaId: 'd3', data: hoje, dias: 1)]);
      expect(r.map((a) => a.valor), [200, null, null]);
      expect(totalEmAberto(r), 200);
    });
  });

  group('contratos', () {
    test('lê do banco', () {
      final c = Contrato.fromJson(const {'id': 'c1', 'empreiteiro': 'João', 'usuario': 'u1', 'servico': 'Reboco', 'etapa': 'alvenaria', 'valor': 10000, 'encerrado': true});
      expect((c.empreiteiro, c.usuario, c.etapa, c.valor, c.encerrado), ('João', 'u1', EtapaId.alvenaria, 10000, true));
      expect(c.paraSalvar()['etapa'], 'alvenaria');
      final m = Medicao.fromJson(const {'id': 'm1', 'contrato_id': 'c1', 'numero': 2, 'data': '2026-11-03', 'percentual': 33.33, 'valor': null, 'observacao': null, 'aprovada': true, 'pago': true, 'pago_em': '2026-11-04'});
      expect((m.numero, m.percentual, m.valor, m.situacao, m.pagaEm), (2, 33.33, null, SituacaoMedicao.paga, DateTime(2026, 11, 4)));
    });

    test('situação da medição', () {
      expect(medicao(1, 10, 1, aprovada: false).situacao, SituacaoMedicao.aguardando);
      expect(medicao(1, 10, 1).situacao, SituacaoMedicao.aprovada);
      expect(medicao(1, 10, 1, paga: true).situacao, SituacaoMedicao.paga);
    });

    test('resume o contrato', () {
      final r = resumirContratos([contrato], [medicao(2, 60, 3000), medicao(1, 30, 3000, paga: true)]).single;
      expect(r.medicoes.map((m) => m.numero), [1, 2]);
      expect(r.percentual, 60);
      expect(r.medido, 6000);
      expect(r.pago, 3000);
      expect(r.aPagar, 3000);
      expect(r.aMedir, 4000);
      expect(r.podeMedir, isTrue);
    });

    test('só as medições do próprio contrato', () {
      final outra = Medicao(contratoId: 'c9', numero: 1, data: hoje, percentual: 10, valor: 1);
      expect(resumirContratos([contrato], [outra]).single.medicoes, isEmpty);
    });

    test('medição pendente, contrato encerrado e 100% param a próxima', () {
      expect(resumirContratos([contrato], [medicao(1, 30, 3000, aprovada: false)]).single.podeMedir, isFalse);
      expect(resumirContratos([contrato], [medicao(1, 100, 10000)]).single.podeMedir, isFalse);
      const fechado = Contrato(id: 'c1', empreiteiro: 'J', servico: 'S', valor: 100, encerrado: true);
      final r = resumirContratos([fechado], const []).single;
      expect(r.podeMedir, isFalse);
      expect(r.aMedir, 0);
    });

    test('quem acompanha contratos', () {
      expect(FuncaoObra.responsavel.veContratos, isTrue);
      expect(FuncaoObra.mestre.veContratos, isTrue);
      expect(FuncaoObra.empreiteiro.veContratos, isTrue);
      expect(FuncaoObra.estagiario.veContratos, isFalse);
      expect(FuncaoObra.cliente.veContratos, isFalse);
    });

    test('texto do percentual', () {
      expect(textoDePercentual(60), '60%');
      expect(textoDePercentual(33.33), '33,33%');
    });
  });

  group('caixa', () {
    test('lê a entrada do banco', () {
      final e = EntradaCaixa.fromJson(const {'id': 'e1', 'descricao': 'Sinal', 'valor': 5000, 'data': '2026-11-03', 'recebido': true});
      expect((e.descricao, e.valor, e.recebido), ('Sinal', 5000, true));
      expect(e.paraSalvar()['data'], '2026-11-03');
    });

    test('saldo atual é o que entrou menos o que saiu', () {
      final p = preverCaixa(
        hoje: hoje,
        resumo: resumo(const [], semEtapa: 1500),
        datas: const {},
        status: const {},
        entradas: [EntradaCaixa(descricao: 'Sinal', valor: 5000, data: hoje, recebido: true), EntradaCaixa(descricao: 'Parcela', valor: 9999, data: DateTime(2026, 12, 20))],
      );
      expect(p.recebido, 5000);
      expect(p.pago, 1500);
      expect(p.saldoAtual, 3500);
    });

    test('mostra 8 semanas, a partir da atual', () {
      final p = preverCaixa(hoje: hoje, resumo: resumo(const []), datas: const {}, status: const {}, entradas: const []);
      expect(p.semanas, hasLength(8));
      expect(p.semanas.first.semana.inicio, DateTime(2026, 11, 2));
      expect(p.semanas.last.semana.inicio, DateTime(2026, 12, 21));
    });

    test('entrada prevista cai na semana dela, e vencida na atual', () {
      final p = preverCaixa(
        hoje: hoje,
        resumo: resumo(const []),
        datas: const {},
        status: const {},
        entradas: [EntradaCaixa(descricao: 'a', valor: 100, data: DateTime(2026, 11, 10)), EntradaCaixa(descricao: 'b', valor: 50, data: DateTime(2026, 10, 1))],
      );
      expect(p.semanas[0].entradas, 50);
      expect(p.semanas[1].entradas, 100);
      expect(p.semanas[1].saldo, 150);
    });

    test('o que já está devido sai na semana atual', () {
      final r = resumirContratos([contrato], [medicao(1, 30, 3000)]);
      final p = preverCaixa(hoje: hoje, resumo: resumo(const []), datas: const {}, status: const {}, entradas: const [], diariasAbertas: 500, contratos: r);
      expect(p.aPagarAgora, 3500);
      expect(p.semanas[0].saidas, 3500);
    });

    test('o que falta da etapa se divide pelos dias que restam', () {
      final p = preverCaixa(
        hoje: hoje,
        resumo: resumo([linha(EtapaId.alvenaria, 1400, 700)]),
        datas: {EtapaId.alvenaria: DatasEtapa(inicioPrevisto: DateTime(2026, 11, 9), fimPrevisto: DateTime(2026, 11, 15))},
        status: const {},
        entradas: const [],
      );
      expect(p.semanas[0].saidas, 0);
      expect(p.semanas[1].saidas, closeTo(700, .001));
      expect(p.semData, 0);
    });

    test('etapa atrasada e etapa em andamento olham só para a frente', () {
      final atrasada = preverCaixa(
        hoje: hoje,
        resumo: resumo([linha(EtapaId.fundacao, 700)]),
        datas: {EtapaId.fundacao: DatasEtapa(inicioPrevisto: DateTime(2026, 10, 1), fimPrevisto: DateTime(2026, 10, 20))},
        status: const {},
        entradas: const [],
      );
      expect(atrasada.semanas[0].saidas, 700);
      final andando = preverCaixa(
        hoje: hoje,
        resumo: resumo([linha(EtapaId.fundacao, 700)]),
        datas: {EtapaId.fundacao: DatasEtapa(inicioPrevisto: DateTime(2026, 10, 1), fimPrevisto: DateTime(2026, 11, 10))},
        status: const {},
        entradas: const [],
      );
      expect(andando.semanas[0].saidas, closeTo(500, .001));
      expect(andando.semanas[1].saidas, closeTo(200, .001));
    });

    test('etapa concluída não espera mais gasto', () {
      final p = preverCaixa(
        hoje: hoje,
        resumo: resumo([linha(EtapaId.fundacao, 700)]),
        datas: {EtapaId.fundacao: DatasEtapa(inicioPrevisto: hoje, fimPrevisto: hoje)},
        status: const {EtapaId.fundacao: StatusEtapa.concluida},
        entradas: const [],
      );
      expect(p.semanas[0].saidas, 0);
    });

    test('etapa, adicional e mudança sem data ficam à parte', () {
      final p = preverCaixa(hoje: hoje, resumo: resumo([linha(EtapaId.fundacao, 700)], adicionais: 200, mudancas: 100), datas: const {}, status: const {}, entradas: const []);
      expect(p.semData, 1000);
      expect(p.semanas[0].saidas, 0);
    });

    test('o que passa das 8 semanas fica em depois', () {
      final p = preverCaixa(
        hoje: hoje,
        resumo: resumo([linha(EtapaId.pintura, 700)]),
        datas: {EtapaId.pintura: DatasEtapa(inicioPrevisto: DateTime(2027, 2, 1), fimPrevisto: DateTime(2027, 2, 7))},
        status: const {},
        entradas: const [],
      );
      expect(p.depois, closeTo(700, .001));
    });

    test('medição a pagar não conta duas vezes na etapa', () {
      final r = resumirContratos([contrato], [medicao(1, 30, 300)]);
      final p = preverCaixa(
        hoje: hoje,
        resumo: resumo([linha(EtapaId.alvenaria, 1000)]),
        datas: {EtapaId.alvenaria: DatasEtapa(inicioPrevisto: hoje, fimPrevisto: hoje)},
        status: const {},
        entradas: const [],
        contratos: r,
      );
      expect(p.semanas[0].saidas, closeTo(10000, .001), reason: '300 a pagar e 9700 a medir, maior que o restante do orçado');
      const pequeno = Contrato(id: 'c1', empreiteiro: 'J', servico: 'S', etapa: EtapaId.alvenaria, valor: 310);
      final q = preverCaixa(
        hoje: hoje,
        resumo: resumo([linha(EtapaId.alvenaria, 1000)]),
        datas: {EtapaId.alvenaria: DatasEtapa(inicioPrevisto: hoje, fimPrevisto: hoje)},
        status: const {},
        entradas: const [],
        contratos: resumirContratos([pequeno], [medicao(1, 30, 300)]),
      );
      expect(q.semanas[0].saidas, closeTo(1000, .001));
    });

    test('contrato sem etapa fica sem data', () {
      const solto = Contrato(id: 'c1', empreiteiro: 'J', servico: 'S', valor: 400);
      final p = preverCaixa(hoje: hoje, resumo: resumo(const []), datas: const {}, status: const {}, entradas: const [], contratos: resumirContratos([solto], const []));
      expect(p.semData, 400);
    });

    group('aviso', () {
      test('avisa a primeira semana negativa', () {
        final p = preverCaixa(
          hoje: hoje,
          resumo: resumo([linha(EtapaId.alvenaria, 700)]),
          datas: {EtapaId.alvenaria: DatasEtapa(inicioPrevisto: DateTime(2026, 11, 9), fimPrevisto: DateTime(2026, 11, 15))},
          status: const {},
          entradas: [EntradaCaixa(descricao: 'Sinal', valor: 500, data: hoje, recebido: true)],
        );
        expect(p.alerta, 'Na semana de 09/11 a 15/11 o caixa fica negativo em ${brl.format(200)}.');
      });

      test('avisa quando já está negativo', () {
        final p = preverCaixa(hoje: hoje, resumo: resumo(const [], semEtapa: 800), datas: const {}, status: const {}, entradas: [EntradaCaixa(descricao: 'Sinal', valor: 500, data: hoje, recebido: true)]);
        expect(p.alerta, 'O caixa está negativo em ${brl.format(300)}.');
      });

      test('sem entradas lançadas não avisa', () {
        final p = preverCaixa(hoje: hoje, resumo: resumo(const [], semEtapa: 800), datas: const {}, status: const {}, entradas: const []);
        expect(p.alerta, isNull);
      });

      test('caixa que aguenta não avisa', () {
        final p = preverCaixa(hoje: hoje, resumo: resumo(const []), datas: const {}, status: const {}, entradas: [EntradaCaixa(descricao: 'Sinal', valor: 500, data: hoje, recebido: true)]);
        expect(p.alerta, isNull);
      });
    });
  });
}
