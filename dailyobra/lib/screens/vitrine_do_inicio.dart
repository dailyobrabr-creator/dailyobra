import 'dart:async';
import 'dart:math' as math;

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'categoria_screen.dart';
import 'componentes.dart';
import 'loja_screen.dart';
import 'menu_da_conta.dart';
import 'produto_screen.dart';

const _casasNaGrade = 10;
const _casasPorLinhaNoCelular = 5;
const _larguraDaLinhaUnica = 720.0;
const _bannersDeLojas = 5;
const _bannersDaMarca = 3;
const _tempoDoBanner = Duration(seconds: 6);
const _larguraDoProduto = 148.0;
const _larguraDoProdutoGrande = 176.0;
const _alturaDaFoto = 128.0;
const _raioDoProduto = 14.0;
const _larguraDaLoja = 132.0;
const _logoDoProduto = 34.0;

void _abrir(BuildContext context, Widget tela) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => tela));

/// A porta do catálogo: cada categoria a um toque. Com mais do que cabe nas duas linhas, a última casa leva à aba Busca,
/// que mostra [todas].
class GradeDeCategorias extends StatelessWidget {
  const GradeDeCategorias({
    super.key,
    required this.categorias,
    this.todas = false,
  });
  final List<Categoria> categorias;
  final bool todas;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final brilho = Theme.of(context).brightness;
    final sobra = !todas && categorias.length > _casasNaGrade;
    final casas = <Widget>[
      for (final categoria
          in sobra ? categorias.take(_casasNaGrade - 1) : categorias)
        _Casa(
          icone: _iconeCheio(categoria.id),
          rotulo: categoria.nome,
          cor: coresDaCategoria(categoria.id, brilho),
          aoTocar: () => _abrir(
            context,
            CategoriaScreen(categoriaId: categoria.id, titulo: categoria.nome),
          ),
        ),
      if (sobra)
        _Casa(
          icone: Icons.grid_view_rounded,
          rotulo: 'Ver mais',
          cor: CorCategoria(c.superficieSutil, c.textoSuave),
          aoTocar: () => irParaAba(context, Aba.busca),
        ),
    ];
    return LayoutBuilder(
      builder: (context, espaco) {
        final porLinha = espaco.maxWidth >= _larguraDaLinhaUnica
            ? _casasNaGrade
            : _casasPorLinhaNoCelular;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < casas.length; i += porLinha)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = i; j < i + porLinha; j++)
                    Expanded(
                      child: j < casas.length ? casas[j] : const SizedBox(),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Quadro cinza claro com o ícone da categoria em destaque e o nome embaixo.
class _Casa extends StatelessWidget {
  const _Casa({
    required this.icone,
    required this.rotulo,
    required this.cor,
    required this.aoTocar,
  });
  final IconData icone;
  final String rotulo;
  final CorCategoria cor;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final texto = Text(
      rotulo,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.15),
    );
    return Semantics(
      button: true,
      label: rotulo,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Raio.md),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.superficieSutil,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(cor.icone, Colors.white, 0.3)!,
                          cor.icone,
                        ],
                      ).createShader,
                      child: Icon(
                        icone,
                        color: Colors.white,
                        size: 34,
                        shadows: const [
                          Shadow(
                            color: Color(0x40000000),
                            offset: Offset(0, 2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Palavra única encolhe um pouco em vez de quebrar antes da última letra
              if (rotulo.contains(' '))
                texto
              else
                FittedBox(fit: BoxFit.scaleDown, child: texto),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faixa fina no alto do Início: como a obra está e o caminho até ela.
class FaixaDaObra extends StatelessWidget {
  const FaixaDaObra({
    super.key,
    required this.texto,
    required this.aoTocar,
    this.alerta = false,
  });
  final String texto;
  final VoidCallback aoTocar;

  /// A obra pede atenção: a faixa fica vermelha.
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final cor = alerta ? c.erro : c.acao;
    return Material(
      color: alerta ? c.hachuraVermelha : c.destaqueSuave,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaco.s4,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                alerta ? Icons.warning_amber : Icons.home_work_outlined,
                color: cor,
                size: 20,
              ),
              const SizedBox(width: Espaco.s2),
              Expanded(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: cor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banners do Início: primeiro as campanhas das lojas, que chegam como a loja subiu, depois os do DailyObra.
/// Passa sozinho, menos para quem pediu ao aparelho para reduzir o movimento.
class CarrosselDeBanners extends StatefulWidget {
  const CarrosselDeBanners({super.key, required this.lojas});

  /// Lojas com banner, na ordem de mostrar.
  final List<Loja> lojas;

  @override
  State<CarrosselDeBanners> createState() => _CarrosselDeBannersState();
}

class _CarrosselDeBannersState extends State<CarrosselDeBanners> {
  final _paginas = PageController();
  Timer? _relogio;
  var _atual = 0;

  List<Loja> get _lojas => widget.lojas.take(_bannersDeLojas).toList();
  int get _total => _lojas.length + _bannersDaMarca;

  @override
  void initState() {
    super.initState();
    _ligarRelogio();
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _paginas.dispose();
    super.dispose();
  }

  void _ligarRelogio() {
    _relogio?.cancel();
    _relogio = Timer.periodic(_tempoDoBanner, (_) => _avancar());
  }

  void _avancar() {
    if (!mounted || !_paginas.hasClients) return;
    // Em outra aba o Início fica montado, sem aparecer
    if (!TickerMode.valuesOf(context).enabled) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _irPara((_atual + 1) % _total);
  }

  void _irPara(int pagina) {
    _paginas.animateToPage(
      pagina,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  List<Widget> _slides(BuildContext context) {
    final c = context.cores;
    return [
      for (final loja in _lojas) _SlideDaLoja(loja: loja),
      _SlideDaMarca(
        titulo: 'Sua obra inteira em um só lugar',
        texto: 'Diário, cronograma, gastos e equipe na aba Obras.',
        botao: 'Abrir Obras',
        icone: Icons.home_work_outlined,
        fundo: c.topo,
        corDoTexto: c.textoSobreTopo,
        aoTocar: () => irParaAba(context, Aba.obras),
      ),
      _SlideDaMarca(
        titulo: 'Compare antes de comprar',
        texto: 'Veja quanto cada loja cobra pelo mesmo material.',
        botao: 'Buscar material',
        icone: Icons.search,
        fundo: c.destaqueSuave,
        corDoTexto: c.texto,
        aoTocar: () => irParaAba(context, Aba.busca),
      ),
      _SlideDaMarca(
        titulo: 'Cashback em cada pedido',
        texto: 'Feche o pedido pelo app e o saldo entra no Clube DailyObra.',
        botao: 'Ver carteira',
        icone: Icons.account_balance_wallet_outlined,
        fundo: c.acao,
        corDoTexto: c.textoSobreAcao,
        aoTocar: () => abrirCarteira(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return LayoutBuilder(
      builder: (context, espaco) {
        final altura = (espaco.maxWidth / 1.45).clamp(210.0, 260.0);
        return Container(
          height: altura,
          padding: const EdgeInsets.fromLTRB(
            Espaco.s2,
            Espaco.s2,
            Espaco.s2,
            0,
          ),
          decoration: BoxDecoration(
            color: c.cartaoEscuro,
            borderRadius: BorderRadius.circular(Raio.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Raio.md),
                  child: ScrollConfiguration(
                    // No site o banner também passa arrastando com o mouse
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                    child: PageView(
                      controller: _paginas,
                      onPageChanged: (pagina) {
                        setState(() => _atual = pagina);
                        _ligarRelogio();
                      },
                      children: _slides(context),
                    ),
                  ),
                ),
              ),
              _Marcas(total: _total, atual: _atual, aoTocar: _irPara),
            ],
          ),
        );
      },
    );
  }
}

/// Um traço por banner, sem número: mostra onde a pessoa está e deixa pular.
class _Marcas extends StatelessWidget {
  const _Marcas({
    required this.total,
    required this.atual,
    required this.aoTocar,
  });
  final int total;
  final int atual;
  final ValueChanged<int> aoTocar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == atual,
                label: 'Banner ${i + 1} de $total',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => aoTocar(i),
                  child: Center(
                    child: AnimatedContainer(
                      key: Key('marca-$i'),
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: i == atual ? 1 : 0.28,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlideDaLoja extends StatelessWidget {
  const _SlideDaLoja({required this.loja});
  final Loja loja;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Campanha de ${loja.nome}',
      excludeSemantics: true,
      child: Material(
        color: c.cartaoEscuro,
        child: InkWell(
          onTap: () => _abrir(context, LojaScreen(lojaId: loja.id)),
          // A proporção é a que a loja subiu: o banner aparece inteiro, sem corte
          child: Image.network(
            loja.bannerUrl!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => Center(
              child: Text(
                loja.nome,
                style: t.titleLarge?.copyWith(
                  color: c.textoCartaoEscuro,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideDaMarca extends StatelessWidget {
  const _SlideDaMarca({
    required this.titulo,
    required this.texto,
    required this.botao,
    required this.icone,
    required this.fundo,
    required this.corDoTexto,
    required this.aoTocar,
  });
  final String titulo;
  final String texto;
  final String botao;
  final IconData icone;
  final Color fundo;
  final Color corDoTexto;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$titulo. $texto $botao',
      excludeSemantics: true,
      child: Material(
        color: fundo,
        child: InkWell(
          onTap: aoTocar,
          child: LayoutBuilder(
            builder: (context, espaco) => Stack(
              children: [
                Positioned(
                  right: -espaco.maxHeight * 0.12,
                  bottom: -espaco.maxHeight * 0.14,
                  child: Icon(
                    icone,
                    size: espaco.maxHeight * 0.92,
                    color: corDoTexto.withValues(alpha: 0.13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.headlineSmall?.copyWith(
                            color: corDoTexto,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                        ),
                      ),
                      const SizedBox(height: Espaco.s1),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          texto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyMedium?.copyWith(color: corDoTexto),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Espaco.s4,
                          vertical: Espaco.s2,
                        ),
                        decoration: BoxDecoration(
                          color: corDoTexto,
                          borderRadius: BorderRadius.circular(Raio.md),
                        ),
                        child: Text(
                          botao,
                          style: t.labelLarge?.copyWith(
                            color: fundo,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

/// Ícone cheio da categoria: na vitrine ele pesa mais que o de traço do resto do app.
IconData _iconeCheio(String categoriaId) => switch (categoriaId) {
  'basico' => Icons.foundation,
  'estrutura' => Icons.view_column,
  'alvenaria' => Icons.view_quilt,
  'cobertura' => Icons.roofing,
  'hidraulica' => Icons.water_drop,
  'eletrica' => Icons.bolt,
  'acabamento' => Icons.grid_on,
  'pintura' => Icons.format_paint,
  'loucas-metais' => Icons.bathtub,
  'ferramentas' => Icons.handyman,
  _ => Icons.construction,
};

/// Um produto na prateleira do Início.
class ProdutoDaPrateleira {
  const ProdutoDaPrateleira({
    required this.item,
    required this.preco,
    this.precoCheio,
    this.rodape = '',
    this.loja,
  });
  final ItemCatalogo item;
  final double preco;

  /// Loja do preço mostrado: a logo dela fica no canto do cartão.
  final Loja? loja;

  /// Preço sem a promoção, riscado ao lado do que vale hoje.
  final double? precoCheio;

  /// Linha pequena embaixo do preço: a loja, em quantas lojas ou a faixa de preços.
  final String rodape;
}

/// Título de prateleira no tamanho da vitrine, com "Ver mais" à direita.
class _TituloDaPrateleira extends StatelessWidget {
  const _TituloDaPrateleira({
    required this.titulo,
    required this.cor,
    this.corDaAcao,
    this.aoVerMais,
  });
  final String titulo;
  final Color cor;
  final Color? corDaAcao;
  final VoidCallback? aoVerMais;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleLarge?.copyWith(
                color: cor,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
        if (aoVerMais != null)
          TextButton(
            onPressed: aoVerMais,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: Espaco.s2),
            ),
            child: Text(
              'Ver mais',
              style: t.labelLarge?.copyWith(
                color: corDaAcao,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// Fileira de produtos que corre de lado. [emFaixa] pinta a faixa laranja de ponta a ponta, com os produtos em cartões
/// brancos; sem ela, os produtos ficam soltos no fundo da página. Nas telas maiores uma seta passa para os próximos.
class Prateleira extends StatefulWidget {
  const Prateleira({
    super.key,
    required this.titulo,
    required this.produtos,
    required this.margem,
    this.emFaixa = false,
    this.aoVerMais,
  });
  final String titulo;
  final List<ProdutoDaPrateleira> produtos;

  /// Distância até a borda da tela, a mesma dos outros blocos.
  final double margem;
  final bool emFaixa;
  final VoidCallback? aoVerMais;

  @override
  State<Prateleira> createState() => _PrateleiraState();
}

class _PrateleiraState extends State<Prateleira> {
  final _rolagem = ScrollController();

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  void _avancar(double largura) {
    final fim = _rolagem.position.maxScrollExtent;
    final destino = _rolagem.offset >= fim - 1
        ? 0.0
        : math.min(_rolagem.offset + largura * 0.8, fim);
    _rolagem.animateTo(
      destino,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final emFaixa = widget.emFaixa;
    final celular = formatoDoContexto(context) == Formato.celular;
    final largura = celular ? _larguraDoProduto : _larguraDoProdutoGrande;
    final escala = MediaQuery.textScalerOf(context).scale(1);
    final comDesconto = widget.produtos.any((p) => p.precoCheio != null);
    final altura = _alturaDaFoto + 24 + (comDesconto ? 118.0 : 92.0) * escala;
    final corDoTitulo = emFaixa ? c.textoSobreTopo : c.texto;
    final total = widget.produtos.length * (largura + Espaco.s3);
    final conteudo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.margem),
          child: _TituloDaPrateleira(
            titulo: widget.titulo,
            cor: corDoTitulo,
            corDaAcao: emFaixa ? c.textoSobreTopo : c.acao,
            aoVerMais: widget.aoVerMais,
          ),
        ),
        const SizedBox(height: Espaco.s3),
        SizedBox(
          height: altura,
          child: LayoutBuilder(
            builder: (context, espaco) => Stack(
              children: [
                ScrollConfiguration(
                  // No site a prateleira também corre arrastando com o mouse
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                  child: ListView.separated(
                    controller: _rolagem,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: widget.margem),
                    itemCount: widget.produtos.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: Espaco.s3),
                    itemBuilder: (context, i) => _CartaoDaPrateleira(
                      produto: widget.produtos[i],
                      largura: largura,
                      emFaixa: emFaixa,
                    ),
                  ),
                ),
                if (!celular && total + widget.margem * 2 > espaco.maxWidth)
                  Positioned(
                    right: Espaco.s2,
                    top: _alturaDaFoto / 2 - 22,
                    child: _Seta(aoTocar: () => _avancar(espaco.maxWidth)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    if (!emFaixa) return conteudo;
    return ColoredBox(
      color: c.topo,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espaco.s4),
        child: conteudo,
      ),
    );
  }
}

class _Seta extends StatelessWidget {
  const _Seta({required this.aoTocar});
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Material(
      color: c.superficie,
      elevation: 2,
      shape: CircleBorder(side: BorderSide(color: c.borda)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Tooltip(
          message: 'Ver mais produtos',
          child: SizedBox.square(
            dimension: 44,
            child: Icon(Icons.chevron_right, color: c.texto),
          ),
        ),
      ),
    );
  }
}

/// Foto inteira do produto, sem corte. Sem foto, o ícone da categoria (o app não inventa foto de produto).
class _FotoDaPrateleira extends StatelessWidget {
  const _FotoDaPrateleira({required this.item, required this.emFaixa});
  final ItemCatalogo item;
  final bool emFaixa;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final brilho = Theme.of(context).brightness;
    final cor = coresDaCategoria(item.categoriaId, brilho);
    final icone = ColoredBox(
      color: c.superficieSutil,
      child: Center(
        child: Icon(_iconeCheio(item.categoriaId), size: 44, color: cor.icone),
      ),
    );
    if (item.imagemUrl == null) return icone;
    // No claro o branco da foto some no cinza do quadro; no escuro a foto fica num quadro branco
    final naFaixaOuEscuro = emFaixa || brilho == Brightness.dark;
    return ColoredBox(
      color: naFaixaOuEscuro ? Colors.white : c.superficieSutil,
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s2),
        child: Image.network(
          item.imagemUrl!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          color: naFaixaOuEscuro ? null : c.superficieSutil,
          colorBlendMode: naFaixaOuEscuro ? null : BlendMode.multiply,
          semanticLabel: item.nome,
          errorBuilder: (_, _, _) => icone,
        ),
      ),
    );
  }
}

/// R$ pequeno, reais grandes e centavos pequenos no alto, como nas lojas online.
class _Preco extends StatelessWidget {
  const _Preco(this.valor);
  final double valor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final partes = brl
        .format(valor)
        .replaceAll(RegExp(r'[^\d.,]'), '')
        .split(',');
    final pequeno = t.labelSmall?.copyWith(
      color: c.texto,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: numerosTabulares,
    );
    return Semantics(
      label: brl.format(valor),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('R\$', style: pequeno),
          const SizedBox(width: 2),
          Text(
            partes.first,
            style: t.titleLarge?.copyWith(
              color: c.texto,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
              fontFeatures: numerosTabulares,
            ),
          ),
          const SizedBox(width: 1),
          if (partes.length > 1) Text(partes.last, style: pequeno),
        ],
      ),
    );
  }
}

class _CartaoDaPrateleira extends StatelessWidget {
  const _CartaoDaPrateleira({
    required this.produto,
    required this.largura,
    required this.emFaixa,
  });
  final ProdutoDaPrateleira produto;
  final double largura;
  final bool emFaixa;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final item = produto.item;
    final cheio = produto.precoCheio;
    final desconto = cheio == null || cheio <= 0
        ? 0
        : ((1 - produto.preco / cheio) * 100).round();
    final escala = MediaQuery.textScalerOf(context).scale(1);
    final foto = SizedBox(
      height: _alturaDaFoto,
      child: _FotoDaPrateleira(item: item, emFaixa: emFaixa),
    );
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34 * escala,
          child: Text(
            item.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: Espaco.s1),
        if (desconto > 0) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.acao,
                  borderRadius: BorderRadius.circular(Raio.sm),
                ),
                child: Text(
                  '$desconto% off',
                  style: t.labelSmall?.copyWith(
                    color: c.textoSobreAcao,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: Espaco.s1),
              Flexible(
                child: Text(
                  'Oferta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSmall?.copyWith(
                    color: c.acao,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espaco.s1),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _Preco(produto.preco),
                        if (desconto > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            brl.format(cheio),
                            style: t.bodySmall?.copyWith(
                              color: c.textoSuave,
                              decoration: TextDecoration.lineThrough,
                              fontFeatures: numerosTabulares,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (produto.rodape.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      produto.rodape,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(
                        color: c.textoSuave,
                        fontFeatures: numerosTabulares,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (produto.loja != null) ...[
              const SizedBox(width: Espaco.s1),
              LogoLoja(loja: produto.loja!, tamanho: _logoDoProduto),
            ],
          ],
        ),
      ],
    );
    void abrir() => _abrir(context, ProdutoScreen(itemId: item.id));
    final Widget cartao;
    if (emFaixa) {
      cartao = Material(
        color: c.superficie,
        borderRadius: BorderRadius.circular(_raioDoProduto),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: abrir,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              foto,
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: texto,
              ),
            ],
          ),
        ),
      );
    } else {
      cartao = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(_raioDoProduto),
          onTap: abrir,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_raioDoProduto),
                child: foto,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                child: texto,
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(width: largura, child: cartao);
  }
}

/// As lojas em cartões cinza que correm de lado, com a logo redonda no alto.
class TrilhoDeLojas extends StatelessWidget {
  const TrilhoDeLojas({
    super.key,
    required this.lojas,
    required this.produtosDaLoja,
    required this.margem,
    this.aviso,
  });
  final List<Loja> lojas;
  final int Function(Loja) produtosDaLoja;
  final double margem;

  /// Texto acima das lojas, como "Ainda não há lojas na sua cidade".
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final escala = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margem),
          child: _TituloDaPrateleira(titulo: 'Lojas perto', cor: c.texto),
        ),
        if (aviso != null)
          Padding(
            padding: EdgeInsets.fromLTRB(margem, Espaco.s2, margem, 0),
            child: Aviso(aviso!, tom: TomSelo.info),
          ),
        const SizedBox(height: Espaco.s3),
        SizedBox(
          height: 92 + 84 * escala,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: margem),
              itemCount: lojas.length,
              separatorBuilder: (_, _) => const SizedBox(width: Espaco.s3),
              itemBuilder: (context, i) => _CartaoDaLoja(
                loja: lojas[i],
                produtos: produtosDaLoja(lojas[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartaoDaLoja extends StatelessWidget {
  const _CartaoDaLoja({required this.loja, required this.produtos});
  final Loja loja;
  final int produtos;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final detalhe = [
      textoFrete(loja),
      produtos == 0
          ? 'ainda sem preços'
          : produtos == 1
          ? '1 produto'
          : '$produtos produtos',
    ].join(' · ');
    return SizedBox(
      width: _larguraDaLoja,
      child: Material(
        color: c.superficieSutil,
        borderRadius: BorderRadius.circular(Raio.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _abrir(context, LojaScreen(lojaId: loja.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s2,
              Espaco.s3,
              Espaco.s2,
              Espaco.s2,
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: Espaco.s2),
                      child: LogoLoja(loja: loja, tamanho: 64),
                    ),
                    SeloSituacao(
                      situacao: situacaoDaLoja(loja, DateTime.now()),
                    ),
                  ],
                ),
                const SizedBox(height: Espaco.s1),
                Text(
                  loja.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalhe,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: c.textoSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
