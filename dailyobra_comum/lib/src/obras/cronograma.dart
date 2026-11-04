/// Cronograma da obra e pendências: datas previstas e reais de cada etapa, atraso e o que ficou por resolver.
library;

import 'dart:math' as math;

import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import 'diario.dart';
import 'obra.dart';

DateTime? _data(Object? v) => v == null ? null : DateTime.parse(v as String);
String? _iso(DateTime? d) => d == null ? null : dataIso(d);
DateTime _somar(DateTime d, int dias) => DateTime(d.year, d.month, d.day + dias);

/// Dias corridos de [de] até [ate]. Conta no calendário, sem hora nem fuso.
int diasEntre(DateTime de, DateTime ate) => DateTime.utc(ate.year, ate.month, ate.day).difference(DateTime.utc(de.year, de.month, de.day)).inDays;

class DatasEtapa {
  const DatasEtapa({this.inicioPrevisto, this.fimPrevisto, this.inicioReal, this.fimReal});
  factory DatasEtapa.fromJson(Map<String, dynamic> j) => DatasEtapa(inicioPrevisto: _data(j['inicio_previsto']), fimPrevisto: _data(j['fim_previsto']), inicioReal: _data(j['inicio_real']), fimReal: _data(j['fim_real']));

  final DateTime? inicioPrevisto;
  final DateTime? fimPrevisto;

  /// Nascem quando a etapa é marcada como iniciada ou concluída; quem lidera pode acertar.
  final DateTime? inicioReal;
  final DateTime? fimReal;

  bool get temPrevisto => inicioPrevisto != null && fimPrevisto != null;

  /// Sem [comReal], as datas reais que estão no banco ficam como estão.
  Map<String, Object?> paraSalvar(EtapaId etapa, {bool comReal = true}) => {
    'etapa': etapa.codigo,
    'inicio_previsto': _iso(inicioPrevisto),
    'fim_previsto': _iso(fimPrevisto),
    if (comReal) 'inicio_real': _iso(inicioReal),
    if (comReal) 'fim_real': _iso(fimReal),
  };
}

/// Dias de atraso da etapa em [hoje]. Etapa concluída conta só até o dia em que terminou.
int diasDeAtraso(DatasEtapa d, StatusEtapa status, DateTime hoje) {
  final fim = d.fimPrevisto;
  final inicio = d.inicioPrevisto;
  if (status == StatusEtapa.concluida) {
    final terminou = d.fimReal;
    return fim == null || terminou == null ? 0 : math.max(0, diasEntre(fim, terminou));
  }
  if (fim != null && diasEntre(fim, hoje) > 0) return diasEntre(fim, hoje);
  if (status == StatusEtapa.prevista && inicio != null && diasEntre(inicio, hoje) > 0) return diasEntre(inicio, hoje);
  return 0;
}

class ResumoCronograma {
  const ResumoCronograma({required this.comDatas, required this.atrasadas, required this.maiorAtraso});
  final int comDatas;

  /// Só as que ainda estão em aberto: etapa concluída com atraso não pede mais nada.
  final int atrasadas;
  final int maiorAtraso;

  bool get emDia => atrasadas == 0;

  String get texto {
    if (comDatas == 0) return 'Sem datas ainda';
    if (emDia) return 'Em dia';
    return atrasadas == 1 ? '1 etapa atrasada' : '$atrasadas etapas atrasadas';
  }
}

ResumoCronograma resumirCronograma({required List<EtapaId> etapas, required Map<EtapaId, DatasEtapa> datas, required Map<EtapaId, StatusEtapa> status, required DateTime hoje}) {
  var comDatas = 0;
  var atrasadas = 0;
  var maior = 0;
  for (final e in etapas) {
    final d = datas[e];
    if (d == null || !d.temPrevisto) continue;
    comDatas++;
    final situacao = status[e] ?? StatusEtapa.prevista;
    if (situacao == StatusEtapa.concluida) continue;
    final dias = diasDeAtraso(d, situacao, hoje);
    if (dias > 0) {
      atrasadas++;
      maior = math.max(maior, dias);
    }
  }
  return ResumoCronograma(comDatas: comDatas, atrasadas: atrasadas, maiorAtraso: maior);
}

