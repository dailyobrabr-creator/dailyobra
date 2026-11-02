import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../obras/obra.dart';
import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import '../tema/tema.dart';
import '../tema/cores.dart';
import 'ui.dart';

final _percentual = NumberFormat.decimalPercentPattern(locale: 'pt_BR', decimalDigits: 1);

/// Amostra da situação: mesmo preenchimento do segmento na faixa (sólido ou hachurado)
class Amostra extends StatelessWidget {
  const Amostra(this.status, {super.key, this.tamanho = 12});
  final StatusEtapa? status;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: ClipRRect(borderRadius: BorderRadius.circular(2), child: _Preenchimento(status: status)),
    );
  }
}

class LegendaStatus extends StatelessWidget {
  const LegendaStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: Espaco.s4,
      runSpacing: Espaco.s1,
      children: [
        for (final s in [StatusEtapa.concluida, StatusEtapa.iniciada, StatusEtapa.bloqueada, StatusEtapa.prevista])
          Row(mainAxisSize: MainAxisSize.min, children: [Amostra(s), const SizedBox(width: 6), Text(s.rotulo, style: t)]),
      ],
    );
  }
}

/// Cronograma físico-financeiro em uma linha: cada etapa ocupa a largura do seu custo.
/// Com [status], o preenchimento mostra a situação; sem, mostra só o peso de cada etapa.
/// Tocar ou arrastar o dedo sobre a faixa mostra o valor da etapa embaixo.
class FaixaObra extends StatefulWidget {
  const FaixaObra({super.key, required this.etapas, this.status, required this.padrao, this.legenda = false, this.onEscolher});
  final List<LinhaResultado> etapas;
  final Map<EtapaId, StatusEtapa>? status;

  /// Texto quando nenhuma etapa está em foco
  final Widget padrao;
  final bool legenda;

  /// Toque solto sobre uma etapa (a tela da obra usa para rolar até ela)
  final ValueChanged<EtapaId>? onEscolher;

  @override
  State<FaixaObra> createState() => _FaixaObraState();
}

class _FaixaObraState extends State<FaixaObra> {
  EtapaId? _ativo;
  static const _vao = 2.0;

  int _peso(LinhaResultado e, double total) => total == 0 ? 1 : (e.total / total * 1000).round().clamp(1, 1000);

  EtapaId? _etapaNaPosicao(double x, double largura) {
    final total = widget.etapas.fold<double>(0, (s, e) => s + e.total);
    final pesos = [for (final e in widget.etapas) _peso(e, total)];
    final soma = pesos.fold<int>(0, (s, p) => s + p);
    final util = largura - _vao * (widget.etapas.length - 1);
    var inicio = 0.0;
    for (var i = 0; i < widget.etapas.length; i++) {
      final fim = inicio + util * pesos[i] / soma + _vao;
      if (x < fim) return widget.etapas[i].etapa;
      inicio = fim;
    }
    return widget.etapas.isEmpty ? null : widget.etapas.last.etapa;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = widget.etapas.fold<double>(0, (s, e) => s + e.total);
    LinhaResultado? foco;
    for (final e in widget.etapas) {
      if (e.etapa == _ativo) foco = e;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          void marcar(double x) => setState(() => _ativo = _etapaNaPosicao(x.clamp(0, c.maxWidth - 1), c.maxWidth));
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => marcar(d.localPosition.dx),
            onTapUp: (_) {
              final a = _ativo;
              if (a != null) widget.onEscolher?.call(a);
            },
            onHorizontalDragStart: (d) => marcar(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => marcar(d.localPosition.dx),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Raio.sm),
              child: SizedBox(
                height: 40,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.etapas.length; i++) ...[
                      if (i > 0) const SizedBox(width: _vao),
                      Expanded(
                        flex: _peso(widget.etapas[i], total),
                        child: Semantics(
                          button: widget.onEscolher != null,
                          label: _rotulo(widget.etapas[i], total),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 120),
                            opacity: _ativo != null && _ativo != widget.etapas[i].etapa ? 0.35 : 1,
                            child: widget.status == null
                                ? ColoredBox(color: _ativo == widget.etapas[i].etapa ? context.cores.acento : context.cores.segNeutra, child: const SizedBox.expand())
                                : _Preenchimento(status: widget.status![widget.etapas[i].etapa] ?? StatusEtapa.prevista),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: Espaco.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 20),
          child: foco == null
              ? DefaultTextStyle.merge(style: t.bodyMedium, child: widget.padrao)
              : Text.rich(
                  TextSpan(children: [
                    TextSpan(text: foco.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                      text: ' ${brl.format(foco.total)}, ${_percentual.format(total == 0 ? 0 : foco.total / total)} do custo'
                          '${widget.status != null ? ', ${(widget.status![foco.etapa] ?? StatusEtapa.prevista).rotulo.toLowerCase()}' : ''}',
                      style: TextStyle(color: context.cores.textoSuave, fontFeatures: numerosTabulares),
                    ),
                  ]),
                  style: t.bodyMedium,
                ),
        ),
        if (widget.legenda) ...[const SizedBox(height: Espaco.s2), const LegendaStatus()],
      ],
    );
  }

  String _rotulo(LinhaResultado e, double total) {
    final s = widget.status?[e.etapa];
    return '${e.nome}: ${brl.format(e.total)}, ${_percentual.format(total == 0 ? 0 : e.total / total)} do custo'
        '${widget.status != null ? ', ${(s ?? StatusEtapa.prevista).rotulo.toLowerCase()}' : ''}';
  }
}

/// Versão compacta, só leitura, para os cartões da lista de obras
class FaixaMini extends StatelessWidget {
  const FaixaMini({super.key, required this.etapas, required this.status});
  final List<LinhaResultado> etapas;
  final Map<EtapaId, StatusEtapa> status;

  @override
  Widget build(BuildContext context) {
    final total = etapas.fold<double>(0, (s, e) => s + e.total);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 8,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < etapas.length; i++) ...[
              if (i > 0) const SizedBox(width: 1),
              Expanded(
                flex: total == 0 ? 1 : (etapas[i].total / total * 1000).round().clamp(1, 1000),
                child: _Preenchimento(status: status[etapas[i].etapa] ?? StatusEtapa.prevista),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Sólido para prevista/concluída; hachura diagonal para em andamento e bloqueada,
/// para os estados se distinguirem também pelo desenho, não só pela cor
class _Preenchimento extends StatelessWidget {
  const _Preenchimento({required this.status});
  final StatusEtapa? status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      StatusEtapa.concluida => ColoredBox(color: context.cores.acento, child: SizedBox.expand()),
      StatusEtapa.iniciada => CustomPaint(painter: _Hachura(context.cores.acento, context.cores.hachuraLaranja), child: SizedBox.expand()),
      StatusEtapa.bloqueada => CustomPaint(painter: _Hachura(context.cores.erro, context.cores.hachuraVermelha), child: SizedBox.expand()),
      StatusEtapa.prevista => ColoredBox(color: context.cores.segPrevista, child: SizedBox.expand()),
      null => ColoredBox(color: context.cores.segNeutra, child: SizedBox.expand()),
    };
  }
}

class _Hachura extends CustomPainter {
  const _Hachura(this.traco, this.fundo);
  final Color traco;
  final Color fundo;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fundo);
    canvas.clipRect(Offset.zero & size);
    final p = Paint()
      ..color = traco
      ..strokeWidth = 3;
    // Linhas a 45° com passo de 6 px, como o repeating-linear-gradient do app web
    for (var x = -size.height; x < size.width + size.height; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_Hachura old) => old.traco != traco || old.fundo != fundo;
}
