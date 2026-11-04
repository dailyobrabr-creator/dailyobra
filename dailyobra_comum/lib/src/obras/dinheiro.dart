/// Dinheiro da obra: gastos lançados, pedidos feitos para a obra e a conta de orçado x realizado.
library;

import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import '../ui/ui.dart' show brl, brlInteiro;
import 'diario.dart';

enum TipoGasto {
  material('material', 'Material'),
  maoDeObra('mao_de_obra', 'Mão de obra'),
  servico('servico', 'Serviço'),
  outro('outro', 'Outro');

  const TipoGasto(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static TipoGasto doCodigo(String? c) => values.firstWhere((t) => t.codigo == c, orElse: () => outro);
}

/// Um gasto lançado à mão ou um pedido feito para a obra.
class LancamentoObra {
  const LancamentoObra({this.id, this.doPedido = false, this.etapa, this.tipo = TipoGasto.material, required this.descricao, this.fornecedor = '', required this.valor, required this.data, this.notaPath, this.autor = '', this.possoMexer = true});
  factory LancamentoObra.fromJson(Map<String, dynamic> j) => LancamentoObra(
    id: j['id'] as String?,
    doPedido: j['origem'] == 'pedido',
    etapa: EtapaId.doCodigo(j['etapa'] as String? ?? ''),
    tipo: TipoGasto.doCodigo(j['tipo'] as String?),
    descricao: j['descricao'] as String,
    fornecedor: j['fornecedor'] as String? ?? '',
    valor: (j['valor'] as num).toDouble(),
    data: DateTime.parse(j['data'] as String),
    notaPath: j['nota_path'] as String?,
    autor: j['autor'] as String? ?? '',
    possoMexer: j['posso_mexer'] as bool? ?? false,
  );

  /// Nulo enquanto não foi salvo.
  final String? id;

  /// Pedido não se edita aqui: só escolhe em qual etapa ele entra.
  final bool doPedido;
  final EtapaId? etapa;
  final TipoGasto tipo;
  final String descricao;
  final String fornecedor;
  final double valor;
  final DateTime data;
  final String? notaPath;

  /// Nome de quem lançou.
  final String autor;
  final bool possoMexer;

  Map<String, Object?> paraSalvar() => {'descricao': descricao, 'valor': valor, 'data': dataIso(data), 'etapa': etapa?.codigo, 'tipo': tipo.codigo, 'fornecedor': fornecedor, 'nota_path': notaPath};
}

class LinhaDinheiro {
  const LinhaDinheiro({required this.etapa, required this.nome, required this.estimado, required this.orcado, required this.proprio, required this.realizado});
  final EtapaId etapa;
  final String nome;

  /// Valor do orçamento calculado pelo app.
  final double estimado;

  /// Valor usado na conta: o digitado pelo responsável ou a estimativa.
  final double orcado;
  final bool proprio;
  final double realizado;

  bool get estourou => realizado > orcado;
  double get excedente => estourou ? realizado - orcado : 0;

  /// Quanto do orçado já foi. Com orçado zero e algum gasto, conta como estourado.
  double get fracao => orcado > 0 ? realizado / orcado : (realizado > 0 ? 1 : 0);

  /// Passou de 90%, sem estourar.
  bool get perto => !estourou && orcado > 0 && fracao >= 0.9;
}

class ResumoDinheiro {
  const ResumoDinheiro({required this.linhas, required this.semEtapa, required this.adicionais});
  final List<LinhaDinheiro> linhas;

  /// Lançamentos que ainda não têm etapa: entram no total, não em uma linha.
  final double semEtapa;

  /// Muro, piscina e outros itens do orçamento que não são etapa.
  final double adicionais;

  double get orcado => linhas.fold(adicionais, (s, l) => s + l.orcado);
  double get realizado => linhas.fold(semEtapa, (s, l) => s + l.realizado);
  double get saldo => orcado - realizado;
  bool get estourou => realizado > orcado;
  int get etapasEstouradas => linhas.where((l) => l.estourou).length;

  /// "R$ 12.000 de R$ 219.173"
  String get texto => '${brlInteiro.format(realizado)} de ${brlInteiro.format(orcado)}';

  /// Frase do aviso de estouro; nula quando está tudo dentro do orçado.
  String? get alerta {
    if (estourou) return 'A obra passou do orçado em ${brl.format(-saldo)}.';
    final n = etapasEstouradas;
    if (n == 0) return null;
    return n == 1 ? '1 etapa passou do orçado.' : '$n etapas passaram do orçado.';
  }
}

/// Junta o orçamento da obra com o que foi lançado. Lançamento de etapa que saiu do orçamento
/// (mudaram os parâmetros da obra) fica como "sem etapa", para o dinheiro não sumir da conta.
ResumoDinheiro resumirDinheiro({required List<LinhaResultado> etapas, double adicionais = 0, Map<EtapaId, double> orcado = const {}, required List<LancamentoObra> lancamentos}) {
  final conhecidas = {for (final e in etapas) e.etapa};
  final porEtapa = <EtapaId, double>{};
  var semEtapa = 0.0;
  for (final l in lancamentos) {
    final e = l.etapa;
    if (e != null && conhecidas.contains(e)) {
      porEtapa[e] = (porEtapa[e] ?? 0) + l.valor;
    } else {
      semEtapa += l.valor;
    }
  }
  return ResumoDinheiro(
    linhas: [
      for (final e in etapas)
        LinhaDinheiro(etapa: e.etapa, nome: e.nome, estimado: e.total, orcado: orcado[e.etapa] ?? e.total, proprio: orcado.containsKey(e.etapa), realizado: porEtapa[e.etapa] ?? 0),
    ],
    semEtapa: semEtapa,
    adicionais: adicionais,
  );
}
