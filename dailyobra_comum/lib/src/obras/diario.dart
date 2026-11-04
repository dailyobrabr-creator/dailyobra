/// Diário de obra: o registro de cada dia, nas tabelas rdos e rdo_*.
library;

enum Clima {
  sol('Sol'),
  nublado('Nublado'),
  chuva('Chuva'),
  impraticavel('Sem condição');

  const Clima(this.rotulo);
  final String rotulo;

  static Clima? de(Object? valor) => Clima.values.asNameMap()[valor];
}

enum SituacaoDia {
  rascunho('Rascunho'),
  finalizado('Finalizado'),
  aprovado('Aprovado');

  const SituacaoDia(this.rotulo);
  final String rotulo;

  static SituacaoDia de(Object? valor) => SituacaoDia.values.asNameMap()[valor] ?? SituacaoDia.rascunho;
}

enum TipoOcorrencia {
  geral('Geral'),
  seguranca('Segurança'),
  atraso('Atraso'),
  qualidade('Qualidade'),
  visita('Visita');

  const TipoOcorrencia(this.rotulo);
  final String rotulo;

  static TipoOcorrencia de(Object? valor) => TipoOcorrencia.values.asNameMap()[valor] ?? TipoOcorrencia.geral;
}

class ItemEquipe {
  const ItemEquipe({required this.funcao, this.quantidade = 1, this.empresa = ''});
  factory ItemEquipe.fromJson(Map<String, dynamic> j) => ItemEquipe(funcao: j['funcao'] as String, quantidade: (j['quantidade'] as num?)?.toInt() ?? 1, empresa: j['empresa'] as String? ?? '');
  final String funcao;
  final int quantidade;
  final String empresa;
  Map<String, Object?> paraSalvar() => {'funcao': funcao, 'quantidade': quantidade, 'empresa': empresa};
}

class Atividade {
  const Atividade({required this.descricao, this.local = '', this.percentual});
  factory Atividade.fromJson(Map<String, dynamic> j) => Atividade(descricao: j['descricao'] as String, local: j['local'] as String? ?? '', percentual: (j['percentual'] as num?)?.toInt());
  final String descricao;
  final String local;

  /// Quanto do serviço ficou pronto, de 0 a 100. Nulo quando não foi informado.
  final int? percentual;
  Map<String, Object?> paraSalvar() => {'descricao': descricao, 'local': local, 'percentual': percentual};
}

class Ocorrencia {
  const Ocorrencia({this.tipo = TipoOcorrencia.geral, required this.descricao});
  factory Ocorrencia.fromJson(Map<String, dynamic> j) => Ocorrencia(tipo: TipoOcorrencia.de(j['tipo']), descricao: j['descricao'] as String);
  final TipoOcorrencia tipo;
  final String descricao;
  Map<String, Object?> paraSalvar() => {'tipo': tipo.name, 'descricao': descricao};
}

class MaterialDia {
  const MaterialDia({required this.material, this.quantidade, this.unidade = '', this.fornecedor = ''});
  factory MaterialDia.fromJson(Map<String, dynamic> j) => MaterialDia(material: j['material'] as String, quantidade: (j['quantidade'] as num?)?.toDouble(), unidade: j['unidade'] as String? ?? '', fornecedor: j['fornecedor'] as String? ?? '');
  final String material;
  final double? quantidade;
  final String unidade;
  final String fornecedor;
  Map<String, Object?> paraSalvar() => {'material': material, 'quantidade': quantidade, 'unidade': unidade, 'fornecedor': fornecedor};
}

class EquipamentoDia {
  const EquipamentoDia({required this.equipamento, this.quantidade = 1});
  factory EquipamentoDia.fromJson(Map<String, dynamic> j) => EquipamentoDia(equipamento: j['equipamento'] as String, quantidade: (j['quantidade'] as num?)?.toInt() ?? 1);
  final String equipamento;
  final int quantidade;
  Map<String, Object?> paraSalvar() => {'equipamento': equipamento, 'quantidade': quantidade};
}

class FotoDia {
  const FotoDia({required this.caminho, this.legenda = ''});
  factory FotoDia.fromJson(Map<String, dynamic> j) => FotoDia(caminho: j['storage_path'] as String, legenda: j['legenda'] as String? ?? '');

  /// Onde o arquivo está no bucket rdo-fotos: {obra}/{data}/{nome}.
  final String caminho;
  final String legenda;
  Map<String, Object?> paraSalvar() => {'caminho': caminho, 'legenda': legenda};
}

class DiaObra {
  const DiaObra({
    this.id,
    required this.obraId,
    required this.data,
    this.climaManha,
    this.climaTarde,
    this.observacoes = '',
    this.situacao = SituacaoDia.rascunho,
    this.equipe = const [],
    this.atividades = const [],
    this.ocorrencias = const [],
    this.materiais = const [],
    this.equipamentos = const [],
    this.fotos = const [],
  });

