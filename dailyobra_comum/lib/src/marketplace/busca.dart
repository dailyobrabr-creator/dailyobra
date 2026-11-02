import 'modelos.dart';
import 'texto.dart';

/// Produtos cujo nome ou sinônimos têm palavras começando com cada termo digitado
/// ("cimen" acha "Cimento CP II"; "vergalhao 8" acha o de 8 mm). Mantém a ordem recebida.
List<ItemCatalogo> buscarItens(List<ItemCatalogo> itens, String texto) {
  final termos = normalizar(texto).split(' ').where((t) => t.isNotEmpty).toList();
  if (termos.isEmpty) return const [];
  return [
    for (final i in itens)
      if (_casa(normalizar('${i.nome} ${i.sinonimos.join(' ')}').split(' '), termos)) i,
  ];
}

bool _casa(List<String> palavras, List<String> termos) => termos.every((t) => palavras.any((p) => p.startsWith(t)));
