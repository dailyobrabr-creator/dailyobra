import '../ui/ui.dart' show brl;
import 'modelos.dart';

/// Faixa de preço de um produto entre as lojas abertas (bloco "Mais barato hoje").
class FaixaPreco {
  const FaixaPreco({required this.item, required this.menor, required this.maior, required this.lojas, required this.melhor});
  final ItemCatalogo item;
  final double menor;
  final double maior;
  final int lojas;
  final Oferta melhor;

  double get diferencaRelativa => maior <= 0 ? 0 : (maior - menor) / maior;
}

/// Produtos vendidos por 2 ou mais lojas abertas, com o menor e o maior preço de hoje.
/// Os do orçamento vêm primeiro; depois, a maior diferença relativa; depois, o nome.
List<FaixaPreco> maisBaratoHoje({
  required List<ItemCatalogo> itens,
  required List<Oferta> ofertas,
  required Map<String, Loja> lojas,
  required DateTime hoje,
  Set<String> noOrcamento = const {},
  int limite = 5,
}) {
  final porItem = <String, List<Oferta>>{};
  for (final o in ofertas) {
    if (lojas[o.lojaId]?.aberta != true || o.precoVigente(hoje) == null) continue;
    (porItem[o.itemId] ??= []).add(o);
  }
  final faixas = <FaixaPreco>[];
  for (final item in itens) {
    final lista = porItem[item.id];
    if (lista == null || lista.length < 2) continue;
    lista.sort((a, b) => a.precoVigente(hoje)!.compareTo(b.precoVigente(hoje)!));
    faixas.add(FaixaPreco(
      item: item,
      menor: lista.first.precoVigente(hoje)!,
      maior: lista.last.precoVigente(hoje)!,
      lojas: lista.length,
      melhor: lista.first,
    ));
  }
  faixas.sort((a, b) {
    final oa = noOrcamento.contains(a.item.id), ob = noOrcamento.contains(b.item.id);
    if (oa != ob) return oa ? -1 : 1;
    final d = b.diferencaRelativa.compareTo(a.diferencaRelativa);
    return d != 0 ? d : a.item.nome.compareTo(b.item.nome);
  });
  return faixas.take(limite).toList();
}

enum TipoNovidade { aceita, recusada, contraproposta, expirada, emSeparacao, saiuEntrega, entregue, cancelado, pagamentoConfirmado, cashbackLiberado }

/// Algo que aconteceu nas propostas, pedidos ou carteira do construtor (sino de novidades).
class Novidade {
  const Novidade({required this.tipo, required this.quando, this.propostaId, this.pedidoId, this.lojaNome, this.detalhe, this.valor});
  final TipoNovidade tipo;
  final DateTime quando;
  final String? propostaId;
  final String? pedidoId;
  final String? lojaNome;

  /// Motivo da recusa, quando houver.
  final String? detalhe;
  final double? valor;

  String get texto {
    final loja = lojaNome ?? 'A loja';
    return switch (tipo) {
      TipoNovidade.aceita => '$loja aceitou sua proposta',
      TipoNovidade.recusada => '$loja recusou a proposta',
      TipoNovidade.contraproposta => '$loja mandou uma contraproposta',
      TipoNovidade.expirada => 'A proposta para ${lojaNome ?? 'a loja'} venceu sem resposta',
      TipoNovidade.emSeparacao => '$loja está separando seu pedido',
      TipoNovidade.saiuEntrega => 'Pedido da ${lojaNome ?? 'loja'} saiu para entrega',
      TipoNovidade.entregue => 'Pedido da ${lojaNome ?? 'loja'} foi entregue',
      TipoNovidade.cancelado => '$loja cancelou o pedido',
      TipoNovidade.pagamentoConfirmado => '$loja confirmou o pagamento',
      TipoNovidade.cashbackLiberado => 'Cashback de ${brl.format(valor ?? 0)} liberado na carteira',
    };
  }
}

const _paraProposta = {
  'aceita': TipoNovidade.aceita,
  'recusada': TipoNovidade.recusada,
  'contraproposta': TipoNovidade.contraproposta,
  'expirada': TipoNovidade.expirada,
};

const _paraPedido = {
  'em_separacao': TipoNovidade.emSeparacao,
  'saiu_entrega': TipoNovidade.saiuEntrega,
  'entregue': TipoNovidade.entregue,
  'cancelado': TipoNovidade.cancelado,
  'pagamento_confirmado': TipoNovidade.pagamentoConfirmado,
};

DateTime _data(Object? v) => DateTime.parse(v as String).toLocal();

/// Junta os eventos do banco em novidades, do mais novo ao mais velho (no máximo 50). Fica de fora
/// o que o próprio construtor fez e o "confirmado" do pedido (repete o "aceita" da proposta).
List<Novidade> novidadesDe({
  required List<Map<String, dynamic>> eventosProposta,
  required List<Map<String, dynamic>> eventosPedido,
  required List<Map<String, dynamic>> cashback,
  required String usuarioId,
}) {
  final lista = <Novidade>[
    for (final e in eventosProposta)
      if (e['papel'] != 'construtor' && _paraProposta[e['para']] != null)
        Novidade(
          tipo: _paraProposta[e['para']]!,
          quando: _data(e['criado_em']),
          propostaId: e['proposta_id'] as String?,
          lojaNome: e['loja_nome'] as String?,
          detalhe: e['justificativa'] as String?,
        ),
    for (final e in eventosPedido)
      if (e['autor'] != usuarioId && _paraPedido[e['para']] != null)
        Novidade(
          tipo: _paraPedido[e['para']]!,
          quando: _data(e['criado_em']),
          pedidoId: e['pedido_id'] as String?,
          lojaNome: e['loja_nome'] as String?,
          valor: e['total'] == null ? null : lerValor(e['total']),
        ),
    for (final e in cashback)
      Novidade(
        tipo: TipoNovidade.cashbackLiberado,
        quando: _data(e['criado_em']),
        pedidoId: e['pedido_id'] as String?,
        lojaNome: e['loja_nome'] as String?,
        valor: lerValor(e['valor']),
      ),
  ]..sort((a, b) => b.quando.compareTo(a.quando));
  return lista.take(50).toList();
}

/// Quantas novidades chegaram depois do "visto até" (todas, se nunca abriu).
int contarDesde(List<Novidade> novidades, DateTime? vistoAte) =>
    vistoAte == null ? novidades.length : novidades.where((n) => n.quando.isAfter(vistoAte)).length;

/// Economia de um mês, como a função economia_mensal devolve.
class EconomiaMes {
  const EconomiaMes({required this.mes, required this.comparando, required this.negociando, required this.cashback});
  final DateTime mes;
  final double comparando;
  final double negociando;
  final double cashback;

  double get total => comparando + negociando + cashback;

  factory EconomiaMes.fromJson(Map<String, dynamic> j) {
    final mes = DateTime.parse(j['mes'] as String);
    return EconomiaMes(
      mes: DateTime(mes.year, mes.month, mes.day),
      comparando: lerValor(j['comparando']),
      negociando: lerValor(j['negociando']),
      cashback: lerValor(j['cashback']),
    );
  }
}
