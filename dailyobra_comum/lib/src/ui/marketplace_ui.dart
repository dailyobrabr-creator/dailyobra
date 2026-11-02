import 'package:flutter/material.dart';

import '../marketplace/modelos.dart';
import '../tema/categorias.dart';
import '../tema/cores.dart';
import '../tema/tema.dart';
import 'ui.dart';
import 'vitrine.dart';

/// Ícone que representa a categoria no lugar da foto (o app não inventa foto de produto).
IconData iconeDaCategoria(String categoriaId) => switch (categoriaId) {
      'basico' => Icons.foundation,
      'estrutura' => Icons.view_column_outlined,
      'alvenaria' => Icons.view_quilt_outlined,
      'cobertura' => Icons.roofing,
      'hidraulica' => Icons.water_drop_outlined,
      'eletrica' => Icons.bolt_outlined,
      'acabamento' => Icons.grid_on,
      'pintura' => Icons.format_paint_outlined,
      'loucas-metais' => Icons.bathtub_outlined,
      'ferramentas' => Icons.handyman_outlined,
      _ => Icons.construction,
    };

class ImagemProduto extends StatelessWidget {
  const ImagemProduto({super.key, required this.item, this.tamanho = 64});
  final ItemCatalogo item;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final icone = Icon(iconeDaCategoria(item.categoriaId), size: tamanho * 0.42, color: c.textoSuave);
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: c.superficieSutil,
        borderRadius: BorderRadius.circular(Raio.md),
        border: Border.all(color: c.borda),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: item.imagemUrl == null
          ? icone
          : Image.network(
              item.imagemUrl!,
              width: tamanho,
              height: tamanho,
              fit: BoxFit.cover,
              semanticLabel: item.nome,
              errorBuilder: (_, _, _) => icone,
            ),
    );
  }
}

/// Logo redonda da loja; sem logo, as iniciais do nome sobre a cor da marca.
class LogoLoja extends StatelessWidget {
  const LogoLoja({super.key, required this.loja, this.tamanho = 48});
  final Loja loja;
  final double tamanho;

  static String iniciais(String nome) {
    const ignorar = {'de', 'da', 'do', 'das', 'dos', 'e', 'ltda', 'me', 'sa'};
    final palavras = nome.split(RegExp(r'\s+')).where((p) => p.isNotEmpty && !ignorar.contains(p.toLowerCase())).toList();
    if (palavras.isEmpty) return '?';
    return palavras.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final letras = Text(
      iniciais(loja.nome),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: tamanho * 0.34),
    );
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: corDaLoja(loja.id),
        border: Border.all(color: c.superficie, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: loja.logoUrl == null
          ? letras
          : Image.network(loja.logoUrl!, width: tamanho, height: tamanho, fit: BoxFit.cover, errorBuilder: (_, _, _) => letras),
    );
  }
}

/// Preço que vale hoje; em promoção, o cheio aparece riscado ao lado.
class PrecoOferta extends StatelessWidget {
  const PrecoOferta({super.key, required this.oferta, required this.hoje, this.unidade, this.aPartirDe = false, this.grande = false});
  final Oferta oferta;
  final DateTime hoje;
  final String? unidade;
  final bool aPartirDe;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final promo = oferta.emPromocao(hoje);
    final preco = oferta.precoVigente(hoje) ?? oferta.preco;
    final suave = t.bodySmall?.copyWith(color: c.textoSuave, fontFeatures: numerosTabulares);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Espaco.s1 + 2,
      children: [
        if (aPartirDe) Text('a partir de', style: suave),
        if (promo) Text(brl.format(oferta.preco), style: suave?.copyWith(decoration: TextDecoration.lineThrough)),
        Text(
          brl.format(preco),
          style: (grande ? t.titleLarge : t.titleSmall)?.copyWith(
            fontWeight: FontWeight.w700,
            color: promo ? c.acao : c.texto,
            fontFeatures: numerosTabulares,
          ),
        ),
        if (unidade != null) Text('/ $unidade', style: suave),
      ],
    );
  }
}

class _SeloOferta extends StatelessWidget {
  const _SeloOferta();

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Espaco.s2, vertical: 2),
      decoration: BoxDecoration(color: c.acento.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text('Oferta', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.acao, fontWeight: FontWeight.w700)),
    );
  }
}

/// Produto do catálogo com a melhor oferta entre as lojas.
class CartaoProduto extends StatelessWidget {
  const CartaoProduto({
    super.key,
    required this.item,
    required this.hoje,
    this.melhorOferta,
    this.lojas = 0,
    this.noOrcamento = false,
    this.onTap,
    this.onAdicionar,
  });
  final ItemCatalogo item;
  final DateTime hoje;
  final Oferta? melhorOferta;