/// Frase do aviso no topo da obra; nulo quando não há nada para avisar.
String? alertaDaObra(ResumoCronograma resumo, int pendenciasVencidas) {
  final partes = [
    if (!resumo.emDia) '${resumo.texto}, a maior com ${_dias(resumo.maiorAtraso)}',
    if (pendenciasVencidas == 1) '1 pendência vencida' else if (pendenciasVencidas > 1) '$pendenciasVencidas pendências vencidas',
  ];
  return partes.isEmpty ? null : '${partes.join('. ')}.';
}

String _dias(int n) => n == 1 ? '1 dia' : '$n dias';

/// Obra de 120 m² leva uns 8 meses; serve só de ponto de partida para o campo "fim previsto".
int diasEstimados(double area) => (60 + area * 1.5).round().clamp(90, 720);

/// Primeiro rascunho do cronograma: etapas em sequência, cada uma com dias proporcionais ao custo.
/// Quem lidera ajusta depois; as datas reais que já existem ficam como estão.
Map<EtapaId, DatasEtapa> sugerirCronograma({required List<LinhaResultado> etapas, required DateTime inicio, required DateTime fim, Map<EtapaId, DatasEtapa> atuais = const {}}) {
  final total = etapas.fold<double>(0, (s, e) => s + e.total);
  final dias = math.max(diasEntre(inicio, fim) + 1, etapas.length);
  final sugestao = <EtapaId, DatasEtapa>{};
  var acumulado = 0.0;
  var comeca = 0;
  for (final (i, e) in etapas.indexed) {
    acumulado += total == 0 ? 1 / etapas.length : e.total / total;
    final restantes = etapas.length - i - 1;
    // O fim vem da soma acumulada, para os arredondamentos não empurrarem o fim da obra
    final termina = restantes == 0 ? dias - 1 : math.min(math.max((acumulado * dias).round() - 1, comeca), dias - 1 - restantes);
    sugestao[e.etapa] = DatasEtapa(inicioPrevisto: _somar(inicio, comeca), fimPrevisto: _somar(inicio, termina), inicioReal: atuais[e.etapa]?.inicioReal, fimReal: atuais[e.etapa]?.fimReal);
    comeca = termina + 1;
  }
  return sugestao;
}

class Pendencia {
  const Pendencia({this.id, required this.descricao, this.etapa, this.responsavelId, this.responsavelNome, this.prazo, this.fotoPath, this.resolvida = false, this.possoMexer = true});
  factory Pendencia.fromJson(Map<String, dynamic> j) => Pendencia(
    id: j['id'] as String?,
    descricao: j['descricao'] as String,
    etapa: EtapaId.doCodigo(j['etapa'] as String? ?? ''),
    responsavelId: j['responsavel_id'] as String?,
    responsavelNome: j['responsavel_nome'] as String?,
    prazo: _data(j['prazo']),
    fotoPath: j['foto_path'] as String?,
    resolvida: j['situacao'] == 'resolvida',
    possoMexer: j['posso_mexer'] as bool? ?? false,
  );

  /// Nulo enquanto não foi salva.
  final String? id;
  final String descricao;
  final EtapaId? etapa;
  final String? responsavelId;
  final String? responsavelNome;
  final DateTime? prazo;
  final String? fotoPath;
  final bool resolvida;

  /// Quem lidera a obra, quem criou e quem vai resolver.
  final bool possoMexer;

  int diasVencida(DateTime hoje) {
    final p = prazo;
    return resolvida || p == null ? 0 : math.max(0, diasEntre(p, hoje));
  }

  Map<String, Object?> paraSalvar() => {'descricao': descricao, 'etapa': etapa?.codigo, 'responsavel_id': responsavelId, 'prazo': _iso(prazo), 'foto_path': fotoPath};
}
