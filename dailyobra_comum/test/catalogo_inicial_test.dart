import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/catalogo_inicial.dart';

void main() {
  test('ids do catálogo são únicos e no formato do banco', () {
    final ids = itensIniciais.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(RegExp(r'^[a-z0-9-]{2,60}$').hasMatch(id), isTrue, reason: id);
    }
  });

  test('todo produto tem categoria válida, unidade e sinônimo', () {
    final cats = categoriasIniciais.map((c) => c.id).toSet();
    expect(cats.length, 10);
    for (final i in itensIniciais) {
      expect(cats, contains(i.categoria), reason: i.id);
      expect(i.unidade.trim(), isNotEmpty, reason: i.id);
      expect(i.sinonimos, isNotEmpty, reason: i.id);
    }
  });

  test('o nível de cashback segue a categoria', () {
    for (final i in itensIniciais) {
      expect(i.tier, tierDaCategoria[i.categoria], reason: i.id);
    }
  });

  test('todos os 109 materiais das planilhas estão no mapeamento', () {
    final nomesPlanilha = <String>{};
    for (final secoes in materiaisPorPadrao.values) {
      for (final itens in secoes.values) {
        for (final i in itens) {
          nomesPlanilha.add('${i.item.trim()}|${i.unidade}');
        }
      }
    }
    expect(nomesPlanilha.length, 109);
    final ids = itensIniciais.map((i) => i.id).toSet();
    for (final chave in nomesPlanilha) {
      expect(planilhaParaCatalogo.containsKey(chave), isTrue, reason: 'falta mapear $chave');
      final destino = planilhaParaCatalogo[chave];
      if (destino != null) expect(ids, contains(destino.$1), reason: chave);
    }
  });

  test('catálogo inicial entre 85 e 120 produtos', () {
    expect(itensIniciais.length, inInclusiveRange(85, 120));
  });

  test('SQL gerado tem os inserts das quatro tabelas', () {
    final sql = gerarSql();
    expect(sql, contains('insert into public.catalogo_categorias'));
    expect(sql, contains('insert into public.catalogo_itens'));
    expect(sql, contains('insert into public.catalogo_planilha'));
    expect(sql, contains('insert into public.cashback_tiers'));
    expect(sql, contains("'cimento-cp2-50kg'"));
  });

  test('Smart List reconhece pedidos comuns no catálogo real', () {
    final cat = [
      for (final i in itensIniciais)
        ItemCatalogo(id: i.id, nome: i.nome, unidade: i.unidade, categoriaId: i.categoria, tier: i.tier, sinonimos: i.sinonimos),
    ];
    final esperado = {
      '100 sacos de cimento itaú': ('cimento-cp2-50kg', 100.0),
      '5 rolos fio 2,5mm': ('cabo-flexivel-2-5mm', 5.0),
      'areia média 2 m³': ('areia-media', 2.0),
      'tijolo 8 furos': ('tijolo-8-furos', 1.0),
      'brita 1 3m3': ('pedra-brita-1', 3.0),
      'prego 2 kg': ('prego-17x27', 2.0),
      'tubo pvc 100mm 6 barras': ('tubo-esgoto-100mm', 6.0),
    };
    final linhas = interpretarLista(esperado.keys.join('\n'), cat);
    expect(linhas, hasLength(esperado.length));
    for (final l in linhas) {
      final (id, qtd) = esperado[l.original]!;
      expect(l.tipo, TipoLinha.reconhecido, reason: l.original);
      expect(l.item!.id, id, reason: l.original);
      expect(l.quantidade, qtd, reason: l.original);
    }
    expect(interpretarLista('areia', cat).single.tipo, TipoLinha.escolher);
  });
}
