import 'modelos.dart';
import 'planilha_precos.dart';
import 'smart_list.dart';

/// Um produto do relatório "Valor do estoque analítico" do Santri, só com o que a importação do dia usa: o custo e os
/// totais nem entram no modelo.
class LinhaEstoque {
  const LinhaEstoque({required this.codigo, required this.nome, this.unidade, required this.disponivel, this.preco});
  final String codigo;
  final String nome;
  final String? unidade;
  final double disponivel;
  final double? preco;

  @override
  bool operator ==(Object other) =>
      other is LinhaEstoque && other.codigo == codigo && other.nome == nome && other.unidade == unidade && other.disponivel == disponivel && other.preco == preco;

  @override
  int get hashCode => Object.hash(codigo, nome, unidade, disponivel, preco);

  @override
  String toString() => 'LinhaEstoque($codigo, $nome, $unidade, $disponivel, $preco)';
}

const _naoEhRelatorio = 'Este arquivo não é o relatório "Valor do estoque analítico" do Santri.';
final _soDigitos = RegExp(r'^\d+$');

/// Código do Santri só com dígitos ("65.097" → "65097"); nulo para títulos, totais e linhas sem código.
String? _codigo(String bruto) {
  final c = bruto.replaceAll('.', '').replaceAll(' ', '');
  return _soDigitos.hasMatch(c) ? c : null;
}

