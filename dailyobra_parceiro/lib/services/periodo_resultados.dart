/// Um mês dos resultados da loja e o período com que ele é comparado, no fuso do aparelho.
class PeriodoResultados {
  const PeriodoResultados({
    required this.de,
    required this.ate,
    required this.deAnterior,
    required this.ateAnterior,
    required this.mesAtual,
  });
  final DateTime de;
  final DateTime ate;
  final DateTime deAnterior;
  final DateTime ateAnterior;

  /// O mês de agora compara com o mesmo período do mês anterior; mês passado, com o anterior inteiro.
  final bool mesAtual;
}

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// O mês de [mes] (qualquer dia dele) e a comparação: no mês atual, de 1º do mês anterior até o mesmo dia e hora de
/// [agora] nele (ou até o fim dele, quando ele não tem esse dia); em mês passado, o mês anterior inteiro.
PeriodoResultados periodoDoMes(DateTime mes, DateTime agora) {
  final de = DateTime(mes.year, mes.month);
  final mesAtual = mes.year == agora.year && mes.month == agora.month;
  // Dia que o mês anterior não tem passa para o mês seguinte e fica depois de `de`
  final mesmoMomento = DateTime(
    agora.year,
    agora.month - 1,
    agora.day,
    agora.hour,
    agora.minute,
    agora.second,
    agora.millisecond,
  );
  return PeriodoResultados(
    de: de,
    ate: DateTime(mes.year, mes.month + 1),
    deAnterior: DateTime(mes.year, mes.month - 1),
    ateAnterior: mesAtual && mesmoMomento.isBefore(de) ? mesmoMomento : de,
    mesAtual: mesAtual,
  );
}

/// "novembro" (o app não inicia o intl com datas).
String nomeSoDoMes(DateTime mes) => _meses[mes.month - 1];

/// "novembro de 2026".
String nomeDoMes(DateTime mes) => '${nomeSoDoMes(mes)} de ${mes.year}';

/// (atual − anterior) ÷ anterior; nulo sem venda no período anterior.
double? variacao(double atual, double anterior) =>
    anterior == 0 ? null : (atual - anterior) / anterior;

/// "+18,4% sobre o mesmo período de outubro", "−5,2% sobre setembro" ou "sem vendas em setembro para comparar".
String textoVariacao(
  PeriodoResultados p, {
  required double atual,
  required double anterior,
}) {
  final mes = nomeSoDoMes(p.deAnterior);
  final v = variacao(atual, anterior);
  if (v == null) return 'sem vendas em $mes para comparar';
  final pct = (v * 1000).round() / 10;
  final sinal = pct > 0
      ? '+'
      : pct < 0
      ? '−'
      : '';
  final numero = pct.abs().toStringAsFixed(1).replaceAll('.', ',');
  return '$sinal$numero% sobre ${p.mesAtual ? 'o mesmo período de $mes' : mes}';
}
