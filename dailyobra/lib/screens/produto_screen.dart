import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carrinho_service.dart';
import '../services/catalogo_service.dart';
import 'componentes.dart';
import 'layout_adaptativo.dart';
import 'loja_screen.dart';

/// Produto do catálogo com o preço em cada loja, do menor para o maior.
class ProdutoScreen extends StatefulWidget {
  const ProdutoScreen({super.key, required this.itemId});
  final String itemId;

  @override
  State<ProdutoScreen> createState() => _ProdutoScreenState();
}

class _ProdutoScreenState extends State<ProdutoScreen> {
  double _quantidade = 1;

  void _adicionar(ItemCatalogo item, {Loja? loja}) {
    CarrinhoService.instance.adicionar(
      item.id,
      _quantidade,
      lojaFixada: loja?.id,
    );
    avisarAdicionado(
      context,
      loja == null ? item.nome : '${item.nome} (${loja.nome})',
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = CatalogoService.instance;
    final item = catalogo.item(widget.itemId);
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVazio(
          titulo: 'Produto não encontrado',
          texto: 'Ele pode ter saído do catálogo. Volte e busque de novo.',
        ),
      );
    }
    final hoje = DateTime.now();
    final precos = catalogo.precosDoItem(item.id, hoje: hoje);
    final percentual = catalogo.percentualPorTier[item.tier] ?? 0;
    final dados = <Widget>[
      Text(item.nome, style: t.headlineSmall),
      const SizedBox(height: Espaco.s1),
      Text(
        'Vendido por ${item.unidade}',
        style: t.bodyMedium?.copyWith(color: c.textoSuave),
      ),
      if (percentual > 0) ...[
        const SizedBox(height: Espaco.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: Selo(
            '${(percentual * 100).round()}% de cashback',
            tom: TomSelo.sucesso,
          ),
        ),
      ],
      const SizedBox(height: Espaco.s4),
      Row(
        children: [
          Expanded(child: Text('Quantidade', style: t.titleSmall)),
          const SizedBox(width: Espaco.s2),
          SeletorQuantidade(
            valor: _quantidade,
            unidade: item.unidade,
            onChanged: (q) => setState(() => _quantidade = q),
          ),
        ],
      ),
    ];
    final lojas = <Widget>[
      if (precos.isEmpty)
        const EstadoVazio(
          icone: Icons.price_change_outlined,
          titulo: 'Nenhuma loja com este produto agora',
          texto: 'Você pode adicionar mesmo assim. Quando uma loja cadastrar o preço, ele entra na cotação.',
        )
      else
        for (final (oferta, loja) in precos) ...[
          _PrecoNaLoja(
            oferta: oferta,
            loja: loja,
            unidade: item.unidade,
            hoje: hoje,
            melhor: identical(oferta, precos.first.$1) && loja.aberta,
            onEscolher: loja.aberta ? () => _adicionar(item, loja: loja) : null,
          ),
          const SizedBox(height: Espaco.s2),
        ],
    ];
    final adicionar = FilledButton(
      onPressed: () => _adicionar(item),
      child: const Text('Adicionar ao orçamento'),
    );
    final ajuda = Text(
      'A cotação escolhe a loja mais barata. Para comprar de uma loja específica, toque em "Escolher".',
      textAlign: TextAlign.center,
      style: t.bodySmall?.copyWith(color: c.textoSuave),
    );

    if (formatoDoContexto(context) == Formato.computador) {
      final cor = coresDaCategoria(
        item.categoriaId,
        Theme.of(context).brightness,
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Produto')),
        body: LayoutBuilder(
          builder: (context, limites) {
            final m = margemLateral(limites.maxWidth);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: m + 420,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(m, Espaco.s5, 0, Espaco.s8),
                    children: [
                      Container(
                        height: 240,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cor.fundo,
                          borderRadius: BorderRadius.circular(Raio.lg),
                        ),
                        child: ImagemProduto(item: item, tamanho: 128),
                      ),
                      const SizedBox(height: Espaco.s4),
                      ...dados,
                      const SizedBox(height: Espaco.s5),
                      adicionar,
                      const SizedBox(height: Espaco.s1),
                      ajuda,
                    ],
                  ),
                ),
                const SizedBox(width: Espaco.s8),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(0, Espaco.s5, m, Espaco.s8),
                    children: [
                      const TituloSecao(
                        'Preço nas lojas',
                        margem: EdgeInsets.only(bottom: Espaco.s3),
                      ),
                      ...lojas,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Produto')),
      body: LayoutBuilder(
        builder: (context, limites) {
          final m = margemLateral(limites.maxWidth, maximo: 720);
          return ListView(
            padding: EdgeInsets.fromLTRB(m, Espaco.s4, m, Espaco.s8),
            children: [
              Center(child: ImagemProduto(item: item, tamanho: 128)),
              const SizedBox(height: Espaco.s4),
              ...dados,
              const TituloSecao('Preço nas lojas'),
              ...lojas,
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s2,
                Espaco.s4,
                Espaco.s3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  adicionar,
                  const SizedBox(height: Espaco.s1),
                  ajuda,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrecoNaLoja extends StatelessWidget {
  const _PrecoNaLoja({
    required this.oferta,
    required this.loja,
    required this.unidade,
    required this.hoje,
    required this.melhor,
    required this.onEscolher,
  });
  final Oferta oferta;
  final Loja loja;
  final String unidade;
  final DateTime hoje;
  final bool melhor;
  final VoidCallback? onEscolher;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.md),
        side: BorderSide(
          color: melhor ? c.acao : c.borda,
          width: melhor ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LojaScreen(lojaId: loja.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s3,
            Espaco.s3,
            Espaco.s2,
            Espaco.s3,
          ),
          child: Row(
            children: [
              LogoLoja(loja: loja, tamanho: 40),
              const SizedBox(width: Espaco.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loja.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall,
                    ),
                    PrecoOferta(oferta: oferta, hoje: hoje, unidade: unidade),
                    Text(
                      [
                        if (melhor) 'Menor preço',
                        if (!loja.aberta) 'Pedidos pausados',
                        if (oferta.disponibilidade ==
                            Disponibilidade.sobConsulta)
                          'Estoque sob consulta',
                        freteEMinimo(loja),
                      ].join(' · '),
                      style: t.bodySmall?.copyWith(
                        color: melhor ? c.acao : c.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espaco.s2),
              TextButton(onPressed: onEscolher, child: const Text('Escolher')),
            ],
          ),
        ),
      ),
    );
  }
}