/// Quantidade no formato do Santri ("12,000", "-3,000", "1.234,500") ou do office:value ("12", "-3.5").
double? _quantidade(String bruto) {
  var t = bruto.trim();
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

/// Produtos do relatório de estoque. O cabeçalho é achado pelos nomes das colunas (primeira célula `Produto`, com
/// `Disponível` e `Preço venda`), então a ordem das colunas pode mudar.
List<LinhaEstoque> relatorioEstoqueSantri(List<List<String>> linhas) {
  for (var i = 0; i < linhas.length; i++) {
    final cabecalho = [for (final c in linhas[i]) c.trim()];
    final disponivel = cabecalho.indexOf('Disponível');
    final preco = cabecalho.indexOf('Preço venda');
    if (cabecalho.isEmpty || cabecalho.first != 'Produto' || disponivel < 0 || preco < 0) continue;
    final nome = cabecalho.indexOf('Nome');
    final und = cabecalho.contains('Und.') ? cabecalho.indexOf('Und.') : cabecalho.indexOf('Und');
    String celula(List<String> linha, int j) => j >= 0 && j < linha.length ? linha[j].trim() : '';
    return [
      for (final linha in linhas.skip(i + 1))
        if (_codigo(celula(linha, 0)) case final codigo?)
          LinhaEstoque(
            codigo: codigo,
            nome: celula(linha, nome),
            unidade: celula(linha, und).isEmpty ? null : celula(linha, und),
            disponivel: _quantidade(celula(linha, disponivel)) ?? 0,
            preco: lerPreco(celula(linha, preco)),
          ),
    ];
  }
  throw const PlanilhaInvalida(_naoEhRelatorio);
}

/// Código do Santri ligado a um produto do catálogo pela loja (tabela loja_produtos).
class LigacaoProduto {
  const LigacaoProduto({required this.codigo, required this.itemId, this.nome, this.unidade});

  factory LigacaoProduto.fromJson(Map<String, dynamic> j) =>
      LigacaoProduto(codigo: j['codigo'] as String, itemId: j['item_id'] as String, nome: j['nome'] as String?, unidade: j['unidade'] as String?);

  final String codigo;
  final String itemId;
  final String? nome;
  final String? unidade;

  Map<String, dynamic> toJson() => {'codigo': codigo, 'item_id': itemId, 'nome': nome, 'unidade': unidade};

  @override
  bool operator ==(Object other) => other is LigacaoProduto && other.codigo == codigo && other.itemId == itemId && other.nome == nome && other.unidade == unidade;

  @override
  int get hashCode => Object.hash(codigo, itemId, nome, unidade);
}

/// Um grupo por produto no resumo, nesta ordem de precedência.
enum GrupoMudanca {
  conferir('Conferir'),
  ficouSemEstoque('Ficou sem estoque'),
  voltouAoEstoque('Voltou ao estoque'),
  precoNovo('Preço novo'),
  semMudanca('Sem mudança');

  const GrupoMudanca(this.rotulo);
  final String rotulo;
}

/// O que acontece com a oferta de um produto do catálogo ligado.
class MudancaOferta {
  const MudancaOferta({required this.item, this.precoAntigo, required this.precoNovo, this.disponibilidadeAntiga, required this.disponibilidadeNova, required this.grupo});
  final ItemCatalogo item;
  final double? precoAntigo;
  final double precoNovo;
  final Disponibilidade? disponibilidadeAntiga;
  final Disponibilidade disponibilidadeNova;
  final GrupoMudanca grupo;
}

/// Um item do relatório que pode ser ligado a um produto do catálogo.
class OpcaoLigacao {
  const OpcaoLigacao({required this.linha, required this.certeza, required this.unidadeDiferente});
  final LinhaEstoque linha;

  /// O reconhecedor ligou com certeza (e não só como uma das opções).
  final bool certeza;
  final bool unidadeDiferente;
}

/// Produto do catálogo ainda sem ligação e até 3 itens do relatório com estoque para ligar.
class SugestaoLigacao {
  const SugestaoLigacao({required this.item, required this.opcoes});
  final ItemCatalogo item;
  final List<OpcaoLigacao> opcoes;
}

class AtualizacaoEstoque {
  const AtualizacaoEstoque({required this.mudancas, required this.naoVieram, required this.sugestoes, required this.semPreco});
  final List<MudancaOferta> mudancas;

  /// Ligados sem nenhum código no relatório: a oferta fica como está.
  final List<ItemCatalogo> naoVieram;
  final List<SugestaoLigacao> sugestoes;

  /// Linhas ligadas sem preço no relatório (ficam de fora).
  final int semPreco;
}

const _limiteConferir = 0.30;
const _precoMinimo = 1.0;

int _centavos(double v) => (v * 100).round();

GrupoMudanca _grupo(Oferta? atual, double preco, Disponibilidade nova) {
  final antigo = atual?.preco;
  if (preco <= _precoMinimo || (antigo != null && (preco - antigo).abs() / antigo > _limiteConferir)) return GrupoMudanca.conferir;
  if (nova == Disponibilidade.semEstoque && atual?.disponibilidade != Disponibilidade.semEstoque) return GrupoMudanca.ficouSemEstoque;
  if (nova == Disponibilidade.disponivel && atual?.disponibilidade == Disponibilidade.semEstoque) return GrupoMudanca.voltouAoEstoque;
  if (antigo == null || _centavos(preco) != _centavos(antigo) || atual!.disponibilidade != nova) return GrupoMudanca.precoNovo;
  return GrupoMudanca.semMudanca;
}

/// Monta a importação do dia: preço e disponibilidade dos produtos ligados (entre os códigos de um produto, vale o mais
/// barato com estoque; sem estoque em nenhum, "sem estoque" com o menor preço) e sugestões de ligação pelo catálogo.
AtualizacaoEstoque montarAtualizacao(List<LinhaEstoque> relatorio, List<LigacaoProduto> ligacoes, Map<String, Oferta> ofertas, List<ItemCatalogo> catalogo) {
  final porCodigo = {for (final l in relatorio) l.codigo: l};
  final porId = {for (final i in catalogo) i.id: i};
  final codigosPorItem = <String, List<String>>{};
  for (final g in ligacoes) {
    (codigosPorItem[g.itemId] ??= []).add(g.codigo);
  }

  final mudancas = <MudancaOferta>[];
  final naoVieram = <ItemCatalogo>[];
  var semPreco = 0;
  for (final MapEntry(key: itemId, value: codigos) in codigosPorItem.entries) {
    final item = porId[itemId];
    if (item == null) continue;
    final vieram = [for (final c in codigos) ?porCodigo[c]];
    if (vieram.isEmpty) {
      naoVieram.add(item);
      continue;
    }
    final comPreco = [for (final l in vieram) if ((l.preco ?? 0) > 0) l];
    semPreco += vieram.length - comPreco.length;
    if (comPreco.isEmpty) continue;
    final comEstoque = [for (final l in comPreco) if (l.disponivel > 0) l];
    final escolhida = (comEstoque.isNotEmpty ? comEstoque : comPreco).reduce((a, b) => a.preco! <= b.preco! ? a : b);
    final nova = comEstoque.isNotEmpty ? Disponibilidade.disponivel : Disponibilidade.semEstoque;
    final atual = ofertas[itemId];
    mudancas.add(MudancaOferta(
      item: item, precoAntigo: atual?.preco, precoNovo: escolhida.preco!, disponibilidadeAntiga: atual?.disponibilidade,
      disponibilidadeNova: nova, grupo: _grupo(atual, escolhida.preco!, nova),
    ));
  }

  // Sugestões: só itens com estoque e preço, ainda não ligados, para produtos do catálogo sem ligação
  final codigosLigados = {for (final g in ligacoes) g.codigo};
  final reconhecedor = ReconhecedorDeProdutos(catalogo);
  final opcoesPorItem = <String, List<OpcaoLigacao>>{};
  for (final l in relatorio) {
    if (l.disponivel <= 0 || (l.preco ?? 0) <= 0 || codigosLigados.contains(l.codigo)) continue;
    final r = reconhecedor.reconhecer(l.nome);
    final alvos = switch (r.tipo) {
      TipoLinha.reconhecido => [if (r.item case final item?) (item, true)],
      TipoLinha.escolher => [for (final c in r.candidatos) (c, false)],
      TipoLinha.naoReconhecido => const <(ItemCatalogo, bool)>[],
    };
    for (final (item, certeza) in alvos) {
      if (codigosPorItem.containsKey(item.id)) continue;
      final unidadeDiferente = l.unidade != null && unidadeCanonica(l.unidade!) != unidadeCanonica(item.unidade);
      (opcoesPorItem[item.id] ??= []).add(OpcaoLigacao(linha: l, certeza: certeza, unidadeDiferente: unidadeDiferente));
    }
  }
  int ordem(OpcaoLigacao a, OpcaoLigacao b) => a.certeza != b.certeza ? (a.certeza ? -1 : 1) : a.linha.preco!.compareTo(b.linha.preco!);
  final sugestoes = [
    for (final item in catalogo)
      if (opcoesPorItem[item.id] case final opcoes?) SugestaoLigacao(item: item, opcoes: (opcoes..sort(ordem)).take(3).toList()),
  ];
  return AtualizacaoEstoque(mudancas: mudancas, naoVieram: naoVieram, sugestoes: sugestoes, semPreco: semPreco);
}
