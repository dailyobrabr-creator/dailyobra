/// O que a IA devolve na obra: sugestões que preenchem o formulário. Nada vai para o banco sem a pessoa conferir e salvar.
library;

import 'diario.dart';
import 'dinheiro.dart';

const _maxObservacoes = 2000;

/// O relato do dia organizado nos campos do diário.
class SugestaoDoDia {
  const SugestaoDoDia({
    this.climaManha,
    this.climaTarde,
    this.equipe = const [],
    this.atividades = const [],
    this.ocorrencias = const [],
    this.materiais = const [],
    this.equipamentos = const [],
    this.observacoes = '',
  });

  factory SugestaoDoDia.fromJson(Map<String, dynamic> j) => SugestaoDoDia(
    climaManha: Clima.de(j['clima_manha']),
    climaTarde: Clima.de(j['clima_tarde']),
    equipe: _lista(j['equipe'], ItemEquipe.fromJson),
    atividades: _lista(j['atividades'], Atividade.fromJson),
    ocorrencias: _lista(j['ocorrencias'], Ocorrencia.fromJson),
    materiais: _lista(j['materiais'], MaterialDia.fromJson),
    equipamentos: _lista(j['equipamentos'], EquipamentoDia.fromJson),
    observacoes: j['observacoes'] as String? ?? '',
  );

  final Clima? climaManha;
  final Clima? climaTarde;
  final List<ItemEquipe> equipe;
  final List<Atividade> atividades;
  final List<Ocorrencia> ocorrencias;
  final List<MaterialDia> materiais;
  final List<EquipamentoDia> equipamentos;
  final String observacoes;

  /// Soma ao que já está no dia, sem trocar nem apagar o que a pessoa preencheu.
  DiaObra aplicar(DiaObra dia) {
    final notas = [dia.observacoes.trim(), observacoes.trim()].where((t) => t.isNotEmpty).join('\n');
    return dia
        .comClima(dia.climaManha ?? climaManha, dia.climaTarde ?? climaTarde)
        .copyWith(
          equipe: [...dia.equipe, ...equipe],
          atividades: [...dia.atividades, ...atividades],
          ocorrencias: [...dia.ocorrencias, ...ocorrencias],
          materiais: [...dia.materiais, ...materiais],
          equipamentos: [...dia.equipamentos, ...equipamentos],
          observacoes: notas.length > _maxObservacoes ? notas.substring(0, _maxObservacoes) : notas,
        );
  }
}

/// Os dados lidos na foto de uma nota.
class SugestaoDaNota {
  const SugestaoDaNota({this.fornecedor = '', this.descricao = '', this.valor, this.data, this.tipo});

  factory SugestaoDaNota.fromJson(Map<String, dynamic> j) => SugestaoDaNota(
    fornecedor: j['fornecedor'] as String? ?? '',
    descricao: j['descricao'] as String? ?? '',
    valor: (j['valor'] as num?)?.toDouble(),
    data: DateTime.tryParse(j['data'] as String? ?? ''),
    tipo: j['tipo'] == null ? null : TipoGasto.doCodigo(j['tipo'] as String?),
  );

  final String fornecedor;
  final String descricao;
  final double? valor;
  final DateTime? data;
  final TipoGasto? tipo;
}

List<T> _lista<T>(Object? itens, T Function(Map<String, dynamic>) ler) => [
  for (final i in (itens as List?) ?? const []) ler(Map<String, dynamic>.from(i as Map)),
];
