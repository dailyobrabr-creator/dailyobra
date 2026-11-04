/// O que vai para o cliente da obra: a marca do responsável, o resumo da semana e as mudanças para aprovar.
library;

import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import '../ui/ui.dart' show brl;
import 'cronograma.dart';
import 'diario.dart';
import 'equipe.dart';
import 'obra.dart';

/// Quem assina os documentos da obra.
class MarcaEngenheiro {
  const MarcaEngenheiro({this.nome = '', this.registro = '', this.telefone = '', this.email = '', this.logoPath});
  factory MarcaEngenheiro.fromJson(Map<String, dynamic> j) => MarcaEngenheiro(nome: j['nome'] as String? ?? '', registro: j['registro'] as String? ?? '', telefone: j['telefone'] as String? ?? '', email: j['email'] as String? ?? '', logoPath: j['logo_path'] as String?);

  final String nome;

  /// CREA ou CAU.
  final String registro;
  final String telefone;
  final String email;
  final String? logoPath;

  /// "CREA 1234/D · (65) 98888-7777 · contato@..."
  String get contato => [registro, telefone, email].where((p) => p.trim().isNotEmpty).join(' · ');

  Map<String, Object?> paraSalvar() => {'nome': nome, 'registro': registro, 'telefone': telefone, 'email': email, 'logo_path': logoPath};
}

enum SituacaoMudanca {
  pendente('Aguardando o cliente'),
  aprovada('Aprovada'),
  recusada('Recusada');

  const SituacaoMudanca(this.rotulo);
  final String rotulo;

  static SituacaoMudanca de(Object? v) => values.asNameMap()[v] ?? pendente;
}

/// Um pedido de aprovação ao cliente.
class Mudanca {
  const Mudanca({this.id, required this.titulo, this.descricao = '', this.valor, this.dias, this.situacao = SituacaoMudanca.pendente, this.resposta = '', this.respondidoPor, this.criadaEm, this.respondidaEm});
  factory Mudanca.fromJson(Map<String, dynamic> j) => Mudanca(
    id: j['id'] as String?,
    titulo: j['titulo'] as String,
    descricao: j['descricao'] as String? ?? '',
    valor: (j['valor'] as num?)?.toDouble(),
    dias: (j['dias'] as num?)?.toInt(),
    situacao: SituacaoMudanca.de(j['situacao']),
    resposta: j['resposta'] as String? ?? '',
    respondidoPor: j['respondido_por'] as String?,
    criadaEm: j['criado_em'] == null ? null : DateTime.parse(j['criado_em'] as String).toLocal(),
    respondidaEm: j['respondido_em'] == null ? null : DateTime.parse(j['respondido_em'] as String).toLocal(),
  );

  final String? id;
  final String titulo;
  final String descricao;

  /// Quanto muda no orçamento: negativo reduz. O mestre recebe sem valor.
  final double? valor;

  /// Quanto muda no prazo, em dias.
  final int? dias;
  final SituacaoMudanca situacao;
  final String resposta;
  final String? respondidoPor;
  final DateTime? criadaEm;
  final DateTime? respondidaEm;

  bool get pendente => situacao == SituacaoMudanca.pendente;

  /// "+ R$ 3.500,00 · + 5 dias"
  String get impacto {
    final v = valor;
    final d = dias;
    return [
      if (v != null && v != 0) '${v > 0 ? '+' : '-'} ${brl.format(v.abs())}',
      if (d != null && d != 0) impactoNoPrazo,
    ].join(' · ');
  }

  /// "+ 5 dias", sem o valor: é o que vai no relatório.
  String get impactoNoPrazo {
    final d = dias;
    if (d == null || d == 0) return '';
    return '${d > 0 ? '+' : '-'} ${d.abs() == 1 ? '1 dia' : '${d.abs()} dias'}';
  }

  /// "Aprovada por Dona Lia em 04/11/2026"
  String get registroDaResposta {
    final r = respondidaEm;
    if (pendente || r == null) return '';
    final quem = respondidoPor == null ? '' : ' por $respondidoPor';
    return '${situacao.rotulo}$quem em ${dataCurta(r)}/${r.year}';
  }

  Map<String, Object?> paraSalvar() => {'titulo': titulo, 'descricao': descricao, 'valor': valor, 'dias': dias};
}

/// Texto para mandar ao cliente quando uma mudança espera a resposta dele.
String mensagemDaMudanca({required String nomeDaObra, required Mudanca mudanca}) {
  final impacto = mudanca.impacto;
  return [
    'Tem uma mudança para você aprovar na obra $nomeDaObra:',
    mudanca.titulo,
    if (impacto.isNotEmpty) impacto,
    'Abra o DailyObra para aprovar ou recusar.',
  ].join('\n');
}

/// Soma do que o cliente aprovou: entra no orçado da obra.
double somarAprovado(List<Mudanca> mudancas) => mudancas.where((m) => m.situacao == SituacaoMudanca.aprovada).fold(0, (s, m) => s + (m.valor ?? 0));

/// Semana de segunda a domingo.
class SemanaObra {
  const SemanaObra._(this.inicio);

  factory SemanaObra.doDia(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return SemanaObra._(DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday)));
  }

  final DateTime inicio;
  DateTime get fim => DateTime(inicio.year, inicio.month, inicio.day + 6);
  SemanaObra get anterior => SemanaObra._(DateTime(inicio.year, inicio.month, inicio.day - 7));
  SemanaObra get proxima => SemanaObra._(DateTime(inicio.year, inicio.month, inicio.day + 7));

  bool contem(DateTime dia) => diasEntre(inicio, dia) >= 0 && diasEntre(dia, fim) >= 0;

  /// "02/11 a 08/11"
  String get texto => '${dataCurta(inicio)} a ${dataCurta(fim)}';
}

