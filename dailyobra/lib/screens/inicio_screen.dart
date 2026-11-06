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
import 'categoria_screen.dart';
import 'componentes.dart';
import 'menu_da_conta.dart';
import 'obra_form_screen.dart';
import 'obra_screen.dart';
import 'pedido_screen.dart';
import 'proposta_screen.dart';
import 'smart_list_screen.dart';
import 'topo_vitrine.dart';
import 'vitrine_do_inicio.dart';

const _produtosPorPrateleira = 12;
const _produtosParaTerPrateleira = 2;
const _prateleirasDeCategoria = 6;
const _alturaDoCotar = 44.0;

/// Início: a loja, em fundo branco e uma coluna só em todas as telas. Depois do topo vêm a lista para cotar, a faixa da
/// obra, os avisos de propostas e pedidos, os banners, as categorias, as lojas e as prateleiras de produtos.
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
      backgroundColor: context.cores.superficie,
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
          final m = switch (formato) {
            Formato.celular => Espaco.s4,
            Formato.tablet => Espaco.s6,
            Formato.computador => Espaco.s8,
          };
          Widget? comMargem(Widget? bloco, {Key? key}) => bloco == null
              ? null
              : Padding(
                  key: key,
                  padding: EdgeInsets.symmetric(horizontal: m),
                  child: bloco,
                );
          return RefreshIndicator(
            color: context.cores.acao,
            onRefresh: _atualizar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: Espaco.s8),
              children: [
                // No computador a barra laranja é da moldura, acima de todas as abas
                if (formato != Formato.computador)
                  TopoVitrine(
                    compacto: formato == Formato.celular,
                    tema: tema,
                    onSino: onSino,
                  ),
                const SizedBox(height: Espaco.s4),
                _coluna([
                  if (erro != null) comMargem(Aviso(erro, tom: TomSelo.aviso)),
                  // Com chave, a lista digitada não se perde quando um aviso aparece acima
                  comMargem(
                    _ListaInteligente(compacta: formato == Formato.celular),
                    key: const ValueKey('lista-inteligente'),
                  ),
                  comMargem(v.obra()),
                  comMargem(v.contraproposta()),
                  comMargem(v.pedido()),
                  comMargem(v.banners()),
                  comMargem(v.categorias()),
                  v.lojas(m),
                  ...v.prateleiras(m),
                  comMargem(v.economia()),
                ], Espaco.s4),
              ],
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
  const _Cartao({required this.child, this.cor, this.borda, this.onTap});
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
    if (servico.obras == null) return const EsqueletoBrilho(altura: 44);
    final obra = servico.obraAtiva;
    if (obra == null) {
      return FaixaDaObra(
        texto: 'Cadastre sua obra e organize o dia a dia',
        aoTocar: () => _abrir(const ObraFormScreen()),
      );
    }
    final etapas =
        Calculo.de(obra.parametros).resultado?.etapas ??
        const <LinhaResultado>[];
    final resumo = resumirCronograma(
      etapas: [for (final e in etapas) e.etapa],
      datas: obra.cronograma,
      status: obra.statusEtapas,
      hoje: hoje,
    );
    final alerta = alertaDaObra(resumo, obra.pendenciasVencidas(hoje));
    final percentual = progresso(etapas, obra.statusEtapas);
    return FaixaDaObra(
      texto: alerta ?? '${obra.nome}: $percentual% concluída',
      alerta: alerta != null,
      aoTocar: () => _abrir(ObraScreen(id: obra.id)),
    );
  }

  Widget economia() {
    final eco = EconomiaService.instance;
    if (!eco.carregado) {
      if (eco.erro == null) return const EsqueletoBrilho(altura: 132);
      return _Cartao(
        onTap: () => abrirCarteira(context),
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
      onTap: () => abrirCarteira(context),
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

  Widget? categorias() {
    final categorias = CatalogoService.instance.categorias;
    if (categorias.isEmpty) return null;
    return GradeDeCategorias(categorias: categorias);
  }

  Widget banners() {
    final lojas = CatalogoService.instance.lojas
        .where((l) => l.bannerUrl != null)
        .toList();
    final anuncios = CatalogoService.instance.bannersPagos(hoje);
    return CarrosselDeBanners(
      key: ValueKey('${lojas.length}-${anuncios.length}'),
      lojas: lojas,
      anuncios: anuncios,
    );
  }

  Widget? _ofertas(double m) {
    final promocoes = CatalogoService.instance.ofertasEmPromocao(hoje);
    if (promocoes.isEmpty) return null;
    return Prateleira(
      titulo: 'Ofertas do dia',
      margem: m,
      emFaixa: true,
      produtos: [
        for (final (oferta, item, loja) in promocoes.take(
          _produtosPorPrateleira,
        ))
          ProdutoDaPrateleira(
            item: item,
            preco: oferta.precoVigente(hoje)!,
            precoCheio: oferta.preco,
            rodape: loja.nome,
            loja: loja,
          ),
      ],
    );
  }

  Widget? _maisBarato(double m, {required bool emFaixa}) {
    final catalogo = CatalogoService.instance;
    final faixas = maisBaratoHoje(
      itens: catalogo.itens,
      ofertas: catalogo.ofertas,
      lojas: catalogo.lojaPorId,
      hoje: hoje,
      noOrcamento: {for (final i in CarrinhoService.instance.itens) i.itemId},
      limite: _produtosPorPrateleira,
    );
    if (faixas.isEmpty) return null;
    return Prateleira(
      key: const Key('mais-barato'),
      titulo: 'Mais barato hoje',
      margem: m,
      emFaixa: emFaixa,
      produtos: [
        for (final f in faixas)
          ProdutoDaPrateleira(
            item: f.item,
            preco: f.menor,
            rodape: 'até ${brl.format(f.maior)}',
            loja: catalogo.loja(f.melhor.lojaId),
          ),
      ],
    );
  }

  /// A faixa laranja e a página branca se alternam, começando pela laranja.
  List<Widget> prateleiras(double m) {
    final catalogo = CatalogoService.instance;
    final blocos = <Widget>[];
    final ofertas = _ofertas(m);
    if (ofertas != null) blocos.add(ofertas);
    final barato = _maisBarato(m, emFaixa: blocos.length.isEven);
    if (barato != null) blocos.add(barato);
    var deCategoria = 0;
    for (final categoria in catalogo.categorias) {
      if (deCategoria == _prateleirasDeCategoria) break;
      final produtos = catalogo.produtosDaPrateleira(
        categoria.id,
        hoje: hoje,
        limite: _produtosPorPrateleira,
      );
      if (produtos.length < _produtosParaTerPrateleira) continue;
      deCategoria++;
      blocos.add(
        Prateleira(
          titulo: 'Melhores preços em ${categoria.nome}',
          margem: m,
          emFaixa: blocos.length.isEven,
          aoVerMais: () => _abrir(
            CategoriaScreen(categoriaId: categoria.id, titulo: categoria.nome),
          ),
          produtos: [
            for (final p in produtos)
              ProdutoDaPrateleira(
                item: p.item,
                preco: p.oferta.precoVigente(hoje)!,
                precoCheio: p.oferta.emPromocao(hoje) ? p.oferta.preco : null,
                rodape: p.lojas > 1
                    ? 'em ${p.lojas} lojas'
                    : catalogo.loja(p.oferta.lojaId)?.nome ?? '',
                loja: catalogo.loja(p.oferta.lojaId),
              ),
          ],
        ),
      );
    }
    return blocos;
  }

  Widget lojas(double m) {
    final catalogo = CatalogoService.instance;
    final perfil = PerfilService.instance;
    final lojas = catalogo.lojas;
    if (lojas.isEmpty) {
      return Padding(
        key: const Key('lojas-perto'),
        padding: EdgeInsets.symmetric(horizontal: m),
        child: const EstadoVazio(
          icone: Icons.storefront_outlined,
          titulo: 'Ainda não há lojas na sua cidade',
          texto:
              'Assim que as lojas da região entrarem no DailyObra, os preços e as ofertas aparecem aqui. '
              'Você já pode montar o orçamento pela lista inteligente.',
        ),
      );
    }
    final daCidade = lojas.where(catalogo.lojaDaMinhaCidade).length;
    return TrilhoDeLojas(
      key: const Key('lojas-perto'),
      lojas: lojas,
      margem: m,
      aviso: perfil.cidade != null && daCidade == 0
          ? 'Ainda não há lojas em ${perfil.cidade}. Veja as de outras cidades.'
          : null,
      produtosDaLoja: (loja) =>
          catalogo.ofertasDaLoja(loja.id, hoje: hoje).length,
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
    final campo = TextField(
      controller: _texto,
      enabled: !_lendo,
      minLines: 1,
      maxLines: 5,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        // Sem isso o campo tem no mínimo 48 de altura e empurra o botão para baixo
        isDense: true,
        constraints: const BoxConstraints(minHeight: _alturaDoCotar),
        hintText: _lendo
            ? 'Lendo o arquivo…'
            : widget.compacta
            ? 'Cole a lista ou anexe'
            : 'Cole a lista ou anexe um PDF ou foto',
        hintMaxLines: 1,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(Espaco.s4, 10, Espaco.s1, 10),
      ),
    );
    final anexo = _lendo
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : IconButton(
            tooltip: 'Adicionar arquivo (PDF ou foto)',
            onPressed: _anexar,
            constraints: const BoxConstraints.tightFor(
              width: _alturaDoCotar,
              height: _alturaDoCotar,
            ),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.attach_file_rounded),
          );
    final botao = SizedBox(
      height: _alturaDoCotar,
      child: FilledButton(
        key: const Key('cotar-agora'),
        onPressed: _cotar,
        style: FilledButton.styleFrom(
          backgroundColor: c.topo,
          foregroundColor: c.textoSobreTopo,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Raio.md),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const RaioReto(tamanho: 16),
            const SizedBox(width: Espaco.s1),
            Text(widget.compacta ? 'Cotar' : 'Cotar agora'),
          ],
        ),
      ),
    );
    // Uma barra só, como a de busca: o botão fica embaixo quando a lista colada cresce
    return Container(
      key: const Key('barra-de-cotar'),
      padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: c.superficieSutil,
        borderRadius: BorderRadius.circular(Raio.lg),
        border: Border.all(color: c.borda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: campo),
          anexo,
          botao,
        ],
      ),
    );
  }
}
