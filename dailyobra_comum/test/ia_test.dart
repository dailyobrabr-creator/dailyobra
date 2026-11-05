import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dia = DiaObra(obraId: 'o', data: DateTime(2026, 11, 4));

  group('SugestaoDoDia', () {
    test('lê o dia inteiro vindo da função', () {
      final s = SugestaoDoDia.fromJson({
        'clima_manha': 'sol',
        'clima_tarde': 'chuva',
        'equipe': [
          {'funcao': 'Pedreiro', 'quantidade': 3, 'empresa': 'Silva'},
        ],
        'atividades': [
          {'descricao': 'Reboco', 'local': 'Sala', 'percentual': 40},
          {'descricao': 'Forro', 'local': '', 'percentual': null},
        ],
        'ocorrencias': [
          {'tipo': 'seguranca', 'descricao': 'Andaime solto'},
        ],
        'materiais': [
          {'material': 'Cimento', 'quantidade': 10.5, 'unidade': 'sacos', 'fornecedor': 'Operário'},
          {'material': 'Areia', 'quantidade': null, 'unidade': '', 'fornecedor': ''},
        ],
        'equipamentos': [
          {'equipamento': 'Betoneira', 'quantidade': 2},
        ],
        'observacoes': 'Tudo certo',
      });
      expect(s.climaManha, Clima.sol);
      expect(s.climaTarde, Clima.chuva);
      expect(s.equipe.single.empresa, 'Silva');
      expect(s.atividades.map((a) => a.percentual), [40, null]);
      expect(s.ocorrencias.single.tipo, TipoOcorrencia.seguranca);
      expect(s.materiais.map((m) => m.quantidade), [10.5, null]);
      expect(s.equipamentos.single.quantidade, 2);
      expect(s.observacoes, 'Tudo certo');
    });

    test('aceita resposta sem nenhum campo', () {
      final s = SugestaoDoDia.fromJson({});
      expect(s.climaManha, isNull);
      expect(s.equipe, isEmpty);
      expect(s.observacoes, '');
    });

    test('preenche um dia vazio', () {
      final novo = const SugestaoDoDia(
        climaManha: Clima.sol,
        climaTarde: Clima.nublado,
        equipe: [ItemEquipe(funcao: 'Pedreiro', quantidade: 2)],
        atividades: [Atividade(descricao: 'Reboco')],
        ocorrencias: [Ocorrencia(descricao: 'Faltou água')],
        materiais: [MaterialDia(material: 'Cimento')],
        equipamentos: [EquipamentoDia(equipamento: 'Betoneira')],
        observacoes: 'Nada mais',
      ).aplicar(dia);
      expect(novo.climaManha, Clima.sol);
      expect(novo.climaTarde, Clima.nublado);
      expect(novo.pessoas, 2);
      expect(novo.atividades.single.descricao, 'Reboco');
      expect(novo.ocorrencias.single.descricao, 'Faltou água');
      expect(novo.materiais.single.material, 'Cimento');
      expect(novo.equipamentos.single.equipamento, 'Betoneira');
      expect(novo.observacoes, 'Nada mais');
    });

    test('soma ao que a pessoa já preencheu, sem trocar nada', () {
      final preenchido = dia
          .comClima(Clima.chuva, null)
          .copyWith(
            equipe: const [ItemEquipe(funcao: 'Servente')],
            atividades: const [Atividade(descricao: 'Limpeza')],
            observacoes: 'Antes',
          );
      final novo = const SugestaoDoDia(
        climaManha: Clima.sol,
        climaTarde: Clima.sol,
        equipe: [ItemEquipe(funcao: 'Pedreiro')],
        atividades: [Atividade(descricao: 'Reboco')],
        observacoes: 'Depois',
      ).aplicar(preenchido);
      expect(novo.climaManha, Clima.chuva);
      expect(novo.climaTarde, Clima.sol);
      expect(novo.equipe.map((e) => e.funcao), ['Servente', 'Pedreiro']);
      expect(novo.atividades.map((a) => a.descricao), ['Limpeza', 'Reboco']);
      expect(novo.observacoes, 'Antes\nDepois');
    });

    test('não mexe em id, data, situação nem fotos', () {
      final salvo = DiaObra(id: 'd1', obraId: 'o', data: DateTime(2026, 11, 4), fotos: const [FotoDia(caminho: 'o/1.jpg')]);
      final novo = const SugestaoDoDia(observacoes: 'x').aplicar(salvo);
      expect(novo.id, 'd1');
      expect(novo.data, DateTime(2026, 11, 4));
      expect(novo.situacao, SituacaoDia.rascunho);
      expect(novo.fotos.single.caminho, 'o/1.jpg');
    });

    test('observações não passam do tamanho do campo', () {
      final cheio = dia.copyWith(observacoes: 'a' * 1995);
      expect(SugestaoDoDia(observacoes: 'b' * 100).aplicar(cheio).observacoes.length, 2000);
    });
  });

  group('SugestaoDaNota', () {
    test('lê a nota inteira', () {
      final n = SugestaoDaNota.fromJson({'fornecedor': 'Casa do Construtor', 'descricao': 'Cimento', 'valor': 1234, 'data': '2026-11-01', 'tipo': 'mao_de_obra'});
      expect(n.fornecedor, 'Casa do Construtor');
      expect(n.descricao, 'Cimento');
      expect(n.valor, 1234.0);
      expect(n.data, DateTime(2026, 11, 1));
      expect(n.tipo, TipoGasto.maoDeObra);
    });

    test('deixa vazio o que não foi lido', () {
      final n = SugestaoDaNota.fromJson({'valor': null, 'data': null, 'tipo': null});
      expect(n.fornecedor, '');
      expect(n.valor, isNull);
      expect(n.data, isNull);
      expect(n.tipo, isNull);
    });
  });
}
