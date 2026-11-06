import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conta impressões e cliques dos anúncios. É um extra da vitrine: falhar nunca aparece para o construtor. Cada anúncio
/// conta uma impressão por sessão, para rolar a tela não inflar o número da loja.
class AnunciosService {
  AnunciosService._();

  static final instance = AnunciosService._();

  final _vistos = <String>{};
  bool _teste = false;

  /// O que iria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  final eventosDeTeste = <(String, String)>[];

  @visibleForTesting
  void definirParaTeste() {
    _teste = true;
    _vistos.clear();
    eventosDeTeste.clear();
  }

  void limpar() => _vistos.clear();

  void impressao(String anuncioId) {
    if (_vistos.add(anuncioId)) _registrar(anuncioId, 'impressao');
  }

  void clique(String anuncioId) => _registrar(anuncioId, 'clique');

  Future<void> _registrar(String anuncioId, String evento) async {
    if (_teste) {
      eventosDeTeste.add((anuncioId, evento));
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'registrar_evento_anuncio',
        params: {'p_anuncio': anuncioId, 'p_evento': evento},
      );
    } on Exception {
      // Métrica perdida não atrapalha a compra
    }
  }
}
