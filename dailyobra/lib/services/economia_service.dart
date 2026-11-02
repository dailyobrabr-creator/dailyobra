import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Economia dos últimos 6 meses (comparando lojas + negociando + cashback), calculada no banco.
class EconomiaService extends ChangeNotifier {
  EconomiaService._();

  static final instance = EconomiaService._();

  SupabaseClient get _db => Supabase.instance.client;

  List<EconomiaMes> _meses = const [];
  bool _carregado = false;
  String? _erro;

  /// Do mais antigo ao mês atual.
  List<EconomiaMes> get meses => _meses;
  EconomiaMes? get atual => _meses.isEmpty ? null : _meses.last;
  bool get carregado => _carregado;
  String? get erro => _erro;

  @visibleForTesting
  void definirParaTeste(List<EconomiaMes> meses, {String? erro}) {
    _meses = meses;
    _erro = erro;
    _carregado = erro == null;
    notifyListeners();
  }

  void limpar() {
    _meses = const [];
    _carregado = false;
    _erro = null;
    notifyListeners();
  }

  Future<void> carregar() async {
    if (_db.auth.currentUser == null) return;
    try {
      final linhas = await _db.rpc('economia_mensal', params: {'p_meses': 6});
      _meses = [
        for (final j in linhas as List)
          EconomiaMes.fromJson(Map<String, dynamic>.from(j as Map)),
      ];
      _erro = null;
      _carregado = true;
    } catch (e) {
      _erro = mensagemDoServidor(e);
    }
    notifyListeners();
  }
}
