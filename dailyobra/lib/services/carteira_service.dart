import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Linha do extrato como o construtor vê: só as contas dele (pendente e disponível).
class Lancamento {
  const Lancamento({
    required this.descricao,
    required this.valor,
    required this.conta,
    required this.tipo,
    required this.data,
    this.loja,
    this.tier,
  });
  final String descricao;
  final double valor;

  /// 'pendente' ou 'disponivel'
  final String conta;
  final String tipo;
  final DateTime data;
  final String? loja;
  final int? tier;

  bool get pendente => conta == 'pendente';
}

/// Saldo de cashback (livro-caixa no banco; o app só lê).
class CarteiraService extends ChangeNotifier {
  CarteiraService._();

  static final instance = CarteiraService._();

  SupabaseClient get _db => Supabase.instance.client;

  double _disponivel = 0, _pendente = 0, _reservado = 0;
  List<Lancamento> _extrato = const [];
  String? _erro;
  bool _carregado = false;

  double get disponivel => _disponivel;
  double get pendente => _pendente;
  double get reservado => _reservado;
  List<Lancamento> get extrato => _extrato;
  String? get erro => _erro;
  bool get carregado => _carregado;

  @visibleForTesting
  void definirParaTeste({
    double disponivel = 0,
    double pendente = 0,
    double reservado = 0,
    List<Lancamento> extrato = const [],
    String? erro,
  }) {
    _disponivel = disponivel;
    _pendente = pendente;
    _reservado = reservado;
    _extrato = extrato;
    _erro = erro;
    _carregado = true;
    notifyListeners();
  }

  void limpar() => definirParaTeste();

  Future<void> carregar() async {
    if (_db.auth.currentUser == null) return;
    try {
      final r = await Future.wait<dynamic>([
        _db
            .from('carteira_saldos')
            .select('disponivel, pendente, reservado')
            .maybeSingle(),
        _db
            .from('carteira_lancamentos')
            .select(
              'conta, valor, tipo, descricao, tier, criado_em, lojas(nome)',
            )
            .inFilter('conta', ['disponivel', 'pendente'])
            .order('criado_em', ascending: false)
            .limit(200),
      ]);
      final saldo = r[0] as Map<String, dynamic>?;
      _disponivel = lerValor(saldo?['disponivel']);
      _pendente = lerValor(saldo?['pendente']);
      _reservado = lerValor(saldo?['reservado']);
      _extrato = [
        for (final j in r[1] as List)
          // Na liberação o valor sai do pendente e entra no disponível: basta mostrar a entrada
          if (!(j['tipo'] == 'cashback_liberado' && j['conta'] == 'pendente'))
            Lancamento(
              descricao: j['descricao'] as String,
              valor: lerValor(j['valor']),
              conta: j['conta'] as String,
              tipo: j['tipo'] as String,
              data: DateTime.parse(j['criado_em'] as String).toLocal(),
              tier: (j['tier'] as num?)?.toInt(),
              loja: (j['lojas'] as Map?)?['nome'] as String?,
            ),
      ];
      _erro = null;
      _carregado = true;
    } catch (e) {
      _erro = mensagemDoServidor(e);
    }
    notifyListeners();
  }
}
