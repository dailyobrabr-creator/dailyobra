import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

const cimento = ItemCatalogo(
  id: 'cimento-cp2-50kg', nome: 'Cimento CP II 50 kg', unidade: 'saco', categoriaId: 'basico', tier: 1,
  sinonimos: ['cimento', 'cp2'],
);
const areia = ItemCatalogo(
  id: 'areia-media', nome: 'Areia média', unidade: 'm³', categoriaId: 'basico', tier: 1, sinonimos: ['areia'],
);
const ferro516 = ItemCatalogo(
  id: 'vergalhao-5-16', nome: 'Vergalhão CA-50 5/16" barra 12 m', unidade: 'barra', categoriaId: 'estrutura', tier: 1,
  sinonimos: ['ferro', 'vergalhao'],
);
const ferro38 = ItemCatalogo(
  id: 'vergalhao-3-8', nome: 'Vergalhão CA-50 3/8" barra 12 m', unidade: 'barra', categoriaId: 'estrutura', tier: 1,
  sinonimos: ['ferro', 'vergalhao'],
);
const cabo = ItemCatalogo(
  id: 'cabo-flexivel-2-5mm', nome: 'Cabo flexível 2,5 mm rolo 100 m', unidade: 'rolo', categoriaId: 'eletrica', tier: 2,
  sinonimos: ['fio', 'cabo'],
);
const tijolo = ItemCatalogo(
  id: 'tijolo-8-furos', nome: 'Tijolo cerâmico 8 furos', unidade: 'un', categoriaId: 'alvenaria', tier: 1,
  sinonimos: ['tijolo', 'bloco ceramico'],
);
const prego = ItemCatalogo(
  id: 'prego-17x27', nome: 'Prego 17x27 com cabeça', unidade: 'kg', categoriaId: 'ferramentas', tier: 3, sinonimos: ['prego'],
);
const catalogo = [cimento, areia, ferro516, ferro38, cabo, tijolo, prego];

LinhaSmartList uma(String texto) {
  final linhas = interpretarLista(texto, catalogo);
  expect(linhas, hasLength(1), reason: texto);
  return linhas.single;
}

void reconhece(String texto, ItemCatalogo item, double quantidade) {
  final l = uma(texto);
  expect(l.tipo, TipoLinha.reconhecido, reason: texto);
  expect(l.item?.id, item.id, reason: texto);
  expect(l.quantidade, quantidade, reason: texto);
}

