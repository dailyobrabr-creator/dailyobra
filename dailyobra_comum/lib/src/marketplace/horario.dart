import 'modelos.dart';

/// Faixa de atendimento num dia da semana (1 = segunda ... 7 = domingo), em minutos do dia.
class FaixaHorario {
  const FaixaHorario(this.dia, this.inicio, this.fim);
  final int dia;
  final int inicio;
  final int fim;
}

const _dias = {'seg': 1, 'ter': 2, 'qua': 3, 'qui': 4, 'sex': 5, 'sab': 6, 'dom': 7};
const _nomesDias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

const _dia = r'(?:dom|seg|ter|qua|qui|sex|sab)[a-z]*(?:-feira)?';
const _padraoHora = r'(?<!\d)\d{1,2}(?:\s*[:h]\s*\d{2})?\s*(?:hs|h)?(?!\d)';
const _faixa = '$_padraoHora\\s*(?:as|a|-|ate)\\s*$_padraoHora';
final _bloco = RegExp(
  '(todos os dias|diariamente|todo dia|$_dia(?:\\s*(?:a|-|ate|,|e)\\s*$_dia)*)'
  '\\s*[:,-]?\\s*(?:das\\s+|de\\s+)?'
  '($_faixa(?:\\s*(?:e|,|/)\\s*(?:das\\s+)?$_faixa)*)',
);
final _reDia = RegExp(_dia);
final _reFaixa = RegExp('($_padraoHora)\\s*(?:as|a|-|ate)\\s*($_padraoHora)');
final _numeros = RegExp(r'\d+');

String _normalizar(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final ch in texto.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i < 0 ? (ch == '–' || ch == '—' ? '-' : ch) : para[i]);
  }
  return b.toString();
}

int? _minutos(String hora) {
  final n = _numeros.allMatches(hora).map((m) => int.parse(m[0]!)).toList();
  final h = n[0];
  final m = n.length > 1 ? n[1] : 0;
  if (h > 24 || m > 59) return null;
  return h * 60 + m;
}

Set<int> _diasDoTrecho(String trecho) {
  if (!_reDia.hasMatch(trecho)) return {1, 2, 3, 4, 5, 6, 7};
  final achados = _reDia.allMatches(trecho).toList();
  final dias = <int>{};
  for (var i = 0; i < achados.length; i++) {
    final atual = _dias[achados[i][0]!.substring(0, 3)]!;
    dias.add(atual);
    if (i + 1 < achados.length) {
      final entre = trecho.substring(achados[i].end, achados[i + 1].start).trim();
      if (entre == 'a' || entre == '-' || entre == 'ate') {
        final fim = _dias[achados[i + 1][0]!.substring(0, 3)]!;
        for (var d = atual; d != fim; d = d % 7 + 1) {
          dias.add(d);
        }
      }
    }
  }
  return dias;
}

/// Faixas de atendimento lidas do horário que a loja escreveu ("Seg a sex 7h às 17h30; sáb 7h
/// às 12h"). Null quando o texto não diz claramente os dias e as horas: melhor não mostrar
/// "aberta" do que chutar.
List<FaixaHorario>? lerHorario(String texto) {
  final normal = _normalizar(texto);
  final faixas = <FaixaHorario>[];
  for (final bloco in _bloco.allMatches(normal)) {
    final dias = _diasDoTrecho(bloco[1]!);
    for (final f in _reFaixa.allMatches(bloco[2]!)) {
      final inicio = _minutos(f[1]!);
      final fim = _minutos(f[2]!);
      if (inicio == null || fim == null || inicio == fim) continue;
      for (final d in dias) {
        if (fim > inicio) {
          faixas.add(FaixaHorario(d, inicio, fim));
        } else {
          // Passa da meia-noite: vai até o fim do dia e continua no seguinte
          faixas.add(FaixaHorario(d, inicio, 24 * 60));
          if (fim > 0) faixas.add(FaixaHorario(d % 7 + 1, 0, fim));
        }
      }
    }
  }
  return faixas.isEmpty ? null : faixas;
}

