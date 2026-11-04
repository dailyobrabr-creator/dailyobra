import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

LinhaResultado linha(EtapaId e) => LinhaResultado(etapa: e, nome: e.codigo, descricao: '', area: 100, custoM2: 1, maoDeObra: 0, material: 0, total: 100);

DiaObra dia(DateTime data, {List<ItemEquipe> equipe = const [], List<Atividade> atividades = const [], List<Ocorrencia> ocorrencias = const [], List<FotoDia> fotos = const []}) =>
    DiaObra(obraId: 'o1', data: data, equipe: equipe, atividades: atividades, ocorrencias: ocorrencias, fotos: fotos);

void main() {
  test('lê a marca do banco', () {
    final m = MarcaEngenheiro.fromJson(const {'nome': 'Duarte', 'registro': 'CREA 1', 'telefone': '65 9', 'email': null, 'logo_path': 'u1/logo.png'});
    expect((m.nome, m.registro, m.email, m.logoPath), ('Duarte', 'CREA 1', '', 'u1/logo.png'));
    expect(m.contato, 'CREA 1 · 65 9');
    expect(const MarcaEngenheiro().contato, '');
  });

  test('lê a mudança do banco', () {
    final m = Mudanca.fromJson(const {'id': 'm1', 'titulo': 'Piso', 'descricao': null, 'valor': 3500.5, 'dias': 5, 'situacao': 'aprovada', 'resposta': 'Ok', 'respondido_por': 'Dona Lia', 'criado_em': '2026-11-03T12:00:00+00:00', 'respondido_em': '2026-11-04T12:00:00+00:00'});
    expect((m.titulo, m.valor, m.dias, m.situacao, m.respondidoPor), ('Piso', 3500.5, 5, SituacaoMudanca.aprovada, 'Dona Lia'));
    expect(m.pendente, isFalse);
    expect(m.respondidaEm!.toUtc(), DateTime.utc(2026, 11, 4, 12));
  });

  test('impacto da mudança', () {
    expect(const Mudanca(titulo: 'x', valor: 3500, dias: 5).impacto, '+ ${brl.format(3500)} · + 5 dias');
    expect(const Mudanca(titulo: 'x', valor: -1200, dias: -1).impacto, '- ${brl.format(1200)} · - 1 dia');
    expect(const Mudanca(titulo: 'x').impacto, '');
    expect(const Mudanca(titulo: 'x', valor: 0, dias: 0).impacto, '');
  });

  test('impacto no prazo não mostra o valor', () {
    expect(const Mudanca(titulo: 'x', valor: 3500, dias: 1).impactoNoPrazo, '+ 1 dia');
    expect(const Mudanca(titulo: 'x', valor: 3500).impactoNoPrazo, '');
  });

  test('registro da resposta', () {
    expect(Mudanca(titulo: 'x', situacao: SituacaoMudanca.aprovada, respondidoPor: 'Dona Lia', respondidaEm: DateTime(2026, 11, 4)).registroDaResposta, 'Aprovada por Dona Lia em 04/11/2026');
    expect(Mudanca(titulo: 'x', situacao: SituacaoMudanca.recusada, respondidaEm: DateTime(2026, 11, 4)).registroDaResposta, 'Recusada em 04/11/2026');
    expect(const Mudanca(titulo: 'x').registroDaResposta, '');
  });

  test('mensagem da mudança para o WhatsApp', () {
    final t = mensagemDaMudanca(nomeDaObra: 'Residência Silva', mudanca: const Mudanca(titulo: 'Trocar o piso', valor: 100));
    expect(t, contains('Residência Silva'));
    expect(t, contains('Trocar o piso'));
    expect(t, contains(brl.format(100)));
    expect(mensagemDaMudanca(nomeDaObra: 'X', mudanca: const Mudanca(titulo: 'Y')).split('\n'), hasLength(3));
  });

  test('só o aprovado soma', () {
    expect(
      somarAprovado(const [
        Mudanca(titulo: 'a', valor: 100, situacao: SituacaoMudanca.aprovada),
        Mudanca(titulo: 'b', valor: -30, situacao: SituacaoMudanca.aprovada),
        Mudanca(titulo: 'c', valor: 999),
        Mudanca(titulo: 'd', valor: 999, situacao: SituacaoMudanca.recusada),
        Mudanca(titulo: 'e', situacao: SituacaoMudanca.aprovada),
      ]),
      70,
    );
  });

  group('semana', () {
    test('vai de segunda a domingo', () {
      final s = SemanaObra.doDia(DateTime(2026, 11, 4));
      expect(s.inicio, DateTime(2026, 11, 2));
      expect(s.fim, DateTime(2026, 11, 8));
      expect(s.texto, '02/11 a 08/11');
    });

    test('domingo fica na semana que começou na segunda', () {
      expect(SemanaObra.doDia(DateTime(2026, 11, 8)).inicio, DateTime(2026, 11, 2));
    });

    test('anda de semana em semana, também na virada do ano', () {
      final s = SemanaObra.doDia(DateTime(2026, 12, 30));
      expect(s.proxima.inicio, DateTime(2027, 1, 4));
      expect(s.proxima.anterior.inicio, s.inicio);
    });

    test('contém do primeiro ao último dia', () {
      final s = SemanaObra.doDia(DateTime(2026, 11, 4));
      expect(s.contem(DateTime(2026, 11, 2, 0, 1)), isTrue);
      expect(s.contem(DateTime(2026, 11, 8, 23, 59)), isTrue);
      expect(s.contem(DateTime(2026, 11, 1)), isFalse);
      expect(s.contem(DateTime(2026, 11, 9)), isFalse);
    });
  });

  group('resumo da semana', () {
    final semana = SemanaObra.doDia(DateTime(2026, 11, 4));

    test('fica só com os dias da semana, em ordem', () {
      final r = resumirSemana([dia(DateTime(2026, 11, 5)), dia(DateTime(2026, 11, 3)), dia(DateTime(2026, 10, 30))], semana);
      expect(r.dias.map((d) => d.data.day), [3, 5]);
    });

    test('sem dias fica vazio', () {
      final r = resumirSemana(const [], semana);
      expect(r.vazio, isTrue);
      expect(r.mediaDePessoas, 0);
    });

    test('serviço repetido aparece uma vez, com o último percentual', () {
      final r = resumirSemana([
        dia(DateTime(2026, 11, 3), atividades: const [Atividade(descricao: 'Reboco', local: 'Sala', percentual: 40)]),
        dia(DateTime(2026, 11, 4), atividades: const [Atividade(descricao: ' reboco ', local: 'SALA', percentual: 70), Atividade(descricao: 'Pintura')]),
      ], semana);
      expect(r.atividades, hasLength(2));
      expect(r.atividades.first.percentual, 70);
    });

    test('média de pessoas só nos dias com equipe', () {
      final r = resumirSemana([
        dia(DateTime(2026, 11, 3), equipe: const [ItemEquipe(funcao: 'a', quantidade: 4)]),
        dia(DateTime(2026, 11, 4), equipe: const [ItemEquipe(funcao: 'a', quantidade: 6)]),
        dia(DateTime(2026, 11, 5)),
      ], semana);
      expect(r.mediaDePessoas, 5);
    });

    test('junta ocorrências e fotos', () {
      final r = resumirSemana([
        dia(DateTime(2026, 11, 3), ocorrencias: const [Ocorrencia(descricao: 'Chuva')], fotos: const [FotoDia(caminho: 'a')]),
        dia(DateTime(2026, 11, 4), fotos: const [FotoDia(caminho: 'b')]),
      ], semana);
      expect(r.ocorrencias, hasLength(1));
      expect(r.fotos.map((f) => f.caminho), ['a', 'b']);
    });
  });

  group('próximos passos', () {
    final etapas = [linha(EtapaId.fundacao), linha(EtapaId.alvenaria), linha(EtapaId.pintura), linha(EtapaId.limpeza)];
    DatasEtapa d(int mes, int dia) => DatasEtapa(inicioPrevisto: DateTime(2026, mes, dia), fimPrevisto: DateTime(2026, mes, dia + 5));

    test('pula o que acabou e o que não tem data, e segue a ordem das datas', () {
      final r = proximasEtapas(
        etapas: etapas,
        datas: {EtapaId.fundacao: d(10, 1), EtapaId.alvenaria: d(12, 1), EtapaId.pintura: d(11, 1)},
        status: const {EtapaId.fundacao: StatusEtapa.concluida},
      );
      expect(r.map((e) => e.nome), ['pintura', 'alvenaria']);
    });

    test('limita a quantidade', () {
      final r = proximasEtapas(etapas: etapas, datas: {EtapaId.fundacao: d(10, 1), EtapaId.alvenaria: d(11, 1), EtapaId.pintura: d(12, 1)}, status: const {}, quantas: 2);
      expect(r, hasLength(2));
    });

    test('previsão de término é a última data', () {
      expect(previsaoDeTermino({EtapaId.fundacao: d(10, 1), EtapaId.pintura: d(12, 1)}), DateTime(2026, 12, 6));
      expect(previsaoDeTermino(const {}), isNull);
    });

    test('mudança aprovada empurra a previsão', () {
      final fim = previsaoDeTermino(
        {EtapaId.pintura: d(12, 1)},
        const [
          Mudanca(titulo: 'a', dias: 5, situacao: SituacaoMudanca.aprovada),
          Mudanca(titulo: 'b', dias: 30),
          Mudanca(titulo: 'c', dias: 30, situacao: SituacaoMudanca.recusada),
        ],
      );
      expect(fim, DateTime(2026, 12, 11));
    });
  });

  group('relatório', () {
    final semana = SemanaObra.doDia(DateTime(2026, 11, 4));

    test('mudanças da semana: as pendentes e as respondidas nela', () {
      final r = mudancasDaSemana([
        const Mudanca(titulo: 'pendente'),
        Mudanca(titulo: 'agora', situacao: SituacaoMudanca.aprovada, respondidaEm: DateTime(2026, 11, 3, 9)),
        Mudanca(titulo: 'antiga', situacao: SituacaoMudanca.recusada, respondidaEm: DateTime(2026, 10, 3)),
      ], semana);
      expect(r.map((m) => m.titulo), ['pendente', 'agora']);
    });

    test('monta com andamento, etapa atual e previsão', () {
      final etapas = [linha(EtapaId.fundacao), linha(EtapaId.alvenaria)];
      final obra = Obra(
        id: 'o1',
        papel: Papel.admin,
        funcao: FuncaoObra.responsavel,
        dados: const DadosObra(nome: 'Casa'),
        parametros: const ParametrosObra(area: '120'),
        statusEtapas: const {EtapaId.fundacao: StatusEtapa.concluida},
        cronograma: {EtapaId.alvenaria: DatasEtapa(inicioPrevisto: DateTime(2026, 12), fimPrevisto: DateTime(2026, 12, 20))},
        criadaEm: DateTime(2026),
        atualizadaEm: DateTime(2026),
      );
      final r = montarRelatorio(
        obra: obra,
        etapas: etapas,
        dias: [
          DiaObra(obraId: 'o1', data: DateTime(2026, 11, 3), situacao: SituacaoDia.finalizado, atividades: const [Atividade(descricao: 'Reboco')]),
          DiaObra(obraId: 'o1', data: DateTime(2026, 11, 4), atividades: const [Atividade(descricao: 'Não revisado')]),
          DiaObra(obraId: 'o1', data: DateTime(2026, 10, 4)),
        ],
        mudancas: const [Mudanca(titulo: 'x', dias: 3, situacao: SituacaoMudanca.aprovada)],
        semana: semana,
      );
      expect(r.andamento, 50);
      expect(r.etapaAtual, 'alvenaria');
      expect(r.termino, DateTime(2026, 12, 23));
      expect(r.proximas.map((p) => p.nome), ['alvenaria']);
      expect(r.resumo.dias, hasLength(1));
      expect(r.resumo.atividades.single.descricao, 'Reboco');
      expect(r.diasEmRascunho, 1);
    });
  });

  test('quem vê as mudanças', () {
    expect(FuncaoObra.responsavel.veMudancas, isTrue);
    expect(FuncaoObra.mestre.veMudancas, isTrue);
    expect(FuncaoObra.cliente.veMudancas, isTrue);
    expect(FuncaoObra.estagiario.veMudancas, isFalse);
    expect(FuncaoObra.empreiteiro.veMudancas, isFalse);
  });

  test('mudança aprovada aumenta o orçado da obra', () {
    final etapas = [linha(EtapaId.fundacao)];
    final r = resumirDinheiro(etapas: etapas, mudancas: 500, lancamentos: const []);
    expect(r.orcado, 600);
    expect(r.mudancas, 500);
    expect(resumirDinheiro(etapas: etapas, mudancas: -30, lancamentos: const []).orcado, 70);
  });
}
