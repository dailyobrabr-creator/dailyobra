import 'dart:math' as math;

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/cronograma_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';

// Azul e laranja continuam diferentes para quem tem daltonismo, nos dois temas
const _previstoClaro = Color(0xFF3F75B5);
const _previstoEscuro = Color(0xFF5F8FCC);
const _realClaro = Color(0xFFA43F05);
const _realEscuro = Color(0xFFE8641C);

Color _corPrevisto(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? _previstoEscuro
    : _previstoClaro;
Color _corReal(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _realEscuro : _realClaro;

String _dias(int n) => n == 1 ? '1 dia' : '$n dias';

/// Datas previstas e reais de cada etapa, na ordem da obra.
class CronogramaScreen extends StatefulWidget {
  const CronogramaScreen({super.key, required this.obra, this.hoje});
  final Obra obra;

  /// Os testes fixam o dia.
  final DateTime? hoje;

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class _CronogramaScreenState extends State<CronogramaScreen> {
  late Map<EtapaId, DatasEtapa> _datas = {...widget.obra.cronograma};
  late final _etapas =
      Calculo.de(widget.obra.parametros).resultado?.etapas ??
      const <LinhaResultado>[];
  bool _ocupado = false;

  DateTime get _hoje => widget.hoje ?? DateTime.now();
  bool get _lidera => widget.obra.funcao.lidera;

  Future<void> _salvar(
    Map<EtapaId, DatasEtapa> novas, {
    bool comReal = true,
  }) async {
    setState(() => _ocupado = true);
    try {
      await CronogramaService.instance.salvar(
        widget.obra.id,
        novas,
        comReal: comReal,
      );
      if (mounted) setState(() => _datas = {..._datas, ...novas});
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _montar({required bool refazer}) async {
    final inicio = DateTime.tryParse(widget.obra.dados.inicioPrevisto) ?? _hoje;
    final area = lerNumero(widget.obra.parametros.area);
    final periodo = await showDialog<(DateTime, DateTime)>(
      context: context,
      builder: (_) => _JanelaMontar(
        inicio: inicio,
        fim: DateTime(
          inicio.year,
          inicio.month,
          inicio.day + diasEstimados(area.isNaN ? 100 : area),
        ),
        refazer: refazer,
      ),
    );
    if (periodo == null) return;
    await _salvar(
      sugerirCronograma(
        etapas: _etapas,
        inicio: periodo.$1,
        fim: periodo.$2,
        atuais: _datas,
      ),
      comReal: false,
    );
  }

  Future<void> _editar(LinhaResultado e) async {
    final novas = await showDialog<DatasEtapa>(
      context: context,
      builder: (_) => _JanelaDatas(
        nome: e.nome,
        datas: _datas[e.etapa] ?? const DatasEtapa(),
        hoje: _hoje,
      ),
    );
    if (novas != null) await _salvar({e.etapa: novas});
  }

  @override
  Widget build(BuildContext context) {
    final resumo = resumirCronograma(
      etapas: [for (final e in _etapas) e.etapa],
      datas: _datas,
      status: widget.obra.statusEtapas,
      hoje: _hoje,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Cronograma')),
      body: _etapas.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(Espaco.s4),
              child: Aviso('Corrija os parâmetros da obra para ver as etapas.'),
            )
          : resumo.comDatas == 0
          ? _vazio()
          : _lista(resumo),
    );
  }

  Widget _vazio() {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('O cronograma ainda não foi montado.', style: t.titleMedium),
            if (_lidera) ...[
              const SizedBox(height: Espaco.s2),
              Text(
                'Escolha o início e o fim da obra. As etapas são distribuídas pelo custo, e depois você ajusta cada uma.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
              ),
              const SizedBox(height: Espaco.s4),
              FilledButton(
                onPressed: _ocupado ? null : () => _montar(refazer: false),
                child: const Text('Montar cronograma'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Fim da barra do que já aconteceu: etapa em andamento vai até hoje.
  DateTime? _fimDoReal(LinhaResultado e, DatasEtapa d) {
    if (d.fimReal != null) return d.fimReal;
    if (d.inicioReal == null) return null;
    return widget.obra.statusDe(e.etapa) == StatusEtapa.iniciada
        ? _hoje
        : d.inicioReal;
  }

  Widget _lista(ResumoCronograma resumo) {
    final datasDaEscala = <DateTime>[
      for (final e in _etapas)
        ...[
          _datas[e.etapa]?.inicioPrevisto,
          _datas[e.etapa]?.fimPrevisto,
          _datas[e.etapa]?.inicioReal,
          if (_datas[e.etapa] != null) _fimDoReal(e, _datas[e.etapa]!),
        ].nonNulls,
    ]..sort();
    final de = datasDaEscala.first;
    final ate = datasDaEscala.last;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s4,
        Espaco.s4,
        Espaco.s10,
      ),
      children: [
        Painel(
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(resumo.texto, style: t.titleMedium)),
                    if (_lidera)
                      TextButton(
                        onPressed: _ocupado
                            ? null
                            : () => _montar(refazer: true),
                        child: const Text('Refazer datas'),
                      ),
                  ],
                ),
                Text(
                  '${dataCurta(de)}/${de.year} a ${dataCurta(ate)}/${ate.year}',
                  style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
                ),
                const SizedBox(height: Espaco.s3),
                Wrap(
                  spacing: Espaco.s4,
                  runSpacing: Espaco.s1,
                  children: [
                    _Legenda(cor: _corPrevisto(context), rotulo: 'Previsto'),
                    _Legenda(cor: _corReal(context), rotulo: 'Real'),
                    _Legenda(
                      cor: context.cores.textoSuave,
                      rotulo: 'Hoje',
                      linha: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.s4),
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, e) in _etapas.indexed) ...[
                if (i > 0) const Divider(),
                _LinhaDaEtapa(
                  etapa: e,
                  datas: _datas[e.etapa] ?? const DatasEtapa(),
                  fimDoReal: _datas[e.etapa] == null
                      ? null
                      : _fimDoReal(e, _datas[e.etapa]!),
                  status: widget.obra.statusDe(e.etapa),
                  de: de,
                  ate: ate,
                  hoje: _hoje,
                  aoTocar: _lidera && !_ocupado ? () => _editar(e) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.cor, required this.rotulo, this.linha = false});
  final Color cor;
  final String rotulo;
  final bool linha;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: linha ? 1 : 16,
        height: linha ? 12 : 6,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(linha ? 0 : 3),
        ),
      ),
      const SizedBox(width: 6),
      Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _LinhaDaEtapa extends StatelessWidget {
  const _LinhaDaEtapa({
    required this.etapa,
    required this.datas,
    required this.fimDoReal,
    required this.status,
    required this.de,
    required this.ate,
    required this.hoje,
    required this.aoTocar,
  });

  final LinhaResultado etapa;
  final DatasEtapa datas;
  final DateTime? fimDoReal;
  final StatusEtapa status;
  final DateTime de;
  final DateTime ate;
  final DateTime hoje;
  final VoidCallback? aoTocar;

  String get _previsto {
    final i = datas.inicioPrevisto;
    final f = datas.fimPrevisto;
    if (i == null || f == null) return 'Previsto: sem datas';
    return 'Previsto: ${dataCurta(i)} a ${dataCurta(f)}';
  }

  String get _real {
    final i = datas.inicioReal;
    final f = datas.fimReal;
    if (i == null) return 'Real: não começou';
    if (f != null) return 'Real: ${dataCurta(i)} a ${dataCurta(f)}';
    return status == StatusEtapa.bloqueada
        ? 'Real: ${dataCurta(i)}, bloqueada'
        : 'Real: ${dataCurta(i)}, em andamento';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final atraso = diasDeAtraso(datas, status, hoje);
    final (rotulo, tom) = status == StatusEtapa.concluida
        ? (status.rotulo, TomSelo.sucesso)
        : atraso > 0
        ? ('${_dias(atraso)} de atraso', TomSelo.erro)
        : status == StatusEtapa.bloqueada
        ? (status.rotulo, TomSelo.erro)
        : status == StatusEtapa.iniciada
        ? ('', TomSelo.info)
        : ('', TomSelo.neutro);
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(etapa.nome, style: t.titleSmall)),
                if (rotulo.isNotEmpty) ...[
                  const SizedBox(width: Espaco.s2),
                  Selo(rotulo, tom: tom),
                ],
              ],
            ),
            if (datas.temPrevisto || datas.inicioReal != null) ...[
              const SizedBox(height: Espaco.s2),
              BarrasDaEtapa(
                datas: datas,
                fimDoReal: fimDoReal,
                de: de,
                ate: ate,
                hoje: hoje,
              ),
            ],
            const SizedBox(height: Espaco.s2),
            Text(_previsto, style: suave),
            Text(_real, style: suave),
            if (status == StatusEtapa.concluida && atraso > 0)
              Text(
                'Terminou ${_dias(atraso)} depois do previsto',
                style: suave,
              ),
          ],
        ),
      ),
    );
  }
}

