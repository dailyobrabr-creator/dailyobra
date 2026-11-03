import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

const cimento = ItemCatalogo(
  id: 'cimento-cp2-50kg', nome: 'Cimento CP II 50 kg', unidade: 'saco', categoriaId: 'basico', tier: 1,
  sinonimos: ['cimento', 'cp2'],
);
const tijolo = ItemCatalogo(
  id: 'tijolo-8-furos', nome: 'Tijolo cerâmico 8 furos', unidade: 'unidade', categoriaId: 'alvenaria', tier: 1,
  sinonimos: ['tijolo', 'bloco ceramico'],
);
const ferro516 = ItemCatalogo(
  id: 'vergalhao-5-16', nome: 'Vergalhão CA-50 5/16" barra 12 m', unidade: 'barra', categoriaId: 'estrutura', tier: 1,
  sinonimos: ['ferro', 'vergalhao'],
);
const ferro38 = ItemCatalogo(
  id: 'vergalhao-3-8', nome: 'Vergalhão CA-50 3/8" barra 12 m', unidade: 'barra', categoriaId: 'estrutura', tier: 1,
  sinonimos: ['ferro', 'vergalhao'],
);
const catalogo = [cimento, tijolo, ferro516, ferro38];

const cabecalhoSantri = ['Produto', 'Nome', 'Marca', 'Código original', 'Código de barras', 'Volume', 'Volume litros', 'Volume total',
  'Volume lt. total', 'Peso total', 'Disponível', 'Und.', 'Custo médio', 'Preço venda', 'Total custo', 'Total venda', 'Diferença'];

Oferta oferta(ItemCatalogo i, double preco, {Disponibilidade disponibilidade = Disponibilidade.disponivel}) =>
    Oferta(lojaId: 'l1', itemId: i.id, preco: preco, disponibilidade: disponibilidade);

LinhaEstoque linha(String codigo, String nome, double disponivel, double? preco, {String? unidade}) =>
    LinhaEstoque(codigo: codigo, nome: nome, unidade: unidade, disponivel: disponivel, preco: preco);

MudancaOferta mudancaDe(AtualizacaoEstoque a, ItemCatalogo i) => a.mudancas.singleWhere((m) => m.item.id == i.id);