  /// Em quantas lojas o produto tem oferta.
  final int lojas;
  final bool noOrcamento;
  final VoidCallback? onTap;
  final VoidCallback? onAdicionar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final oferta = melhorOferta;
    return Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg), side: BorderSide(color: c.borda)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImagemProduto(item: item, tamanho: 72),
              const SizedBox(width: Espaco.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (oferta != null && oferta.emPromocao(hoje)) ...[const _SeloOferta(), const SizedBox(height: Espaco.s1)],
                    Text(item.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                    const SizedBox(height: Espaco.s1),
                    if (oferta == null)
                      Text('Sem oferta no momento', style: t.bodySmall?.copyWith(color: c.textoSuave))
                    else ...[
                      PrecoOferta(oferta: oferta, hoje: hoje, unidade: item.unidade, aPartirDe: lojas > 1),
                      if (lojas > 0)
                        Text(lojas == 1 ? 'em 1 loja' : 'em $lojas lojas', style: t.bodySmall?.copyWith(color: c.textoSuave)),
                    ],
                  ],
                ),
              ),
              if (onAdicionar != null) ...[
                const SizedBox(width: Espaco.s2),
                IconButton.filledTonal(
                  tooltip: noOrcamento ? 'Já está no orçamento' : 'Adicionar ao orçamento',
                  onPressed: onAdicionar,
                  icon: Icon(noOrcamento ? Icons.check : Icons.add),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String freteEMinimo(Loja loja) {
  final frete = loja.freteFixo == 0 ? 'Frete grátis' : 'Frete ${brl.format(loja.freteFixo)}';
  return loja.pedidoMinimo > 0 ? '$frete · Pedido mínimo ${brl.format(loja.pedidoMinimo)}' : frete;
}

class CartaoLoja extends StatelessWidget {
  const CartaoLoja({super.key, required this.loja, this.onTap, this.detalhe, this.ofertas});
  final Loja loja;
  final VoidCallback? onTap;

  /// Linha extra, como "12 produtos em oferta".
  final String? detalhe;

  /// Quantas ofertas a loja tem hoje (aparece ao lado do frete).
  final int? ofertas;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final cor = corDaLoja(loja.id);
    final faixa = ColoredBox(color: cor.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.22));
    final linha = [
      freteEMinimo(loja),
      if (ofertas != null && ofertas! > 0) ofertas == 1 ? '1 oferta' : '$ofertas ofertas',
    ].join(' · ');
    return Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg), side: BorderSide(color: c.borda)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 64,
              child: loja.capaUrl == null ? faixa : Image.network(loja.capaUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => faixa),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Espaco.s3, 0, Espaco.s3, Espaco.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Transform.translate(offset: const Offset(0, -20), child: LogoLoja(loja: loja, tamanho: 52)),
                      const Spacer(),
                      if (loja.nova && loja.aberta) ...[const Selo('Nova', tom: TomSelo.info), const SizedBox(width: Espaco.s2)],
                      Padding(padding: const EdgeInsets.only(top: Espaco.s2), child: SeloAberta(aberta: loja.aberta)),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loja.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${loja.cidade} · ${loja.uf}', style: t.bodySmall?.copyWith(color: c.textoSuave)),
                        const SizedBox(height: 2),
                        Text(linha, maxLines: 2, style: t.bodySmall?.copyWith(color: c.textoSuave, fontFeatures: numerosTabulares)),
                        if (detalhe != null) ...[
                          const SizedBox(height: 2),
                          Text(detalhe!, style: t.bodySmall?.copyWith(color: c.acao, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChipCategoria extends StatelessWidget {
  const ChipCategoria({super.key, required this.categoria, this.selecionada = false, this.onTap});
  final Categoria categoria;
  final bool selecionada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Semantics(
      button: true,
      selected: selecionada,
      label: categoria.nome,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Raio.md),
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Espaco.s1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selecionada ? c.acao : coresDaCategoria(categoria.id, Theme.of(context).brightness).fundo,
                    borderRadius: BorderRadius.circular(Raio.lg),
                    border: Border.all(color: selecionada ? c.acao : c.borda),
                  ),
                  child: Icon(
                    iconeDaCategoria(categoria.id),
                    color: selecionada ? c.textoSobreAcao : coresDaCategoria(categoria.id, Theme.of(context).brightness).icone,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  categoria.nome,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: selecionada ? FontWeight.w700 : FontWeight.w500,
                        color: selecionada ? c.texto : c.textoSuave,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra fixa no pé da tela com o total, o cashback previsto e as ações (como a sacola do delivery).
class RodapeTotal extends StatelessWidget {
  const RodapeTotal({super.key, required this.total, required this.cashback, required this.acoes, this.rotulo = 'Total', this.extra});
  final double total;
  final double cashback;
  final List<Widget> acoes;
  final String rotulo;

  /// Conteúdo entre o total e os botões, como o interruptor "Usar saldo da carteira".
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.superficie,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borda))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s3, Espaco.s4, Espaco.s3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rotulo, style: t.labelMedium?.copyWith(color: c.textoSuave)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              brl.format(total),
                              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontFeatures: numerosTabulares),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cashback > 0) ...[
                      const SizedBox(width: Espaco.s3),
                      Flexible(
                        child: Text(
                          '+ ${brl.format(cashback)} de cashback',
                          textAlign: TextAlign.end,
                          style: t.bodySmall?.copyWith(color: c.sucesso, fontWeight: FontWeight.w600, fontFeatures: numerosTabulares),
                        ),
                      ),
                    ],
                  ],
                ),
                ?extra,
                if (acoes.isNotEmpty) ...[
                  const SizedBox(height: Espaco.s3),
                  Row(
                    children: [
                      for (var i = 0; i < acoes.length; i++) ...[
                        if (i > 0) const SizedBox(width: Espaco.s2),
                        Expanded(child: acoes[i]),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.titulo, required this.texto, this.icone = Icons.inventory_2_outlined, this.acao});
  final String titulo;
  final String texto;
  final IconData icone;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Espaco.s6, vertical: Espaco.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.superficieSutil, shape: BoxShape.circle, border: Border.all(color: c.borda)),
            child: Icon(icone, color: c.textoSuave, size: 28),
          ),
          const SizedBox(height: Espaco.s4),
          Text(titulo, textAlign: TextAlign.center, style: t.titleMedium),
          const SizedBox(height: Espaco.s2),
          Text(texto, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: c.textoSuave)),
          if (acao != null) ...[const SizedBox(height: Espaco.s4), acao!],
        ],
      ),
    );
  }
}
