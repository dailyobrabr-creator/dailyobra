import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/ofertas_service.dart';
import '../services/periodo_resultados.dart';
import '../services/propostas_loja_service.dart';
import '../services/resultados_service.dart';
import 'dashboard_blocos.dart';
import 'graficos_resultados.dart';
import 'inicio_screen.dart';

const _larguraDosBlocosLadoALado = 760.0;

/// Resultados do mês no Dashboard, para dono e gerente: seis números, vendas por dia e por faixa de cashback, funil de
/// propostas, mercado, top construtores e produtos mais vendidos, com setas para os meses anteriores. Sem vendas, os
/// blocos continuam no lugar com uma frase.
class ResultadosDoMes extends StatefulWidget {
  const ResultadosDoMes({super.key, this.agora});

  /// Relógio dos testes; no app, a hora do aparelho.
  final DateTime Function()? agora;

  @override
  State<ResultadosDoMes> createState() => _ResultadosDoMesState();
}

class _ResultadosDoMesState extends State<ResultadosDoMes> {
  final _servico = ResultadosService.instance;

  DateTime _agora() => (widget.agora ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    // Depois do primeiro quadro: carregar avisa quem escuta o serviço, e o Início ainda está sendo montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ir(_agora());
    });
  }

  void _ir(DateTime mes) => _servico.carregar(mes, agora: _agora());

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      _servico,
      PropostasLojaService.instance,
      OfertasService.instance,
    ]),
    builder: (context, _) {
      final t = Theme.of(context).textTheme;
      final agora = _agora();
      final mes = _servico.mes ?? DateTime(agora.year, agora.month);
      final mesAtual = mes.year == agora.year && mes.month == agora.month;
      final atual = _servico.atual;
      final anterior = _servico.anterior;
      final periodo = _servico.periodo;
      final erro = _servico.erro;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Resultados do mês', style: t.titleMedium),
          Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _ir(DateTime(mes.year, mes.month - 1)),
              ),
              Expanded(
                child: Text(
                  nomeDoMes(mes),
                  textAlign: TextAlign.center,
                  style: t.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                icon: const Icon(Icons.chevron_right),
                onPressed: mesAtual
                    ? null
                    : () => _ir(DateTime(mes.year, mes.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: Espaco.s2),
          if (erro != null) ...[Aviso(erro), const SizedBox(height: Espaco.s3)],
          if (atual != null && anterior != null && periodo != null)
            ..._numeros(context, atual, anterior, periodo)
          else if (erro == null)
            const Esqueleto(altura: 160),
        ],
      );
    },
  );

  List<Widget> _numeros(
    BuildContext context,
    ResultadosPeriodo atual,
    ResultadosPeriodo anterior,
    PeriodoResultados periodo,
  ) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final v = variacao(atual.faturamento, anterior.faturamento);
    // Mesmo arredondamento do texto: o que sai 0,0% fica neutro
    final passos = v == null ? 0 : (v * 1000).round();
    final cor = passos > 0
        ? c.sucesso
        : passos < 0
        ? c.erro
        : c.textoSuave;
    final mes = nomeSoDoMes(periodo.de);
    final desempenho = _servico.desempenho;
    final recebidas = desempenho?.propostas ?? 0;
    final conversao = desempenho?.conversao;
    final vendas = desempenho?.vendasPorDia ?? const <VendaDoDia>[];
    final produtos = desempenho?.produtos ?? const <ProdutoVendido>[];
    return [
      GradeIndicadores(
        children: [
          Indicador(
            rotulo: 'Faturamento',
            valor: brl.format(atual.faturamento),
            icone: Icons.attach_money,
          ),
          Indicador(
            rotulo: 'Pedidos fechados',
            valor: '${atual.pedidos}',
            icone: Icons.shopping_bag_outlined,
          ),
          Indicador(
            rotulo: 'Ticket médio',
            valor: switch (atual.ticket) {
              final ticket? => brl.format(ticket),
              null => '—',
            },
            icone: Icons.receipt_long_outlined,
          ),
          Indicador(
            rotulo: 'Cashback gerado para os clientes',
            valor: brl.format(atual.cashback),
            icone: Icons.account_balance_wallet_outlined,
          ),
          Indicador(
            rotulo: 'Conversão de propostas',
            valor: conversao == null ? '—' : textoPercentual(conversao),
            detalhe: recebidas == 0
                ? null
                : '${desempenho!.viraramPedido} de $recebidas viraram pedido',
            icone: Icons.percent,
          ),
          Indicador(
            rotulo: 'Propostas respondidas',
            valor: recebidas == 0
                ? '—'
                : textoPercentual(desempenho!.respondidas / recebidas),
            detalhe: recebidas == 0
                ? null
                : '${desempenho!.respondidas} de $recebidas respondidas',
            icone: Icons.forum_outlined,
          ),
        ],
      ),
      const SizedBox(height: Espaco.s2),
      Row(
        children: [
          Icon(
            passos > 0
                ? Icons.trending_up
                : passos < 0
                ? Icons.trending_down
                : Icons.trending_flat,
            size: 18,
            color: cor,
          ),
          const SizedBox(width: Espaco.s1),
          Expanded(
            child: Text(
              'Faturamento: ${textoVariacao(periodo, atual: atual.faturamento, anterior: anterior.faturamento)}',
              style: t.bodySmall?.copyWith(color: cor),
            ),
          ),
        ],
      ),
      const SizedBox(height: Espaco.s4),
      _Blocos(
        vendas: vendas.isNotEmpty
            ? GraficoVendas(mes: periodo.de, vendas: vendas)
            : PainelSemDados(
                titulo: 'Vendas por dia',
                texto: 'As vendas de $mes aparecem aqui, dia a dia.',
              ),
        faixas: VendasPorFaixa(
          faixas: vendasPorFaixa(
            PropostasLojaService.instance.pedidos,
            periodo,
            _servico.percentuais,
          ),
        ),
        funil: recebidas > 0
            ? FunilPropostas(desempenho!)
            : PainelSemDados(
                titulo: 'Funil de propostas',
                texto: 'Nenhuma proposta recebida em $mes.',
              ),
        mercado: const PainelDeMercado(),
        construtores: atual.pedidos == 0
            ? PainelSemDados(
                titulo: 'Top construtores',
                texto: periodo.mesAtual
                    ? 'Nenhum pedido em $mes ainda.'
                    : 'Nenhum pedido em $mes.',
              )
            : Painel(
                titulo: 'Top construtores',
                child: Column(
                  children: [
                    for (final (i, construtor) in atual.top.indexed) ...[
                      if (i > 0) Divider(height: 1, color: c.borda),
                      _LinhaConstrutor(construtor),
                    ],
                  ],
                ),
              ),
        produtos: produtos.isNotEmpty
            ? ProdutosMaisVendidos(produtos)
            : PainelSemDados(
                titulo: 'Produtos mais vendidos',
                texto: 'Os produtos que mais saírem em $mes aparecem aqui.',
              ),
      ),
    ];
  }
}

