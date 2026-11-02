import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

const cimento = ItemCatalogo(id: 'cimento', nome: 'Cimento CP II', unidade: 'saco', categoriaId: 'basico', tier: 1);
const tijolo = ItemCatalogo(id: 'tijolo', nome: 'Tijolo 8 furos', unidade: 'unidade', categoriaId: 'alvenaria', tier: 1);
const areia = ItemCatalogo(id: 'areia', nome: 'Areia média', unidade: 'm³', categoriaId: 'basico', tier: 1);
const torneira = ItemCatalogo(id: 'torneira', nome: 'Torneira', unidade: 'unidade', categoriaId: 'loucas-metais', tier: 4);

const lojas = {
  'a': Loja(id: 'a', nome: 'Loja A', cidade: 'Maringá', uf: 'PR'),
  'b': Loja(id: 'b', nome: 'Loja B', cidade: 'Maringá', uf: 'PR'),
  'f': Loja(id: 'f', nome: 'Loja Fechada', cidade: 'Maringá', uf: 'PR', aberta: false),
};

void main() {
  final hoje = DateTime(2026, 11, 1, 10);

  group('maisBaratoHoje', () {
    final ofertas = [
      const Oferta(lojaId: 'a', itemId: 'cimento', preco: 45), const Oferta(lojaId: 'b', itemId: 'cimento', preco: 38),
      const Oferta(lojaId: 'a', itemId: 'tijolo', preco: 1.40), const Oferta(lojaId: 'b', itemId: 'tijolo', preco: 1.20),
      const Oferta(lojaId: 'a', itemId: 'areia', preco: 150), const Oferta(lojaId: 'f', itemId: 'areia', preco: 90),
      const Oferta(lojaId: 'a', itemId: 'torneira', preco: 200),
    ];

    test('só produtos com 2 ou mais lojas abertas, maior diferença primeiro', () {
      final r = maisBaratoHoje(itens: const [cimento, tijolo, areia, torneira], ofertas: ofertas, lojas: lojas, hoje: hoje);
      expect(r.map((f) => f.item.id), ['cimento', 'tijolo'], reason: 'areia só tem uma loja aberta; torneira uma loja só');
      expect(r.first.menor, 38);
      expect(r.first.maior, 45);
      expect(r.first.lojas, 2);
      expect(r.first.melhor.lojaId, 'b');
    });

    test('produto do orçamento vem antes de outro com diferença maior', () {
      final r = maisBaratoHoje(itens: const [cimento, tijolo], ofertas: ofertas, lojas: lojas, hoje: hoje, noOrcamento: {'tijolo'});
      expect(r.map((f) => f.item.id), ['tijolo', 'cimento']);
    });

    test('respeita o limite', () {
      final r = maisBaratoHoje(itens: const [cimento, tijolo], ofertas: ofertas, lojas: lojas, hoje: hoje, limite: 1);
      expect(r, hasLength(1));
    });
  });

  group('novidades', () {
    const eu = 'u1';
    final eventosProposta = [
      {'proposta_id': 'p1', 'para': 'contraproposta', 'papel': 'vendedor', 'criado_em': '2026-11-01T12:00:00Z', 'loja_nome': 'Casa do Construtor'},
      {'proposta_id': 'p1', 'para': 'aceita', 'papel': 'construtor', 'criado_em': '2026-11-01T13:00:00Z', 'loja_nome': 'Casa do Construtor'},
      {'proposta_id': 'p2', 'para': 'recusada', 'papel': 'dono', 'justificativa': 'Sem estoque', 'criado_em': '2026-10-31T09:00:00Z', 'loja_nome': 'Loja B'},
      {'proposta_id': 'p3', 'para': 'expirada', 'papel': 'sistema', 'criado_em': '2026-10-30T09:00:00Z', 'loja_nome': 'Loja C'},
    ];
    final eventosPedido = [
      {'pedido_id': 'd1', 'para': 'confirmado', 'autor': 'loja1', 'criado_em': '2026-11-01T13:00:01Z', 'loja_nome': 'Casa do Construtor'},
      {'pedido_id': 'd1', 'para': 'saiu_entrega', 'autor': 'loja1', 'criado_em': '2026-11-01T15:00:00Z', 'loja_nome': 'Casa do Construtor'},
      {'pedido_id': 'd2', 'para': 'cancelado', 'autor': eu, 'criado_em': '2026-11-01T14:00:00Z', 'loja_nome': 'Loja B'},
    ];
    final cashback = [
      {'valor': 50, 'descricao': 'Cashback liberado', 'criado_em': '2026-10-29T10:00:00Z', 'loja_nome': 'Loja A', 'pedido_id': 'd0'},
    ];

    test('ignora o que o próprio construtor fez e o "confirmado" repetido', () {
      final n = novidadesDe(eventosProposta: eventosProposta, eventosPedido: eventosPedido, cashback: cashback, usuarioId: eu);
      expect(n.map((x) => x.tipo), [
        TipoNovidade.saiuEntrega,
        TipoNovidade.contraproposta,
        TipoNovidade.recusada,
        TipoNovidade.expirada,
        TipoNovidade.cashbackLiberado,
      ]);
      expect(n[1].texto, 'Casa do Construtor mandou uma contraproposta');
      expect(n[1].propostaId, 'p1');
      expect(n[2].detalhe, 'Sem estoque');
      expect(n.first.pedidoId, 'd1');
      expect(n.last.valor, 50);
    });

    test('conta só o que chegou depois do visto até', () {
      final n = novidadesDe(eventosProposta: eventosProposta, eventosPedido: eventosPedido, cashback: cashback, usuarioId: eu);
      expect(contarDesde(n, null), 5);
      expect(contarDesde(n, DateTime.parse('2026-11-01T12:30:00Z')), 1);
      expect(contarDesde(n, DateTime.parse('2026-12-01T00:00:00Z')), 0);
    });

    test('no máximo 50', () {
      final muitos = [
        for (var i = 0; i < 80; i++)
          {'proposta_id': 'p$i', 'para': 'aceita', 'papel': 'dono', 'criado_em': '2026-10-01T00:00:${(i % 60).toString().padLeft(2, '0')}Z', 'loja_nome': 'L'},
      ];
      expect(novidadesDe(eventosProposta: muitos, eventosPedido: const [], cashback: const [], usuarioId: eu), hasLength(50));
    });
  });

  test('economia do mês lida do banco, nulo vira zero', () {
    final e = EconomiaMes.fromJson({'mes': '2026-10-01', 'comparando': '70.00', 'negociando': 50, 'cashback': null, 'total': 120});
    expect(e.mes, DateTime(2026, 10, 1));
    expect(e.comparando, 70);
    expect(e.negociando, 50);
    expect(e.cashback, 0);
    expect(e.total, 120);
  });
}