/// Horas de diferença para UTC no estado da loja. O Brasil não tem horário de verão desde 2019.
int fusoDaUf(String uf) => switch (uf) {
  'AC' => -5,
  'AM' || 'RO' || 'RR' || 'MT' || 'MS' => -4,
  _ => -3,
};

enum EstadoLoja { aberta, fechada, pausada, semHorario }

/// Situação da loja num instante: o que o selo mostra e quando muda.
class SituacaoLoja {
  const SituacaoLoja(this.estado, [this.detalhe = '']);
  final EstadoLoja estado;

  /// "fecha às 17h30", "abre às 7h", "abre amanhã às 7h", "abre seg às 7h".
  final String detalhe;

  String get selo => switch (estado) {
    EstadoLoja.aberta => 'aberta',
    EstadoLoja.fechada => 'fechada',
    EstadoLoja.pausada => 'pedidos pausados',
    EstadoLoja.semHorario => '',
  };
}

String _hora(int minutos) {
  final h = (minutos ~/ 60) % 24;
  final m = minutos % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

/// Texto do horário no formato que [lerHorario] lê ("Seg a sex 7h às 11h e 13h às 18h; sáb 7h às 12h"): dias
/// seguidos com as mesmas faixas viram um trecho ("sáb e dom", "ter a sex"). Sem faixa nenhuma, texto vazio.
String escreverHorario(List<FaixaHorario> faixas) {
  final porDia = {for (var d = 1; d <= 7; d++) d: <FaixaHorario>[]};
  for (final f in faixas) {
    porDia[f.dia]?.add(f);
  }
  String doDia(int d) => ([...porDia[d]!]..sort((a, b) => a.inicio.compareTo(b.inicio)))
      .map((f) => '${_hora(f.inicio)} às ${_hora(f.fim)}')
      .join(' e ');
  final trechos = <String>[];
  var d = 1;
  while (d <= 7) {
    final horas = doDia(d);
    if (horas.isEmpty) {
      d++;
      continue;
    }
    var fim = d;
    while (fim < 7 && doDia(fim + 1) == horas) {
      fim++;
    }
    final dias = fim == d ? _nomesDias[d - 1] : '${_nomesDias[d - 1]} ${fim == d + 1 ? 'e' : 'a'} ${_nomesDias[fim - 1]}';
    trechos.add('$dias $horas');
    d = fim + 1;
  }
  final texto = trechos.join('; ');
  return texto.isEmpty ? '' : texto[0].toUpperCase() + texto.substring(1);
}

/// Aberta ou fechada agora, pelo horário da loja e no fuso dela. A loja que desligou os pedidos
/// no app aparece como pausada; sem horário legível, não há selo.
SituacaoLoja situacaoDaLoja(Loja loja, DateTime agora) {
  if (!loja.aberta) return const SituacaoLoja(EstadoLoja.pausada);
  final faixas = lerHorario(loja.horario);
  if (faixas == null) return const SituacaoLoja(EstadoLoja.semHorario);
  final local = agora.toUtc().add(Duration(hours: fusoDaUf(loja.uf)));
  final hoje = local.weekday;
  final minuto = local.hour * 60 + local.minute;
  for (final f in faixas) {
    if (f.dia == hoje && f.inicio <= minuto && minuto < f.fim) {
      // Se outra faixa começa exatamente quando esta acaba (passa da meia-noite), fecha depois
      final emSeguida = faixas.where((g) => g.dia == hoje % 7 + 1 && g.inicio == 0 && f.fim == 24 * 60);
      final fim = emSeguida.isEmpty ? f.fim : emSeguida.first.fim;
      return SituacaoLoja(EstadoLoja.aberta, 'fecha às ${_hora(fim)}');
    }
  }
  for (var d = 0; d < 7; d++) {
    final dia = (hoje - 1 + d) % 7 + 1;
    final proximas = faixas.where((f) => f.dia == dia && (d > 0 || f.inicio > minuto)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    if (proximas.isEmpty) continue;
    final quando = d == 0 ? 'às' : d == 1 ? 'amanhã às' : '${_nomesDias[dia - 1]} às';
    return SituacaoLoja(EstadoLoja.fechada, 'abre $quando ${_hora(proximas.first.inicio)}');
  }
  return const SituacaoLoja(EstadoLoja.fechada);
}