/// Previsto em cima, real embaixo, na mesma escala de datas para todas as etapas.
class BarrasDaEtapa extends StatelessWidget {
  const BarrasDaEtapa({
    super.key,
    required this.datas,
    required this.fimDoReal,
    required this.de,
    required this.ate,
    required this.hoje,
  });

  final DatasEtapa datas;
  final DateTime? fimDoReal;
  final DateTime de;
  final DateTime ate;
  final DateTime hoje;

  static const _altura = 6.0;
  static const _vao = 2.0;

  @override
  Widget build(BuildContext context) {
    final previsto = _corPrevisto(context);
    final real = _corReal(context);
    final inicioReal = datas.inicioReal;
    final fimReal = fimDoReal;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, limites) {
          final largura = limites.maxWidth;
          final total = math.max(1, diasEntre(de, ate));
          double x(DateTime d) => diasEntre(de, d) / total * largura;
          Widget barra(DateTime i, DateTime f, Color cor, double topo) {
            final tamanho = math.max(x(f) - x(i), _altura);
            return Positioned(
              left: math.min(x(i), largura - tamanho),
              top: topo,
              width: tamanho,
              height: _altura,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(_altura / 2),
                ),
              ),
            );
          }

          final temHoje = !hoje.isBefore(de) && !hoje.isAfter(ate);
          return SizedBox(
            height: _altura * 2 + _vao,
            child: Stack(
              children: [
                if (datas.temPrevisto)
                  barra(datas.inicioPrevisto!, datas.fimPrevisto!, previsto, 0),
                if (inicioReal != null && fimReal != null)
                  barra(inicioReal, fimReal, real, _altura + _vao),
                if (temHoje)
                  Positioned(
                    left: x(hoje),
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: ColoredBox(color: context.cores.textoSuave),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Início e fim da obra para distribuir as etapas.
class _JanelaMontar extends StatefulWidget {
  const _JanelaMontar({
    required this.inicio,
    required this.fim,
    required this.refazer,
  });

  final DateTime inicio;
  final DateTime fim;
  final bool refazer;

  @override
  State<_JanelaMontar> createState() => _JanelaMontarState();
}

class _JanelaMontarState extends State<_JanelaMontar> {
  late DateTime _inicio = widget.inicio;
  late DateTime _fim = widget.fim;
  String? _erro;

  void _concluir() {
    if (_fim.isBefore(_inicio)) {
      setState(() => _erro = 'O fim não pode vir antes do início.');
      return;
    }
    Navigator.pop(context, (_inicio, _fim));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.refazer ? 'Refazer datas' : 'Montar cronograma'),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.refazer
                  ? 'As datas previstas de todas as etapas serão trocadas. As datas reais ficam como estão.'
                  : 'As etapas são distribuídas em sequência, pelo custo de cada uma.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Início da obra',
              valor: _inicio,
              aoMudar: (d) => setState(() => _inicio = d ?? _inicio),
              limpavel: false,
            ),
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Fim previsto',
              valor: _fim,
              aoMudar: (d) => setState(() => _fim = d ?? _fim),
              limpavel: false,
            ),
            if (_erro != null) ...[
              const SizedBox(height: Espaco.s3),
              Aviso(_erro!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _concluir, child: const Text('Montar')),
      ],
    );
  }
}