/// Os blocos do Dashboard: um embaixo do outro; no computador, vendas ao lado do funil e do mercado, e clientes ao lado
/// dos produtos.
class _Blocos extends StatelessWidget {
  const _Blocos({
    required this.vendas,
    required this.faixas,
    required this.funil,
    required this.mercado,
    required this.construtores,
    required this.produtos,
  });
  final Widget vendas;
  final Widget faixas;
  final Widget funil;
  final Widget mercado;
  final Widget construtores;
  final Widget produtos;

  Widget _coluna(List<Widget> blocos) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, bloco) in blocos.indexed) ...[
        if (i > 0) const SizedBox(height: Espaco.s4),
        bloco,
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      if (limites.maxWidth < _larguraDosBlocosLadoALado) {
        return _coluna([
          vendas,
          faixas,
          funil,
          mercado,
          construtores,
          produtos,
        ]);
      }
      return _coluna([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _coluna([vendas, faixas])),
            const SizedBox(width: Espaco.s4),
            Expanded(child: _coluna([funil, mercado])),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: construtores),
            const SizedBox(width: Espaco.s4),
            Expanded(child: produtos),
          ],
        ),
      ]);
    },
  );
}

/// Um construtor do top: nome, empresa e pedidos à esquerda; total à direita.
class _LinhaConstrutor extends StatelessWidget {
  const _LinhaConstrutor(this.construtor);
  final ConstrutorTop construtor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final k = construtor;
    final pedidos = k.pedidos == 1 ? '1 pedido' : '${k.pedidos} pedidos';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.s4,
        vertical: Espaco.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k.exibicao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall,
                ),
                Text(
                  k.empresa.isEmpty ? pedidos : '${k.empresa} · $pedidos',
                  style: t.bodySmall?.copyWith(color: c.textoSuave),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.s3),
          Text(
            brl.format(k.total),
            style: t.titleSmall?.copyWith(fontFeatures: numerosTabulares),
          ),
        ],
      ),
    );
  }
}
