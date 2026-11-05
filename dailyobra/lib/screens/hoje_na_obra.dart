import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/diario_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';
import 'dia_obra_screen.dart';
import 'dinheiro_screen.dart';
import 'entradas_da_obra.dart';
import 'mao_de_obra_screen.dart';
import 'mudancas_screen.dart';
import 'obra_screen.dart';
import 'pendencias_screen.dart';
import 'propostas_comerciais_screen.dart';

/// As cores dos blocos, na ordem em que aparecem: a mesma paleta das categorias do catálogo.
const _tons = [
  'basico',
  'hidraulica',
  'pintura',
  'eletrica',
  'estrutura',
  'loucas-metais',
  'ferramentas',
  'cobertura',
  'acabamento',
  'alvenaria',
];

int _colunasPara(double largura) => switch (largura) {
  >= 900 => 4,
  >= 600 => 3,
  _ => 2,
};

DateTime _diaDeHoje() {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
}

/// O miolo da aba Obras: como a obra está hoje, o que dá para fazer em um toque e o caminho para cada parte dela.
class HojeNaObra extends StatefulWidget {
  const HojeNaObra({super.key, required this.obra, this.compacto = false});
  final Obra obra;

  /// No celular o nome e a data ficam em linhas separadas e os atalhos, em duas colunas.
  final bool compacto;

  @override
  State<HojeNaObra> createState() => _HojeNaObraState();
}

class _HojeNaObraState extends State<HojeNaObra> {
  /// Muda quando a pessoa volta de uma tela, para as linhas buscarem os dados de novo.
  var _versao = 0;

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    _recarregar();
  }

  void _abrirObra() => _abrir(ObraScreen(id: widget.obra.id));

  List<Widget> _atalhos() {
    final obra = widget.obra;
    final funcao = obra.funcao;
    OutlinedButton botao(IconData icone, String texto, Widget tela) {
      return OutlinedButton.icon(
        onPressed: () => _abrir(tela),
        icon: Icon(icone, size: 18),
        label: Text(texto),
      );
    }

    return [
      if (funcao.registra)
        FilledButton.icon(
          onPressed: () => _abrir(
            DiaObraScreen(obra: obra, data: _diaDeHoje(), ditarAoAbrir: true),
          ),
          icon: const Icon(Icons.mic_none, size: 18),
          label: const Text('Ditar o dia'),
        ),
      if (funcao.lidera) ...[
        botao(
          Icons.receipt_long_outlined,
          'Lançar gasto',
          GastoScreen(obra: obra),
        ),
        botao(
          Icons.how_to_reg_outlined,
          'Marcar presença',
          MaoDeObraScreen(obra: obra),
        ),
      ],
      if (funcao.registra)
        botao(
          Icons.add_task_outlined,
          'Nova pendência',
          PendenciaScreen(obra: obra),
        ),
    ];
  }

  Widget _coluna(List<Widget> filhos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, filho) in filhos.indexed) ...[
          if (i > 0) const SizedBox(height: Espaco.s2),
          filho,
        ],
      ],
    );
  }

  Widget _emColunas(List<Widget> itens, int colunas) {
    return _coluna([
      for (var i = 0; i < itens.length; i += colunas)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + colunas; j++) ...[
                if (j > i) const SizedBox(width: Espaco.s2),
                Expanded(child: j < itens.length ? itens[j] : const SizedBox()),
              ],
            ],
          ),
        ),
    ]);
  }

  Widget _grade(List<Widget> linhas) {
    final blocos = [
      for (final (i, linha) in linhas.indexed)
        BlocoDaObra(tom: _tons[i % _tons.length], child: linha),
    ];
    return LayoutBuilder(
      builder: (context, espaco) =>
          _emColunas(blocos, _colunasPara(espaco.maxWidth)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obra = widget.obra;
    final funcao = obra.funcao;
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final agora = DateTime.now();
    final etapas =
        Calculo.de(obra.parametros).resultado?.etapas ??
        const <LinhaResultado>[];
    final percentual = progresso(etapas, obra.statusEtapas);
    final atual = etapaAtual(etapas, obra.statusEtapas);
    final feitas = etapas
        .where((e) => obra.statusEtapas[e.etapa] == StatusEtapa.concluida)
        .length;
    final resumo = resumirCronograma(
      etapas: [for (final e in etapas) e.etapa],
      datas: obra.cronograma,
      status: obra.statusEtapas,
      hoje: agora,
    );
    final alerta = alertaDaObra(resumo, obra.pendenciasVencidas(agora));
    final suave = t.bodySmall?.copyWith(color: c.textoSuave);
    final atalhos = _atalhos();
    final linhas = [
      if (funcao == FuncaoObra.cliente) EntradaDasMudancas(obra: obra),
      EntradaDoDiaDeHoje(obra: obra, aoVoltar: _recarregar),
      ...entradasDaObra(obra, resumo),
      if (funcao.administra) const EntradaDasPropostas(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Painel(
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hoje na obra',
                            style: t.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.compacto
                                ? '${obra.nome}\n${diaPorExtenso(agora)}'
                                : '${obra.nome} · ${diaPorExtenso(agora)}',
                            style: t.bodyMedium?.copyWith(color: c.textoSuave),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Espaco.s2),
                    TextButton(
                      onPressed: _abrirObra,
                      child: const Text('Abrir a obra'),
                    ),
                  ],
                ),
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
                const SizedBox(height: Espaco.s2),
                Wrap(
                  spacing: Espaco.s3,
                  children: [
                    Text(
                      '$percentual% concluída',
                      style: t.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: numerosTabulares,
                      ),
                    ),
                    Text(
                      atual == null
                          ? 'Todas as etapas concluídas'
                          : 'Etapa atual: ${atual.nome}',
                      style: suave,
                    ),
                    Text('$feitas de ${etapas.length} etapas', style: suave),
                  ],
                ),
                if (alerta != null) ...[
                  const SizedBox(height: Espaco.s3),
                  Aviso(alerta, tom: TomSelo.aviso),
                ],
                if (atalhos.isNotEmpty) ...[
                  const SizedBox(height: Espaco.s4),
                  if (widget.compacto)
                    _emColunas(atalhos, 2)
                  else
                    Wrap(
                      spacing: Espaco.s2,
                      runSpacing: Espaco.s2,
                      children: atalhos,
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.s4),
        const TituloSecao(
          'Tudo da obra',
          margem: EdgeInsets.only(bottom: Espaco.s2),
        ),
        KeyedSubtree(key: ValueKey(_versao), child: _grade(linhas)),
      ],
    );
  }

  void _recarregar() {
    if (mounted) setState(() => _versao++);
  }
}

