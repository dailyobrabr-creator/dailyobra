import 'package:flutter/material.dart';

import '../marketplace/horario.dart';
import '../marketplace/modelos.dart';
import '../tema/categorias.dart';
import '../tema/cores.dart';
import '../tema/tema.dart';
import 'marketplace_ui.dart';
import 'ui.dart';

/// Cor fixa de cada loja (pelo id), usada na capa sem foto e no fundo das iniciais.
/// Todas passam de 4,5:1 com texto branco.
Color corDaLoja(String lojaId) {
  const cores = [Color(0xFFA43F05), Color(0xFF1D4ED8), Color(0xFF166534), Color(0xFF4C2F94), Color(0xFF0F5F5F), Color(0xFF535965)];
  var h = 0;
  for (final c in lojaId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return cores[h % cores.length];
}

/// Título de seção da vitrine com a ação "Ver todas" à direita.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.acao, this.onAcao, this.margem = const EdgeInsets.only(top: Espaco.s6, bottom: Espaco.s3)});
  final String texto;
  final String? acao;
  final VoidCallback? onAcao;
  final EdgeInsets margem;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: margem,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(texto, style: t.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700))),
          if (acao != null)
            TextButton(
              onPressed: onAcao,
              style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: Espaco.s2)),
              child: Text(acao!, style: t.labelLarge?.copyWith(color: context.cores.acao, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Oferta na vitrine: quadro da categoria (ou foto), selo de desconto, nome em duas linhas,
/// loja e preço (o antigo riscado em cima). Todos têm a mesma altura para alinhar em linha.
class CartaoOferta extends StatelessWidget {
  const CartaoOferta({super.key, required this.item, required this.oferta, required this.hoje, this.nomeLoja, this.onTap, this.largura});
  final ItemCatalogo item;

  /// Sem oferta, o cartão mostra o preço de referência do item (ex.: SINAPI) ou "Sem oferta no momento".
  final Oferta? oferta;
  final DateTime hoje;
  final String? nomeLoja;
  final VoidCallback? onTap;
  final double? largura;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final cor = coresDaCategoria(item.categoriaId, Theme.of(context).brightness);
    final oferta = this.oferta;
    final promo = oferta?.emPromocao(hoje) ?? false;
    final vigente = oferta == null ? null : oferta.precoVigente(hoje) ?? oferta.preco;
    final desconto = promo ? ((1 - vigente! / oferta!.preco) * 100).round() : 0;
    // Sem oferta, o preço de referência do item (ex.: SINAPI) entra no lugar do aviso, em cor suave
    final referencia = vigente == null ? item.precoReferencia : null;
    final estiloNome = t.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.3);
    final alturaNome = MediaQuery.textScalerOf(context).scale(estiloNome?.fontSize ?? 14) * 1.3 * 2;
    final icone = Icon(iconeDaCategoria(item.categoriaId), size: 40, color: cor.icone);
    final cartao = Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg), side: BorderSide(color: c.borda)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: cor.fundo,
                    child: item.imagemUrl == null
                        ? Center(child: icone)
                        : Image.network(item.imagemUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: icone)),
                  ),
                  if (desconto > 0)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: c.acao, borderRadius: BorderRadius.circular(8)),
                        child: Text('-$desconto%', style: t.labelSmall?.copyWith(color: c.textoSobreAcao, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: alturaNome,
                    child: Text(item.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: estiloNome),
                  ),
                  Text(nomeLoja ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.textoSuave)),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    promo ? brl.format(oferta!.preco) : referencia != null ? 'Referência ${item.fonteReferencia ?? ''}'.trim() : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: c.textoSuave, decoration: promo ? TextDecoration.lineThrough : null, fontFeatures: numerosTabulares),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      vigente != null ? brl.format(vigente) : referencia != null ? brl.format(referencia) : 'Sem oferta no momento',
                      style: t.titleMedium?.copyWith(color: vigente == null ? c.textoSuave : c.acao, fontWeight: FontWeight.w700, fontFeatures: numerosTabulares),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return largura == null ? cartao : SizedBox(width: largura, child: cartao);
  }
}

/// Categoria do catálogo: horizontal (ícone ao lado, computador) ou vertical (ícone em cima).
class TileCategoria extends StatelessWidget {
  const TileCategoria({super.key, required this.categoria, required this.horizontal, this.onTap});
  final Categoria categoria;
  final bool horizontal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final cor = coresDaCategoria(categoria.id, Theme.of(context).brightness);
    final tamanho = horizontal ? 40.0 : 48.0;
    final icone = Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: cor.fundo, borderRadius: BorderRadius.circular(12)),
      child: Icon(iconeDaCategoria(categoria.id), color: cor.icone, size: horizontal ? 21 : 24),
    );
    final nome = Text(
      categoria.nome,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: (horizontal ? t.bodyMedium : t.bodySmall)?.copyWith(fontWeight: horizontal ? FontWeight.w600 : FontWeight.w500, height: 1.2),
    );
    return Semantics(
      button: true,
      label: categoria.nome,
      excludeSemantics: true,
      child: Material(
        color: c.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.borda)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: horizontal ? const EdgeInsets.all(10) : const EdgeInsets.fromLTRB(6, 12, 6, 10),
            child: horizontal
                ? Row(children: [icone, const SizedBox(width: 10), Expanded(child: nome)])
                : Column(mainAxisSize: MainAxisSize.min, children: [icone, const SizedBox(height: 6), nome]),
          ),
        ),
      ),
    );
  }
}