class _JanelaDatas extends StatefulWidget {
  const _JanelaDatas({
    required this.nome,
    required this.datas,
    required this.hoje,
  });

  final String nome;
  final DatasEtapa datas;
  final DateTime hoje;

  @override
  State<_JanelaDatas> createState() => _JanelaDatasState();
}

class _JanelaDatasState extends State<_JanelaDatas> {
  late DateTime? _inicioPrevisto = widget.datas.inicioPrevisto;
  late DateTime? _fimPrevisto = widget.datas.fimPrevisto;
  late DateTime? _inicioReal = widget.datas.inicioReal;
  late DateTime? _fimReal = widget.datas.fimReal;
  String? _erro;

  bool _invertidas(DateTime? i, DateTime? f) =>
      i != null && f != null && f.isBefore(i);

  void _concluir() {
    final erro = _invertidas(_inicioPrevisto, _fimPrevisto)
        ? 'O fim previsto não pode vir antes do início.'
        : _invertidas(_inicioReal, _fimReal)
        ? 'O fim real não pode vir antes do início.'
        : null;
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    Navigator.pop(
      context,
      DatasEtapa(
        inicioPrevisto: _inicioPrevisto,
        fimPrevisto: _fimPrevisto,
        inicioReal: _inicioReal,
        fimReal: _fimReal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.nome),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoData(
              rotulo: 'Início previsto',
              valor: _inicioPrevisto,
              aoMudar: (d) => setState(() => _inicioPrevisto = d),
            ),
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Fim previsto',
              valor: _fimPrevisto,
              aoMudar: (d) => setState(() => _fimPrevisto = d),
            ),
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Início real',
              valor: _inicioReal,
              ate: widget.hoje,
              aoMudar: (d) => setState(() => _inicioReal = d),
            ),
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Fim real',
              valor: _fimReal,
              ate: widget.hoje,
              aoMudar: (d) => setState(() => _fimReal = d),
            ),
            if (_erro != null) ...[
              const SizedBox(height: Espaco.s3),
              Aviso(_erro!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _concluir, child: const Text('Salvar')),
      ],
    );
  }
}

/// Entrada do cronograma na tela da obra.
class EntradaDoCronograma extends StatelessWidget {
  const EntradaDoCronograma({
    super.key,
    required this.obra,
    required this.resumo,
  });

  final Obra obra;
  final ResumoCronograma resumo;

  @override
  Widget build(BuildContext context) => EntradaDaObra(
    icone: Icons.calendar_month_outlined,
    titulo: 'Cronograma',
    detalhe: resumo.texto,
    alerta: !resumo.emDia,
    aoTocar: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CronogramaScreen(obra: obra)),
    ),
  );
}
