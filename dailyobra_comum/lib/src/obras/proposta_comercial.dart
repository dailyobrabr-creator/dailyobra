/// Proposta comercial do engenheiro para o cliente: nasce antes da obra e, aceita, vira obra.
library;

import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import 'diario.dart';
import 'obra.dart';

enum SituacaoComercial {
  rascunho('rascunho', 'Rascunho'),
  enviada('enviada', 'Enviada'),
  aceita('aceita', 'Aceita'),
  recusada('recusada', 'Recusada');

  const SituacaoComercial(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static SituacaoComercial doCodigo(String? c) => values.firstWhere((s) => s.codigo == c, orElse: () => rascunho);
}

class ItemComercial {
  const ItemComercial({required this.descricao, required this.valor});
  factory ItemComercial.fromJson(Map<String, dynamic> j) => ItemComercial(descricao: j['descricao'] as String, valor: (j['valor'] as num).toDouble());

  final String descricao;
  final double valor;

  Map<String, Object?> paraSalvar() => {'descricao': descricao, 'valor': valor};
}

class ParcelaComercial {
  const ParcelaComercial({required this.descricao, required this.percentual, this.dias = 0});
  factory ParcelaComercial.fromJson(Map<String, dynamic> j) => ParcelaComercial(descricao: j['descricao'] as String, percentual: (j['percentual'] as num).toDouble(), dias: (j['dias'] as num?)?.toInt() ?? 0);

  final String descricao;
  final double percentual;

  /// Dias depois do início.
  final int dias;

  /// "No início", "30 dias depois"
  String get quando => dias == 0 ? 'No início' : (dias == 1 ? '1 dia depois' : '$dias dias depois');

  Map<String, Object?> paraSalvar() => {'descricao': descricao, 'percentual': percentual, 'dias': dias};
}

class PropostaComercial {
  const PropostaComercial({this.id, this.numero, required this.cliente, this.contato = '', required this.titulo, this.endereco = '', this.cidade = '', this.uf = '', this.area, this.padrao = Padrao.medio, this.itens = const [], this.desconto = 0, this.mostrarValores = true, this.parcelas = const [], this.inclui = '', this.naoInclui = '', this.prazoDias, this.validade, this.observacoes = '', this.situacao = SituacaoComercial.rascunho, this.obraId, this.criadaEm});
  factory PropostaComercial.fromJson(Map<String, dynamic> j) => PropostaComercial(
    id: j['id'] as String?,
    numero: (j['numero'] as num?)?.toInt(),
    cliente: j['cliente'] as String,
    contato: j['contato'] as String? ?? '',
    titulo: j['titulo'] as String,
    endereco: j['endereco'] as String? ?? '',
    cidade: j['cidade'] as String? ?? '',
    uf: j['uf'] as String? ?? '',
    area: (j['area'] as num?)?.toDouble(),
    padrao: Padrao.doCodigo(j['padrao'] as String?),
    itens: [for (final i in j['itens'] as List<dynamic>? ?? const []) ItemComercial.fromJson(Map<String, dynamic>.from(i as Map))],
    desconto: (j['desconto'] as num?)?.toDouble() ?? 0,
    mostrarValores: j['mostrar_valores'] as bool? ?? true,
    parcelas: [for (final p in j['parcelas'] as List<dynamic>? ?? const []) ParcelaComercial.fromJson(Map<String, dynamic>.from(p as Map))],
    inclui: j['inclui'] as String? ?? '',
    naoInclui: j['nao_inclui'] as String? ?? '',
    prazoDias: (j['prazo_dias'] as num?)?.toInt(),
    validade: j['validade'] == null ? null : DateTime.parse(j['validade'] as String),
    observacoes: j['observacoes'] as String? ?? '',
    situacao: SituacaoComercial.doCodigo(j['situacao'] as String?),
    obraId: j['obra_id'] as String?,
    criadaEm: j['criado_em'] == null ? null : DateTime.parse(j['criado_em'] as String).toLocal(),
  );

  final String? id;

