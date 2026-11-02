import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

const tijolo = ItemCatalogo(id: 'tijolo', nome: 'Tijolo 8 furos', unidade: 'unidade', categoriaId: 'alvenaria', tier: 1);
const argamassa = ItemCatalogo(id: 'argamassa', nome: 'Argamassa AC-I', unidade: 'saco', categoriaId: 'basico', tier: 1);
const cimento = ItemCatalogo(id: 'cimento', nome: 'Cimento CP II', unidade: 'saco', categoriaId: 'basico', tier: 1);
const torneira = ItemCatalogo(id: 'torneira', nome: 'Torneira', unidade: 'unidade', categoriaId: 'loucas-metais', tier: 4);
final catalogo = {for (final i in [tijolo, argamassa, cimento, torneira]) i.id: i};

const lojaA = Loja(id: 'A', nome: 'Loja A', cidade: 'Maringá', uf: 'PR', freteFixo: 50, pedidoMinimo: 100);
const lojaB = Loja(id: 'B', nome: 'Loja B', cidade: 'Maringá', uf: 'PR', freteFixo: 30);
const lojaC = Loja(id: 'C', nome: 'Loja C', cidade: 'Sarandi', uf: 'PR', freteFixo: 0);
final lojas = {for (final l in [lojaA, lojaB, lojaC]) l.id: l};

const tiers = {1: 0.01, 2: 0.02, 3: 0.03, 4: 0.05};
final hoje = DateTime(2026, 10, 31, 10);
final ontem = DateTime(2026, 10, 30);

Oferta of(String loja, String item, double preco,
        {double? promo, DateTime? ate, Disponibilidade d = Disponibilidade.disponivel, bool pausada = false}) =>
    Oferta(lojaId: loja, itemId: item, preco: preco, precoPromocional: promo, promoAte: ate, disponibilidade: d, pausada: pausada);

/// Cada loja é a mais barata em um item: tijolo na A, argamassa na B, cimento na C.
final ofertasBase = [
  of('A', 'tijolo', 1.20), of('B', 'tijolo', 1.35), of('C', 'tijolo', 1.40),
  of('A', 'argamassa', 30), of('B', 'argamassa', 25), of('C', 'argamassa', 28),
  of('A', 'cimento', 45), of('B', 'cimento', 42), of('C', 'cimento', 38),
];

final itensBase = [
  const ItemDesejado(itemId: 'tijolo', quantidade: 1000),
  const ItemDesejado(itemId: 'argamassa', quantidade: 10),
  const ItemDesejado(itemId: 'cimento', quantidade: 20),
];

ResultadoCotacao cotarCom({
  List<ItemDesejado>? itens,
  List<Oferta>? ofertas,
  Map<String, Loja>? lojasUsadas,
  ModoCotacao modo = ModoCotacao.menorPrecoGlobal,
  String? cidade,
}) =>
    cotar(
      itens: itens ?? itensBase,
      catalogo: catalogo,
      ofertas: ofertas ?? ofertasBase,
      lojas: lojasUsadas ?? lojas,
      modo: modo,
      hoje: hoje,
      percentualPorTier: tiers,
      cidade: cidade,
    );

String? lojaDo(ResultadoCotacao r, String itemId) {
  for (final g in r.grupos) {
    for (final l in g.linhas) {
      if (l.item.id == itemId) return g.loja.id;
    }
  }
  return null;
}

