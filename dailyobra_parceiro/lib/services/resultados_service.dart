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

/// Vendas de um dia do período, no fuso do aparelho.
class VendaDoDia {
  const VendaDoDia({
    required this.dia,
    required this.total,
    required this.pedidos,
  });

  factory VendaDoDia.fromJson(Map<String, dynamic> j) => VendaDoDia(
    dia: DateTime.parse(j['dia'] as String),
    total: (j['total'] as num).toDouble(),
    pedidos: (j['pedidos'] as num).toInt(),
  );

  final DateTime dia;
  final double total;
  final int pedidos;
}

/// Produto dos pedidos do período, pelo valor dos itens (sem frete e sem o desconto no total).
class ProdutoVendido {
  const ProdutoVendido({
    required this.itemId,
    required this.nome,
    required this.unidade,
    required this.quantidade,
    required this.total,
  });

  factory ProdutoVendido.fromJson(Map<String, dynamic> j) => ProdutoVendido(
    itemId: j['item_id'] as String,
    nome: j['nome'] as String,
    unidade: j['unidade'] as String,
    quantidade: (j['quantidade'] as num).toDouble(),
    total: (j['total'] as num).toDouble(),
  );

  final String itemId;
  final String nome;
  final String unidade;
  final double quantidade;
  final double total;
}

/// Gráfico, funil e produtos de um período, pela função desempenho_loja.
class DesempenhoPeriodo {
  const DesempenhoPeriodo({
    this.vendasPorDia = const [],
    this.propostas = 0,
    this.respondidas = 0,
    this.viraramPedido = 0,
    this.produtos = const [],
  });

  factory DesempenhoPeriodo.fromJson(Map<String, dynamic> j) =>
      DesempenhoPeriodo(
        vendasPorDia: [
          for (final v in (j['vendas_por_dia'] as List?) ?? const [])
            VendaDoDia.fromJson(v as Map<String, dynamic>),
        ],
        propostas: (j['propostas'] as num).toInt(),
        respondidas: (j['respondidas'] as num).toInt(),
        viraramPedido: (j['viraram_pedido'] as num).toInt(),
        produtos: [
          for (final p in (j['produtos'] as List?) ?? const [])
            ProdutoVendido.fromJson(p as Map<String, dynamic>),
        ],
      );

  final List<VendaDoDia> vendasPorDia;

  /// Propostas recebidas no período.
  final int propostas;
  final int respondidas;

  /// Das recebidas, as que têm pedido não cancelado.
  final int viraramPedido;

  /// Os cinco de maior valor, do maior ao menor.
  final List<ProdutoVendido> produtos;

  /// Sem proposta não há conversão.
  double? get conversao => propostas == 0 ? null : viraramPedido / propostas;
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
  DesempenhoPeriodo? _desempenho;
  bool _carregando = false;
  String? _erro;
  int _pedido = 0;
  Future<ResultadosPeriodo> Function(DateTime de, DateTime ate)? _buscarDeTeste;
  Future<DesempenhoPeriodo> Function(DateTime de, DateTime ate)?
  _buscarDesempenhoDeTeste;

  /// Primeiro dia do mês aberto.
  DateTime? get mes => _mes;
  PeriodoResultados? get periodo => _periodo;
  ResultadosPeriodo? get atual => _atual;

  /// O período com que o mês é comparado.
  ResultadosPeriodo? get anterior => _anterior;

  /// Gráfico, funil e produtos do mês aberto.
  DesempenhoPeriodo? get desempenho => _desempenho;
  bool get carregando => _carregando;
  String? get erro => _erro;

  @visibleForTesting
  void definirParaTeste({
    required Future<ResultadosPeriodo> Function(DateTime de, DateTime ate)
    buscar,
    Future<DesempenhoPeriodo> Function(DateTime de, DateTime ate)?
    buscarDesempenho,
  }) {
    limpar();
    _buscarDeTeste = buscar;
    _buscarDesempenhoDeTeste = buscarDesempenho;
  }

  void limpar() {
    _pedido++;
    _mes = null;
    _periodo = null;
    _atual = null;
    _anterior = null;
    _desempenho = null;
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
      _desempenho = null;
    }
    _mes = periodo.de;
    _periodo = periodo;
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      final r = await Future.wait<Object>([
        _buscar(periodo.de, periodo.ate),
        _buscar(periodo.deAnterior, periodo.ateAnterior),
        _buscarDesempenho(periodo.de, periodo.ate),
      ]);
      if (meu != _pedido) return;
      _atual = r[0] as ResultadosPeriodo;
      _anterior = r[1] as ResultadosPeriodo;
      _desempenho = r[2] as DesempenhoPeriodo;
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

  Future<DesempenhoPeriodo> _buscarDesempenho(DateTime de, DateTime ate) async {
    if (_buscarDeTeste != null) {
      return await _buscarDesempenhoDeTeste?.call(de, ate) ??
          const DesempenhoPeriodo();
    }
    final loja = LojaService.instance.minhaLoja;
    if (loja == null) {
      throw const FalhaComMensagem(
        'Cadastre a loja antes de ver os resultados.',
      );
    }
    final j = await comMensagem(
      () => _db.rpc(
        'desempenho_loja',
        params: {
          'p_loja': loja.id,
          'p_de': de.toUtc().toIso8601String(),
          'p_ate': ate.toUtc().toIso8601String(),
          'p_fuso_min': de.timeZoneOffset.inMinutes,
        },
      ),
    );
    return DesempenhoPeriodo.fromJson(Map<String, dynamic>.from(j as Map));
  }
}