/// Marca oficial: o mesmo logo nos dois temas (texto grafite no claro, texto claro no escuro),
/// ou só o símbolo (trilho do tablet, tela de abertura).
class MarcaDailyObra extends StatelessWidget {
  const MarcaDailyObra({super.key, required this.soSimbolo, this.altura = 30});
  final bool soSimbolo;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    Image imagem(String nome, double h) => Image.asset('assets/marca/$nome', package: 'dailyobra_comum', height: h, semanticLabel: 'DailyObra');
    if (soSimbolo) return imagem(escuro ? 'simbolo_claro.png' : 'simbolo.png', altura);
    return imagem(escuro ? 'logo_tela_claro.png' : 'logo_tela.png', altura);
  }
}

/// Bloco de carregamento com brilho passando.
class EsqueletoBrilho extends StatefulWidget {
  const EsqueletoBrilho({super.key, this.altura = 120, this.largura, this.raio = Raio.lg});
  final double altura;
  final double? largura;
  final double raio;

  @override
  State<EsqueletoBrilho> createState() => _EsqueletoBrilhoState();
}

class _EsqueletoBrilhoState extends State<EsqueletoBrilho> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final x = _anim.value * 3 - 1;
        return Container(
          height: widget.altura,
          width: widget.largura,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.raio),
            border: Border.all(color: c.borda),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [c.superficie, c.superficieSutil, c.superficie],
            ),
          ),
        );
      },
    );
  }
}

/// Barras dos últimos meses; o último (o mês atual) em laranja.
class GraficoMeses extends StatelessWidget {
  const GraficoMeses({super.key, required this.meses});
  final List<(String, double)> meses;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final maior = meses.fold<double>(0, (m, e) => e.$2 > m ? e.$2 : m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < meses.length; i++) ...[
          if (i > 0) const SizedBox(width: Espaco.s2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: maior <= 0 ? 0.06 : (meses[i].$2 / maior).clamp(0.06, 1.0),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 28),
                        decoration: BoxDecoration(
                          color: i == meses.length - 1 ? c.topo : c.segPrevista,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(3)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Espaco.s1),
                Text(
                  meses[i].$1,
                  maxLines: 1,
                  style: t.labelSmall?.copyWith(
                    color: i == meses.length - 1 ? c.texto : c.textoSuave,
                    fontWeight: i == meses.length - 1 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Barra de passos do pedido (4 passos: confirmado, em separação, a caminho, entregue).
class BarraPassos extends StatelessWidget {
  const BarraPassos({super.key, required this.feitos, this.total = 4, this.inicio, this.fim, this.sobreEscuro = true});
  final int feitos;
  final int total;
  final String? inicio;
  final String? fim;
  final bool sobreEscuro;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final vazio = sobreEscuro ? Colors.white.withValues(alpha: 0.18) : c.segPrevista;
    final rotulo = t.labelSmall?.copyWith(color: sobreEscuro ? c.textoCartaoEscuroSuave : c.textoSuave);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(color: i < feitos ? c.topo : vazio, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ],
          ],
        ),
        if (inicio != null || fim != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(inicio ?? '', style: rotulo)),
              Text(fim ?? '', style: rotulo),
            ],
          ),
        ],
      ],
    );
  }
}

/// Selo da situação da loja pelo horário dela: aberta, fechada ou pedidos pausados. Sem horário
/// legível, não mostra nada (não afirma que está aberta).
class SeloSituacao extends StatelessWidget {
  const SeloSituacao({super.key, required this.situacao});
  final SituacaoLoja situacao;

  @override
  Widget build(BuildContext context) {
    if (situacao.estado == EstadoLoja.semHorario) return const SizedBox.shrink();
    final c = context.cores;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final (fundo, cor) = switch (situacao.estado) {
      EstadoLoja.aberta => (escuro ? const Color(0xFF16301F) : const Color(0xFFE3F5EA), c.sucesso),
      EstadoLoja.pausada => (escuro ? const Color(0xFF33270F) : const Color(0xFFFFF1D6), c.aviso),
      _ => (c.superficieSutil, c.textoSuave),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(8)),
      child: Text(
        situacao.selo,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Raio desenhado e centralizado na própria caixa (o ícone `bolt` do Material fica inclinado
/// e deslocado). Usa a cor do ícone ao redor, como um `Icon`.
class RaioReto extends StatelessWidget {
  const RaioReto({super.key, this.tamanho = 18, this.cor});
  final double tamanho;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(tamanho),
      painter: _PintorRaio(cor ?? tema.color ?? DefaultTextStyle.of(context).style.color ?? Colors.black),
    );
  }
}

class _PintorRaio extends CustomPainter {
  _PintorRaio(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    // Raio numa grade 24 × 24, com a caixa do desenho (x 5 a 19, y 2 a 22) no centro
    final e = size.width / 24;
    final raio = Path()
      ..moveTo(13.5 * e, 2 * e)
      ..lineTo(5 * e, 13.5 * e)
      ..lineTo(11.5 * e, 13.5 * e)
      ..lineTo(10.5 * e, 22 * e)
      ..lineTo(19 * e, 10.5 * e)
      ..lineTo(12.5 * e, 10.5 * e)
      ..close();
    canvas.drawPath(raio, Paint()..color = cor..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_PintorRaio antigo) => antigo.cor != cor;
}
