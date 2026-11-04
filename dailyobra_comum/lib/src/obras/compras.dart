/// Compras da obra: a lista de materiais da obra, o saldo, o que comprar nos próximos dias e os alertas de preço.
library;

import '../marketplace/materiais_catalogo.dart';
import '../marketplace/modelos.dart';
import '../orcamento/materiais.dart';
import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import 'cronograma.dart';
import 'obra.dart';

DateTime? _data(Object? v) => v == null ? null : DateTime.parse(v as String);

/// Liga o mesmo material vindo de lugares diferentes: pelo item do catálogo ou, sem ele, pelo nome e a unidade.
String _chave(String? itemId, String nome, String unidade) => itemId ?? '${nome.trim().toLowerCase()}|${unidade.trim().toLowerCase()}';

/// Um material previsto para a obra. A lista nasce do orçamento e o responsável ajusta.
class MaterialObra {
  const MaterialObra({this.id, this.etapa, this.itemId, required this.nome, required this.unidade, required this.quantidade, this.precoBase});
  factory MaterialObra.fromJson(Map<String, dynamic> j) => MaterialObra(
    id: j['id'] as String?,
    etapa: EtapaId.doCodigo(j['etapa'] as String? ?? ''),
    itemId: j['item_id'] as String?,
    nome: j['nome'] as String,
    unidade: j['unidade'] as String,
    quantidade: (j['quantidade'] as num).toDouble(),
    precoBase: (j['preco_base'] as num?)?.toDouble(),
  );

  final String? id;
  final EtapaId? etapa;

  /// Produto do catálogo; sem ele o material não entra na cotação.
  final String? itemId;
  final String nome;
  final String unidade;
  final double quantidade;

  /// Melhor preço do dia em que entrou na lista: é com ele que o alerta compara.
  final double? precoBase;

  Map<String, Object?> paraSalvar() => {'etapa': etapa?.codigo, 'item_id': itemId, 'nome': nome, 'unidade': unidade, 'quantidade': quantidade, 'preco_base': precoBase};
}

/// Um item de pedido feito para a obra. Sem preço: quem confere a entrega não precisa dele.
class ItemDePedido {
  const ItemDePedido({required this.pedidoId, required this.loja, required this.situacao, required this.data, this.itemId, required this.nome, required this.unidade, required this.quantidade});
  factory ItemDePedido.fromJson(Map<String, dynamic> j) => ItemDePedido(
    pedidoId: j['pedido_id'] as String,
    loja: j['loja'] as String,
    situacao: j['situacao'] as String,
    data: DateTime.parse(j['data'] as String),
    itemId: j['item_id'] as String?,
    nome: j['nome'] as String,
    unidade: j['unidade'] as String,
    quantidade: (j['quantidade'] as num).toDouble(),
  );

  final String pedidoId;
  final String loja;
  final String situacao;
  final DateTime data;
  final String? itemId;
  final String nome;
  final String unidade;
  final double quantidade;
}

/// O que chegou na obra. Sem pedido, é compra feita fora do app.
class Recebimento {
  const Recebimento({this.id, this.pedidoId, this.itemId, required this.nome, required this.unidade, required this.quantidade, required this.data, this.observacao = '', this.fotoPath});
  factory Recebimento.fromJson(Map<String, dynamic> j) => Recebimento(
    id: j['id'] as String?,
    pedidoId: j['pedido_id'] as String?,
    itemId: j['item_id'] as String?,
    nome: j['nome'] as String,
    unidade: j['unidade'] as String,
    quantidade: (j['quantidade'] as num).toDouble(),
    data: _data(j['data'])!,
    observacao: j['observacao'] as String? ?? '',
    fotoPath: j['foto_path'] as String?,
  );

  final String? id;
  final String? pedidoId;
  final String? itemId;
  final String nome;
  final String unidade;
  final double quantidade;
  final DateTime data;
  final String observacao;
  final String? fotoPath;

  Map<String, Object?> paraSalvar() => {'item_id': itemId, 'nome': nome, 'unidade': unidade, 'quantidade': quantidade};
}

class SaldoMaterial {
  const SaldoMaterial({this.itemId, required this.nome, required this.unidade, required this.previsto, required this.comprado, required this.recebido});
  final String? itemId;
  final String nome;
  final String unidade;
  final double previsto;

