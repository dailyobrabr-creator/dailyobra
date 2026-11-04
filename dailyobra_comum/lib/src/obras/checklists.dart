/// Checklists de qualidade e segurança: modelos prontos, respostas e o resultado de cada um.
library;

import '../orcamento/tabelas.dart';
import 'diario.dart';
import 'equipe.dart';

enum TipoChecklist {
  qualidade('qualidade', 'Qualidade'),
  seguranca('seguranca', 'Segurança');

  const TipoChecklist(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static TipoChecklist doCodigo(String? c) => values.firstWhere((t) => t.codigo == c, orElse: () => qualidade);
}

enum ResultadoItem {
  ok('ok', 'Conforme'),
  nao('nao', 'Não conforme'),
  na('na', 'Não se aplica');

  const ResultadoItem(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static ResultadoItem? doCodigo(String? c) {
    for (final r in values) {
      if (r.codigo == c) return r;
    }
    return null;
  }
}

class ItemChecklist {
  const ItemChecklist({required this.texto, this.resultado, this.observacao = '', this.fotoPath});
  factory ItemChecklist.fromJson(Map<String, dynamic> j) => ItemChecklist(texto: j['texto'] as String, resultado: ResultadoItem.doCodigo(j['resultado'] as String?), observacao: j['observacao'] as String? ?? '', fotoPath: j['foto_path'] as String?);

  final String texto;
  final ResultadoItem? resultado;
  final String observacao;
  final String? fotoPath;

  Map<String, Object?> paraSalvar() => {'texto': texto, 'resultado': resultado?.codigo, 'observacao': observacao, 'foto_path': fotoPath};
}

class Checklist {
  const Checklist({this.id, required this.modelo, required this.tipo, required this.titulo, this.etapa, this.local = '', required this.data, this.observacoes = '', this.concluido = false, this.concluidoPor = '', this.concluidoEm, this.itens = const []});
  factory Checklist.fromJson(Map<String, dynamic> j) {
    final linhas = [for (final i in j['obra_checklist_itens'] as List<dynamic>? ?? const []) Map<String, dynamic>.from(i as Map)]..sort((a, b) => (a['ordem'] as num).compareTo(b['ordem'] as num));
    return Checklist(
      id: j['id'] as String?,
      modelo: j['modelo'] as String,
      tipo: TipoChecklist.doCodigo(j['tipo'] as String?),
      titulo: j['titulo'] as String,
      etapa: EtapaId.doCodigo(j['etapa'] as String? ?? ''),
      local: j['local'] as String? ?? '',
      data: DateTime.parse(j['data'] as String),
      observacoes: j['observacoes'] as String? ?? '',
      concluido: j['concluido'] as bool? ?? false,
      concluidoPor: j['concluido_nome'] as String? ?? '',
      concluidoEm: j['concluido_em'] == null ? null : DateTime.parse(j['concluido_em'] as String).toLocal(),
      itens: [for (final l in linhas) ItemChecklist.fromJson(l)],
    );
  }

  final String? id;
  final String modelo;
  final TipoChecklist tipo;
  final String titulo;
  final EtapaId? etapa;
  final String local;
  final DateTime data;
  final String observacoes;
  final bool concluido;
  final String concluidoPor;
  final DateTime? concluidoEm;
  final List<ItemChecklist> itens;

  int _com(ResultadoItem r) => itens.where((i) => i.resultado == r).length;
  int get conformes => _com(ResultadoItem.ok);
  int get naoConformes => _com(ResultadoItem.nao);
  int get naoSeAplica => _com(ResultadoItem.na);
  int get faltam => itens.where((i) => i.resultado == null).length;

  /// Percentual de itens conformes entre os que se aplicam. Nulo enquanto nenhum foi respondido.
  int? get conformidade {
    final validos = conformes + naoConformes;
    return validos == 0 ? null : (conformes * 100 / validos).round();
  }

