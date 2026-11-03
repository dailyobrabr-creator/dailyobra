import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loja_service.dart';
import 'periodo_resultados.dart';

/// Construtor do top do período (a loja já vê o nome e a empresa de quem comprou dela).
class ConstrutorTop {
  const ConstrutorTop({
    required this.construtorId,
    this.nome = '',
    this.empresa = '',
    required this.pedidos,
    required this.total,
  });

  factory ConstrutorTop.fromJson(Map<String, dynamic> j) => ConstrutorTop(
    construtorId: j['construtor_id'] as String,
    nome: (j['nome'] as String?) ?? '',
    empresa: (j['empresa'] as String?) ?? '',
    pedidos: (j['pedidos'] as num).toInt(),
    total: (j['total'] as num).toDouble(),
  );

  final String construtorId;
  final String nome;
  final String empresa;
  final int pedidos;
  final double total;

  String get exibicao => nome.isEmpty ? 'Construtor' : nome;
}

/// Pedidos fechados de um período, somados pela função resultados_loja.
class ResultadosPeriodo {
  const ResultadosPeriodo({
    this.faturamento = 0,
    this.pedidos = 0,
    this.cashback = 0,
    this.top = const [],
  });

  factory ResultadosPeriodo.fromJson(Map<String, dynamic> j) =>
      ResultadosPeriodo(
        faturamento: (j['faturamento'] as num).toDouble(),
        pedidos: (j['pedidos'] as num).toInt(),
        cashback: (j['cashback'] as num).toDouble(),
        top: [
          for (final t in (j['top'] as List?) ?? const [])
            ConstrutorTop.fromJson(t as Map<String, dynamic>),
        ],
      );

  final double faturamento;
  final int pedidos;
  final double cashback;
  final List<ConstrutorTop> top;

  /// Sem pedido não há ticket.
  double? get ticket => pedidos == 0 ? null : faturamento / pedidos;
}

/// Resultados do mês da loja no Início, para dono e gerente (o banco recusa o vendedor).
class ResultadosService extends ChangeNotifier {
  ResultadosService._();

  static final instance = ResultadosService._();

  SupabaseClient get _db => Supabase.instance.client;

  DateTime? _mes;
  PeriodoResultados? _periodo;
  ResultadosPeriodo? _atual;
  ResultadosPeriodo? _anterior;
  bool _carregando = false;
  String? _erro;
  int _pedido = 0;
  Future<ResultadosPeriodo> Function(DateTime de, DateTime ate)? _buscarDeTeste;

  /// Primeiro dia do mês aberto.
  DateTime? get mes => _mes;
  PeriodoResultados? get periodo => _periodo;
  ResultadosPeriodo? get atual => _atual;

  /// O período com que o mês é comparado.
  ResultadosPeriodo? get anterior => _anterior;
  bool get carregando => _carregando;
  String? get erro => _erro;

  @visibleForTesting
  void definirParaTeste({
    required Future<ResultadosPeriodo> Function(DateTime de, DateTime ate)
    buscar,
  }) {
    limpar();
    _buscarDeTeste = buscar;
  }

  void limpar() {
    _pedido++;
    _mes = null;
    _periodo = null;
    _atual = null;
    _anterior = null;
    _carregando = false;
    _erro = null;
    notifyListeners();
  }

  /// Carrega o mês de [mes] e a comparação dele; a resposta de um carregar mais antigo é descartada.
  Future<void> carregar(DateTime mes, {DateTime? agora}) async {
    final meu = ++_pedido;
    final periodo = periodoDoMes(mes, agora ?? DateTime.now());
    if (_mes != periodo.de) {
      _atual = null;
      _anterior = null;
    }
    _mes = periodo.de;
    _periodo = periodo;
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        _buscar(periodo.de, periodo.ate),
        _buscar(periodo.deAnterior, periodo.ateAnterior),
      ]);
      if (meu != _pedido) return;
      _atual = r[0];
      _anterior = r[1];
    } on FalhaComMensagem catch (e) {
      if (meu != _pedido) return;
      _erro = e.mensagem;
    }
    _carregando = false;
    notifyListeners();
  }

  /// O mesmo mês de novo (puxar para atualizar no Início).
  Future<void> recarregar() async {
    final mes = _mes;
    if (mes != null) await carregar(mes);
  }

  Future<ResultadosPeriodo> _buscar(DateTime de, DateTime ate) async {
    final buscar = _buscarDeTeste;
    if (buscar != null) return buscar(de, ate);
    final loja = LojaService.instance.minhaLoja;
    if (loja == null) {
      throw const FalhaComMensagem(
        'Cadastre a loja antes de ver os resultados.',
      );
    }
    final j = await comMensagem(
      () => _db.rpc(
        'resultados_loja',
        params: {
          'p_loja': loja.id,
          'p_de': de.toUtc().toIso8601String(),
          'p_ate': ate.toUtc().toIso8601String(),
        },
      ),
    );
    return ResultadosPeriodo.fromJson(Map<String, dynamic>.from(j as Map));
  }
}
