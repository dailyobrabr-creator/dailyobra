import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/anuncios_service.dart';
import '../services/carrinho_service.dart';
import '../services/catalogo_service.dart';
import 'componentes.dart';
import 'produto_screen.dart';

const _destaquesPorLista = 2;

enum _Ordem {
  relevancia('Relevância'),
  menorPreco('Menor preço'),
  nome('Nome');

  const _Ordem(this.rotulo);
  final String rotulo;
}

/// Produtos com a melhor oferta entre as lojas e o botão de adicionar: lista no celular; grade
/// com filtros (só com oferta, ordem e, na busca, categoria) no tablet e no computador.
class ListaProdutos extends StatefulWidget {
  const ListaProdutos({
    super.key,
    required this.itens,
    this.cabecalho = const [],
    this.filtrarCategoria = false,
  });
  final List<ItemCatalogo> itens;
  final List<Widget> cabecalho;
  final bool filtrarCategoria;

  @override
  State<ListaProdutos> createState() => _ListaProdutosState();
}

class _ListaProdutosState extends State<ListaProdutos> {
  bool _soComOferta = false;
  _Ordem _ordem = _Ordem.relevancia;
  String? _categoria;

  void _abrir(ItemCatalogo item) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProdutoScreen(itemId: item.id)),
  );

  /// Os destaques pagos que sobem na lista, no máximo dois. Só eles têm o selo e o preço de quem anuncia, e contam como
  /// vistos.
  Set<ItemCatalogo> _destaques(List<ItemCatalogo> itens, DateTime hoje) {
    final catalogo = CatalogoService.instance;
    final destaques = itens
        .where((i) => catalogo.destaqueDoItem(i.id, hoje) != null)
        .take(_destaquesPorLista)
        .toSet();
    if (destaques.isEmpty) return destaques;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final item in destaques) {
        final destaque = catalogo.destaqueDoItem(item.id, hoje);
        if (destaque != null) {
          AnunciosService.instance.impressao(destaque.anuncio.id);
        }
      }
    });
    return destaques;
  }

  List<ItemCatalogo> _primeiro(
    Set<ItemCatalogo> destaques,
    List<ItemCatalogo> itens,
  ) => [...destaques, ...itens.where((i) => !destaques.contains(i))];

  void _abrirDestaque(ItemCatalogo item, Anuncio anuncio) {
    AnunciosService.instance.clique(anuncio.id);
    _abrir(item);
  }

  void _adicionar(ItemCatalogo item) {
    CarrinhoService.instance.adicionar(item.id, 1);
    avisarAdicionado(context, item.nome);
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = CatalogoService.instance;
    final carrinho = CarrinhoService.instance;
    final hoje = DateTime.now();
    final formato = formatoDoContexto(context);
    return ListenableBuilder(
      listenable: Listenable.merge([catalogo, carrinho]),
      builder: (context, _) {
        if (formato == Formato.celular) {
          final destaques = _destaques(widget.itens, hoje);
          final itens = _primeiro(destaques, widget.itens);
          final cabecalho = widget.cabecalho;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s4,
              Espaco.s4,
              Espaco.s8,
            ),
            itemCount: cabecalho.length + itens.length,
            separatorBuilder: (_, i) =>
                SizedBox(height: i < cabecalho.length ? 0 : Espaco.s3),
            itemBuilder: (context, i) {
              if (i < cabecalho.length) return cabecalho[i];
              final item = itens[i - cabecalho.length];
              final resumo = catalogo.resumoDoItem(item.id, hoje: hoje);
              final destaque = destaques.contains(item)
                  ? catalogo.destaqueDoItem(item.id, hoje)
                  : null;
              final oferta = destaque?.oferta ?? resumo.oferta;
              return CartaoProduto(
                item: item,
                melhorOferta: oferta,
                lojas: resumo.lojas,
                loja: oferta == null ? null : catalogo.loja(oferta.lojaId),
                patrocinado: destaque != null,
                hoje: hoje,
                noOrcamento: carrinho.contem(item.id),
                onTap: destaque == null
                    ? () => _abrir(item)
                    : () => _abrirDestaque(item, destaque.anuncio),
                onAdicionar: () => _adicionar(item),
              );
            },
          );
        }

        final categorias = {for (final i in widget.itens) i.categoriaId};
        // A categoria escolhida pode sumir numa nova busca: aí vale "Todas"
        final categoria = categorias.contains(_categoria) ? _categoria : null;
        final ofertas = {
          for (final i in widget.itens)
            i.id: catalogo.resumoDoItem(i.id, hoje: hoje).oferta,
        };
        double? preco(ItemCatalogo i) => ofertas[i.id]?.precoVigente(hoje);
        final filtrados = [
          for (final i in widget.itens)
            if ((categoria == null || i.categoriaId == categoria) &&
                (!_soComOferta || preco(i) != null))
              i,
        ];
        // Com a pessoa pedindo outra ordem, o patrocinado não passa na frente
        final destaques = _ordem == _Ordem.relevancia
            ? _destaques(filtrados, hoje)
            : <ItemCatalogo>{};
        final itens = _primeiro(destaques, filtrados);
        switch (_ordem) {
          case _Ordem.relevancia:
            break;
          case _Ordem.menorPreco:
            // Estável: empates mantêm a ordem original; sem oferta vai para o fim
            final posicao = {for (final (n, i) in itens.indexed) i.id: n};
            itens.sort((a, b) {
              final pa = preco(a), pb = preco(b);
              final c = pa == null || pb == null
                  ? (pa == null ? 1 : 0) - (pb == null ? 1 : 0)
                  : pa.compareTo(pb);
              return c != 0 ? c : posicao[a.id]!.compareTo(posicao[b.id]!);
            });
          case _Ordem.nome:
            itens.sort(
              (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
            );
        }

        Widget cartao(ItemCatalogo item) {
          final destaque = destaques.contains(item)
              ? catalogo.destaqueDoItem(item.id, hoje)
              : null;
          final oferta = destaque?.oferta ?? ofertas[item.id];
          return CartaoOfertaComBotao(
            item: item,
            oferta: oferta,
            loja: oferta == null ? null : catalogo.loja(oferta.lojaId),
            patrocinado: destaque != null,
            hoje: hoje,
            noOrcamento: carrinho.contem(item.id),
            onTap: destaque == null
                ? () => _abrir(item)
                : () => _abrirDestaque(item, destaque.anuncio),
            onAdicionar: () => _adicionar(item),
          );
        }

        final filtros = Wrap(
          spacing: Espaco.s2,
          runSpacing: Espaco.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.filtrarCategoria && categorias.length > 1) ...[
              ChoiceChip(
                label: const Text('Todas'),
                selected: categoria == null,
                onSelected: (_) => setState(() => _categoria = null),
              ),
              for (final cat in catalogo.categorias)
                if (categorias.contains(cat.id))
                  ChoiceChip(
                    label: Text(cat.nome),
                    selected: categoria == cat.id,
                    onSelected: (_) => setState(
                      () => _categoria = categoria == cat.id ? null : cat.id,
                    ),
                  ),
              const SizedBox(width: Espaco.s3),
            ],
            FilterChip(
              label: const Text('Só com oferta'),
              selected: _soComOferta,
              onSelected: (v) => setState(() => _soComOferta = v),
            ),
            const SizedBox(width: Espaco.s3),
            for (final o in _Ordem.values)
              ChoiceChip(
                label: Text(o.rotulo),
                selected: _ordem == o,
                onSelected: (_) => setState(() => _ordem = o),
              ),
          ],
        );

        return LayoutBuilder(
          builder: (context, limites) {
            final m = margemLateral(limites.maxWidth);
            return ListView(
              padding: EdgeInsets.fromLTRB(m, Espaco.s4, m, Espaco.s8),
              children: [
                ...widget.cabecalho,
                filtros,
                const SizedBox(height: Espaco.s4),
                if (itens.isEmpty)
                  const EstadoVazio(
                    icone: Icons.filter_alt_off_outlined,
                    titulo: 'Nenhum produto com esses filtros',
                    texto: 'Tire o filtro "Só com oferta" ou escolha outra categoria.',
                  )
                else
                  GradeCartoes(
                    colunas: colunasDaGrade(formato),
                    filhos: [for (final item in itens) cartao(item)],
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class CategoriaScreen extends StatelessWidget {
  const CategoriaScreen({
    super.key,
    required this.categoriaId,
    required this.titulo,
  });
  final String categoriaId;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final itens = CatalogoService.instance.itensDaCategoria(categoriaId);
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: itens.isEmpty
          ? EstadoVazio(
              icone: iconeDaCategoria(categoriaId),
              titulo: 'Nenhum produto nesta categoria ainda',
              texto: 'Use a busca ou a lista inteligente para achar o que precisa.',
            )
          : ListaProdutos(itens: itens),
    );
  }
}
