import 'dart:async';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'busca_screen.dart';
import 'categoria_screen.dart';
import 'componentes.dart';
import 'loja_screen.dart';

const _casasNaGrade = 10;
const _casasPorLinhaNoCelular = 5;
const _larguraDaLinhaUnica = 720.0;
const _bannersDeLojas = 5;
const _bannersDaMarca = 3;
const _tempoDoBanner = Duration(seconds: 6);

void _abrir(BuildContext context, Widget tela) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => tela));

/// A porta do catálogo: cada categoria a um toque. Com mais do que cabe nas duas linhas, a última casa leva a todas.
class GradeDeCategorias extends StatelessWidget {
  const GradeDeCategorias({super.key, required this.categorias});
  final List<Categoria> categorias;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final brilho = Theme.of(context).brightness;
    final sobra = categorias.length > _casasNaGrade;
    final casas = <Widget>[
      for (final categoria in categorias.take(
        sobra ? _casasNaGrade - 1 : _casasNaGrade,
      ))
        _Casa(
          icone: iconeDaCategoria(categoria.id),
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
          aoTocar: () => _abrir(context, const BuscaScreen()),
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
                      color: cor.fundo,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icone, color: cor.icone, size: 30),
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

/// Faixa fina no alto do Início: como a obra está e o caminho até a aba Obras.
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
        aoTocar: () => _abrir(context, const BuscaScreen()),
      ),
      _SlideDaMarca(
        titulo: 'Cashback em cada pedido',
        texto: 'Feche o pedido pelo app e o saldo entra no Clube DailyObra.',
        botao: 'Ver carteira',
        icone: Icons.account_balance_wallet_outlined,
        fundo: c.acao,
        corDoTexto: c.textoSobreAcao,
        aoTocar: () => irParaAba(context, Aba.carteira),
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
