import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

Obra obra(Papel papel, {FuncaoObra? funcao}) => Obra(
  id: 'o1',
  papel: papel,
  funcao: funcao,
  dados: const DadosObra(nome: 'Residência Silva'),
  parametros: const ParametrosObra(area: '120'),
  statusEtapas: const {},
  criadaEm: DateTime(2026, 11),
  atualizadaEm: DateTime(2026, 11),
);

void main() {
  group('cada função tem seu acesso', () {
    test('responsável faz tudo', () {
      const f = FuncaoObra.responsavel;
      expect([f.administra, f.lidera, f.registra, f.veValores], everyElement(isTrue));
    });

    test('mestre lidera, mas não administra', () {
      const f = FuncaoObra.mestre;
      expect(f.administra, isFalse);
      expect([f.lidera, f.registra, f.veValores], everyElement(isTrue));
    });

    test('estagiário registra e não finaliza', () {
      const f = FuncaoObra.estagiario;
      expect([f.administra, f.lidera], everyElement(isFalse));
      expect([f.registra, f.veValores], everyElement(isTrue));
    });

    test('empreiteiro registra e não vê valores', () {
      const f = FuncaoObra.empreiteiro;
      expect(f.registra, isTrue);
      expect([f.administra, f.lidera, f.veValores], everyElement(isFalse));
    });

    test('cliente acompanha', () {
      const f = FuncaoObra.cliente;
      expect(f.veValores, isTrue);
      expect([f.administra, f.lidera, f.registra], everyElement(isFalse));
    });
  });

  test('só as quatro funções da equipe podem ser convidadas', () {
    expect(FuncaoObra.convidaveis, [FuncaoObra.mestre, FuncaoObra.estagiario, FuncaoObra.empreiteiro, FuncaoObra.cliente]);
    for (final f in FuncaoObra.convidaveis) {
      expect(f.descricao, isNotEmpty, reason: f.name);
    }
  });

  test('função lida do banco', () {
    expect(FuncaoObra.doCodigo('mestre'), FuncaoObra.mestre);
    expect(FuncaoObra.doCodigo('estagiario').rotulo, 'Estagiário');
    expect(FuncaoObra.doCodigo('qualquer'), FuncaoObra.cliente);
    expect(FuncaoObra.doCodigo(null), FuncaoObra.cliente);
  });

  test('obra sem função vem do papel, para quem ainda não atualizou', () {
    expect(obra(Papel.admin).funcao, FuncaoObra.responsavel);
    expect(obra(Papel.membro).funcao, FuncaoObra.mestre);
    expect(obra(Papel.cliente).funcao, FuncaoObra.cliente);
    expect(obra(Papel.membro, funcao: FuncaoObra.empreiteiro).funcao, FuncaoObra.empreiteiro);
  });

  test('mudar a etapa não perde a função', () {
    final o = obra(Papel.membro, funcao: FuncaoObra.estagiario).comStatus(EtapaId.values.first, StatusEtapa.concluida);
    expect(o.funcao, FuncaoObra.estagiario);
  });

  test('lê a pessoa e o convite do banco', () {
    final m = MembroObra.fromJson(const {'user_id': 'u1', 'nome': 'João', 'funcao': 'mestre', 'eu': true});
    expect((m.id, m.nome, m.funcao, m.eu), ('u1', 'João', FuncaoObra.mestre, true));
    final c = ConviteObra.fromJson(const {'id': 'c1', 'codigo': 'AB12C-3DE45', 'funcao': 'cliente', 'expira_em': '2026-11-11T12:00:00+00:00'});
    expect((c.id, c.codigo, c.funcao), ('c1', 'AB12C-3DE45', FuncaoObra.cliente));
    expect(c.expiraEm.toUtc(), DateTime.utc(2026, 11, 11, 12));
  });

  test('convite vencido', () {
    final c = ConviteObra(id: 'c', codigo: 'x', funcao: FuncaoObra.cliente, expiraEm: DateTime(2026, 11, 11));
    expect(c.vencidoEm(DateTime(2026, 11, 10)), isFalse);
    expect(c.vencidoEm(DateTime(2026, 11, 12)), isTrue);
  });

  test('link e mensagem do convite', () {
    expect(linkDoConvite('AB12C-3DE45'), 'https://dailyobrabr-creator.github.io/dailyobra/?convite=AB12C-3DE45');
    final texto = mensagemDoConvite(nomeDaObra: 'Residência Silva', funcao: FuncaoObra.mestre, codigo: 'AB12C-3DE45');
    expect(texto, contains('Residência Silva'));
    expect(texto, contains('Mestre de obras'));
    expect(texto, contains('?convite=AB12C-3DE45'));
    expect(texto, contains('AB12C-3DE45'));
  });
}
