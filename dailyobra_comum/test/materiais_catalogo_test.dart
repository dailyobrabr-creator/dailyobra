import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/catalogo_inicial.dart';

void main() {
  final planilha = {
    for (final e in planilhaParaCatalogo.entries)
      if (e.value != null) e.key: e.value!,
  };
  final catalogo = {
    for (final i in itensIniciais)
      i.id: ItemCatalogo(id: i.id, nome: i.nome, unidade: i.unidade, categoriaId: i.categoria, tier: i.tier),
  };
  final casa = listarMateriais(const ParametrosObra(area: '100', padrao: Padrao.economico).paraEntrada()) as MateriaisDisponiveis;

  test('cimento de todas as etapas vira um item só do catálogo', () {
    final etapasComCimento = casa.etapas.where((e) => e.itens.any((i) => i.item.trim() == 'Cimento 50kg')).length;
    expect(etapasComCimento, greaterThan(1), reason: 'a casa de referência usa cimento em várias etapas');

    final q = materiaisDaObraNoCatalogo(casa, planilha, catalogo: catalogo);
    final esperado = casa.consolidado
        .where((i) => planilha['${i.item.trim()}|${i.unidade}']?.$1 == 'cimento-cp2-50kg')
        .fold(0.0, (s, i) => s + i.quantidadeExata * planilha['${i.item.trim()}|${i.unidade}']!.$2);
    expect(q['cimento-cp2-50kg'], esperado.ceilToDouble(), reason: 'saco é comprado inteiro');
  });

  test('aplica o fator de conversão e ignora o que não é produto de loja', () {
    final q = materiaisDaObraNoCatalogo(casa, planilha, catalogo: catalogo);
    expect(q.keys.every(catalogo.containsKey), isTrue);
    expect(q.values.every((v) => v > 0), isTrue);
    final semLigacao = casa.consolidado.where((i) => !planilha.containsKey('${i.item.trim()}|${i.unidade}'));
    expect(semLigacao, isNotEmpty, reason: 'sapatas e itens de canteiro ficam de fora');
  });

  test('sem lista de materiais devolve vazio', () {
    expect(materiaisDaObraNoCatalogo(const MateriaisIndisponiveis('sem área'), planilha), isEmpty);
  });
}
