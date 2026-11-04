/// Mão de obra da obra: diaristas, presenças, contratos de empreiteiros e medições.
library;

import '../orcamento/tabelas.dart';
import 'equipe.dart';

/// Quem recebe por dia. O mestre recebe sem o valor da diária.
class Diarista {
  const Diarista({this.id, required this.nome, this.funcao = '', this.diaria, this.ativo = true});
  factory Diarista.fromJson(Map<String, dynamic> j) => Diarista(id: j['id'] as String?, nome: j['nome'] as String, funcao: j['funcao'] as String? ?? '', diaria: (j['diaria'] as num?)?.toDouble(), ativo: j['ativo'] as bool? ?? true);

  final String? id;
  final String nome;
  final String funcao;
  final double? diaria;
  final bool ativo;

  Map<String, Object?> paraSalvar() => {'nome': nome, 'funcao': funcao, 'diaria': diaria, 'ativo': ativo};
}

class Presenca {
  const Presenca({required this.diaristaId, required this.data, required this.dias, this.pago = false});
  factory Presenca.fromJson(Map<String, dynamic> j) => Presenca(diaristaId: j['diarista_id'] as String, data: DateTime.parse(j['data'] as String), dias: (j['dias'] as num).toDouble(), pago: j['pago'] as bool? ?? false);

  final String diaristaId;
  final DateTime data;

  /// 1 é dia inteiro, 0,5 é meio dia.
  final double dias;
  final bool pago;
}

/// "1 dia", "2,5 dias"
String textoDeDias(double dias) {
  final n = dias == dias.roundToDouble() ? dias.toStringAsFixed(0) : dias.toString().replaceAll('.', ',');
  return dias == 1 ? '1 dia' : '$n dias';
}

/// O que falta pagar para uma pessoa.
class DiariasAbertas {
  const DiariasAbertas({required this.diarista, required this.dias});
  final Diarista diarista;
  final double dias;

  /// Sem valor enquanto o responsável não definir a diária, ou para quem não vê valores.
  double? get valor {
    final d = diarista.diaria;
    return d == null || d == 0 ? null : d * dias;
  }
}

/// Quem tem dias sem pagar, inclusive quem já saiu da lista.
List<DiariasAbertas> diariasEmAberto(List<Diarista> diaristas, List<Presenca> presencas) {
  final dias = <String, double>{};
  for (final p in presencas) {
    if (!p.pago) dias[p.diaristaId] = (dias[p.diaristaId] ?? 0) + p.dias;
  }
  return [
    for (final d in diaristas)
      if (dias[d.id] != null) DiariasAbertas(diarista: d, dias: dias[d.id]!),
  ];
}

/// Soma do que já tem valor definido.
double totalEmAberto(List<DiariasAbertas> abertas) => abertas.fold(0, (s, a) => s + (a.valor ?? 0));

class Contrato {
  const Contrato({this.id, required this.empreiteiro, this.usuario, required this.servico, this.etapa, this.valor, this.encerrado = false});
  factory Contrato.fromJson(Map<String, dynamic> j) => Contrato(id: j['id'] as String?, empreiteiro: j['empreiteiro'] as String, usuario: j['usuario'] as String?, servico: j['servico'] as String, etapa: EtapaId.doCodigo(j['etapa'] as String? ?? ''), valor: (j['valor'] as num?)?.toDouble(), encerrado: j['encerrado'] as bool? ?? false);

  final String? id;
  final String empreiteiro;

  /// A pessoa da equipe que acompanha este contrato, quando ela tem acesso ao app.
  final String? usuario;
  final String servico;
  final EtapaId? etapa;

  /// O mestre recebe sem valor.
  final double? valor;
  final bool encerrado;

  Map<String, Object?> paraSalvar() => {'empreiteiro': empreiteiro, 'usuario': usuario, 'servico': servico, 'etapa': etapa?.codigo, 'valor': valor, 'encerrado': encerrado};
}

enum SituacaoMedicao {
  aguardando('Aguardando aprovação'),
  aprovada('A pagar'),
  paga('Paga');

  const SituacaoMedicao(this.rotulo);
  final String rotulo;
}

class Medicao {
  const Medicao({this.id, required this.contratoId, required this.numero, required this.data, required this.percentual, this.valor, this.observacao = '', this.aprovada = false, this.paga = false, this.pagaEm});
  factory Medicao.fromJson(Map<String, dynamic> j) => Medicao(
    id: j['id'] as String?,
    contratoId: j['contrato_id'] as String,
    numero: (j['numero'] as num).toInt(),
    data: DateTime.parse(j['data'] as String),
    percentual: (j['percentual'] as num).toDouble(),
    valor: (j['valor'] as num?)?.toDouble(),
    observacao: j['observacao'] as String? ?? '',
    aprovada: j['aprovada'] as bool? ?? false,
    paga: j['pago'] as bool? ?? false,
    pagaEm: j['pago_em'] == null ? null : DateTime.parse(j['pago_em'] as String),
  );

  final String? id;
  final String contratoId;
  final int numero;
  final DateTime data;

  /// Quanto do contrato estava pronto nesta medição, somando as anteriores.
  final double percentual;
  final double? valor;
  final String observacao;
  final bool aprovada;
  final bool paga;
  final DateTime? pagaEm;

  SituacaoMedicao get situacao => paga
      ? SituacaoMedicao.paga
      : aprovada
      ? SituacaoMedicao.aprovada
      : SituacaoMedicao.aguardando;
}

/// "33,33%", "60%"
String textoDePercentual(double p) => '${p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString().replaceAll('.', ',')}%';

/// Um contrato com as medições dele, da primeira para a última.
class ResumoContrato {
  const ResumoContrato({required this.contrato, required this.medicoes});
  final Contrato contrato;
  final List<Medicao> medicoes;

  Medicao? get ultima => medicoes.isEmpty ? null : medicoes.last;
  double get percentual => ultima?.percentual ?? 0;
  double get medido => medicoes.fold(0, (s, m) => s + (m.valor ?? 0));
  double get pago => medicoes.where((m) => m.paga).fold(0, (s, m) => s + (m.valor ?? 0));

  /// Já medido e ainda sem pagamento.
  double get aPagar => medido - pago;

  /// O que falta acontecer. Contrato encerrado não espera mais nada.
  double get aMedir => contrato.encerrado ? 0 : (contrato.valor ?? 0) - medido;

  bool get aguardando => medicoes.any((m) => m.situacao == SituacaoMedicao.aguardando);
  bool get podeMedir => !contrato.encerrado && !aguardando && percentual < 100;
}

List<ResumoContrato> resumirContratos(List<Contrato> contratos, List<Medicao> medicoes) => [
  for (final c in contratos)
    ResumoContrato(
      contrato: c,
      medicoes: [
        for (final m in medicoes)
          if (m.contratoId == c.id) m,
      ]..sort((a, b) => a.numero.compareTo(b.numero)),
    ),
];

extension FuncaoNaMaoDeObra on FuncaoObra {
  /// O empreiteiro entra só para acompanhar o contrato dele.
  bool get veContratos => lidera || this == FuncaoObra.empreiteiro;
}