  /// "10 de 12 respondidos" no rascunho, "92% conforme" depois de concluído.
  String get resumo {
    final c = conformidade;
    if (concluido) return c == null ? 'Concluído' : '$c% conforme';
    return '${itens.length - faltam} de ${itens.length} respondidos';
  }

  Map<String, Object?> paraSalvar() => {'modelo': modelo, 'tipo': tipo.codigo, 'titulo': titulo, 'etapa': etapa?.codigo, 'local': local, 'data': dataIso(data), 'observacoes': observacoes, 'itens': [for (final i in itens) i.paraSalvar()]};
}

/// Ponto de partida de um checklist. Os itens podem ser ajustados em cada obra.
class ModeloChecklist {
  const ModeloChecklist({required this.codigo, required this.tipo, required this.titulo, this.etapa, required this.itens});
  final String codigo;
  final TipoChecklist tipo;
  final String titulo;
  final EtapaId? etapa;
  final List<String> itens;

  Checklist novo(DateTime data) => Checklist(modelo: codigo, tipo: tipo, titulo: titulo, etapa: etapa, data: data, itens: [for (final i in itens) ItemChecklist(texto: i)]);
}

const modelosDeChecklist = <ModeloChecklist>[
  ModeloChecklist(
    codigo: 'seguranca_geral',
    tipo: TipoChecklist.seguranca,
    titulo: 'Segurança da obra',
    itens: [
      'Todos usam capacete, botina e luvas',
      'Guarda-corpo nas periferias, vãos e aberturas no piso',
      'Escadas e andaimes firmes e com proteção',
      'Quadro elétrico fechado e sem fio exposto',
      'Escavações escoradas e sinalizadas',
      'Extintores no lugar, carregados e dentro da validade',
      'Caixa de primeiros socorros na obra',
      'Circulação limpa, sem pregos nem entulho',
      'Materiais empilhados com segurança',
      'Banheiro e área de refeição limpos',
      'Placa da obra e sinalização de segurança no lugar',
    ],
  ),
  ModeloChecklist(
    codigo: 'seguranca_altura',
    tipo: TipoChecklist.seguranca,
    titulo: 'Trabalho em altura',
    itens: [
      'Trabalhadores com treinamento em dia',
      'Cinto de segurança em bom estado',
      'Ponto de ancoragem firme e identificado',
      'Andaime montado, travado e com piso completo',
      'Guarda-corpo e rodapé no andaime',
      'Área de baixo isolada e sinalizada',
      'Sem trabalho em altura com chuva ou vento forte',
    ],
  ),
  ModeloChecklist(
    codigo: 'formas_armadura',
    tipo: TipoChecklist.qualidade,
    titulo: 'Formas e armadura, antes de concretar',
    etapa: EtapaId.estrutura,
    itens: [
      'Medidas e posição conforme o projeto',
      'Formas no prumo, no nível e travadas',
      'Formas limpas e vedadas',
      'Bitola e espaçamento da armadura conforme o projeto',
      'Espaçadores garantem o cobrimento',
      'Tubos e caixas embutidos posicionados e fixos',
    ],
  ),
  ModeloChecklist(
    codigo: 'concretagem',
    tipo: TipoChecklist.qualidade,
    titulo: 'Concretagem',
    etapa: EtapaId.estrutura,
    itens: [
      'Concreto com a resistência do projeto',
      'Nota do concreto conferida',
      'Consistência conferida na chegada',
      'Corpos de prova coletados',
      'Concreto bem adensado, sem falhas',
      'Cura iniciada e mantida',
    ],
  ),
  ModeloChecklist(
    codigo: 'alvenaria',
    tipo: TipoChecklist.qualidade,
    titulo: 'Alvenaria',
    etapa: EtapaId.alvenaria,
    itens: [
      'Paredes no prumo, no nível e no esquadro',
      'Locação das paredes conforme o projeto',
      'Juntas uniformes e preenchidas',
      'Amarração entre as paredes',
      'Vergas e contravergas nos vãos',
      'Encunhamento feito no prazo certo',
      'Vãos de portas e janelas na medida',
    ],
  ),
  ModeloChecklist(
    codigo: 'hidraulica',
    tipo: TipoChecklist.qualidade,
    titulo: 'Instalações hidráulicas',
    etapa: EtapaId.hidraulica,
    itens: [
      'Pontos na posição do projeto',
      'Diâmetro dos tubos conforme o projeto',
      'Teste de pressão sem vazamento',
      'Caimento correto no esgoto',
      'Ralos e sifões instalados',
      'Registros acessíveis',
      'Tubulação protegida antes de fechar',
    ],
  ),
  ModeloChecklist(
    codigo: 'eletrica',
    tipo: TipoChecklist.qualidade,
    titulo: 'Instalações elétricas',
    etapa: EtapaId.eletrica,
    itens: [
      'Pontos na posição do projeto',
      'Bitola dos fios conforme o projeto',
      'Circuitos identificados no quadro',
      'Disjuntores conforme o projeto',
      'Aterramento executado',
      'Proteção DR instalada onde o projeto pede',
      'Todos os pontos testados',
    ],
  ),
  ModeloChecklist(
    codigo: 'impermeabilizacao',
    tipo: TipoChecklist.qualidade,
    titulo: 'Impermeabilização',
    itens: [
      'Base limpa, seca e regularizada',
      'Cantos arredondados',
      'Produto conforme o projeto',
      'Demãos e tempo de secagem respeitados',
      'Subida nas paredes e ralos tratados',
      'Teste de estanqueidade sem vazamento',
      'Proteção feita antes de liberar a área',
    ],
  ),
  ModeloChecklist(
    codigo: 'cobertura',
    tipo: TipoChecklist.qualidade,
    titulo: 'Cobertura',
    itens: [
      'Estrutura alinhada e bem fixada',
      'Inclinação conforme o projeto',
      'Telhas fixadas e sem peças quebradas',
      'Rufos e calhas instalados',
      'Teste com água sem infiltração',
    ],
  ),
  ModeloChecklist(
    codigo: 'revestimentos',
    tipo: TipoChecklist.qualidade,
    titulo: 'Pisos e revestimentos',
    etapa: EtapaId.revestimentos,
    itens: [
      'Base limpa e nivelada',
      'Argamassa adequada ao material',
      'Peças do mesmo lote e tonalidade',
      'Juntas alinhadas e uniformes',
      'Caimento para os ralos',
      'Sem peças ocas ao bater',
      'Rejunte uniforme',
    ],
  ),
  ModeloChecklist(
    codigo: 'pintura',
    tipo: TipoChecklist.qualidade,
    titulo: 'Pintura',
    etapa: EtapaId.pintura,
    itens: [
      'Superfície seca, lixada e limpa',
      'Selador ou massa aplicados',
      'Cor conforme o combinado',
      'Demãos com a secagem respeitada',
      'Sem falhas nem escorridos',
      'Pisos e esquadrias protegidos',
    ],
  ),
  ModeloChecklist(
    codigo: 'entrega',
    tipo: TipoChecklist.qualidade,
    titulo: 'Vistoria de entrega',
    etapa: EtapaId.limpeza,
    itens: [
      'Portas e janelas abrem e fecham bem',
      'Torneiras e registros sem vazamento',
      'Ralos e vasos escoando',
      'Tomadas e interruptores funcionando',
      'Pintura sem falhas',
      'Pisos e revestimentos sem peças soltas',
      'Limpeza final feita',
      'Chaves e manuais entregues',
    ],
  ),
  ModeloChecklist(codigo: 'livre', tipo: TipoChecklist.qualidade, titulo: 'Checklist em branco', itens: []),
];

extension FuncaoNosChecklists on FuncaoObra {
  /// Preenche e acompanha os checklists.
  bool get inspeciona => this == FuncaoObra.responsavel || this == FuncaoObra.mestre || this == FuncaoObra.estagiario;
}
