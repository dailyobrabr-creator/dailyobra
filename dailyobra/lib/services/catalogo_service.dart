import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vitrine do marketplace: catálogo mestre, lojas ativas e ofertas. Carrega tudo de uma vez
/// (o catálogo tem ~100 produtos) e responde as telas em memória. Se a recarga falhar, os dados
/// anteriores continuam valendo e [erro] avisa.
class CatalogoService extends ChangeNotifier {
  CatalogoService._();

  static final instance = CatalogoService._();

  SupabaseClient get _db => Supabase.instance.client;

  List<Categoria> _categorias = const [];
  List<ItemCatalogo> _itens = const [];
  Map<String, ItemCatalogo> _itemPorId = const {};
  List<Loja> _lojas = [];
  Map<String, Loja> _lojaPorId = const {};
  List<Oferta> _ofertas = const [];
  Map<int, double> _tiers = const {1: 0.01, 2: 0.02, 3: 0.03, 4: 0.05};
  Map<String, (String, double)> _planilha = const {};
  String? _cidade;
  String? _erro;
  bool _carregado = false;
  bool _carregando = false;

  List<Categoria> get categorias => _categorias;
  List<ItemCatalogo> get itens => _itens;
  Map<String, ItemCatalogo> get itemPorId => _itemPorId;

  /// Lojas da cidade do perfil primeiro, depois as abertas, depois por nome.
  List<Loja> get lojas => _lojas;
  Map<String, Loja> get lojaPorId => _lojaPorId;
  List<Oferta> get ofertas => _ofertas;
  Map<int, double> get percentualPorTier => _tiers;

  /// "nome|unidade" da planilha de materiais → produto do catálogo e fator de conversão.
  Map<String, (String, double)> get planilhaParaItem => _planilha;
  String? get erro => _erro;
  bool get carregado => _carregado;
  bool get carregando => _carregando;

  ItemCatalogo? item(String id) => _itemPorId[id];
  Loja? loja(String id) => _lojaPorId[id];

  @visibleForTesting
  void definirParaTeste({
    List<Categoria> categorias = const [],
    List<ItemCatalogo> itens = const [],
    List<Loja> lojas = const [],
    List<Oferta> ofertas = const [],
    Map<int, double>? tiers,
    Map<String, (String, double)> planilha = const {},
    String? cidade,
    String? erro,
  }) {
    _aplicar(
      categorias,
      itens,
      lojas,
      ofertas,
      tiers ?? const {1: 0.01, 2: 0.02, 3: 0.03, 4: 0.05},
      planilha,
    );
    _cidade = cidade;
    _ordenarLojas();
    _erro = erro;
    _carregado = true;
    notifyListeners();
  }

  void _aplicar(
    List<Categoria> categorias,
    List<ItemCatalogo> itens,
    List<Loja> lojas,
    List<Oferta> ofertas,
    Map<int, double> tiers,
    Map<String, (String, double)> planilha,
  ) {
    _categorias = [...categorias]..sort((a, b) => a.ordem.compareTo(b.ordem));
    _itens = [...itens]..sort((a, b) => a.nome.compareTo(b.nome));
    _itemPorId = {for (final i in _itens) i.id: i};
    _lojas = [...lojas];
    _lojaPorId = {for (final l in lojas) l.id: l};
    _ofertas = [
      for (final o in ofertas)
        if (_lojaPorId.containsKey(o.lojaId) &&
            _itemPorId.containsKey(o.itemId))
          o,
    ];
    _tiers = tiers;
    _planilha = planilha;
  }

  /// Cidade do perfil: as lojas dela aparecem primeiro e ganham o desempate na cotação.
  void definirCidade(String? cidade) {
    if (cidade == _cidade) return;
    _cidade = cidade;
    _ordenarLojas();
    notifyListeners();
  }

  String? get cidade => _cidade;

  void _ordenarLojas() {
    final minha = _cidade == null ? null : normalizar(_cidade!);
    _lojas.sort((a, b) {
      if (minha != null) {
        final ca = normalizar(a.cidade) == minha,
            cb = normalizar(b.cidade) == minha;
        if (ca != cb) return ca ? -1 : 1;
      }
      if (a.aberta != b.aberta) return a.aberta ? -1 : 1;
      return a.nome.compareTo(b.nome);
    });
  }

  bool lojaDaMinhaCidade(Loja l) =>
      _cidade != null && normalizar(l.cidade) == normalizar(_cidade!);

