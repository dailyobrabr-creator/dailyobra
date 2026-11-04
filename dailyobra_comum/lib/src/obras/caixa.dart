/// Caixa da obra: o que entrou, o que saiu e como o saldo fica nas próximas semanas.
library;

import 'dart:math';

import '../orcamento/tabelas.dart';
import '../ui/ui.dart' show brl;
import 'cliente.dart';
import 'cronograma.dart';
import 'diario.dart';
import 'dinheiro.dart';
import 'mao_de_obra.dart';
import 'obra.dart';

/// Dinheiro que o cliente pagou ou combinou de pagar.
class EntradaCaixa {
  const EntradaCaixa({this.id, required this.descricao, required this.valor, required this.data, this.recebido = false});
  factory EntradaCaixa.fromJson(Map<String, dynamic> j) => EntradaCaixa(id: j['id'] as String?, descricao: j['descricao'] as String, valor: (j['valor'] as num).toDouble(), data: DateTime.parse(j['data'] as String), recebido: j['recebido'] as bool? ?? false);

  final String? id;
  final String descricao;
  final double valor;
  final DateTime data;

  /// Falso enquanto é só previsão.
  final bool recebido;

  Map<String, Object?> paraSalvar() => {'descricao': descricao, 'valor': valor, 'data': dataIso(data), 'recebido': recebido};
}

class SemanaDeCaixa {
  const SemanaDeCaixa({required this.semana, required this.entradas, required this.saidas, required this.saldo});
  final SemanaObra semana;
  final double entradas;
  final double saidas;

  /// Como o caixa termina a semana.
  final double saldo;
}

class PrevisaoCaixa {
  const PrevisaoCaixa({required this.recebido, required this.pago, required this.semanas, required this.semData, required this.depois, required this.aPagarAgora, this.temEntradas = true});
  final double recebido;
  final double pago;
  final List<SemanaDeCaixa> semanas;

  /// Etapas sem data no cronograma e contratos sem etapa: existem, mas não têm semana.
  final double semData;

  /// O que fica para depois das semanas mostradas.
  final double depois;

  /// Diárias em aberto e medições sem pagamento.
  final double aPagarAgora;

  /// Sem nenhuma entrada lançada, o saldo só mostra os gastos e o aviso não ajudaria.
  final bool temEntradas;

  double get saldoAtual => recebido - pago;

  /// Frase do aviso; nula quando o caixa aguenta as semanas mostradas.
  String? get alerta {
    if (!temEntradas) return null;
    if (saldoAtual < 0) return 'O caixa está negativo em ${brl.format(-saldoAtual)}.';
    for (final s in semanas) {
      if (s.saldo < 0) return 'Na semana de ${s.semana.texto} o caixa fica negativo em ${brl.format(-s.saldo)}.';
    }
    return null;
  }
}

/// Junta o que já aconteceu com o que falta. O que já está devido cai na semana atual. O que falta
/// de cada etapa se divide por igual entre os dias que restam dela no cronograma.
PrevisaoCaixa preverCaixa({required DateTime hoje, required ResumoDinheiro resumo, required Map<EtapaId, DatasEtapa> datas, required Map<EtapaId, StatusEtapa> status, required List<EntradaCaixa> entradas, double diariasAbertas = 0, List<ResumoContrato> contratos = const [], int quantasSemanas = 8}) {
  final hojeLimpo = DateTime(hoje.year, hoje.month, hoje.day);
  final primeira = SemanaObra.doDia(hojeLimpo);
  final semanas = <SemanaObra>[primeira];
  while (semanas.length < quantasSemanas) {
    semanas.add(semanas.last.proxima);
  }
  final entra = List<double>.filled(quantasSemanas, 0);
  final sai = List<double>.filled(quantasSemanas, 0);
  int indice(DateTime dia) => diasEntre(primeira.inicio, dia) ~/ 7;

  var recebido = 0.0;
  for (final e in entradas) {
    if (e.recebido) {
      recebido += e.valor;
      continue;
    }
    // Previsão vencida ainda é dinheiro a receber: fica na semana atual
    final i = max(indice(e.data), 0);
    if (i < quantasSemanas) entra[i] += e.valor;
  }

  final aPagarAgora = diariasAbertas + contratos.fold<double>(0, (s, c) => s + c.aPagar);
  sai[0] += aPagarAgora;

  final firmes = <EtapaId, double>{};
  final aMedir = <EtapaId, double>{};
  var semData = max(resumo.adicionais + resumo.mudancas, 0.0);
  for (final c in contratos) {
    final e = c.contrato.etapa;
    if (e == null) {
      semData += c.aMedir;
    } else {
      firmes[e] = (firmes[e] ?? 0) + c.aPagar;
      aMedir[e] = (aMedir[e] ?? 0) + c.aMedir;
    }
  }

  var depois = 0.0;
  for (final l in resumo.linhas) {
    if (status[l.etapa] == StatusEtapa.concluida) continue;
    final falta = max(max(l.orcado - l.realizado - (firmes[l.etapa] ?? 0), 0.0), aMedir[l.etapa] ?? 0);
    if (falta <= 0) continue;
    final d = datas[l.etapa];
    if (d == null || !d.temPrevisto) {
      semData += falta;
      continue;
    }
    final inicio = d.inicioPrevisto!.isAfter(hojeLimpo) ? d.inicioPrevisto! : hojeLimpo;
    final fim = d.fimPrevisto!.isAfter(inicio) ? d.fimPrevisto! : inicio;
    final total = diasEntre(inicio, fim) + 1;
    final porDia = falta / total;
    for (var i = 0; i < total; i++) {
      final s = indice(DateTime(inicio.year, inicio.month, inicio.day + i));
      if (s < quantasSemanas) {
        sai[s] += porDia;
      } else {
        depois += porDia;
      }
    }
  }

  var saldo = recebido - resumo.realizado;
  final linhas = <SemanaDeCaixa>[];
  for (var i = 0; i < quantasSemanas; i++) {
    saldo += entra[i] - sai[i];
    linhas.add(SemanaDeCaixa(semana: semanas[i], entradas: entra[i], saidas: sai[i], saldo: saldo));
  }
  return PrevisaoCaixa(recebido: recebido, pago: resumo.realizado, semanas: linhas, semData: semData, depois: depois, aPagarAgora: aPagarAgora, temEntradas: entradas.isNotEmpty);
}
