import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loja_service.dart';

/// Catálogo mestre e os preços da loja. A loja não cria produto: escolhe do catálogo e põe preço,
/// promoção, disponibilidade ou pausa (o catálogo é o mesmo para todas as lojas).
class OfertasService extends ChangeNotifier {
  OfertasService._();

  static final instance = OfertasService._();

  SupabaseClient get _db => Supabase.instance.client;

  List<Categoria> _categorias = const [];
  List<ItemCatalogo> _catalogo = const [];
  Map<String, Oferta> _minhas = const {};
  String? _lojaId;
  String? _erro;
  bool _carregado = false;

  List<Categoria> get categorias => _categorias;
  List<ItemCatalogo> get catalogo => _catalogo;

  /// Ofertas da loja por item_id, inclusive as pausadas.
  Map<String, Oferta> get minhas => _minhas;
  String? get erro => _erro;
  bool get carregado => _carregado;

  ItemCatalogo? item(String id) {
    for (final i in _catalogo) {
      if (i.id == id) return i;
    }
    return null;
  }

  int get ativas => _minhas.values.where((o) => !o.pausada).length;

  @visibleForTesting
  void definirParaTeste({
    List<Categoria> categorias = const [],
    List<ItemCatalogo> catalogo = const [],
    List<Oferta> minhas = const [],
    List<LigacaoProduto> ligacoes = const [],
  }) {
    _categorias = categorias;
    _catalogo = catalogo;
    _minhas = {for (final o in minhas) o.itemId: o};
    _teste = true;
    _ligacoesDeTeste = ligacoes;
    importacoesDeTeste.clear();
    _carregado = true;
    _erro = null;
    notifyListeners();
  }

  bool _teste = false;
  List<LigacaoProduto> _ligacoesDeTeste = const [];

  /// Importações do estoque nos testes (ofertas, ligações), sem chamar o banco.
  @visibleForTesting
  final importacoesDeTeste = <(List<Oferta>, List<LigacaoProduto>)>[];

  /// Códigos do Santri que a loja já ligou aos produtos do catálogo (loja_produtos).
  Future<List<LigacaoProduto>> carregarLigacoes() async {
    if (_teste) return _ligacoesDeTeste;
    final lojaId = _lojaId;
    if (lojaId == null) return const [];
    final linhas = await comMensagem(
      () => _db
          .from('loja_produtos')
          .select('codigo, item_id, nome, unidade')
          .eq('loja_id', lojaId),
    );
    return [for (final j in linhas) LigacaoProduto.fromJson(j)];
  }

  /// Grava o estoque do dia (função importar_estoque: ofertas e ligações juntas) e devolve quantas ofertas gravou.
  /// Lança [FalhaComMensagem].
  Future<int> importarEstoque({
    required List<Oferta> ofertas,
    required List<LigacaoProduto> ligacoes,
  }) async {
    if (_teste) {
      importacoesDeTeste.add((ofertas, ligacoes));
      return ofertas.length;
    }
    final lojaId = _lojaId;
    if (lojaId == null) {
      throw const FalhaComMensagem(
        'Cadastre a loja antes de atualizar o estoque.',
      );
    }
    final r = await comMensagem(
      () => _db.rpc(
        'importar_estoque',
        params: {
          'p_loja': lojaId,
          'p_ofertas': [
            for (final o in ofertas)
              {
                'item_id': o.itemId,
                'preco': o.preco,
                'disponibilidade': o.disponibilidade.codigo,
              },
          ],
          'p_ligacoes': [for (final g in ligacoes) g.toJson()],
        },
      ),
    );
    // A loja também, para a tela de Produtos mostrar a hora da última atualização
    await Future.wait([carregar(lojaId), LojaService.instance.carregar()]);
    return (r as Map)['ofertas'] as int;
  }

  void limpar() {
    _minhas = const {};
    _lojaId = null;
    _carregado = false;
    notifyListeners();
  }

  Future<void> carregar(String lojaId) async {
    _lojaId = lojaId;
    try {
      final r = await Future.wait<List<Map<String, dynamic>>>([
        _db
            .from('catalogo_categorias')
            .select('id, nome, ordem')
            .order('ordem'),
        _db
            .from('catalogo_itens')
            .select(
              'id, nome, unidade, categoria_id, tier_cashback, sinonimos, imagem_path, catalogo_referencias(preco, fonte)',
            )
            .eq('ativo', true)
            .order('nome'),
        _db
            .from('ofertas')
            .select(
              'loja_id, item_id, preco, preco_promocional, promo_ate, disponibilidade, pausada',
            )
            .eq('loja_id', lojaId),
      ]);
      _categorias = [for (final j in r[0]) Categoria.fromJson(j)];
      _catalogo = [for (final j in r[1]) ItemCatalogo.fromJson(j)];
      _minhas = {
        for (final j in r[2]) j['item_id'] as String: Oferta.fromJson(j),
      };
      _erro = null;
      _carregado = true;
    } catch (e) {
      _erro = mensagemDoServidor(e);
    }
    notifyListeners();
  }

  static String _data(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Grava (ou cria) o preço da loja para o produto. Lança [FalhaComMensagem].
  Future<void> salvar(Oferta o) async {
    final lojaId = _lojaId ?? o.lojaId;
    await comMensagem(
      () => _db.from('ofertas').upsert({
        'loja_id': lojaId,
        'item_id': o.itemId,
        'preco': o.preco,
        'preco_promocional': o.precoPromocional,
        'promo_ate': o.promoAte == null ? null : _data(o.promoAte!),
        'disponibilidade': o.disponibilidade.codigo,
        'pausada': o.pausada,
      }, onConflict: 'loja_id,item_id'),
    );
    await carregar(lojaId);
  }

  /// Grava vários preços de uma vez (importação de planilha), num upsert só. Disponibilidade e pausa
  /// ficam como estavam. Lança [FalhaComMensagem].
  Future<void> salvarVarias(List<Oferta> ofertas) async {
    if (ofertas.isEmpty) return;
    final lojaId = _lojaId ?? ofertas.first.lojaId;
    await comMensagem(
      () => _db.from('ofertas').upsert([
        for (final o in ofertas)
          {
            'loja_id': lojaId,
            'item_id': o.itemId,
            'preco': o.preco,
            'preco_promocional': o.precoPromocional,
            'promo_ate': o.promoAte == null ? null : _data(o.promoAte!),
          },
      ], onConflict: 'loja_id,item_id'),
    );
    await carregar(lojaId);
  }

  Future<void> pausar(String itemId, bool pausada) async {
    final lojaId = _lojaId;
    if (lojaId == null) return;
    await comMensagem(
      () => _db
          .from('ofertas')
          .update({'pausada': pausada})
          .eq('loja_id', lojaId)
          .eq('item_id', itemId),
    );
    await carregar(lojaId);
  }

  Future<void> remover(String itemId) async {
    final lojaId = _lojaId;
    if (lojaId == null) return;
    await comMensagem(
      () => _db
          .from('ofertas')
          .delete()
          .eq('loja_id', lojaId)
          .eq('item_id', itemId),
    );
    await carregar(lojaId);
  }
}
