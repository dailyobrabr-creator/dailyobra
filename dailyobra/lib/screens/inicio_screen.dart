import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carrinho_service.dart';
import '../services/carteira_service.dart';
import '../services/catalogo_service.dart';
import '../services/economia_service.dart';
import '../services/leitura_lista_service.dart';
import '../services/negociacao_service.dart';
import '../services/novidades_service.dart';
import '../services/obras_service.dart';
import '../services/perfil_service.dart';
import 'busca_screen.dart';
import 'categoria_screen.dart';
import 'componentes.dart';
import 'layout_adaptativo.dart';
import 'loja_screen.dart';
import 'obra_form_screen.dart';
import 'obra_screen.dart';
import 'pedido_screen.dart';
import 'produto_screen.dart';
import 'proposta_screen.dart';
import 'smart_list_screen.dart';
import 'topo_vitrine.dart';

/// Vitrine "vitrine viva": obra ativa, economia, lista inteligente, avisos de propostas e pedidos,
/// categorias, ofertas, mais barato hoje e lojas perto. Uma coluna no celular e no tablet; duas
/// no computador (a lateral com avisos e lojas).
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, this.tema, this.onSino});
  final PreferenciaTema? tema;
  final VoidCallback? onSino;

  Future<void> _atualizar() => Future.wait([
    CatalogoService.instance.carregar(),
    CarteiraService.instance.carregar(),
    EconomiaService.instance.carregar(),
    NegociacaoService.instance.carregar(),
    ObrasService.instance.carregar(),
    NovidadesService.instance.carregar(),
  ]);

  @override
  Widget build(BuildContext context) {
    final formato = formatoDoContexto(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([
          CatalogoService.instance,
          PerfilService.instance,
          CarteiraService.instance,
          EconomiaService.instance,
          NegociacaoService.instance,
          ObrasService.instance,
          CarrinhoService.instance,
          NovidadesService.instance,
        ]),
        builder: (context, _) {
          final v = _Vitrine(context, formato);
          final erro = CatalogoService.instance.erro;
          final topo = TopoVitrine(
            compacto: formato == Formato.celular,
            tema: tema,
            onSino: onSino,
          );
          final List<Widget> filhos;
          switch (formato) {
            case Formato.celular:
              filhos = [
                topo,
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s4,
                    Espaco.s4,
                    Espaco.s4,
                    Espaco.s8,
                  ),
                  child: _coluna([
                    if (erro != null) Aviso(erro, tom: TomSelo.aviso),
                    v.clube(),
                    v.contraproposta(),
                    v.pedido(),
                    const _ListaInteligente(compacta: true),
                    v.obra(),
                    v.economia(),
                    v.categorias(),
                    v.ofertas(),
                    v.maisBarato(),
                    v.lojas(),
                  ], Espaco.s4),
                ),
              ];
            case Formato.tablet:
              filhos = [
                topo,
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s6,
                    Espaco.s6,
                    Espaco.s6,
                    Espaco.s10,
                  ),
                  child: _coluna([
                    if (erro != null) Aviso(erro, tom: TomSelo.aviso),
                    v.contraproposta(),
                    v.pedido(),
                    const _ListaInteligente(compacta: false),
                    v.dupla(),
                    v.categorias(),
                    v.ofertas(),
                    v.maisBarato(),
                    v.lojas(),
                  ], Espaco.s6),
                ),
              ];
            case Formato.computador:
              filhos = [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s8,
                    Espaco.s6,
                    Espaco.s8,
                    Espaco.s10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (erro != null) ...[
                        Aviso(erro, tom: TomSelo.aviso),
                        const SizedBox(height: Espaco.s4),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _coluna([
                              v.dupla(),
                              const _ListaInteligente(compacta: false),
                              v.categorias(),
                              v.ofertas(),
                              v.maisBarato(),
                            ], Espaco.s6),
                          ),
                          const SizedBox(width: Espaco.s6),
                          SizedBox(
                            width: 340,
                            child: _coluna([
                              v.contraproposta(),
                              v.pedido(),
                              v.lojas(),
                            ], Espaco.s6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ];
          }
          return RefreshIndicator(
            color: context.cores.acao,
            onRefresh: _atualizar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: filhos,
            ),
          );
        },
      ),
    );
  }
}

/// Coluna com espaço igual entre os blocos que existem (os nulos somem).
Widget _coluna(List<Widget?> blocos, double espaco) {
  final visiveis = blocos.whereType<Widget>().toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < visiveis.length; i++) ...[
        if (i > 0) SizedBox(height: espaco),
        visiveis[i],
      ],
    ],
  );
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.child,
    this.cor,
    this.borda,
    this.onTap,
    super.key,
  });
  final Widget child;
  final Color? cor;
  final Color? borda;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Material(
      color: cor ?? c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
        side: borda == null
            ? BorderSide(color: c.borda)
            : BorderSide(color: borda!, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      ),
    );
  }
}

