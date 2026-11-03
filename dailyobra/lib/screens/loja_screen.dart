import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carrinho_service.dart';
import '../services/catalogo_service.dart';
import 'componentes.dart';
import 'produto_screen.dart';

/// Vitrine de uma loja: capa, logo, frete, pedido mínimo e os produtos com preço.
/// Produto adicionado daqui fica fixado nesta loja na cotação.
class LojaScreen extends StatelessWidget {
  const LojaScreen({super.key, required this.lojaId});
  final String lojaId;

  @override
  Widget build(BuildContext context) {
    final catalogo = CatalogoService.instance;
    final loja = catalogo.loja(lojaId);
    if (loja == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVazio(
          titulo: 'Loja não encontrada',
          texto:
              'Ela pode ter saído do DailyObra. Volte e veja as outras lojas.',
        ),
      );
    }
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final hoje = DateTime.now();
    final carrinho = CarrinhoService.instance;
    final formato = formatoDoContexto(context);
    final situacao = situacaoDaLoja(loja, hoje);
    Widget linha(IconData icone, String texto) => Padding(
      padding: const EdgeInsets.only(top: Espaco.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: c.textoSuave),
          const SizedBox(width: Espaco.s2),
          Expanded(child: Text(texto, style: t.bodyMedium)),
        ],
      ),
    );
    final dados = <Widget>[
      Text(loja.nome, style: t.headlineSmall),
      const SizedBox(height: 2),
      Text(
        '${loja.cidade} · ${loja.uf}',
        style: t.bodyMedium?.copyWith(color: c.textoSuave),
      ),
      if (situacao.estado != EstadoLoja.semHorario) ...[
        const SizedBox(height: Espaco.s2),
        Row(
          children: [
            SeloSituacao(situacao: situacao),
            if (situacao.detalhe.isNotEmpty) ...[
              const SizedBox(width: Espaco.s2),
              Text(
                situacao.detalhe,
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
            ],
          ],
        ),
      ],
      linha(Icons.local_shipping_outlined, freteEMinimo(loja)),
      if (loja.endereco.isNotEmpty) linha(Icons.place_outlined, loja.endereco),
      if (loja.horario.isNotEmpty) linha(Icons.schedule_outlined, loja.horario),
      if (loja.descricao.isNotEmpty) ...[
        const SizedBox(height: Espaco.s3),
        Text(
          loja.descricao,
          style: t.bodyMedium?.copyWith(color: c.textoSuave),
        ),
      ],
      if (loja.whatsapp.isNotEmpty) ...[
        const SizedBox(height: Espaco.s2),
        Row(
          children: [
            Icon(Icons.chat_outlined, size: 16, color: c.textoSuave),
            const SizedBox(width: Espaco.s1),
            SelectableText(_telefone(loja.whatsapp), style: t.bodyMedium),
          ],
        ),
      ],
    ];
    const fechada = Aviso(
      'Esta loja pausou os pedidos pelo app. Os preços aparecem, mas ela não entra na cotação.',
      tom: TomSelo.aviso,
    );
    const semProdutos = EstadoVazio(
      icone: Icons.inventory_2_outlined,
      titulo: 'Esta loja ainda não cadastrou preços',
      texto: 'Volte em breve ou veja os produtos das outras lojas.',
    );
    void abrirProduto(ItemCatalogo item) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProdutoScreen(itemId: item.id)),
    );
    VoidCallback? adicionar(ItemCatalogo item) => loja.aberta
        ? () {
            carrinho.adicionar(item.id, 1, lojaFixada: loja.id);
            avisarAdicionado(context, item.nome);
          }
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(loja.nome, overflow: TextOverflow.ellipsis)),
      body: ListenableBuilder(
        listenable: Listenable.merge([catalogo, carrinho]),
        builder: (context, _) {
          final produtos = catalogo.ofertasDaLoja(lojaId, hoje: hoje);
          final titulo = TituloSecao(
            produtos.isEmpty ? 'Produtos' : 'Produtos (${produtos.length})',
          );
          if (formato != Formato.celular) {
            return LayoutBuilder(
              builder: (context, limites) {
                final m = margemLateral(limites.maxWidth);
                return ListView(
                  padding: const EdgeInsets.only(bottom: Espaco.s8),
                  children: [
                    _Capa(loja: loja, larga: true, margem: m),
                    Padding(
                      padding: EdgeInsets.fromLTRB(m, Espaco.s3, m, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 96 + Espaco.s4,
                            ),
                            child: ConstrainedBox(
                              // Altura da metade da logo que sai da capa
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: dados,
                              ),
                            ),
                          ),
                          if (!loja.aberta) ...[
                            const SizedBox(height: Espaco.s4),
                            fechada,
                          ],
                          titulo,
                          if (produtos.isEmpty)
                            semProdutos
                          else
                            GradeCartoes(
                              colunas: colunasDaGrade(formato),
                              filhos: [
                                for (final (oferta, item) in produtos)
                                  CartaoOfertaComBotao(
                                    item: item,
                                    oferta: oferta,
                                    hoje: hoje,
                                    noOrcamento: carrinho.contem(item.id),
                                    onTap: () => abrirProduto(item),
                                    onAdicionar: adicionar(item),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: Espaco.s8),
            children: [
              _Capa(loja: loja),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s3,
                  Espaco.s4,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...dados,
                    if (!loja.aberta) ...[
                      const SizedBox(height: Espaco.s3),
                      fechada,
                    ],
                    titulo,
                  ],
                ),
              ),
              if (produtos.isEmpty)
                semProdutos
              else
                for (final (oferta, item) in produtos)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Espaco.s4,
                      0,
                      Espaco.s4,
                      Espaco.s3,
                    ),
                    child: CartaoProduto(
                      item: item,
                      melhorOferta: oferta,
                      hoje: hoje,
                      noOrcamento: carrinho.contem(item.id),
                      onTap: () => abrirProduto(item),
                      onAdicionar: adicionar(item),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

String _telefone(String d) {
  if (d.length == 11) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  }
  if (d.length == 10) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  }
  return d;
}

/// Capa com a logo sobreposta: 136 px no celular; 220 px de largura total no tablet e no
/// computador, com a logo alinhada ao conteúdo ([margem]).
class _Capa extends StatelessWidget {
  const _Capa({
    required this.loja,
    this.larga = false,
    this.margem = Espaco.s4,
  });
  final Loja loja;
  final bool larga;
  final double margem;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final fundo = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.acao.withValues(alpha: 0.22),
            c.acento.withValues(alpha: 0.08),
          ],
        ),
      ),
    );
    final altura = larga ? 220.0 : 136.0;
    final logo = larga ? 96.0 : 72.0;
    // Larga: a metade de baixo da logo transborda e os dados da loja ficam ao lado dela
    return SizedBox(
      height: larga ? altura : altura + logo / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: altura,
            child: loja.capaUrl == null
                ? fundo
                : Image.network(
                    loja.capaUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fundo,
                  ),
          ),
          Positioned(
            left: margem,
            bottom: larga ? -logo / 2 : 0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.fundo, width: 3),
              ),
              child: LogoLoja(loja: loja, tamanho: logo),
            ),
          ),
        ],
      ),
    );
  }
}