  /// Pedidos do app e compras de fora.
  final double comprado;
  final double recebido;

  double get falta => previsto > comprado ? previsto - comprado : 0;
  double get aReceber => comprado > recebido ? comprado - recebido : 0;
}

List<SaldoMaterial> calcularSaldo({required List<MaterialObra> materiais, required List<ItemDePedido> pedidos, required List<Recebimento> recebimentos}) {
  final previsto = <String, double>{};
  final comprado = <String, double>{};
  final recebido = <String, double>{};
  final dados = <String, (String?, String, String)>{};
  void anotar(String? itemId, String nome, String unidade) => dados.putIfAbsent(_chave(itemId, nome, unidade), () => (itemId, nome, unidade));
  for (final m in materiais) {
    anotar(m.itemId, m.nome, m.unidade);
    previsto.update(_chave(m.itemId, m.nome, m.unidade), (v) => v + m.quantidade, ifAbsent: () => m.quantidade);
  }
  for (final p in pedidos) {
    anotar(p.itemId, p.nome, p.unidade);
    comprado.update(_chave(p.itemId, p.nome, p.unidade), (v) => v + p.quantidade, ifAbsent: () => p.quantidade);
  }
  for (final r in recebimentos) {
    anotar(r.itemId, r.nome, r.unidade);
    final chave = _chave(r.itemId, r.nome, r.unidade);
    recebido.update(chave, (v) => v + r.quantidade, ifAbsent: () => r.quantidade);
    if (r.pedidoId == null) comprado.update(chave, (v) => v + r.quantidade, ifAbsent: () => r.quantidade);
  }
  return [
    for (final MapEntry(key: chave, value: (itemId, nome, unidade)) in dados.entries)
      SaldoMaterial(itemId: itemId, nome: nome, unidade: unidade, previsto: previsto[chave] ?? 0, comprado: comprado[chave] ?? 0, recebido: recebido[chave] ?? 0),
  ];
}

class ItemAComprar {
  const ItemAComprar({this.itemId, required this.nome, required this.unidade, required this.quantidade, required this.etapas, this.precoBase});
  final String? itemId;
  final String nome;
  final String unidade;
  final double quantidade;
  final List<EtapaId> etapas;
  final double? precoBase;

  ItemAComprar somando(double mais, EtapaId? etapa, double? base) => ItemAComprar(
    itemId: itemId,
    nome: nome,
    unidade: unidade,
    quantidade: quantidade + mais,
    etapas: [...etapas, if (etapa != null && !etapas.contains(etapa)) etapa],
    precoBase: precoBase ?? base,
  );
}

/// O que falta comprar para as etapas dos próximos [dias]. O que já foi comprado atende primeiro as
/// etapas que vêm antes, na ordem da obra. Etapa sem data só entra se for a atual, para a lista
/// continuar útil antes de existir cronograma.
List<ItemAComprar> oQueComprar({required List<LinhaResultado> etapas, required List<MaterialObra> materiais, required List<ItemDePedido> pedidos, required List<Recebimento> recebimentos, required Map<EtapaId, DatasEtapa> datas, required Map<EtapaId, StatusEtapa> status, required DateTime hoje, int dias = 7}) {
  final disponivel = <String, double>{};
  for (final p in pedidos) {
    disponivel.update(_chave(p.itemId, p.nome, p.unidade), (v) => v + p.quantidade, ifAbsent: () => p.quantidade);
  }
  for (final r in recebimentos) {
    if (r.pedidoId != null) continue;
    disponivel.update(_chave(r.itemId, r.nome, r.unidade), (v) => v + r.quantidade, ifAbsent: () => r.quantidade);
  }

  final limite = DateTime(hoje.year, hoje.month, hoje.day + dias);
  final atual = etapaAtual(etapas, status)?.etapa;
  final daObra = {for (final e in etapas) e.etapa};

  bool entra(EtapaId? e) {
    if (e == null || !daObra.contains(e)) return true;
    final s = status[e] ?? StatusEtapa.prevista;
    if (s == StatusEtapa.concluida) return false;
    if (s == StatusEtapa.iniciada || s == StatusEtapa.bloqueada) return true;
    final inicio = datas[e]?.inicioPrevisto;
    return inicio == null ? e == atual : !inicio.isAfter(limite);
  }

  final naOrdem = [
    for (final e in etapas) ...materiais.where((m) => m.etapa == e.etapa),
    ...materiais.where((m) => !daObra.contains(m.etapa)),
  ];
  final compras = <String, ItemAComprar>{};
  for (final m in naOrdem) {
    final chave = _chave(m.itemId, m.nome, m.unidade);
    final coberto = (disponivel[chave] ?? 0).clamp(0, m.quantidade).toDouble();
    disponivel[chave] = (disponivel[chave] ?? 0) - coberto;
    final falta = m.quantidade - coberto;
    if (falta <= 0 || !entra(m.etapa)) continue;
    final atualizado = compras[chave]?.somando(falta, m.etapa, m.precoBase);
    compras[chave] = atualizado ?? ItemAComprar(itemId: m.itemId, nome: m.nome, unidade: m.unidade, quantidade: falta, etapas: [?m.etapa], precoBase: m.precoBase);
  }
  return compras.values.toList();
}