class ResumoDaSemana {
  const ResumoDaSemana({required this.dias, required this.atividades, required this.ocorrencias, required this.fotos});
  final List<DiaObra> dias;

  /// Cada serviço uma vez, com o último percentual informado.
  final List<Atividade> atividades;
  final List<Ocorrencia> ocorrencias;
  final List<FotoDia> fotos;

  bool get vazio => dias.isEmpty;

  /// Média de pessoas nos dias em que a equipe foi anotada.
  int get mediaDePessoas {
    final comEquipe = dias.where((d) => d.pessoas > 0).toList();
    if (comEquipe.isEmpty) return 0;
    return (comEquipe.fold<int>(0, (s, d) => s + d.pessoas) / comEquipe.length).round();
  }
}

ResumoDaSemana resumirSemana(List<DiaObra> dias, SemanaObra semana) {
  final daSemana = dias.where((d) => semana.contem(d.data)).toList()..sort((a, b) => a.data.compareTo(b.data));
  final atividades = <String, Atividade>{};
  for (final d in daSemana) {
    for (final a in d.atividades) {
      atividades['${a.descricao.trim().toLowerCase()}|${a.local.trim().toLowerCase()}'] = a;
    }
  }
  return ResumoDaSemana(dias: daSemana, atividades: atividades.values.toList(), ocorrencias: [for (final d in daSemana) ...d.ocorrencias], fotos: [for (final d in daSemana) ...d.fotos]);
}

class ProximaEtapa {
  const ProximaEtapa({required this.nome, required this.inicio, required this.fim});
  final String nome;
  final DateTime inicio;
  final DateTime fim;
}

/// As próximas etapas ainda não concluídas, na ordem das datas.
List<ProximaEtapa> proximasEtapas({required List<LinhaResultado> etapas, required Map<EtapaId, DatasEtapa> datas, required Map<EtapaId, StatusEtapa> status, int quantas = 3}) {
  final lista = <ProximaEtapa>[
    for (final e in etapas)
      if (status[e.etapa] != StatusEtapa.concluida && (datas[e.etapa]?.temPrevisto ?? false)) ProximaEtapa(nome: e.nome, inicio: datas[e.etapa]!.inicioPrevisto!, fim: datas[e.etapa]!.fimPrevisto!),
  ]..sort((a, b) => a.inicio.compareTo(b.inicio));
  return lista.take(quantas).toList();
}

/// A última data prevista do cronograma, somada aos dias das mudanças aprovadas.
DateTime? previsaoDeTermino(Map<EtapaId, DatasEtapa> datas, [List<Mudanca> mudancas = const []]) {
  DateTime? fim;
  for (final d in datas.values) {
    final f = d.fimPrevisto;
    if (f != null && (fim == null || f.isAfter(fim))) fim = f;
  }
  if (fim == null) return null;
  final dias = mudancas.where((m) => m.situacao == SituacaoMudanca.aprovada).fold<int>(0, (s, m) => s + (m.dias ?? 0));
  return DateTime(fim.year, fim.month, fim.day + dias);
}

/// O que entra no relatório: o que ainda espera resposta e o que aconteceu na semana.
List<Mudanca> mudancasDaSemana(List<Mudanca> mudancas, SemanaObra semana) => [
  for (final m in mudancas)
    if (m.pendente || (m.respondidaEm != null && semana.contem(m.respondidaEm!))) m,
];

/// Tudo o que o relatório da semana mostra.
class RelatorioDaSemana {
  const RelatorioDaSemana({required this.semana, required this.resumo, required this.andamento, this.etapaAtual, this.termino, this.mudancas = const [], this.proximas = const [], this.diasEmRascunho = 0});
  final SemanaObra semana;
  final ResumoDaSemana resumo;

  /// Percentual concluído da obra.
  final int andamento;
  final String? etapaAtual;
  final DateTime? termino;
  final List<Mudanca> mudancas;
  final List<ProximaEtapa> proximas;

  /// Dias da semana ainda não finalizados: ficam fora, porque ninguém revisou.
  final int diasEmRascunho;
}

RelatorioDaSemana montarRelatorio({required Obra obra, required List<LinhaResultado> etapas, required List<DiaObra> dias, required List<Mudanca> mudancas, required SemanaObra semana}) {
  final atual = etapaAtual(etapas, obra.statusEtapas);
  return RelatorioDaSemana(
    semana: semana,
    resumo: resumirSemana(dias.where((d) => d.fechado).toList(), semana),
    andamento: progresso(etapas, obra.statusEtapas),
    etapaAtual: atual?.nome,
    termino: previsaoDeTermino(obra.cronograma, mudancas),
    mudancas: mudancasDaSemana(mudancas, semana),
    proximas: proximasEtapas(etapas: etapas, datas: obra.cronograma, status: obra.statusEtapas),
    diasEmRascunho: dias.where((d) => !d.fechado && semana.contem(d.data)).length,
  );
}

/// Mensagem que acompanha o PDF no WhatsApp.
String mensagemDoRelatorio({required String nomeDaObra, required SemanaObra semana}) => 'Relatório da obra $nomeDaObra, semana de ${semana.texto}.';

extension FuncaoNoCliente on FuncaoObra {
  /// Empreiteiro e estagiário não entram nas conversas com o cliente.
  bool get veMudancas => this == FuncaoObra.responsavel || this == FuncaoObra.mestre || this == FuncaoObra.cliente;
}