/// O diário de hoje em uma linha, levando direto ao dia.
class EntradaDoDiaDeHoje extends StatefulWidget {
  const EntradaDoDiaDeHoje({super.key, required this.obra, this.aoVoltar});
  final Obra obra;

  /// O dia pode ter mudado o resto do painel.
  final VoidCallback? aoVoltar;

  @override
  State<EntradaDoDiaDeHoje> createState() => _EntradaDoDiaDeHojeState();
}

class _EntradaDoDiaDeHojeState extends State<EntradaDoDiaDeHoje> {
  DiaObra? _dia;
  var _carregando = true;
  var _falhou = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dia = await DiarioService.instance.doDia(
        widget.obra.id,
        _diaDeHoje(),
      );
      if (mounted) {
        setState(() {
          _dia = dia;
          _carregando = false;
        });
      }
    } on FalhaAoSalvar {
      if (mounted) {
        setState(() {
          _falhou = true;
          _carregando = false;
        });
      }
    }
  }

  String _detalhe() {
    if (_carregando) return 'Carregando...';
    if (_falhou) return 'Toque para abrir o dia';
    final dia = _dia;
    if (dia == null) {
      return widget.obra.funcao.registra
          ? 'Ainda não preenchido'
          : 'Ainda não registrado';
    }
    final situacao = dia.fechado ? 'Finalizado' : 'Em rascunho';
    return '$situacao · ${dia.resumo}';
  }

  @override
  Widget build(BuildContext context) {
    return EntradaDaObra(
      icone: Icons.edit_note,
      titulo: 'Diário de hoje',
      detalhe: _detalhe(),
      aoTocar: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DiaObraScreen(obra: widget.obra, data: _diaDeHoje()),
          ),
        );
        widget.aoVoltar?.call();
      },
    );
  }
}
