import 'dart:math' as math;

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/periodo_resultados.dart';
import '../services/resultados_service.dart';
import 'componentes.dart';

/// Espaço dos valores à esquerda das colunas.
const _margemEsquerda = 44.0;

/// Faixa dos dias embaixo das colunas.
const _faixaDosDias = 20.0;
const _alturaDoGrafico = 180.0;
const _maiorColuna = 24.0;

/// Vão na cor do fundo entre as colunas.
const _vao = 2.0;

double _faixa(double largura, int dias) => (largura - _margemEsquerda) / dias;

double larguraDaColuna(double largura, int dias) =>
    (_faixa(largura, dias) - _vao).clamp(1.0, _maiorColuna);

double centroDaColuna(int indice, double largura, int dias) =>
    _margemEsquerda + (indice + 0.5) * _faixa(largura, dias);

/// Índice da coluna mais próxima de [x].
int diaDoToque(double x, double largura, int dias) =>
    ((x - _margemEsquerda) / _faixa(largura, dias)).floor().clamp(0, dias - 1);

/// Todos os dias do mês de [mes], com zero nos dias sem venda.
List<VendaDoDia> diasDoMes(DateTime mes, List<VendaDoDia> vendas) {
  final porDia = {
    for (final v in vendas)
      if (v.dia.year == mes.year && v.dia.month == mes.month) v.dia.day: v,
  };
  return [
    for (var d = 1; d <= DateTime(mes.year, mes.month + 1, 0).day; d++)
      porDia[d] ??
          VendaDoDia(
            dia: DateTime(mes.year, mes.month, d),
            total: 0,
            pedidos: 0,
          ),
  ];
}

/// O dia de maior venda; no empate, o primeiro.
VendaDoDia? melhorDia(List<VendaDoDia> vendas) {
  VendaDoDia? melhor;
  for (final v in vendas) {
    if (v.total > (melhor?.total ?? 0)) melhor = v;
  }
  return melhor;
}

/// Primeiro 1, 2 ou 5 vezes uma potência de 10 que cabe [maior].
double topoDaEscala(double maior) {
  if (maior <= 1) return 1;
  for (var passo = 1.0; ; passo *= 10) {
    for (final vezes in const [1, 2, 5]) {
      if (vezes * passo >= maior) return vezes * passo;
    }
  }
}

/// "1.000", "10 mil", "2,5 mi".
String rotuloDaEscala(double valor) {
  if (valor >= 1000000) return '${formatarQuantidade(valor / 1000000)} mi';
  if (valor >= 10000) return '${formatarQuantidade(valor / 1000)} mil';
  return formatarQuantidade(valor);
}

/// "28,6%", "100%".
String textoPercentual(double fracao) {
  final decimos = (fracao * 1000).round();
  final inteiro = decimos ~/ 10;
  return decimos % 10 == 0 ? '$inteiro%' : '$inteiro,${decimos % 10}%';
}

String _dois(int n) => n.toString().padLeft(2, '0');

String _diaMes(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}';

String _pedidos(int n) => n == 1 ? '1 pedido' : '$n pedidos';