void main() {
  group('normalizar', () {
    test('tira acento, caixa e espaço sobrando e mantém medidas', () {
      expect(normalizar('  Vergalhão   CA-50 5/16"  '), 'vergalhao ca50 5/16');
      expect(normalizar('Fio 2,5mm Cimento 50kg'), 'fio 2,5mm cimento 50kg');
      expect(normalizar('2,5 m³ de AREIA'), '2,5 m3 de areia');
      expect(normalizar('🙂'), '');
    });
  });

  group('interpretarLista', () {
    test('quantidade antes da unidade', () {
      reconhece('100 sacos de cimento itaú', cimento, 100);
      reconhece('20 barras ferro 5/16', ferro516, 20);
      reconhece('5 rolos fio 2,5mm', cabo, 5);
    });

    test('quantidade depois do nome', () {
      reconhece('cimento 50 sacos', cimento, 50);
      reconhece('areia 3 m3', areia, 3);
    });

    test('número que faz parte do nome não é quantidade', () {
      reconhece('- tijolo 8 furos', tijolo, 1);
      reconhece('5/16 ferro 20 barras', ferro516, 20);
    });

    test('milhar, decimal e fração no começo da linha', () {
      reconhece('1.000 tijolos', tijolo, 1000);
      reconhece('2,5 m³ de areia', areia, 2.5);
      reconhece('1/2 saco cimento', cimento, 0.5);
    });

    test('unidade colada no número também conta', () {
      reconhece('areia 3m3', areia, 3);
    });

    test('quilo e metro no meio da linha só são quantidade quando o produto é vendido assim', () {
      reconhece('prego 2 kg', prego, 2);
      reconhece('cimento cp2 50 kg', cimento, 1);
      reconhece('fio 2,5mm 100 m', cabo, 1);
    });

    test('guarda a unidade falada', () {
      expect(uma('20 barras ferro 5/16').unidadeFalada, 'barra');
      expect(uma('areia 3 m3').unidadeFalada, 'm3');
      expect(uma('1.000 tijolos').unidadeFalada, isNull);
    });

    test('termo genérico pede para escolher entre os parecidos', () {
      final l = uma('ferro');
      expect(l.tipo, TipoLinha.escolher);
      expect(l.item, isNull);
      expect(l.candidatos.map((i) => i.id), unorderedEquals([ferro516.id, ferro38.id]));
    });

    test('produto fora do catálogo fica como não reconhecido', () {
      final l = uma('parafuso sextavado');
      expect(l.tipo, TipoLinha.naoReconhecido);
      expect(l.item, isNull);
      expect(l.candidatos, isEmpty);
      expect(uma('10').tipo, TipoLinha.naoReconhecido);
      expect(uma('joelho 2,5mm').tipo, TipoLinha.naoReconhecido, reason: 'só a medida em comum não basta');
    });

    test('linhas vazias e sem texto são ignoradas', () {
      expect(interpretarLista('', catalogo), isEmpty);
      expect(interpretarLista('   ', catalogo), isEmpty);
      expect(interpretarLista('🙂', catalogo), isEmpty);
      expect(interpretarLista('cimento 10 sacos\n\n   \n🙂\nareia 2 m3', catalogo), hasLength(2));
    });

    test('linha enorme não quebra', () {
      final enorme = 'cimento ${'abc ' * 500}';
      expect(enorme.length, greaterThanOrEqualTo(2000));
      expect(() => interpretarLista(enorme, catalogo), returnsNormally);
      expect(() => interpretarLista('9' * 2000, catalogo), returnsNormally);
    });

    test('escolher um candidato vira linha reconhecida', () {
      final l = uma('12 ferro').escolher(ferro38);
      expect(l.tipo, TipoLinha.reconhecido);
      expect(l.item, ferro38);
      expect(l.quantidade, 12);
    });
  });

  test('somarPorItem junta linhas do mesmo produto', () {
    final linhas = interpretarLista('10 sacos cimento\n5 cimento\nferro\nparafuso', catalogo);
    expect(somarPorItem(linhas), {cimento.id: 15});
  });

  group('ReconhecedorDeProdutos', () {
    test('liga nome de planilha ao catálogo, sem ler quantidade no começo', () {
      final r = ReconhecedorDeProdutos(catalogo);
      expect(r.reconhecer('CIMENTO CP II 50KG VOTORAN').item?.id, 'cimento-cp2-50kg');
      final ferro = r.reconhecer('VERGALHAO CA-50 BARRA 12M');
      expect(ferro.tipo, TipoLinha.escolher);
      expect(ferro.candidatos.map((i) => i.id), containsAll(['vergalhao-5-16', 'vergalhao-3-8']));
      expect(r.reconhecer('MANGUEIRA DE JARDIM 20M').tipo, TipoLinha.naoReconhecido);
      expect(r.reconhecer('100 TIJOLO 8 FUROS').item?.id, 'tijolo-8-furos');
    });

    test('unidade canônica iguala os jeitos de escrever', () {
      expect(unidadeCanonica('m²'), unidadeCanonica('M2'));
      expect(unidadeCanonica('unidade'), unidadeCanonica('UN'));
      expect(unidadeCanonica('Saco'), unidadeCanonica('SC'));
      expect(unidadeCanonica('caixa'), isNot(unidadeCanonica('m²')));
    });
  });
}
