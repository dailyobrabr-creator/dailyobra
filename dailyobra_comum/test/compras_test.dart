import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

final hoje = DateTime(2026, 11, 20);

MaterialObra material(String nome, double q, {EtapaId? etapa, String? item, String unidade = 'saco', double? base}) =>
    MaterialObra(nome: nome, unidade: unidade, quantidade: q, etapa: etapa, itemId: item, precoBase: base);

ItemDePedido pedido(String nome, double q, {String? item, String id = 'p1', String unidade = 'saco'}) =>
    ItemDePedido(pedidoId: id, loja: 'Operário', situacao: 'confirmado', data: hoje, itemId: item, nome: nome, unidade: unidade, quantidade: q);

Recebimento recebido(String nome, double q, {String? item, String? pedidoId, String unidade = 'saco'}) =>
    Recebimento(id: 'r', pedidoId: pedidoId, itemId: item, nome: nome, unidade: unidade, quantidade: q, data: hoje);

LinhaResultado linha(EtapaId e) => LinhaResultado(etapa: e, nome: e.codigo, descricao: '', area: 100, custoM2: 1, maoDeObra: 0, material: 0, total: 100);

void main() {
  test('lê material, pedido e recebimento do banco', () {
    final m = MaterialObra.fromJson(const {'id': 'm1', 'etapa': 'alvenaria', 'item_id': 'cimento', 'nome': 'Cimento', 'unidade': 'saco', 'quantidade': 100, 'preco_base': 35.5});
    expect((m.id, m.etapa, m.itemId, m.quantidade, m.precoBase), ('m1', EtapaId.alvenaria, 'cimento', 100.0, 35.5));
    final p = ItemDePedido.fromJson(const {'pedido_id': 'p1', 'loja': 'Operário', 'situacao': 'entregue', 'data': '2026-11-03', 'item_id': 'cimento', 'nome': 'Cimento', 'unidade': 'saco', 'quantidade': 50});
    expect((p.pedidoId, p.loja, p.situacao, p.quantidade), ('p1', 'Operário', 'entregue', 50.0));
    final r = Recebimento.fromJson(const {'id': 'r1', 'pedido_id': null, 'item_id': null, 'nome': 'Areia', 'unidade': 'm3', 'quantidade': 2, 'data': '2026-11-03', 'observacao': 'ok', 'foto_path': 'o1/a.jpg'});
    expect((r.pedidoId, r.nome, r.quantidade, r.observacao, r.fotoPath), (null, 'Areia', 2.0, 'ok', 'o1/a.jpg'));
  });

  test('prepara material para salvar', () {
    expect(material('Cimento', 10, etapa: EtapaId.alvenaria, item: 'c', base: 30).paraSalvar(), {'etapa': 'alvenaria', 'item_id': 'c', 'nome': 'Cimento', 'unidade': 'saco', 'quantidade': 10.0, 'preco_base': 30.0});
  });

  group('saldo', () {
    test('previsto, comprado no app e recebido', () {
      final s = calcularSaldo(
        materiais: [material('Cimento', 100, item: 'c')],
        pedidos: [pedido('Cimento', 60, item: 'c')],
        recebimentos: [recebido('Cimento', 40, item: 'c', pedidoId: 'p1')],
      ).single;
      expect((s.previsto, s.comprado, s.recebido), (100.0, 60.0, 40.0));
      expect(s.falta, 40);
      expect(s.aReceber, 20);
    });

    test('compra de fora conta como comprada e recebida', () {
      final s = calcularSaldo(materiais: [material('Areia', 10, unidade: 'm3')], pedidos: const [], recebimentos: [recebido('Areia', 4, unidade: 'm3')]).single;
      expect((s.comprado, s.recebido, s.falta, s.aReceber), (4.0, 4.0, 6.0, 0.0));
    });

    test('comprar a mais não dá falta negativa', () {
      final s = calcularSaldo(materiais: [material('Cimento', 10, item: 'c')], pedidos: [pedido('Cimento', 15, item: 'c')], recebimentos: const []).single;
      expect(s.falta, 0);
    });

    test('mesmo material em duas etapas soma', () {
      final s = calcularSaldo(materiais: [material('Cimento', 10, item: 'c', etapa: EtapaId.fundacao), material('Cimento', 20, item: 'c', etapa: EtapaId.alvenaria)], pedidos: const [], recebimentos: const []).single;
      expect(s.previsto, 30);
    });

    test('sem item do catálogo compara por nome e unidade, sem ligar para maiúsculas', () {
      final s = calcularSaldo(materiais: [material('Tinta Branca', 3, unidade: 'lata')], pedidos: const [], recebimentos: [recebido(' tinta branca', 1, unidade: 'LATA')]).single;
      expect(s.comprado, 1);
    });

    test('mesmo nome em unidades diferentes são materiais diferentes', () {
      final s = calcularSaldo(materiais: [material('Areia', 3, unidade: 'm3'), material('Areia', 10, unidade: 'saco')], pedidos: const [], recebimentos: const []);
      expect(s, hasLength(2));
    });

    test('comprado fora da lista aparece no saldo', () {
      final s = calcularSaldo(materiais: const [], pedidos: [pedido('Prego', 5, item: 'p')], recebimentos: const []).single;
      expect((s.previsto, s.comprado, s.falta), (0.0, 5.0, 0.0));
    });
  });

  group('o que comprar', () {
    final etapas = [linha(EtapaId.fundacao), linha(EtapaId.alvenaria), linha(EtapaId.pintura)];
    final datas = {
      EtapaId.fundacao: DatasEtapa(inicioPrevisto: DateTime(2026, 11, 1), fimPrevisto: DateTime(2026, 11, 19)),
      EtapaId.alvenaria: DatasEtapa(inicioPrevisto: DateTime(2026, 11, 24), fimPrevisto: DateTime(2026, 12, 10)),
      EtapaId.pintura: DatasEtapa(inicioPrevisto: DateTime(2027, 1, 10), fimPrevisto: DateTime(2027, 1, 20)),
    };
    List<ItemAComprar> calcular(List<MaterialObra> m, {List<ItemDePedido> p = const [], List<Recebimento> r = const [], Map<EtapaId, StatusEtapa> s = const {}, int dias = 7, Map<EtapaId, DatasEtapa>? d}) => oQueComprar(
      etapas: etapas,
      materiais: m,
      pedidos: p,
      recebimentos: r,
      datas: d ?? datas,
      status: s,
      hoje: hoje,
      dias: dias,
    );

    test('entra a etapa que começa dentro do período', () {
      final r = calcular([material('Bloco', 100, etapa: EtapaId.alvenaria), material('Tinta', 5, etapa: EtapaId.pintura)]);
      expect(r.single.nome, 'Bloco');
      expect(r.single.quantidade, 100);
      expect(r.single.etapas, [EtapaId.alvenaria]);
    });

    test('período maior traz mais etapas', () {
      expect(calcular([material('Tinta', 5, etapa: EtapaId.pintura)], dias: 60).single.nome, 'Tinta');
    });

    test('etapa concluída não pede compra', () {
      expect(calcular([material('Cimento', 10, etapa: EtapaId.fundacao)], s: const {EtapaId.fundacao: StatusEtapa.concluida}), isEmpty);
    });

    test('etapa em andamento pede compra mesmo sem data', () {
      expect(calcular([material('Cimento', 10, etapa: EtapaId.pintura)], s: const {EtapaId.pintura: StatusEtapa.iniciada}), hasLength(1));
    });

    test('etapa atrasada que não começou continua pedindo', () {
      expect(calcular([material('Cimento', 10, etapa: EtapaId.fundacao)]), hasLength(1));
    });

    test('o que já foi comprado sai da conta', () {
      final r = calcular([material('Bloco', 100, etapa: EtapaId.alvenaria, item: 'b')], p: [pedido('Bloco', 60, item: 'b')]);
      expect(r.single.quantidade, 40);
    });

    test('comprado tudo some da lista', () {
      expect(calcular([material('Bloco', 100, etapa: EtapaId.alvenaria, item: 'b')], p: [pedido('Bloco', 100, item: 'b')]), isEmpty);
    });

    test('compra de fora também sai da conta', () {
      expect(calcular([material('Areia', 10, etapa: EtapaId.alvenaria)], r: [recebido('Areia', 4)]).single.quantidade, 6);
    });

    test('o comprado atende primeiro a etapa que vem antes', () {
      final r = calcular(
        [material('Cimento', 30, etapa: EtapaId.alvenaria, item: 'c'), material('Cimento', 20, etapa: EtapaId.pintura, item: 'c')],
        p: [pedido('Cimento', 40, item: 'c')],
        dias: 7,
      );
      expect(r, isEmpty, reason: 'os 40 cobrem os 30 da alvenaria; a pintura ainda não chegou');
      final depois = calcular(
        [material('Cimento', 30, etapa: EtapaId.alvenaria, item: 'c'), material('Cimento', 20, etapa: EtapaId.pintura, item: 'c')],
        p: [pedido('Cimento', 40, item: 'c')],
        dias: 60,
      );
      expect(depois.single.quantidade, 10);
    });

    test('material em duas etapas do período vem somado', () {
      final r = calcular([material('Cimento', 10, etapa: EtapaId.fundacao, item: 'c'), material('Cimento', 20, etapa: EtapaId.alvenaria, item: 'c')]);
      expect(r.single.quantidade, 30);
      expect(r.single.etapas, [EtapaId.fundacao, EtapaId.alvenaria]);
    });

    test('material sem etapa entra sempre', () {
      expect(calcular([material('Luva', 5)]).single.nome, 'Luva');
    });

    test('sem cronograma, usa a primeira etapa ainda não concluída', () {
      final r = calcular([material('Cimento', 10, etapa: EtapaId.fundacao), material('Bloco', 10, etapa: EtapaId.alvenaria)], d: const {});
      expect(r.single.nome, 'Cimento');
      final depois = calcular([material('Cimento', 10, etapa: EtapaId.fundacao), material('Bloco', 10, etapa: EtapaId.alvenaria)], d: const {}, s: const {EtapaId.fundacao: StatusEtapa.concluida});
      expect(depois.single.nome, 'Bloco');
    });

    test('unidade inteira arredonda para cima na compra', () {
      expect(quantidadeDeCompra(2.1, 'saco'), 3);
      expect(quantidadeDeCompra(2, 'saco'), 2);
      expect(quantidadeDeCompra(2.1, 'm3'), 2.1);
    });
  });

  group('alerta de preço', () {
    test('subiu desde o planejamento', () {
      final a = alertaDePreco(base: 100, atual: 108, emPromocao: false)!;
      expect(a.texto, 'Subiu 8%');
      expect(a.bom, isFalse);
    });

    test('baixou desde o planejamento', () {
      final a = alertaDePreco(base: 100, atual: 90, emPromocao: false)!;
      expect(a.texto, 'Baixou 10%');
      expect(a.bom, isTrue);
    });

    test('promoção vem antes da comparação', () {
      final a = alertaDePreco(base: 100, atual: 104, emPromocao: true)!;
      expect(a.texto, 'Em promoção');
      expect(a.bom, isTrue);
    });

    test('variação pequena não avisa', () {
      expect(alertaDePreco(base: 100, atual: 104, emPromocao: false), isNull);
      expect(alertaDePreco(base: 100, atual: 96, emPromocao: false), isNull);
    });

    test('sem base ou sem preço não avisa', () {
      expect(alertaDePreco(base: null, atual: 100, emPromocao: false), isNull);
      expect(alertaDePreco(base: 100, atual: null, emPromocao: false), isNull);
      expect(alertaDePreco(base: 0, atual: 100, emPromocao: false), isNull);
    });

    test('sem base, a promoção ainda avisa', () {
      expect(alertaDePreco(base: null, atual: 100, emPromocao: true)!.texto, 'Em promoção');
    });
  });

  group('montar a lista', () {
    final planilha = {'Cimento|sc': ('cimento-50', 1.0), 'Tijolo|mil': ('tijolo', 1000.0)};
    const catalogo = {
      'cimento-50': ItemCatalogo(id: 'cimento-50', nome: 'Cimento CP II 50 kg', unidade: 'saco', categoriaId: 'basico', tier: 1, sinonimos: []),
      'tijolo': ItemCatalogo(id: 'tijolo', nome: 'Tijolo 8 furos', unidade: 'unidade', categoriaId: 'basico', tier: 1, sinonimos: []),
    };
    final lista = MateriaisDisponiveis(
      etapas: [
        const EtapaMateriais(
          etapa: EtapaId.alvenaria,
          nome: 'Alvenaria',
          itens: [
            ItemMaterial(item: 'Cimento', unidade: 'sc', quantidadeExata: 10.2, quantidade: 10.2, precoRef: 30),
            ItemMaterial(item: 'Tijolo', unidade: 'mil', quantidadeExata: 1.5, quantidade: 1.5, precoRef: 900),
            ItemMaterial(item: 'Prego especial', unidade: 'kg', quantidadeExata: 2, quantidade: 2, precoRef: 20),
          ],
        ),
      ],
      consolidado: const [],
      etapasSemLista: const [],
    );

    test('liga ao catálogo, converte a unidade e guarda o preço do dia', () {
      final m = montarListaDaObra(lista, planilha, catalogo, (id) => id == 'cimento-50' ? 35.0 : null);
      expect(m[0].itemId, 'cimento-50');
      expect(m[0].nome, 'Cimento CP II 50 kg');
      expect(m[0].unidade, 'saco');
      expect(m[0].quantidade, 11, reason: 'saco é unidade inteira');
      expect(m[0].precoBase, 35);
      expect(m[0].etapa, EtapaId.alvenaria);
      expect(m[1].quantidade, 1500);
      expect(m[1].precoBase, isNull);
    });

    test('material fora do catálogo continua na lista', () {
      final m = montarListaDaObra(lista, planilha, catalogo, (_) => null);
      expect(m[2].itemId, isNull);
      expect(m[2].nome, 'Prego especial');
      expect(m[2].unidade, 'kg');
    });

    test('lista indisponível não monta nada', () {
      expect(montarListaDaObra(const MateriaisIndisponiveis('x'), planilha, catalogo, (_) => null), isEmpty);
    });

    test('padrão médio tem as duas bases vizinhas', () {
      expect(basesParaOPadrao(Padrao.medio), [Padrao.economico, Padrao.mediaAlta]);
      expect(basesParaOPadrao(Padrao.alto), isEmpty);
    });

    test('lista-base de outro padrão sai para a mesma obra', () {
      const p = ParametrosObra(area: '120');
      expect(listarMateriais(p.paraEntrada()), isA<MateriaisIndisponiveis>());
      expect(materiaisComBase(p, Padrao.mediaAlta), isA<MateriaisDisponiveis>());
    });
  });

  test('quem cuida das compras', () {
    expect(FuncaoObra.responsavel.cuidaDasCompras, isTrue);
    expect(FuncaoObra.mestre.cuidaDasCompras, isTrue);
    expect(FuncaoObra.estagiario.cuidaDasCompras, isTrue);
    expect(FuncaoObra.empreiteiro.cuidaDasCompras, isFalse);
    expect(FuncaoObra.cliente.cuidaDasCompras, isFalse);
  });
}
