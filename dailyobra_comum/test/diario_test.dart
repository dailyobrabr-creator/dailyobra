import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

final completo = DiaObra.fromJson(const {
  'id': 'd1',
  'obra_id': 'o1',
  'data': '2026-11-03',
  'clima_manha': 'sol',
  'clima_tarde': 'chuva',
  'observacoes': 'Concretagem adiada',
  'status': 'finalizado',
  'rdo_efetivo': [
    {'funcao': 'Pedreiro', 'quantidade': 3, 'empresa': 'Equipe Silva'},
    {'funcao': 'Servente', 'quantidade': 2, 'empresa': null},
  ],
  'rdo_atividades': [
    {'descricao': 'Reboco da sala', 'local': 'Térreo', 'percentual': 60},
  ],
  'rdo_ocorrencias': [
    {'tipo': 'atraso', 'descricao': 'Chuva à tarde'},
  ],
  'rdo_materiais': [
    {'material': 'Cimento', 'quantidade': 10, 'unidade': 'saco', 'fornecedor': 'Operário'},
  ],
  'rdo_equipamentos': [
    {'equipamento': 'Betoneira', 'quantidade': 1},
  ],
  'rdo_fotos': [
    {'id': 'f1', 'storage_path': 'o1/2026-11-03/a.jpg', 'legenda': 'Sala'},
  ],
});

void main() {
  test('lê o dia do banco', () {
    final d = completo;
    expect(d.id, 'd1');
    expect(d.data, DateTime(2026, 11, 3));
    expect(d.climaManha, Clima.sol);
    expect(d.climaTarde, Clima.chuva);
    expect(d.situacao, SituacaoDia.finalizado);
    expect(d.equipe.first.funcao, 'Pedreiro');
    expect(d.equipe.last.empresa, '');
    expect(d.atividades.single.percentual, 60);
    expect(d.ocorrencias.single.tipo, TipoOcorrencia.atraso);
    expect(d.materiais.single.quantidade, 10);
    expect(d.equipamentos.single.equipamento, 'Betoneira');
    expect(d.fotos.single.caminho, 'o1/2026-11-03/a.jpg');
  });

  test('prepara o dia para salvar', () {
    final j = completo.paraSalvar();
    expect(j['clima_manha'], 'sol');
    expect(j['clima_tarde'], 'chuva');
    expect(j['observacoes'], 'Concretagem adiada');
    expect((j['equipe'] as List).first, {'funcao': 'Pedreiro', 'quantidade': 3, 'empresa': 'Equipe Silva'});
    expect((j['atividades'] as List).single, {'descricao': 'Reboco da sala', 'local': 'Térreo', 'percentual': 60});
    expect((j['ocorrencias'] as List).single, {'tipo': 'atraso', 'descricao': 'Chuva à tarde'});
    expect((j['fotos'] as List).single, {'caminho': 'o1/2026-11-03/a.jpg', 'legenda': 'Sala'});
  });

  test('dia em branco', () {
    final d = DiaObra(obraId: 'o1', data: DateTime(2026, 11, 3));
    expect(d.vazio, isTrue);
    expect(d.pessoas, 0);
    expect(d.resumo, 'Sem registros');
    expect(d.situacao, SituacaoDia.rascunho);
    expect(d.paraSalvar()['clima_manha'], isNull);
  });

  test('resumo com singular e plural', () {
    expect(completo.pessoas, 5);
    expect(completo.vazio, isFalse);
    expect(completo.resumo, '5 pessoas · 1 atividade · 1 foto');
    final d = DiaObra(
      obraId: 'o1',
      data: DateTime(2026, 11, 3),
      equipe: const [ItemEquipe(funcao: 'Mestre', quantidade: 1)],
      atividades: const [Atividade(descricao: 'a'), Atividade(descricao: 'b')],
    );
    expect(d.resumo, '1 pessoa · 2 atividades');
  });

  test('copyWith troca só o que veio', () {
    final d = completo.copyWith(observacoes: 'Outra', equipe: const []);
    expect(d.observacoes, 'Outra');
    expect(d.equipe, isEmpty);
    expect(d.atividades, completo.atividades);
    expect(d.id, 'd1');
  });

  test('datas', () {
    expect(dataIso(DateTime(2026, 11, 3, 22, 30)), '2026-11-03');
    expect(diaPorExtenso(DateTime(2026, 11, 3)), 'Terça, 3 de novembro de 2026');
    expect(diaPorExtenso(DateTime(2026, 11, 1)), 'Domingo, 1 de novembro de 2026');
    expect(mesmoDia(DateTime(2026, 11, 3, 1), DateTime(2026, 11, 3, 23)), isTrue);
    expect(mesmoDia(DateTime(2026, 11, 3), DateTime(2026, 11, 4)), isFalse);
  });

  test('rótulos em português', () {
    expect(Clima.impraticavel.rotulo, 'Sem condição');
    expect(TipoOcorrencia.seguranca.rotulo, 'Segurança');
    expect(SituacaoDia.rascunho.rotulo, 'Rascunho');
  });
}
