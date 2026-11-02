import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sino de novidades: o que as lojas fizeram nas propostas e pedidos do construtor e o cashback
/// liberado, nos últimos 30 dias. O "visto até" fica no aparelho.
class NovidadesService extends ChangeNotifier {
  NovidadesService._();

  static final instance = NovidadesService._();
  static const _chaveVisto = 'dailyobra.novidades.vistoAte';

  SupabaseClient get _db => Supabase.instance.client;

  List<Novidade> _itens = const [];
  DateTime? _vistoAte;
  bool _carregado = false;
  String? _erro;
  int _pedido = 0;

  List<Novidade> get itens => _itens;
  int get naoVistas => contarDesde(_itens, _vistoAte);
  bool get carregado => _carregado;
  String? get erro => _erro;

  @visibleForTesting
  void definirParaTeste({List<Novidade> itens = const [], DateTime? vistoAte}) {
    _itens = itens;
    _vistoAte = vistoAte;
    _carregado = true;
    notifyListeners();
  }

  void limpar() {
    _pedido++;
    _itens = const [];
    _carregado = false;
    notifyListeners();
  }

  Future<void> carregar() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final meu = ++_pedido;
    try {
      final texto = (await SharedPreferences.getInstance()).getString(
        _chaveVisto,
      );
      _vistoAte = texto == null ? null : DateTime.tryParse(texto);
      final desde = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 30))
          .toIso8601String();
      final r = await Future.wait<List<Map<String, dynamic>>>([
        _db
            .from('proposta_eventos')
            .select(
              'proposta_id, para, papel, justificativa, criado_em, propostas!inner(construtor_id, lojas(nome))',
            )
            .eq('propostas.construtor_id', uid)
            .gte('criado_em', desde)
            .order('criado_em', ascending: false)
            .limit(50),
        _db
            .from('pedido_eventos')
            .select(
              'pedido_id, para, autor, criado_em, pedidos!inner(construtor_id, total, lojas(nome))',
            )
            .eq('pedidos.construtor_id', uid)
            .gte('criado_em', desde)
            .order('criado_em', ascending: false)
            .limit(50),
        _db
            .from('carteira_lancamentos')
            .select('valor, descricao, criado_em, pedido_id, lojas(nome)')
            .eq('construtor_id', uid)
            .eq('tipo', 'cashback_liberado')
            .eq('conta', 'disponivel')
            .gte('criado_em', desde)
            .order('criado_em', ascending: false)
            .limit(50),
      ]);
      if (meu != _pedido) return;
      String? lojaDe(Map<String, dynamic>? m) =>
          (m?['lojas'] as Map?)?['nome'] as String?;
      _itens = novidadesDe(
        usuarioId: uid,
        eventosProposta: [
          for (final j in r[0])
            {
              ...j,
              'loja_nome': lojaDe(j['propostas'] as Map<String, dynamic>?),
            },
        ],
        eventosPedido: [
          for (final j in r[1])
            {
              ...j,
              'loja_nome': lojaDe(j['pedidos'] as Map<String, dynamic>?),
              'total': (j['pedidos'] as Map?)?['total'],
            },
        ],
        cashback: [
          for (final j in r[2])
            {...j, 'loja_nome': (j['lojas'] as Map?)?['nome']},
        ],
      );
      _erro = null;
      _carregado = true;
    } catch (e) {
      if (meu != _pedido) return;
      _erro = mensagemDoServidor(e);
    }
    notifyListeners();
  }

  /// Abriu a lista: tudo o que está nela conta como visto.
  Future<void> marcarVistas() async {
    final agora = DateTime.now();
    final maisNova = _itens.isEmpty ? agora : _itens.first.quando;
    _vistoAte = maisNova.isAfter(agora) ? maisNova : agora;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(
        _chaveVisto,
        _vistoAte!.toIso8601String(),
      );
    } catch (_) {}
  }
}
