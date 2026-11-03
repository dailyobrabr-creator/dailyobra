import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/periodo_resultados.dart';
import '../services/resultados_service.dart';
import 'inicio_screen.dart';

/// Resultados do mês no Início, para dono e gerente: faturamento (com a variação), pedidos fechados, ticket médio,
/// cashback gerado e top construtores, com setas para os meses anteriores.
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
    listenable: _servico,
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
    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Espaco.s3,
        crossAxisSpacing: Espaco.s3,
        childAspectRatio: 1.55,
        children: [
          Indicador(
            rotulo: 'Faturamento',
            valor: brl.format(atual.faturamento),
          ),
          Indicador(rotulo: 'Pedidos fechados', valor: '${atual.pedidos}'),
          Indicador(
            rotulo: 'Ticket médio',
            valor: switch (atual.ticket) {
              final ticket? => brl.format(ticket),
              null => '—',
            },
          ),
          Indicador(
            rotulo: 'Cashback gerado para os clientes',
            valor: brl.format(atual.cashback),
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
      if (atual.pedidos == 0)
        Text(
          periodo.mesAtual
              ? 'Nenhum pedido em $mes ainda.'
              : 'Nenhum pedido em $mes.',
          style: t.bodyMedium?.copyWith(color: c.textoSuave),
        )
      else
        Painel(
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
    ];
  }
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