void main() {
  group('menor preço global', () {
    test('cada item vai para a loja mais barata naquele item', () {
      final r = cotarCom();
      expect(lojaDo(r, 'tijolo'), 'A');
      expect(lojaDo(r, 'argamassa'), 'B');
      expect(lojaDo(r, 'cimento'), 'C');
      expect(r.grupos.map((g) => g.loja.id), ['A', 'B', 'C']);
    });

    test('item com loja fixada fica nela mesmo mais caro', () {
      final r = cotarCom(itens: [
        itensBase[0], itensBase[1],
        const ItemDesejado(itemId: 'cimento', quantidade: 20, lojaFixada: 'A'),
      ]);
      expect(lojaDo(r, 'cimento'), 'A');
      final linha = r.grupos.firstWhere((g) => g.loja.id == 'A').linhas.firstWhere((l) => l.item.id == 'cimento');
      expect(linha.precoUnitario, 45);
    });

    test('loja fixada que não tem mais o item cai para a mais barata', () {
      final r = cotarCom(
        itens: [const ItemDesejado(itemId: 'cimento', quantidade: 1, lojaFixada: 'B')],
        ofertas: [of('A', 'cimento', 45), of('B', 'cimento', 42, pausada: true), of('C', 'cimento', 38)],
      );
      expect(lojaDo(r, 'cimento'), 'C');
    });

    test('promoção vencida ontem usa o preço cheio; vencendo hoje usa o promocional', () {
      final vencida = cotarCom(ofertas: [of('A', 'tijolo', 1.20), of('B', 'tijolo', 1.35, promo: 1.00, ate: ontem)]);
      expect(lojaDo(vencida, 'tijolo'), 'A');

      final vigente = cotarCom(ofertas: [of('A', 'tijolo', 1.20), of('B', 'tijolo', 1.35, promo: 1.00, ate: DateTime(2026, 10, 31))]);
      expect(lojaDo(vigente, 'tijolo'), 'B');
      expect(vigente.grupos.single.linhas.single.precoUnitario, 1.00);
      expect(vigente.grupos.single.linhas.single.total, 1000.00);
    });

    test('oferta pausada ou sem estoque é ignorada; sob consulta entra marcada', () {
      final r = cotarCom(
        itens: [const ItemDesejado(itemId: 'cimento', quantidade: 2)],
        ofertas: [
          of('C', 'cimento', 30, pausada: true),
          of('B', 'cimento', 31, d: Disponibilidade.semEstoque),
          of('A', 'cimento', 45, d: Disponibilidade.sobConsulta),
        ],
      );
      final linha = r.grupos.single.linhas.single;
      expect(r.grupos.single.loja.id, 'A');
      expect(linha.sobConsulta, isTrue);
      expect(linha.total, 90);
    });

    test('empate de preço vai para a loja da cidade e depois para o menor frete', () {
      final empate = [of('A', 'cimento', 40), of('B', 'cimento', 40), of('C', 'cimento', 40)];
      final itens = [const ItemDesejado(itemId: 'cimento', quantidade: 1)];
      expect(lojaDo(cotarCom(itens: itens, ofertas: empate, cidade: 'Sarandi'), 'cimento'), 'C');
      expect(lojaDo(cotarCom(itens: itens, ofertas: empate, cidade: 'maringa'), 'cimento'), 'B', reason: 'B tem frete menor que A');
      expect(lojaDo(cotarCom(itens: itens, ofertas: empate), 'cimento'), 'C', reason: 'sem cidade, decide o frete');
    });

    test('loja fechada não entra na cotação', () {
      final fechada = {...lojas, 'C': const Loja(id: 'C', nome: 'Loja C', cidade: 'Sarandi', uf: 'PR', aberta: false)};
      expect(lojaDo(cotarCom(lojasUsadas: fechada), 'cimento'), 'B');
    });
  });

  group('melhor por loja', () {
    test('escolhe a loja que atende mais itens', () {
      final r = cotarCom(
        modo: ModoCotacao.melhorPorLoja,
        ofertas: [
          of('A', 'tijolo', 1.50), of('A', 'argamassa', 35), of('A', 'cimento', 50),
          of('B', 'tijolo', 1.00), of('B', 'cimento', 30),
        ],
      );
      expect(r.grupos.map((g) => g.loja.id), ['A']);
      expect(r.grupos.single.linhas, hasLength(3));
      expect(r.semOferta, isEmpty);
    });

    test('empate no número de itens vai para o menor total com frete', () {
      final r = cotarCom(
        modo: ModoCotacao.melhorPorLoja,
        itens: [const ItemDesejado(itemId: 'cimento', quantidade: 10)],
        ofertas: [of('A', 'cimento', 40), of('B', 'cimento', 41), of('C', 'cimento', 44)],
      );
      // A: 400 + 50 = 450; B: 410 + 30 = 440; C: 440 + 0 = 440 → empate B e C; C tem total igual e frete menor.
      expect(r.grupos.single.loja.id, isIn(['B', 'C']));
      expect(r.total, 440);
    });

    test('itens que a loja escolhida não tem ficam sem oferta', () {
      final r = cotarCom(
        modo: ModoCotacao.melhorPorLoja,
        ofertas: [of('A', 'tijolo', 1.50), of('A', 'argamassa', 35), of('B', 'cimento', 30)],
      );
      expect(r.grupos.single.loja.id, 'A');
      expect(r.semOferta.map((i) => i.id), ['cimento']);
    });
  });

  group('totais', () {
    test('frete entra uma vez por loja e pedido mínimo é sinalizado', () {
      final r = cotarCom(
        itens: [const ItemDesejado(itemId: 'tijolo', quantidade: 50), const ItemDesejado(itemId: 'argamassa', quantidade: 1)],
        ofertas: [of('A', 'tijolo', 1.20), of('A', 'argamassa', 30)],
      );
      final g = r.grupos.single;
      expect(g.subtotal, 90);
      expect(g.frete, 50);
      expect(g.total, 140);
      expect(g.abaixoMinimo, isTrue);
      expect(r.total, 140);
    });

    test('cashback de R\$ 1.000 em item nível 4 é R\$ 50 e o frete não gera cashback', () {
      final r = cotarCom(
        itens: [const ItemDesejado(itemId: 'torneira', quantidade: 5)],
        ofertas: [of('A', 'torneira', 200)],
      );
      expect(r.grupos.single.linhas.single.cashback, 50);
      expect(r.cashbackPrevisto, 50);
      expect(r.total, 1050);
    });

    test('item sem oferta em nenhuma loja fica fora do total', () {
      final r = cotarCom(itens: [...itensBase, const ItemDesejado(itemId: 'torneira', quantidade: 1)]);
      expect(r.semOferta.map((i) => i.id), ['torneira']);
      expect(r.total, closeTo(1200 + 50 + 250 + 30 + 760 + 0, 0.001));
    });

    test('lista vazia dá resultado vazio', () {
      final r = cotarCom(itens: []);
      expect(r.grupos, isEmpty);
      expect(r.semOferta, isEmpty);
      expect(r.total, 0);
      expect(r.cashbackPrevisto, 0);
    });
  });
}
