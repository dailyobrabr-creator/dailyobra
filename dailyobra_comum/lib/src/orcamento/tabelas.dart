// Tipos das tabelas de custo. Os números ficam em tabelas_dados.dart, gerado a partir do
// motor TypeScript do app web para os dois darem exatamente o mesmo resultado.

part 'tabelas_dados.dart';

/// Padrão de acabamento. [codigo] é o valor gravado no banco (igual ao app web).
enum Padrao {
  economico('economico', 'Econômico'),
  medio('medio', 'Médio'),
  mediaAlta('media_alta', 'Médio/Alto'),
  alto('alto', 'Alto padrão');

  const Padrao(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static Padrao doCodigo(String? c) => values.firstWhere((p) => p.codigo == c, orElse: () => medio);
}

/// Etapas da tabela "Construção nova". Cada obra usa 15 delas, conforme laje e cobertura.
enum EtapaId {
  preparacao('preparacao'),
  aluguelEquipamentos('aluguel_equipamentos'),
  fundacao('fundacao'),
  fundacaoLaje('fundacao_laje'),
  estrutura('estrutura'),
  estruturaLaje('estrutura_laje'),
  alvenaria('alvenaria'),
  calhasPlatibanda('calhas_platibanda'),
  calhasTelhado('calhas_telhado'),
  coberturaPlatibanda('cobertura_platibanda'),
  telhado3Aguas('telhado_3_aguas'),
  telhadoAparente('telhado_aparente'),
  eletrica('eletrica'),
  hidraulica('hidraulica'),
  forro('forro'),
  revestimentos('revestimentos'),
  pintura('pintura'),
  esquadrias('esquadrias'),
  acabamentos('acabamentos'),
  limpeza('limpeza');

  const EtapaId(this.codigo);
  final String codigo;

  static EtapaId? doCodigo(String c) {
    for (final e in values) {
      if (e.codigo == c) return e;
    }
    return null;
  }
}

class LinhaEtapa {
  const LinhaEtapa({required this.nome, required this.descricao, required this.custoM2, required this.maoDeObra});
  final String nome;
  final String descricao;

  /// R$/m² por padrão
  final Map<Padrao, double> custoM2;

  /// Fração de mão de obra por padrão; material = 1 - mão de obra
  final Map<Padrao, double> maoDeObra;
}

enum AcabamentoMuro {
  economico('economico', 'Econômico'),
  chapiscado('chapiscado', 'Chapiscado'),
  rebocadoInterno('rebocado_interno', 'Rebocado interno'),
  reboco2Lados('reboco_2_lados', 'Reboco dos 2 lados'),
  texturado('texturado', 'Texturado');

  const AcabamentoMuro(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static AcabamentoMuro doCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => economico);
}

enum TipoPiscina {
  fibra('fibra', 'Fibra'),
  vinil('vinil', 'Vinil'),
  alvenaria('alvenaria', 'Alvenaria');

  const TipoPiscina(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static TipoPiscina doCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => fibra);
}

enum TipoGourmet {
  churrasqueira('churrasqueira', 'Churrasqueira'),
  churrasqueiraIlha('churrasqueira_ilha', 'Churrasqueira e ilha'),
  churrasqueiraIlhaPlanejados('churrasqueira_ilha_planejados', 'Churrasqueira, ilha e planejados');

  const TipoGourmet(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static TipoGourmet doCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => churrasqueira);
}

enum TipoJardim {
  grama('grama', 'Grama'),
  gramaVegetacao('grama_vegetacao', 'Grama e vegetação');

  const TipoJardim(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static TipoJardim doCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => grama);
}
