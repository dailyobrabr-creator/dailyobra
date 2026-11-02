import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

const itens = [
  ItemCatalogo(id: 'cimento', nome: 'Cimento CP II 50 kg', unidade: 'saco', categoriaId: 'basico', tier: 1, sinonimos: ['cp2']),
  ItemCatalogo(id: 'v8', nome: 'Vergalhão CA-50 8 mm barra 12 m', unidade: 'barra', categoriaId: 'estrutura', tier: 1, sinonimos: ['ferro 5/16']),
  ItemCatalogo(id: 'v10', nome: 'Vergalhão CA-50 10 mm barra 12 m', unidade: 'barra', categoriaId: 'estrutura', tier: 1, sinonimos: ['ferro 3/8']),
];

void main() {
  test('acha pelo começo das palavras do nome e dos sinônimos, sem acento', () {
    expect(buscarItens(itens, 'cimen').map((i) => i.id), ['cimento']);
    expect(buscarItens(itens, 'VERGALHAO 8').map((i) => i.id), ['v8']);
    expect(buscarItens(itens, 'ferro').map((i) => i.id), ['v8', 'v10']);
    expect(buscarItens(itens, 'cp2').map((i) => i.id), ['cimento']);
  });

  test('busca vazia ou sem resultado', () {
    expect(buscarItens(itens, '   '), isEmpty);
    expect(buscarItens(itens, 'xyz'), isEmpty);
  });
}