String _prazo(DateTime ate) {
  final resto = ate.difference(DateTime.now());
  if (resto.inHours >= 1) return '${resto.inHours} h';
  return '${resto.inMinutes.clamp(1, 59)} min';
}

/// Monta cada bloco do Início; devolve nulo quando o bloco não deve aparecer.
class _Vitrine {
  _Vitrine(this.context, this.formato);
  final BuildContext context;
  final Formato formato;

  CoresDailyObra get c => context.cores;
  TextTheme get t => Theme.of(context).textTheme;
  DateTime get hoje => DateTime.now();

  void _abrir(Widget tela) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => tela));

  TextStyle? get _rotulo => t.bodyMedium?.copyWith(color: c.textoSuave);
  TextStyle? get _grande => t.headlineSmall?.copyWith(
    fontWeight: FontWeight.w700,
    fontFeatures: numerosTabulares,
  );

  Widget clube() {
    final carteira = CarteiraService.instance;
    return _Cartao(
      cor: c.cartaoEscuro,
      borda: c.cartaoEscuro,
      onTap: () => irParaAba(context, Aba.carteira),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clube DailyObra',
                  style: t.bodySmall?.copyWith(color: c.textoCartaoEscuroSuave),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${brl.format(carteira.disponivel)} disponível',
                    style: t.titleLarge?.copyWith(
                      color: c.textoCartaoEscuro,
                      fontWeight: FontWeight.w700,
                      fontFeatures: numerosTabulares,
                    ),
                  ),
                ),
                Text(
                  carteira.pendente > 0
                      ? '+ ${brl.format(carteira.pendente)} a liberar depois da entrega'
                      : 'Ganhe cashback em cada pedido fechado pelo app',
                  style: t.bodySmall?.copyWith(color: const Color(0xFFFFB98F)),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.textoCartaoEscuro),
        ],
      ),
    );
  }

  Widget? contraproposta() {
    final lista =
        NegociacaoService.instance.propostas
            .where((p) => p.status == StatusProposta.contraproposta)
            .toList()
          ..sort((a, b) => a.validaAte.compareTo(b.validaAte));
    if (lista.isEmpty) return null;
    final primeira = lista.first;
    final cabecalho = Row(
      children: [
        Icon(Icons.swap_horiz, color: c.acao, size: 22),
        const SizedBox(width: Espaco.s2),
        Expanded(
          child: Text(
            lista.length == 1
                ? 'Contraproposta'
                : '${lista.length} contrapropostas esperando você',
            style: t.titleSmall?.copyWith(
              color: c.acao,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    if (lista.length > 1) {
      return _Cartao(
        borda: c.acento,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cabecalho,
            const SizedBox(height: Espaco.s2),
            Text(
              'A primeira vence em ${_prazo(primeira.validaAte)}: ${primeira.lojaNome}.',
              style: _rotulo,
            ),
            const SizedBox(height: Espaco.s3),
            FilledButton(
              onPressed: () => irParaAba(context, Aba.orcamentos),
              child: const Text('Ver propostas'),
            ),
          ],
        ),
      );
    }
    final item = primeira.itens.isEmpty ? null : primeira.itens.first;
    final resumo = item == null
        ? brl.format(primeira.total)
        : '${formatarQuantidade(item.quantidade)} ${item.unidade} de ${item.nome}'
              '${primeira.itens.length > 1 ? ' e mais ${primeira.itens.length - 1}' : ''} por ${brl.format(primeira.total)}';
    return _Cartao(
      borda: c.acento,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecalho,
          const SizedBox(height: Espaco.s2),
          Text(
            primeira.lojaNome,
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            resumo,
            style: _rotulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Espaco.s2),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.destaqueSuave,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: c.acao),
                  const SizedBox(width: 4),
                  Text(
                    'Responda em ${_prazo(primeira.validaAte)}',
                    style: t.labelMedium?.copyWith(
                      color: c.acao,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Espaco.s3),
          FilledButton(
            onPressed: () => _abrir(PropostaScreen(id: primeira.id)),
            child: const Text('Ver proposta'),
          ),
        ],
      ),
    );
  }

  Widget? pedido() {
    final emAndamento =
        NegociacaoService.instance.propostas
            .where(
              (p) =>
                  p.pedido != null &&
                  const {
                    StatusPedido.emSeparacao,
                    StatusPedido.saiuEntrega,
                  }.contains(p.pedido!.status),
            )
            .toList()
          ..sort((a, b) => b.pedido!.criadoEm.compareTo(a.pedido!.criadoEm));
    if (emAndamento.isEmpty) return null;
    final p = emAndamento.first;
    final saiu = p.pedido!.status == StatusPedido.saiuEntrega;
    return _Cartao(
      cor: c.cartaoEscuro,
      borda: c.cartaoEscuro,
      onTap: () => _abrir(PedidoScreen(pedidoId: p.pedido!.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: c.topo, size: 22),
              const SizedBox(width: Espaco.s2),
              Expanded(
                child: Text(
                  saiu ? 'Pedido saiu para entrega' : 'Pedido em separação',
                  style: t.titleSmall?.copyWith(
                    color: c.textoCartaoEscuro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${p.lojaNome} · ${brl.format(p.pedido!.total)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(
              color: c.textoCartaoEscuroSuave,
              fontFeatures: numerosTabulares,
            ),
          ),
          const SizedBox(height: Espaco.s3),
          BarraPassos(
            feitos: saiu ? 3 : 2,
            inicio: 'Confirmado',
            fim: 'Entregue',
          ),
        ],
      ),
    );
  }

  Widget obra() {
    final servico = ObrasService.instance;
    if (servico.obras == null) return const EsqueletoBrilho(altura: 132);
    final obra = servico.obraAtiva;
    if (obra == null) {
      return _Cartao(
        onTap: () => _abrir(const ObraFormScreen()),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.destaqueSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.home_work_outlined, color: c.acao),
            ),
            const SizedBox(width: Espaco.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cadastre sua obra e cote os materiais dela',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'O app calcula os materiais e manda para as lojas.',
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textoSuave),
          ],
        ),
      );
    }
    final etapas =
        Calculo.de(obra.parametros).resultado?.etapas ??
        const <LinhaResultado>[];
    final percentual = progresso(etapas, obra.statusEtapas);
    final atual = etapaAtual(etapas, obra.statusEtapas);
    final feitas = etapas
        .where((e) => obra.statusEtapas[e.etapa] == StatusEtapa.concluida)
        .length;
    return _Cartao(
      onTap: () => _abrir(ObraScreen(id: obra.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Obra ativa · ${obra.nome}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _rotulo,
          ),
          const SizedBox(height: 2),
          Text('$percentual% concluída', style: _grande),
          const SizedBox(height: Espaco.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentual / 100,
              minHeight: 8,
              color: c.topo,
              backgroundColor: c.segPrevista,
            ),
          ),
          const SizedBox(height: Espaco.s3),
          Row(
            children: [
              Expanded(
                child: Text(
                  atual == null
                      ? 'Todas as etapas concluídas'
                      : 'Etapa atual: ${atual.nome}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: c.textoSuave),
                ),
              ),
              const SizedBox(width: Espaco.s2),
              Text(
                '$feitas de ${etapas.length} etapas',
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget economia() {
    final eco = EconomiaService.instance;
    if (!eco.carregado) {
      if (eco.erro == null) return const EsqueletoBrilho(altura: 132);
      return _Cartao(
        onTap: () => irParaAba(context, Aba.carteira),
        child: Text(
          'Não deu para carregar a economia agora. ${eco.erro}',
          style: t.bodyMedium,
        ),
      );
    }
    final atual = eco.atual;
    final mes = atual?.mes ?? hoje;
    final semNada = eco.meses.every((m) => m.total == 0);
    return _Cartao(
      onTap: () => irParaAba(context, Aba.carteira),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Você economizou em ${mesesExtenso[mes.month - 1]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _rotulo,
          ),
          const SizedBox(height: 2),
          if (semNada) ...[
            const SizedBox(height: Espaco.s2),
            Text(
              'Feche seu primeiro pedido pelo app para ver a economia aqui.',
              style: t.bodyMedium,
            ),
          ] else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                brl.format(atual!.total),
                style: _grande?.copyWith(color: c.sucesso),
              ),
            ),
            const SizedBox(height: Espaco.s2),
            SizedBox(
              height: 64,
              child: GraficoMeses(
                meses: [
                  for (final m in eco.meses)
                    (mesesCurtos[m.mes.month - 1], m.total),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Obra ativa e economia lado a lado (tablet e computador), com a mesma altura.
  Widget dupla() => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: obra()),
        const SizedBox(width: Espaco.s4),
        Expanded(child: economia()),
      ],
    ),
  );

  Widget? categorias() {
    final categorias = CatalogoService.instance.categorias;
    if (categorias.isEmpty) return null;
    Widget tile(Categoria cat, bool horizontal) => TileCategoria(
      categoria: cat,
      horizontal: horizontal,
      onTap: () =>
          _abrir(CategoriaScreen(categoriaId: cat.id, titulo: cat.nome)),
    );
    final Widget grade;
    if (formato == Formato.celular) {
      grade = SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categorias.length,
          separatorBuilder: (_, _) => const SizedBox(width: Espaco.s2),
          itemBuilder: (_, i) =>
              SizedBox(width: 88, child: tile(categorias[i], false)),
        ),
      );
    } else {
      final horizontal = formato == Formato.computador;
      grade = GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categorias.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: Espaco.s3,
          crossAxisSpacing: Espaco.s3,
          mainAxisExtent: horizontal ? 64 : 108,
        ),
        itemBuilder: (_, i) => tile(categorias[i], horizontal),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSecao(
          'Categorias',
          acao: 'Ver todas',
          onAcao: () => _abrir(const BuscaScreen()),
          margem: const EdgeInsets.only(bottom: Espaco.s2),
        ),
        grade,
      ],
    );
  }

  Widget? ofertas() {
    final promocoes = CatalogoService.instance.ofertasEmPromocao(hoje);
    if (promocoes.isEmpty) return null;
    Widget cartao((Oferta, ItemCatalogo, Loja) p, {double? largura}) =>
        CartaoOferta(
          item: p.$2,
          oferta: p.$1,
          hoje: hoje,
          nomeLoja: p.$3.nome,
          largura: largura,
          onTap: () => _abrir(ProdutoScreen(itemId: p.$2.id)),
        );
    final Widget lista;
    if (formato == Formato.celular) {
      final escala = MediaQuery.textScalerOf(context).scale(1);
      lista = SizedBox(
        height: 152 + 100 * escala,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: promocoes.length,
          separatorBuilder: (_, _) => const SizedBox(width: Espaco.s3),
          itemBuilder: (_, i) => Align(
            alignment: Alignment.topCenter,
            child: cartao(promocoes[i], largura: 168),
          ),
        ),
      );
    } else {
      final porLinha = formato == Formato.computador ? 4 : 3;
      final primeiros = promocoes.take(porLinha).toList();
      lista = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < porLinha; i++) ...[
            if (i > 0) const SizedBox(width: Espaco.s4),
            Expanded(
              child: i < primeiros.length
                  ? cartao(primeiros[i])
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSecao(
          'Ofertas do dia',
          margem: EdgeInsets.only(bottom: Espaco.s3),
        ),
        lista,
      ],
    );
  }

  Widget? maisBarato() {
    final catalogo = CatalogoService.instance;
    final faixas = maisBaratoHoje(
      itens: catalogo.itens,
      ofertas: catalogo.ofertas,
      lojas: catalogo.lojaPorId,
      hoje: hoje,
      noOrcamento: {for (final i in CarrinhoService.instance.itens) i.itemId},
    );
    if (faixas.isEmpty) return null;
    final estreito = formato == Formato.celular;
    return _Cartao(
      key: const Key('mais-barato'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSecao(
            'Mais barato hoje',
            margem: EdgeInsets.only(bottom: Espaco.s1),
          ),
          for (var i = 0; i < faixas.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.borda),
            InkWell(
              onTap: () => _abrir(ProdutoScreen(itemId: faixas[i].item.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Espaco.s3),
                child: _LinhaFaixa(faixa: faixas[i], estreito: estreito),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget lojas() {
    final catalogo = CatalogoService.instance;
    final perfil = PerfilService.instance;
    final lojas = catalogo.lojas;
    if (lojas.isEmpty) {
      return const KeyedSubtree(
        key: Key('lojas-perto'),
        child: EstadoVazio(
          icone: Icons.storefront_outlined,
          titulo: 'Ainda não há lojas na sua cidade',
          texto:
              'Assim que as lojas da região entrarem no DailyObra, os preços e as ofertas aparecem aqui. '
              'Você já pode montar o orçamento pela lista inteligente.',
        ),
      );
    }
    final daCidade = lojas.where(catalogo.lojaDaMinhaCidade).length;
    return _Cartao(
      key: const Key('lojas-perto'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSecao(
            'Lojas perto',
            margem: EdgeInsets.only(bottom: Espaco.s2),
          ),
          if (perfil.cidade != null && daCidade == 0) ...[
            Aviso(
              'Ainda não há lojas em ${perfil.cidade}. Veja as de outras cidades.',
              tom: TomSelo.info,
            ),
            const SizedBox(height: Espaco.s2),
          ],
          for (var i = 0; i < lojas.length && i < 5; i++) ...[
            if (i > 0) Divider(height: 1, color: c.borda),
            InkWell(
              onTap: () => _abrir(LojaScreen(lojaId: lojas[i].id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Espaco.s3),
                child: _LinhaLoja(
                  loja: lojas[i],
                  produtos: catalogo
                      .ofertasDaLoja(lojas[i].id, hoje: hoje)
                      .length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaFaixa extends StatelessWidget {
  const _LinhaFaixa({required this.faixa, required this.estreito});
  final FaixaPreco faixa;
  final bool estreito;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final nome = Text.rich(
      TextSpan(
        text: faixa.item.nome,
        style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        children: [
          TextSpan(
            text: ' · ${faixa.lojas} lojas',
            style: t.bodyMedium?.copyWith(color: c.textoSuave),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final intervalo = Text(
      'de ${brl.format(faixa.menor)} a ${brl.format(faixa.maior)}',
      style: t.bodySmall?.copyWith(
        color: c.textoSuave,
        fontFeatures: numerosTabulares,
      ),
    );
    final melhor = Text(
      brl.format(faixa.menor),
      style: t.titleSmall?.copyWith(
        color: c.acao,
        fontWeight: FontWeight.w700,
        fontFeatures: numerosTabulares,
      ),
    );
    if (estreito) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [nome, intervalo],
            ),
          ),
          const SizedBox(width: Espaco.s3),
          melhor,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: nome),
        const SizedBox(width: Espaco.s4),
        intervalo,
        const SizedBox(width: Espaco.s4),
        melhor,
      ],
    );
  }
}

class _LinhaLoja extends StatelessWidget {
  const _LinhaLoja({required this.loja, required this.produtos});
  final Loja loja;
  final int produtos;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final frete = textoFrete(loja);
    final detalhe = loja.aberta
        ? [
            frete,
            if (produtos > 0)
              produtos == 1 ? '1 produto' : '$produtos produtos',
          ].join(' · ')
        : [loja.cidade, if (loja.horario.isNotEmpty) loja.horario].join(' · ');
    return Row(
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
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                detalhe,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
            ],
          ),
        ),
        const SizedBox(width: Espaco.s2),
        SeloAberta(aberta: loja.aberta),
      ],
    );
  }
}

class _ListaInteligente extends StatefulWidget {
  const _ListaInteligente({required this.compacta});
  final bool compacta;

  @override
  State<_ListaInteligente> createState() => _ListaInteligenteState();
}

class _ListaInteligenteState extends State<_ListaInteligente> {
  final _texto = TextEditingController();

  /// Lendo a lista de um PDF ou foto
  bool _lendo = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _cotar() {
    final texto = _texto.text;
    if (texto.trim().isEmpty) {
      avisar(context, 'Escreva ou cole a lista de materiais, um por linha.');
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SmartListScreen(texto: texto)),
    );
  }

  /// PDF ou foto com a lista: o servidor lê os materiais e a revisão da lista inteligente abre.
  Future<void> _anexar() async {
    final servico = LeituraListaService.instance;
    try {
      final arquivo = await servico.escolher();
      if (arquivo == null || !mounted) return;
      setState(() => _lendo = true);
      final texto = await servico.ler(arquivo);
      if (!mounted) return;
      _texto.text = texto;
      _cotar();
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _lendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final icone = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: c.destaqueSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.auto_awesome_outlined, color: c.acao),
    );
    final campo = TextField(
      controller: _texto,
      enabled: !_lendo,
      minLines: 1,
      maxLines: 5,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        hintText: _lendo
            ? 'Lendo o arquivo…'
            : 'Cole a lista ou anexe um PDF ou foto',
        suffixIcon: _lendo
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: 'Adicionar arquivo (PDF ou foto)',
                onPressed: _anexar,
                icon: const Icon(Icons.attach_file_rounded),
              ),
      ),
    );
    final botao = SizedBox(
      height: 48,
      child: FilledButton(
        key: const Key('cotar-agora'),
        onPressed: _cotar,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Espaco.s5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RaioReto(),
            SizedBox(width: Espaco.s2),
            Text('Cotar agora'),
          ],
        ),
      ),
    );
    return _Cartao(
      child: widget.compacta
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    icone,
                    const SizedBox(width: Espaco.s3),
                    Expanded(child: campo),
                  ],
                ),
                const SizedBox(height: Espaco.s3),
                botao,
              ],
            )
          : Row(
              children: [
                icone,
                const SizedBox(width: Espaco.s3),
                Expanded(child: campo),
                const SizedBox(width: Espaco.s3),
                botao,
              ],
            ),
    );
  }
}