void main() {
  group('relatorioEstoqueSantri', () {
    test('lê o relatório do Santri', () {
      final linhas = relatorioEstoqueSantri([
        ['Santri ADM 1.1.5.9 R1'],
        ['Valor de Estoque - Analítico'],
        cabecalhoSantri,
        ['65.097', 'ABAFADOR DE RUIDOS TIPO CONCHA', 'VONDER', '7060000100', '7893946366216', '', '', '', '', '1,128000', '12,000', 'UN', '8,0512', '27,90', '96,61', '334,80', '238,19'],
        ['10.259', 'CIMENTO CP II', 'ITAU', '', '7898265332478', '', '', '', '', '50,000', '-3,000', 'SO', '30,10', '60,40', '', '', ''],
        ['Total geral', '', '', '', '', '', '', '', '', '', '9,000', '', '', '', '1.000,00', '2.000,00', '1.000,00'],
      ]);
      expect(linhas, [
        linha('65097', 'ABAFADOR DE RUIDOS TIPO CONCHA', 12, 27.9, unidade: 'UN'),
        linha('10259', 'CIMENTO CP II', -3, 60.4, unidade: 'SO'),
      ]);
    });

    test('colunas em outra ordem', () {
      final linhas = relatorioEstoqueSantri([
        ['Produto', 'Preço venda', 'Und.', 'Disponível', 'Nome'],
        ['65.097', '27,90', 'UN', '12,000', 'ABAFADOR DE RUIDOS TIPO CONCHA'],
      ]);
      expect(linhas, [linha('65097', 'ABAFADOR DE RUIDOS TIPO CONCHA', 12, 27.9, unidade: 'UN')]);
    });

    test('código como número', () {
      final linhas = relatorioEstoqueSantri([
        ['Produto', 'Nome', 'Disponível', 'Preço venda'],
        ['65097', 'ABAFADOR', '12', '27.9'],
        ['1.234', 'LUVA', '1,000', '5,00'],
      ]);
      expect([for (final l in linhas) l.codigo], ['65097', '1234']);
      expect([linhas.first.disponivel, linhas.first.preco], [12, 27.9]);
    });

    test('arquivo errado', () {
      expect(() => relatorioEstoqueSantri([['Produto', 'Nome', 'Disponível'], ['65.097', 'ABAFADOR', '12,000']]),
          throwsA(isA<PlanilhaInvalida>().having((e) => e.mensagem, 'mensagem', 'Este arquivo não é o relatório "Valor do estoque analítico" do Santri.')));
    });
  });

  group('montarAtualizacao', () {
    test('regras do dia', () {
      final a = montarAtualizacao(
        [
          linha('10259', 'CIMENTO CP II ITAU', 0, 58),
          linha('99999', 'CIMENTO CP II 50KG VOTORAN', 5, 62),
          linha('61879', 'TIJOLO 8 FUROS', 1000, 1.40, unidade: 'UN'),
          linha('55555', 'VERGALHAO CA-50 3/8 BARRA 12M', 20, 39, unidade: 'BR'),
          linha('44444', 'MANGUEIRA DE JARDIM 20M', 3, 30),
          linha('33333', 'CIMENTO CP II 50KG CAUE', 0, 40, unidade: 'CX'),
        ],
        const [
          LigacaoProduto(codigo: '10259', itemId: 'cimento-cp2-50kg'),
          LigacaoProduto(codigo: '99999', itemId: 'cimento-cp2-50kg'),
          LigacaoProduto(codigo: '61879', itemId: 'tijolo-8-furos'),
          LigacaoProduto(codigo: '70000', itemId: 'vergalhao-5-16'),
        ],
        {
          cimento.id: oferta(cimento, 60),
          tijolo.id: oferta(tijolo, 1.35, disponibilidade: Disponibilidade.semEstoque),
          ferro516.id: oferta(ferro516, 52),
        },
        catalogo,
      );
      final c = mudancaDe(a, cimento);
      expect([c.precoNovo, c.disponibilidadeNova, c.grupo], [62, Disponibilidade.disponivel, GrupoMudanca.precoNovo]);
      final t = mudancaDe(a, tijolo);
      expect([t.precoNovo, t.disponibilidadeNova, t.grupo], [1.40, Disponibilidade.disponivel, GrupoMudanca.voltouAoEstoque]);
      expect(a.naoVieram, [ferro516]);
      expect([for (final s in a.sugestoes) s.item.id], [ferro38.id]);
      expect(a.sugestoes.single.opcoes.first.linha.codigo, '55555');
      expect(a.semPreco, 0);
    });

    test('conferir', () {
      GrupoMudanca grupo(double atual, double novo) => montarAtualizacao(
            [linha('1', 'TIJOLO 8 FUROS', 10, novo, unidade: 'UN')],
            const [LigacaoProduto(codigo: '1', itemId: 'tijolo-8-furos')],
            {tijolo.id: oferta(tijolo, atual)},
            catalogo,
          ).mudancas.single.grupo;
      expect(grupo(18.88, 30), GrupoMudanca.conferir);
      expect(grupo(1.20, 0.99), GrupoMudanca.conferir);
      expect(grupo(60, 61), GrupoMudanca.precoNovo);
      expect(grupo(60, 60), GrupoMudanca.semMudanca);
    });

    test('ficou sem estoque e sem preço', () {
      final a = montarAtualizacao(
        [linha('1', 'CIMENTO CP II A', 0, 61), linha('2', 'CIMENTO CP II B', -2, 59), linha('3', 'TIJOLO 8 FUROS', 10, null)],
        const [
          LigacaoProduto(codigo: '1', itemId: 'cimento-cp2-50kg'),
          LigacaoProduto(codigo: '2', itemId: 'cimento-cp2-50kg'),
          LigacaoProduto(codigo: '3', itemId: 'tijolo-8-furos'),
        ],
        {cimento.id: oferta(cimento, 60), tijolo.id: oferta(tijolo, 1.35)},
        catalogo,
      );
      final c = a.mudancas.single;
      expect([c.item.id, c.precoNovo, c.disponibilidadeNova, c.grupo], [cimento.id, 59, Disponibilidade.semEstoque, GrupoMudanca.ficouSemEstoque]);
      expect(a.semPreco, 1);
    });

    test('sugestão com unidade diferente', () {
      final a = montarAtualizacao(
        [
          linha('1', 'CIMENTO CP II 50KG VOTORAN', 2, 45, unidade: 'CX'),
          linha('2', 'CIMENTO CP II 50KG CAUE', 3, 44.50, unidade: 'CX'),
          linha('3', 'TIJOLO 8 FUROS', 100, 1.30, unidade: 'UN'),
        ],
        const [],
        const {},
        catalogo,
      );
      final c = a.sugestoes.singleWhere((s) => s.item.id == cimento.id);
      expect([for (final o in c.opcoes) o.linha.codigo], ['2', '1']);
      expect(c.opcoes.first.unidadeDiferente, isTrue);
      final t = a.sugestoes.singleWhere((s) => s.item.id == tijolo.id);
      expect(t.opcoes.single.unidadeDiferente, isFalse);
    });

    test('código já ligado não vira sugestão', () {
      final a = montarAtualizacao(
        [linha('55555', 'VERGALHAO CA-50 3/8 BARRA 12M', 20, 39, unidade: 'BR')],
        const [LigacaoProduto(codigo: '55555', itemId: 'vergalhao-5-16')],
        const {},
        catalogo,
      );
      expect(a.sugestoes, isEmpty);
    });
  });

  test('ligação vai e volta do banco', () {
    const g = LigacaoProduto(codigo: '10259', itemId: 'cimento-cp2-50kg', nome: 'CIMENTO ITAU', unidade: 'SO');
    expect(g.toJson(), {'codigo': '10259', 'item_id': 'cimento-cp2-50kg', 'nome': 'CIMENTO ITAU', 'unidade': 'SO'});
    expect(LigacaoProduto.fromJson(g.toJson()), g);
  });
}