  Future<void> carregar() async {
    if (_carregando) return;
    _carregando = true;
    notifyListeners();
    try {
      final r = await Future.wait<List<Map<String, dynamic>>>([
        _db.from('catalogo_categorias').select('id, nome, ordem'),
        _db
            .from('catalogo_itens')
            .select(
              'id, nome, unidade, categoria_id, tier_cashback, sinonimos, imagem_path, catalogo_referencias(preco, fonte)',
            )
            .eq('ativo', true),
        _db
            .from('lojas')
            .select(
              'id, nome, descricao, logo_path, capa_path, whatsapp, endereco, cidade, uf, horario, frete_fixo, pedido_minimo, frete_a_combinar, aberta, criada_em',
            )
            .eq('status', 'ativa'),
        _db
            .from('ofertas')
            .select(
              'loja_id, item_id, preco, preco_promocional, promo_ate, disponibilidade, pausada',
            )
            .eq('pausada', false),
        _db.from('cashback_tiers').select('tier, percentual'),
        _db
            .from('catalogo_planilha')
            .select('nome, unidade, item_id, fator')
            .not('item_id', 'is', null),
      ]);
      _aplicar(
        [for (final j in r[0]) Categoria.fromJson(j)],
        [for (final j in r[1]) ItemCatalogo.fromJson(j)],
        [for (final j in r[2]) Loja.fromJson(j)],
        [for (final j in r[3]) Oferta.fromJson(j)],
        {
          for (final j in r[4])
            (j['tier'] as num).toInt(): lerValor(j['percentual']),
        },
        {
          for (final j in r[5])
            '${j['nome']}|${j['unidade']}': (
              j['item_id'] as String,
              j['fator'] == null ? 1.0 : lerValor(j['fator']),
            ),
        },
      );
      _ordenarLojas();
      _erro = null;
      _carregado = true;
    } catch (e) {
      final m = mensagemDoServidor(e);
      _erro = _carregado && m.startsWith('Sem conexão')
          ? 'Sem conexão. Mostrando os dados carregados por último.'
          : m;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Ofertas do produto que valem hoje, das lojas abertas primeiro e do menor para o maior preço.
  List<(Oferta, Loja)> precosDoItem(String itemId, {DateTime? hoje}) {
    final dia = hoje ?? DateTime.now();
    final lista = [
      for (final o in _ofertas)
        if (o.itemId == itemId && o.precoVigente(dia) != null)
          (o, _lojaPorId[o.lojaId]!),
    ];
    lista.sort((a, b) {
      if (a.$2.aberta != b.$2.aberta) return a.$2.aberta ? -1 : 1;
      final p = a.$1.precoVigente(dia)!.compareTo(b.$1.precoVigente(dia)!);
      if (p != 0) return p;
      final ca = lojaDaMinhaCidade(a.$2), cb = lojaDaMinhaCidade(b.$2);
      if (ca != cb) return ca ? -1 : 1;
      return a.$2.freteFixo.compareTo(b.$2.freteFixo);
    });
    return lista;
  }

  /// Melhor oferta (loja aberta) e em quantas lojas abertas o produto tem preço.
  ({Oferta? oferta, int lojas}) resumoDoItem(String itemId, {DateTime? hoje}) {
    final abertas = precosDoItem(
      itemId,
      hoje: hoje,
    ).where((p) => p.$2.aberta).toList();
    return (
      oferta: abertas.isEmpty ? null : abertas.first.$1,
      lojas: abertas.length,
    );
  }

  /// Promoções que valem hoje em lojas abertas, maior desconto primeiro.
  List<(Oferta, ItemCatalogo, Loja)> ofertasEmPromocao(DateTime hoje) {
    final lista = [
      for (final o in _ofertas)
        if (o.emPromocao(hoje) &&
            o.precoVigente(hoje) != null &&
            _lojaPorId[o.lojaId]!.aberta)
          (o, _itemPorId[o.itemId]!, _lojaPorId[o.lojaId]!),
    ];
    double desconto(Oferta o) => 1 - o.precoPromocional! / o.preco;
    lista.sort((a, b) => desconto(b.$1).compareTo(desconto(a.$1)));
    return lista;
  }

  /// Produtos que a loja vende, na ordem das categorias e por nome.
  List<(Oferta, ItemCatalogo)> ofertasDaLoja(String lojaId, {DateTime? hoje}) {
    final dia = hoje ?? DateTime.now();
    final ordem = {for (final c in _categorias) c.id: c.ordem};
    final lista = [
      for (final o in _ofertas)
        if (o.lojaId == lojaId && o.precoVigente(dia) != null)
          (o, _itemPorId[o.itemId]!),
    ];
    lista.sort((a, b) {
      final c = (ordem[a.$2.categoriaId] ?? 99).compareTo(
        ordem[b.$2.categoriaId] ?? 99,
      );
      return c != 0 ? c : a.$2.nome.compareTo(b.$2.nome);
    });
    return lista;
  }

  int promocoesDaLoja(String lojaId, DateTime hoje) => _ofertas
      .where(
        (o) =>
            o.lojaId == lojaId &&
            o.emPromocao(hoje) &&
            o.precoVigente(hoje) != null,
      )
      .length;

  List<ItemCatalogo> itensDaCategoria(String categoriaId) => [
    for (final i in _itens)
      if (i.categoriaId == categoriaId) i,
  ];

  /// Busca por começo de palavra no nome e nos sinônimos ("cimen" acha "Cimento CP II").
  /// Produtos com oferta vêm primeiro.
  List<ItemCatalogo> buscar(String texto) {
    final achados = [...buscarItens(_itens, texto)];
    final comOferta = {for (final o in _ofertas) o.itemId};
    achados.sort((a, b) {
      final ca = comOferta.contains(a.id), cb = comOferta.contains(b.id);
      if (ca != cb) return ca ? -1 : 1;
      return a.nome.compareTo(b.nome);
    });
    return achados;
  }
}