bool _escuro(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

// Cores conferidas com o validador de paletas do dataviz nas superfícies do tema (branca e #1C1E23). O laranja da marca
// (#F36E21) fica claro demais como cor de dado no tema escuro; #E8641C é o passo aprovado mais próximo dele.
Color _corDoDado(BuildContext context) =>
    _escuro(context) ? const Color(0xFFE8641C) : const Color(0xFFA43F05);

List<Color> _rampaDoFunil(BuildContext context) => _escuro(context)
    ? const [Color(0xFF8A4A22), Color(0xFFBF5C1E), Color(0xFFE8641C)]
    : const [Color(0xFFE59660), Color(0xFFC9601F), Color(0xFFA43F05)];

/// Vendas de cada dia do mês em colunas. Tocar (ou passar o mouse) mostra o dia; "Ver dia a dia" abre a mesma
/// informação em lista, para quem não usa o gráfico.
class GraficoVendas extends StatefulWidget {
  const GraficoVendas({super.key, required this.mes, required this.vendas});

  /// Qualquer dia do mês mostrado.
  final DateTime mes;

  /// Só os dias com venda.
  final List<VendaDoDia> vendas;

  @override
  State<GraficoVendas> createState() => _GraficoVendasState();
}

class _GraficoVendasState extends State<GraficoVendas> {
  /// Coluna tocada; sem nenhuma, a leitura mostra o melhor dia.
  int? _dia;

  @override
  void didUpdateWidget(GraficoVendas antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.mes != widget.mes) _dia = null;
  }

  String _leitura(List<VendaDoDia> dias) {
    final i = _dia;
    if (i == null) {
      final melhor = melhorDia(widget.vendas);
      return melhor == null
          ? 'Sem vendas neste mês'
          : 'Melhor dia: ${_diaMes(melhor.dia)} · ${brl.format(melhor.total)}';
    }
    final d = dias[i];
    return d.pedidos == 0
        ? '${_diaMes(d.dia)}: sem vendas'
        : '${_diaMes(d.dia)}: ${brl.format(d.total)} · ${_pedidos(d.pedidos)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final dias = diasDoMes(widget.mes, widget.vendas);
    final topo = topoDaEscala(dias.map((d) => d.total).reduce(math.max));
    final leitura = _leitura(dias);
    return Painel(
      titulo: 'Vendas por dia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s3,
              Espaco.s4,
              Espaco.s3,
            ),
            child: Text(
              leitura,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espaco.s4),
            child: LayoutBuilder(
              builder: (context, limites) {
                final largura = limites.maxWidth;
                int indice(double x) => diaDoToque(x, largura, dias.length);
                return MouseRegion(
                  onHover: (e) =>
                      setState(() => _dia = indice(e.localPosition.dx)),
                  onExit: (_) => setState(() => _dia = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (e) => setState(() {
                      final i = indice(e.localPosition.dx);
                      _dia = _dia == i ? null : i;
                    }),
                    onHorizontalDragUpdate: (e) =>
                        setState(() => _dia = indice(e.localPosition.dx)),
                    child: Semantics(
                      image: true,
                      label:
                          'Gráfico de vendas por dia de ${nomeDoMes(widget.mes)}. $leitura.',
                      child: CustomPaint(
                        key: const Key('grafico-vendas'),
                        size: Size(largura, _alturaDoGrafico),
                        painter: _PintorDasVendas(
                          dias: dias,
                          topo: topo,
                          selecionado: _dia,
                          corDaColuna: _corDoDado(context),
                          corDaGrade: c.borda,
                          estiloDosEixos: (t.labelSmall ?? const TextStyle())
                              .copyWith(
                                color: c.textoSuave,
                                fontFeatures: numerosTabulares,
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          ExpansionTile(
            title: Text('Ver dia a dia', style: t.bodyMedium),
            tilePadding: const EdgeInsets.symmetric(horizontal: Espaco.s4),
            childrenPadding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              0,
              Espaco.s4,
              Espaco.s3,
            ),
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              for (final v in widget.vendas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Espaco.s1),
                  child: Row(
                    children: [
                      Text(
                        _diaMes(v.dia),
                        style: t.bodyMedium?.copyWith(
                          fontFeatures: numerosTabulares,
                        ),
                      ),
                      const SizedBox(width: Espaco.s3),
                      Expanded(
                        child: Text(
                          _pedidos(v.pedidos),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: c.textoSuave),
                        ),
                      ),
                      const SizedBox(width: Espaco.s3),
                      Text(
                        brl.format(v.total),
                        style: t.bodyMedium?.copyWith(
                          fontFeatures: numerosTabulares,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PintorDasVendas extends CustomPainter {
  _PintorDasVendas({
    required this.dias,
    required this.topo,
    required this.selecionado,
    required this.corDaColuna,
    required this.corDaGrade,
    required this.estiloDosEixos,
  });
  final List<VendaDoDia> dias;
  final double topo;
  final int? selecionado;
  final Color corDaColuna;
  final Color corDaGrade;
  final TextStyle estiloDosEixos;

  void _texto(Canvas canvas, String texto, Offset ponto, Alignment ancora) {
    final p = TextPainter(
      text: TextSpan(text: texto, style: estiloDosEixos),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(
      canvas,
      ponto -
          Offset(p.width * (ancora.x + 1) / 2, p.height * (ancora.y + 1) / 2),
    );
    p.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final alturaUtil = size.height - _faixaDosDias;
    final grade = Paint()
      ..color = corDaGrade
      ..strokeWidth = 1;
    for (final valor in [0.0, topo / 2, topo]) {
      final y = alturaUtil * (1 - valor / topo);
      canvas.drawLine(Offset(_margemEsquerda, y), Offset(size.width, y), grade);
      _texto(
        canvas,
        rotuloDaEscala(valor),
        Offset(_margemEsquerda - 6, y),
        Alignment.centerRight,
      );
    }
    final largura = larguraDaColuna(size.width, dias.length);
    final raio = Radius.circular(math.min(4, largura / 2));
    for (final (i, d) in dias.indexed) {
      final centro = centroDaColuna(i, size.width, dias.length);
      if (d.total > 0) {
        final altura = math.max(2.0, alturaUtil * d.total / topo);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              centro - largura / 2,
              alturaUtil - altura,
              largura,
              altura,
            ),
            topLeft: raio,
            topRight: raio,
          ),
          Paint()
            ..color = selecionado == null || selecionado == i
                ? corDaColuna
                : corDaColuna.withValues(alpha: 0.4),
        );
      }
      // Uma marca por semana: todos os dias não cabem no celular
      if (i % 7 == 0) {
        _texto(
          canvas,
          '${d.dia.day}',
          Offset(centro, size.height),
          Alignment.bottomCenter,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorDasVendas antigo) => true;
}

/// Barra fina deitada, proporcional a [fracao] do espaço.
class _Barra extends StatelessWidget {
  const _Barra({required this.fracao, required this.cor});
  final double fracao;
  final Color cor;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: fracao.clamp(0.0, 1.0),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(4),
          ),
        ),
      ),
    ),
  );
}

/// Das propostas recebidas no mês, quantas a loja respondeu e quantas viraram pedido.
class FunilPropostas extends StatelessWidget {
  const FunilPropostas(this.desempenho, {super.key});

  /// Com ao menos uma proposta.
  final DesempenhoPeriodo desempenho;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final d = desempenho;
    final rampa = _rampaDoFunil(context);
    final passos = [
      ('Recebidas', d.propostas),
      ('Respondidas', d.respondidas),
      ('Viraram pedido', d.viraramPedido),
    ];
    return Painel(
      titulo: 'Funil de propostas',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (rotulo, quantos)) in passos.indexed) ...[
              if (i > 0) const SizedBox(height: Espaco.s3),
              Row(
                children: [
                  Expanded(child: Text(rotulo, style: t.bodyMedium)),
                  const SizedBox(width: Espaco.s2),
                  Text(
                    i == 0
                        ? '$quantos'
                        : '$quantos · ${textoPercentual(quantos / d.propostas)}',
                    style: t.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: numerosTabulares,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espaco.s1),
              _Barra(fracao: quantos / d.propostas, cor: rampa[i]),
            ],
            const SizedBox(height: Espaco.s3),
            Text(
              '${textoPercentual(d.conversao ?? 0)} das propostas viraram pedido',
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Os produtos de maior valor nos pedidos do mês, do maior ao menor.
class ProdutosMaisVendidos extends StatelessWidget {
  const ProdutosMaisVendidos(this.produtos, {super.key});

  /// Em ordem de valor, com ao menos um.
  final List<ProdutoVendido> produtos;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: c.textoSuave);
    final maior = produtos.first.total;
    return Painel(
      titulo: 'Produtos mais vendidos',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, p) in produtos.indexed) ...[
              if (i > 0) const SizedBox(height: Espaco.s3),
              Text(
                p.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${formatarQuantidade(p.quantidade)} ${p.unidade} · ${brl.format(p.total)}',
                style: suave,
              ),
              const SizedBox(height: Espaco.s1),
              _Barra(
                fracao: maior == 0 ? 0 : p.total / maior,
                cor: _corDoDado(context),
              ),
            ],
            const SizedBox(height: Espaco.s3),
            Text('Valor dos produtos, sem frete e sem desconto.', style: suave),
          ],
        ),
      ),
    );
  }
}
