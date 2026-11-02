import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hoje = DateTime(2026, 10, 31, 15, 30);

  Oferta oferta({double? promo, DateTime? ate, Disponibilidade d = Disponibilidade.disponivel, bool pausada = false}) =>
      Oferta(lojaId: 'a', itemId: 'x', preco: 40, precoPromocional: promo, promoAte: ate, disponibilidade: d, pausada: pausada);

  group('Oferta.precoVigente', () {
    test('sem promoção vale o preço cheio', () => expect(oferta().precoVigente(hoje), 40));
    test('promoção vale até o fim do dia indicado', () {
      expect(oferta(promo: 35, ate: DateTime(2026, 10, 31)).precoVigente(hoje), 35);
      expect(oferta(promo: 35, ate: DateTime(2026, 10, 30)).precoVigente(hoje), 40);
    });
    test('pausada ou sem estoque não tem preço', () {
      expect(oferta(pausada: true).precoVigente(hoje), isNull);
      expect(oferta(d: Disponibilidade.semEstoque).precoVigente(hoje), isNull);
      expect(oferta(d: Disponibilidade.sobConsulta).precoVigente(hoje), 40);
    });
  });

  test('fromJson lê as linhas do banco', () {
    final o = Oferta.fromJson({
      'loja_id': 'l1', 'item_id': 'cimento-cp2-50kg', 'preco': 45, 'preco_promocional': '39.90',
      'promo_ate': '2026-11-02', 'disponibilidade': 'sob_consulta', 'pausada': false,
    });
    expect(o.preco, 45.0);
    expect(o.precoPromocional, 39.9);
    expect(o.promoAte, DateTime(2026, 11, 2));
    expect(o.disponibilidade, Disponibilidade.sobConsulta);

    final i = ItemCatalogo.fromJson({
      'id': 'tijolo-8-furos', 'nome': 'Tijolo cerâmico 8 furos', 'unidade': 'un', 'categoria_id': 'alvenaria',
      'tier_cashback': 1, 'sinonimos': ['tijolo'], 'imagem_path': null,
    });
    expect(i.tier, 1);
    expect(i.sinonimos, ['tijolo']);
    expect(i.imagemUrl, isNull);

    final l = Loja.fromJson({
      'id': 'l1', 'nome': 'Loja A', 'descricao': null, 'logo_path': 'l1/logo.jpg', 'capa_path': null, 'whatsapp': null,
      'cidade': 'Maringá', 'uf': 'PR', 'frete_fixo': 50, 'pedido_minimo': '100.00', 'aberta': true,
      'criada_em': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    });
    expect(l.descricao, '');
    expect(l.logoUrl, endsWith('/storage/v1/object/public/lojas/l1/logo.jpg'));
    expect(l.capaUrl, isNull);
    expect(l.pedidoMinimo, 100);
    expect(l.nova, isTrue);
    expect(l.freteACombinar, isFalse, reason: 'sem a coluna, o frete vale como cadastrado');
    final combinar = Loja.fromJson({
      'id': 'l2', 'nome': 'Loja B', 'cidade': 'Rondonópolis', 'uf': 'MT', 'frete_fixo': 0, 'pedido_minimo': 0,
      'frete_a_combinar': true,
    });
    expect(combinar.freteACombinar, isTrue);

    expect(Categoria.fromJson({'id': 'basico', 'nome': 'Básico', 'ordem': 1}).nome, 'Básico');
  });

  test('status têm código do banco e rótulo em português', () {
    expect(StatusPedido.fromCodigo('saiu_entrega'), StatusPedido.saiuEntrega);
    expect(StatusPedido.emSeparacao.rotulo, 'Em separação');
    expect(StatusProposta.fromCodigo('contraproposta'), StatusProposta.contraproposta);
    expect(ModoProposta.pedido.codigo, 'pedido');
    expect(Disponibilidade.fromCodigo('sem_estoque'), Disponibilidade.semEstoque);
    for (final s in StatusProposta.values) {
      expect(s.rotulo, isNotEmpty);
      expect(StatusProposta.fromCodigo(s.codigo), s);
    }
  });
}