  /// Sequência de cada pessoa. Nulo enquanto não foi salva.
  final int? numero;
  final String cliente;
  final String contato;
  final String titulo;
  final String endereco;
  final String cidade;
  final String uf;
  final double? area;
  final Padrao padrao;
  final List<ItemComercial> itens;
  final double desconto;

  /// Falso mostra só o total no PDF, sem o valor de cada item.
  final bool mostrarValores;
  final List<ParcelaComercial> parcelas;
  final String inclui;
  final String naoInclui;
  final int? prazoDias;
  final DateTime? validade;
  final String observacoes;
  final SituacaoComercial situacao;
  final String? obraId;
  final DateTime? criadaEm;

  double get subtotal => itens.fold(0, (s, i) => s + i.valor);

  /// Nunca negativo, mesmo com desconto maior que os itens.
  double get total {
    final t = subtotal - desconto;
    return t < 0 ? 0 : t;
  }

  double get somaDasParcelas => parcelas.fold(0, (s, p) => s + p.percentual);

  /// Sem parcelas não há o que conferir; com parcelas, elas precisam fechar 100%.
  bool get parcelasFecham => parcelas.isEmpty || (somaDasParcelas - 100).abs() < .005;

  /// Valor de cada parcela. A última fecha o total, sem sobra de arredondamento.
  List<double> get valoresDasParcelas {
    final valores = <double>[];
    var acumulado = 0.0;
    for (final (i, p) in parcelas.indexed) {
      final v = i == parcelas.length - 1 ? total - acumulado : (total * p.percentual).roundToDouble() / 100;
      valores.add(v);
      acumulado += v;
    }
    return valores;
  }

  bool vencida(DateTime hoje) {
    final v = validade;
    if (v == null || situacao == SituacaoComercial.aceita || situacao == SituacaoComercial.recusada) return false;
    return DateTime(hoje.year, hoje.month, hoje.day).isAfter(v);
  }

  /// O que falta para o PDF sair; nulo quando pode gerar.
  String? get faltaParaGerar {
    if (cliente.trim().isEmpty) return 'Diga quem é o cliente.';
    if (titulo.trim().isEmpty) return 'Diga o nome da obra ou do serviço.';
    if (itens.isEmpty) return 'Adicione pelo menos um item.';
    if (total <= 0) return 'A proposta precisa de um valor.';
    if (!parcelasFecham) return 'As parcelas precisam somar 100%.';
    return null;
  }

  /// O que a obra herda da proposta.
  DadosObra get dadosDaObra => DadosObra(nome: titulo, endereco: endereco, cidade: cidade, uf: uf);
  ParametrosObra get parametrosDaObra => ParametrosObra(area: area == null ? '' : area!.toString().replaceAll('.', ','), padrao: padrao);

  Map<String, Object?> paraSalvar() => {
    'cliente': cliente,
    'contato': contato,
    'titulo': titulo,
    'endereco': endereco,
    'cidade': cidade,
    'uf': uf,
    'area': area,
    'padrao': padrao.codigo,
    'itens': [for (final i in itens) i.paraSalvar()],
    'desconto': desconto,
    'mostrar_valores': mostrarValores,
    'parcelas': [for (final p in parcelas) p.paraSalvar()],
    'inclui': inclui,
    'nao_inclui': naoInclui,
    'prazo_dias': prazoDias,
    'validade': validade == null ? null : dataIso(validade!),
    'observacoes': observacoes,
    'situacao': situacao.codigo,
  };
}

/// Transforma a estimativa do app em itens da proposta, com o acréscimo do engenheiro por cima.
List<ItemComercial> itensDaEstimativa(ResultadoOrcamento r, {double acrescimo = 0}) => [
  for (final e in r.etapas) ItemComercial(descricao: e.nome, valor: (e.total * (100 + acrescimo)).roundToDouble() / 100),
];

/// Mensagem que acompanha o PDF.
String mensagemDaProposta(PropostaComercial p) => 'Proposta nº ${p.numero} para ${p.titulo}.';