class AlertaPreco {
  const AlertaPreco(this.texto, {required this.bom});
  final String texto;

  /// Boa notícia para quem compra.
  final bool bom;
}

/// Compara o melhor preço de hoje com o do dia em que o material entrou na lista.
/// Variação de até 5% não avisa: é ruído do dia a dia das lojas.
AlertaPreco? alertaDePreco({required double? base, required double? atual, required bool emPromocao}) {
  if (emPromocao) return const AlertaPreco('Em promoção', bom: true);
  if (base == null || atual == null || base <= 0) return null;
  final variacao = (atual - base) / base;
  if (variacao.abs() < 0.05) return null;
  final pontos = (variacao.abs() * 100).round();
  return variacao > 0 ? AlertaPreco('Subiu $pontos%', bom: false) : AlertaPreco('Baixou $pontos%', bom: true);
}

/// Transforma a lista do orçamento na lista da obra: liga ao catálogo, converte a unidade e guarda o preço do dia.
/// Material sem ligação continua na lista, só não entra na cotação.
List<MaterialObra> montarListaDaObra(ResultadoMateriais materiais, Map<String, (String, double)> planilha, Map<String, ItemCatalogo> catalogo, double? Function(String itemId) preco) {
  if (materiais is! MateriaisDisponiveis) return const [];
  final lista = <MaterialObra>[];
  for (final e in materiais.etapas) {
    final doCatalogo = <String, double>{};
    for (final i in e.itens) {
      final destino = planilha['${i.item.trim()}|${i.unidade}'];
      final item = destino == null ? null : catalogo[destino.$1];
      if (destino == null || item == null) {
        lista.add(MaterialObra(etapa: e.etapa, nome: i.item.trim(), unidade: i.unidade, quantidade: i.quantidade));
      } else {
        doCatalogo.update(item.id, (v) => v + i.quantidadeExata * destino.$2, ifAbsent: () => i.quantidadeExata * destino.$2);
      }
    }
    final posicao = lista.length - lista.reversed.takeWhile((m) => m.etapa == e.etapa).length;
    lista.insertAll(posicao, [
      for (final MapEntry(key: id, value: q) in doCatalogo.entries)
        if (q > 0) MaterialObra(etapa: e.etapa, itemId: id, nome: catalogo[id]!.nome, unidade: catalogo[id]!.unidade, quantidade: quantidadeDeCompra(q, catalogo[id]!.unidade), precoBase: preco(id)),
    ]);
  }
  return lista;
}

/// Padrões que servem de ponto de partida quando a obra não tem lista própria. O médio aguarda correção
/// na planilha de referência: em vez de inventar quantidades, o responsável escolhe uma base vizinha e ajusta.
List<Padrao> basesParaOPadrao(Padrao padrao) => padrao == Padrao.medio ? const [Padrao.economico, Padrao.mediaAlta] : const [];

/// A lista de materiais desta obra, calculada com as quantidades de outro padrão.
ResultadoMateriais materiaisComBase(ParametrosObra parametros, Padrao base) {
  final e = parametros.paraEntrada();
  return listarMateriais(
    EntradaOrcamento(areaConstruida: e.areaConstruida, padrao: base, laje: e.laje, areaPisosSuperiores: e.areaPisosSuperiores, cobertura: e.cobertura, aguas: e.aguas, muro: e.muro, piscina: e.piscina, gourmet: e.gourmet, jardim: e.jardim),
  );
}
