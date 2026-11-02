import 'modelos.dart';
import 'texto.dart';

/// Prévia da cotação no aparelho. O servidor recalcula tudo com os preços dele no envio.
class ItemDesejado {
  const ItemDesejado({required this.itemId, required this.quantidade, this.lojaFixada});
  final String itemId;
  final double quantidade;

  /// Loja escolhida à mão pelo construtor; vale no menor preço global.
  final String? lojaFixada;

  ItemDesejado copyWith({double? quantidade, String? lojaFixada, bool soltarLoja = false}) => ItemDesejado(
        itemId: itemId,
        quantidade: quantidade ?? this.quantidade,
        lojaFixada: soltarLoja ? null : (lojaFixada ?? this.lojaFixada),
      );

  Map<String, dynamic> toJson() => {'item_id': itemId, 'quantidade': quantidade, 'loja_fixada': ?lojaFixada};

  factory ItemDesejado.fromJson(Map<String, dynamic> j) => ItemDesejado(
        itemId: j['item_id'] as String,
        quantidade: lerValor(j['quantidade']),
        lojaFixada: j['loja_fixada'] as String?,
      );
}

enum ModoCotacao {
  menorPrecoGlobal('Menor preço global'),
  melhorPorLoja('Melhor por loja');

  const ModoCotacao(this.rotulo);
  final String rotulo;
}

class LinhaCotada {
  const LinhaCotada({
    required this.item,
    required this.quantidade,
    required this.oferta,
    required this.precoUnitario,
    required this.total,
    required this.cashback,
    required this.sobConsulta,
  });
  final ItemCatalogo item;
  final double quantidade;
  final Oferta oferta;
  final double precoUnitario;
  final double total;
  final double cashback;
  final bool sobConsulta;
}

class GrupoLoja {
  const GrupoLoja({required this.loja, required this.linhas, required this.subtotal, required this.frete, required this.abaixoMinimo});
  final Loja loja;
  final List<LinhaCotada> linhas;
  final double subtotal;
  final double frete;
  final bool abaixoMinimo;

  double get total => _centavos(subtotal + frete);
  double get faltaParaMinimo => abaixoMinimo ? _centavos(loja.pedidoMinimo - subtotal) : 0;
}

class ResultadoCotacao {
  const ResultadoCotacao({required this.grupos, required this.semOferta});
  final List<GrupoLoja> grupos;
  final List<ItemCatalogo> semOferta;

  double get total => _centavos(grupos.fold(0.0, (s, g) => s + g.total));
  double get cashbackPrevisto => _centavos(grupos.fold(0.0, (s, g) => s + g.linhas.fold(0.0, (t, l) => t + l.cashback)));
  bool get vazio => grupos.isEmpty && semOferta.isEmpty;
}

double _centavos(double v) => (v * 100).roundToDouble() / 100;

ResultadoCotacao cotar({
  required List<ItemDesejado> itens,
  required Map<String, ItemCatalogo> catalogo,
  required List<Oferta> ofertas,
  required Map<String, Loja> lojas,
  required ModoCotacao modo,
  required DateTime hoje,
  required Map<int, double> percentualPorTier,
  String? cidade,
}) {
  final cidadeNormal = cidade == null ? null : normalizar(cidade);

  // Ofertas que valem hoje, por item, só de lojas abertas.
  final porItem = <String, List<Oferta>>{};
  for (final o in ofertas) {
    final loja = lojas[o.lojaId];
    if (loja == null || !loja.aberta || o.precoVigente(hoje) == null) continue;
    (porItem[o.itemId] ??= []).add(o);
  }

  int compararLojas(Loja a, Loja b) {
    if (cidadeNormal != null) {
      final ca = normalizar(a.cidade) == cidadeNormal, cb = normalizar(b.cidade) == cidadeNormal;
      if (ca != cb) return ca ? -1 : 1;
    }
    final f = a.freteFixo.compareTo(b.freteFixo);
    if (f != 0) return f;
    final n = a.nome.compareTo(b.nome);
    return n != 0 ? n : a.id.compareTo(b.id);
  }

  LinhaCotada linha(ItemCatalogo item, double quantidade, Oferta o) {
    final preco = o.precoVigente(hoje)!;
    final total = _centavos(preco * quantidade);
    return LinhaCotada(
      item: item,
      quantidade: quantidade,
      oferta: o,
      precoUnitario: preco,
      total: total,
      cashback: _centavos(total * (percentualPorTier[item.tier] ?? 0)),
      sobConsulta: o.disponibilidade == Disponibilidade.sobConsulta,
    );
  }

  final validos = [
    for (final i in itens)
      if (catalogo[i.itemId] != null && i.quantidade > 0) i,
  ];
  final escolhidas = <String, List<LinhaCotada>>{};
  final semOferta = <ItemCatalogo>[];

  if (modo == ModoCotacao.menorPrecoGlobal) {
    for (final desejado in validos) {
      final item = catalogo[desejado.itemId]!;
      final opcoes = porItem[item.id] ?? const <Oferta>[];
      if (opcoes.isEmpty) {
        semOferta.add(item);
        continue;
      }
      Oferta? escolhida;
      if (desejado.lojaFixada != null) {
        for (final o in opcoes) {
          if (o.lojaId == desejado.lojaFixada) escolhida = o;
        }
      }
      escolhida ??= (opcoes.toList()
            ..sort((a, b) {
              final p = a.precoVigente(hoje)!.compareTo(b.precoVigente(hoje)!);
              return p != 0 ? p : compararLojas(lojas[a.lojaId]!, lojas[b.lojaId]!);
            }))
          .first;
      (escolhidas[escolhida.lojaId] ??= []).add(linha(item, desejado.quantidade, escolhida));
    }
  } else {
    // Uma loja só: a que atende mais itens; empate vai para o menor total com frete.
    ({Loja loja, List<LinhaCotada> linhas, double total})? melhor;
    for (final loja in lojas.values.where((l) => l.aberta)) {
      final linhas = <LinhaCotada>[];
      for (final desejado in validos) {
        final item = catalogo[desejado.itemId]!;
        for (final o in porItem[item.id] ?? const <Oferta>[]) {
          if (o.lojaId == loja.id) linhas.add(linha(item, desejado.quantidade, o));
        }
      }
      if (linhas.isEmpty) continue;
      final total = linhas.fold(0.0, (s, l) => s + l.total) + loja.freteFixo;
      final atual = (loja: loja, linhas: linhas, total: total);
      if (melhor == null ||
          linhas.length > melhor.linhas.length ||
          (linhas.length == melhor.linhas.length &&
              (total < melhor.total || (total == melhor.total && compararLojas(loja, melhor.loja) < 0)))) {
        melhor = atual;
      }
    }
    if (melhor != null) escolhidas[melhor.loja.id] = melhor.linhas;
    final atendidos = {for (final l in melhor?.linhas ?? const <LinhaCotada>[]) l.item.id};
    for (final desejado in validos) {
      if (!atendidos.contains(desejado.itemId)) semOferta.add(catalogo[desejado.itemId]!);
    }
  }

  final grupos = [
    for (final MapEntry(key: lojaId, value: linhas) in escolhidas.entries)
      () {
        final loja = lojas[lojaId]!;
        final subtotal = _centavos(linhas.fold(0.0, (s, l) => s + l.total));
        return GrupoLoja(
          loja: loja,
          linhas: linhas,
          subtotal: subtotal,
          frete: loja.freteFixo,
          abaixoMinimo: subtotal < loja.pedidoMinimo,
        );
      }(),
  ];
  return ResultadoCotacao(grupos: grupos, semOferta: semOferta);
}