  factory DiaObra.fromJson(Map<String, dynamic> j) => DiaObra(
    id: j['id'] as String?,
    obraId: j['obra_id'] as String,
    data: DateTime.parse(j['data'] as String),
    climaManha: Clima.de(j['clima_manha']),
    climaTarde: Clima.de(j['clima_tarde']),
    observacoes: j['observacoes'] as String? ?? '',
    situacao: SituacaoDia.de(j['status']),
    equipe: _itens(j['rdo_efetivo'], ItemEquipe.fromJson),
    atividades: _itens(j['rdo_atividades'], Atividade.fromJson),
    ocorrencias: _itens(j['rdo_ocorrencias'], Ocorrencia.fromJson),
    materiais: _itens(j['rdo_materiais'], MaterialDia.fromJson),
    equipamentos: _itens(j['rdo_equipamentos'], EquipamentoDia.fromJson),
    fotos: _itens(j['rdo_fotos'], FotoDia.fromJson),
  );

  /// Nulo enquanto o dia não foi salvo.
  final String? id;
  final String obraId;
  final DateTime data;
  final Clima? climaManha;
  final Clima? climaTarde;
  final String observacoes;
  final SituacaoDia situacao;
  final List<ItemEquipe> equipe;
  final List<Atividade> atividades;
  final List<Ocorrencia> ocorrencias;
  final List<MaterialDia> materiais;
  final List<EquipamentoDia> equipamentos;
  final List<FotoDia> fotos;

  /// Dia fechado: não muda mais, a não ser que o administrador reabra.
  bool get fechado => situacao != SituacaoDia.rascunho;

  /// Só o clima não conta: o banco também não deixa finalizar um dia assim.
  bool get vazio => equipe.isEmpty && atividades.isEmpty && ocorrencias.isEmpty && materiais.isEmpty && equipamentos.isEmpty && fotos.isEmpty && observacoes.trim().isEmpty;

  int get pessoas => equipe.fold(0, (soma, e) => soma + e.quantidade);

  String get resumo {
    final partes = [
      if (pessoas > 0) _contagem(pessoas, 'pessoa', 'pessoas'),
      if (atividades.isNotEmpty) _contagem(atividades.length, 'atividade', 'atividades'),
      if (fotos.isNotEmpty) _contagem(fotos.length, 'foto', 'fotos'),
    ];
    if (partes.isNotEmpty) return partes.join(' · ');
    return vazio ? 'Sem registros' : 'Com anotações';
  }

  DiaObra copyWith({
    String? id,
    String? observacoes,
    SituacaoDia? situacao,
    List<ItemEquipe>? equipe,
    List<Atividade>? atividades,
    List<Ocorrencia>? ocorrencias,
    List<MaterialDia>? materiais,
    List<EquipamentoDia>? equipamentos,
    List<FotoDia>? fotos,
  }) => DiaObra(
    id: id ?? this.id,
    obraId: obraId,
    data: data,
    climaManha: climaManha,
    climaTarde: climaTarde,
    observacoes: observacoes ?? this.observacoes,
    situacao: situacao ?? this.situacao,
    equipe: equipe ?? this.equipe,
    atividades: atividades ?? this.atividades,
    ocorrencias: ocorrencias ?? this.ocorrencias,
    materiais: materiais ?? this.materiais,
    equipamentos: equipamentos ?? this.equipamentos,
    fotos: fotos ?? this.fotos,
  );

  /// Separado de [copyWith] porque nulo aqui quer dizer "sem clima", não "manter como está".
  DiaObra comClima(Clima? manha, Clima? tarde) => DiaObra(
    id: id,
    obraId: obraId,
    data: data,
    climaManha: manha,
    climaTarde: tarde,
    observacoes: observacoes,
    situacao: situacao,
    equipe: equipe,
    atividades: atividades,
    ocorrencias: ocorrencias,
    materiais: materiais,
    equipamentos: equipamentos,
    fotos: fotos,
  );

  /// O que vai para a função salvar_dia_obra do banco.
  Map<String, Object?> paraSalvar() => {
    'clima_manha': climaManha?.name,
    'clima_tarde': climaTarde?.name,
    'observacoes': observacoes,
    'equipe': [for (final e in equipe) e.paraSalvar()],
    'atividades': [for (final a in atividades) a.paraSalvar()],
    'ocorrencias': [for (final o in ocorrencias) o.paraSalvar()],
    'materiais': [for (final m in materiais) m.paraSalvar()],
    'equipamentos': [for (final e in equipamentos) e.paraSalvar()],
    'fotos': [for (final f in fotos) f.paraSalvar()],
  };
}

/// Na ordem em que foram digitados: o banco não garante a ordem das linhas sem a coluna "ordem".
List<T> _itens<T>(Object? linhas, T Function(Map<String, dynamic>) ler) {
  final lista = [for (final l in (linhas as List?) ?? const []) Map<String, dynamic>.from(l as Map)];
  num ordem(int i) => lista[i]['ordem'] as num? ?? 0;
  final indices = [for (var i = 0; i < lista.length; i++) i]
    ..sort((a, b) {
      final c = ordem(a).compareTo(ordem(b));
      return c != 0 ? c : a.compareTo(b);
    });
  return [for (final i in indices) ler(lista[i])];
}

String _contagem(int n, String uma, String varias) => '$n ${n == 1 ? uma : varias}';

String _dois(int n) => n.toString().padLeft(2, '0');

/// "2026-11-03", como o banco guarda.
String dataIso(DateTime d) => '${d.year}-${_dois(d.month)}-${_dois(d.day)}';

/// "03/11"
String dataCurta(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}';

const _diasDaSemana = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const _meses = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

/// "Terça, 3 de novembro de 2026"
String diaPorExtenso(DateTime d) => '${_diasDaSemana[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]} de ${d.year}';

bool mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
