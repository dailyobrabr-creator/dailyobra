import '../orcamento/materiais.dart';
import 'modelos.dart';

/// Unidades do catálogo vendidas só inteiras.
const _inteiras = {'saco', 'unidade', 'barra', 'rolo', 'lata', 'galão', 'balde', 'caixa', 'peça', 'kit', 'pacote', 'folha', 'painel'};

/// Lista de materiais da obra (planilha) convertida em quantidades de produtos do catálogo.
///
/// [planilha] liga "nome|unidade" da planilha ao produto e ao fator de conversão (ex.: coluna
/// em metro → barra de 6 m = 1/6). Itens sem ligação (estrutura sob medida, canteiro) ficam de
/// fora. A soma usa a quantidade exata; o arredondamento de compra é feito no fim, por produto.
Map<String, double> materiaisDaObraNoCatalogo(
  ResultadoMateriais materiais,
  Map<String, (String, double)> planilha, {
  Map<String, ItemCatalogo> catalogo = const {},
}) {
  if (materiais is! MateriaisDisponiveis) return const {};
  final soma = <String, double>{};
  for (final i in materiais.consolidado) {
    final destino = planilha['${i.item.trim()}|${i.unidade}'];
    if (destino == null) continue;
    final (id, fator) = destino;
    soma[id] = (soma[id] ?? 0) + i.quantidadeExata * fator;
  }
  return {
    for (final MapEntry(key: id, value: q) in soma.entries)
      if (q > 0) id: _inteiras.contains(catalogo[id]?.unidade) ? (q - 1e-9).ceilToDouble() : ((q * 100 - 1e-9).ceilToDouble() / 100),
  };
}
