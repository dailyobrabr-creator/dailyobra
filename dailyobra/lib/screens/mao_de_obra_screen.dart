import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/mao_de_obra_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';
import 'contratos_screen.dart';
import 'dinheiro_screen.dart';

/// Quem trabalha na obra: diaristas, de um lado, e empreiteiros, do outro.
class MaoDeObraScreen extends StatefulWidget {
  const MaoDeObraScreen({super.key, required this.obra, this.hoje});
  final Obra obra;

  /// Os testes fixam o dia.
  final DateTime? hoje;

  @override
  State<MaoDeObraScreen> createState() => _MaoDeObraScreenState();
}

class _MaoDeObraScreenState extends State<MaoDeObraScreen> {
  var _contratos = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mão de obra')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s4,
              Espaco.s4,
              0,
            ),
            child: Segmentado<bool>(
              valor: _contratos,
              opcoes: const [(false, 'Diárias'), (true, 'Empreiteiros')],
              onChanged: (v) => setState(() => _contratos = v),
            ),
          ),
          Expanded(
            child: _contratos
                ? ContratosAba(obra: widget.obra, hoje: widget.hoje)
                : DiariasAba(obra: widget.obra, hoje: widget.hoje),
          ),
        ],
      ),
    );
  }
}

/// Marcar quem veio é um toque por pessoa e já fica salvo: é feito em pé, na obra.
class DiariasAba extends StatefulWidget {
  const DiariasAba({super.key, required this.obra, this.hoje});
  final Obra obra;
  final DateTime? hoje;

  @override
  State<DiariasAba> createState() => _DiariasAbaState();
}

class _DiariasAbaState extends State<DiariasAba> {
  late final DateTime _hoje = () {
    final h = widget.hoje ?? DateTime.now();
    return DateTime(h.year, h.month, h.day);
  }();
  late DateTime _dia = _hoje;
  List<Diarista>? _diaristas;
  List<Presenca> _presencas = const [];
  String? _erro;
  bool _ocupado = false;

  bool get _administra => widget.obra.funcao.administra;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final servico = MaoDeObraService.instance;
    try {
      final diaristas = await servico.diaristas(widget.obra.id);
      final presencas = await servico.presencas(widget.obra.id);
      if (mounted) {
        setState(() {
          _diaristas = diaristas;
          _presencas = presencas;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Presenca? _doDia(Diarista d) => _presencas
      .where((p) => p.diaristaId == d.id && mesmoDia(p.data, _dia))
      .firstOrNull;

  Future<void> _marcar(Diarista d, double dias) async {
    setState(() {
      _presencas = [
        for (final p in _presencas)
          if (p.diaristaId != d.id || !mesmoDia(p.data, _dia)) p,
        if (dias > 0) Presenca(diaristaId: d.id!, data: _dia, dias: dias),
      ];
    });
    try {
      await MaoDeObraService.instance.marcarPresenca(d.id!, _dia, dias);
    } on FalhaAoSalvar catch (e) {
      if (!mounted) return;
      avisar(context, e.mensagem);
      await _carregar();
    }
  }

  Future<void> _abrirPessoa([Diarista? d]) async {
    final nova = await showDialog<Diarista>(
      context: context,
      builder: (_) => _JanelaDiarista(diarista: d, comValor: _administra),
    );
    if (nova == null) return;
    setState(() => _ocupado = true);
    try {
      await MaoDeObraService.instance.salvarDiarista(widget.obra.id, nova);
      await _carregar();
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _pagar(double total) async {
    final pagamento = await showDialog<(DateTime, EtapaId?)>(
      context: context,
      builder: (_) => _JanelaPagamento(obra: widget.obra, total: total),
    );
    if (pagamento == null) return;
    setState(() => _ocupado = true);
    try {
      await MaoDeObraService.instance.pagarDiarias(
        widget.obra.id,
        pagamento.$1,
        pagamento.$2,
      );
      await _carregar();
      if (mounted) avisar(context, 'Pagamento lançado no dinheiro da obra.');
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diaristas = _diaristas;
    if (_erro != null && diaristas == null) {
      return Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Aviso(_erro!),
            const SizedBox(height: Espaco.s3),
            OutlinedButton(
              onPressed: _carregar,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    if (diaristas == null) {
      return Center(
        child: CircularProgressIndicator(color: context.cores.acao),
      );
    }
    return _lista(diaristas);
  }

  Widget _lista(List<Diarista> diaristas) {
    final t = Theme.of(context).textTheme;
    final doDia = [
      for (final d in diaristas)
        if (d.ativo || _doDia(d) != null) d,
    ];
    final abertas = diariasEmAberto(diaristas, _presencas);
    final total = totalEmAberto(abertas);
    final semValor = abertas.where((a) => a.valor == null).firstOrNull;
    return RefreshIndicator(
      color: context.cores.acao,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(Espaco.s4),
        children: [
          Painel(
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Dia anterior',
                  onPressed: () => setState(
                    () => _dia = DateTime(_dia.year, _dia.month, _dia.day - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    diaPorExtenso(_dia),
                    textAlign: TextAlign.center,
                    style: t.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo dia',
                  onPressed: mesmoDia(_dia, _hoje)
                      ? null
                      : () => setState(
                          () => _dia = DateTime(
                            _dia.year,
                            _dia.month,
                            _dia.day + 1,
                          ),
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: Espaco.s4),
          if (doDia.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Espaco.s6),
              child: Column(
                children: [
                  Text('Ninguém na lista', style: t.titleMedium),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    'Adicione quem trabalha por dia. Depois é só marcar quem veio.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ),
            )
          else
            Painel(
              titulo: 'Quem veio',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, d) in doDia.indexed) ...[
                    if (i > 0) const Divider(),
                    _LinhaDoDiarista(
                      diarista: d,
                      presenca: _doDia(d),
                      aoMudar: (dias) => _marcar(d, dias),
                      aoEditar: _ocupado ? null : () => _abrirPessoa(d),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: Espaco.s3),
          OutlinedButton.icon(
            onPressed: _ocupado ? null : _abrirPessoa,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Adicionar pessoa'),
          ),
          if (abertas.isNotEmpty) ...[
            const SizedBox(height: Espaco.s4),
            Painel(
              titulo: _administra ? 'A pagar' : 'Dias em aberto',
              child: Padding(
                padding: const EdgeInsets.all(Espaco.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, a) in abertas.indexed) ...[
                      if (i > 0) const SizedBox(height: Espaco.s2),
                      LinhaValor(
                        '${a.diarista.nome} · ${textoDeDias(a.dias)}',
                        !_administra
                            ? ''
                            : a.valor == null
                            ? 'Falta a diária'
                            : brl.format(a.valor),
                      ),
                    ],
                    if (_administra) ...[
                      const SizedBox(height: Espaco.s3),
                      if (semValor != null) ...[
                        Aviso(
                          'Toque em ${semValor.diarista.nome} na lista e defina o valor da diária para pagar.',
                          tom: TomSelo.aviso,
                        ),
                        const SizedBox(height: Espaco.s3),
                      ],
                      FilledButton(
                        onPressed: _ocupado || total <= 0 || semValor != null
                            ? null
                            : () => _pagar(total),
                        child: Text('Pagar ${brl.format(total)}'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaDoDiarista extends StatelessWidget {
  const _LinhaDoDiarista({
    required this.diarista,
    required this.presenca,
    required this.aoMudar,
    required this.aoEditar,
  });

  final Diarista diarista;
  final Presenca? presenca;
  final ValueChanged<double> aoMudar;
  final VoidCallback? aoEditar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = presenca;
    return Padding(
      padding: const EdgeInsets.all(Espaco.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: aoEditar,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(diarista.nome, style: t.bodyLarge),
                      if (diarista.funcao.isNotEmpty)
                        Text(
                          diarista.funcao,
                          style: t.bodySmall?.copyWith(
                            color: context.cores.textoSuave,
                          ),
                        ),
                    ],
                  ),
                ),
                if (p?.pago ?? false) const Selo('Pago', tom: TomSelo.sucesso),
              ],
            ),
          ),
          const SizedBox(height: Espaco.s2),
          if (p?.pago ?? false)
            Text(
              p!.dias == 1 ? 'Dia inteiro' : 'Meio dia',
              style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
            )
          else
            Segmentado<double>(
              valor: p?.dias ?? 0,
              opcoes: const [
                (0, 'Não veio'),
                (0.5, 'Meio dia'),
                (1, 'Dia inteiro'),
              ],
              onChanged: aoMudar,
            ),
        ],
      ),
    );
  }
}

/// Novo ou alterar. O valor da diária só aparece para o responsável.
class _JanelaDiarista extends StatefulWidget {
  const _JanelaDiarista({required this.diarista, required this.comValor});
  final Diarista? diarista;
  final bool comValor;

  @override
  State<_JanelaDiarista> createState() => _JanelaDiaristaState();
}

class _JanelaDiaristaState extends State<_JanelaDiarista> {
  late final _nome = TextEditingController(text: widget.diarista?.nome);
  late final _funcao = TextEditingController(text: widget.diarista?.funcao);
  late final _diaria = TextEditingController(
    text: (widget.diarista?.diaria ?? 0) == 0
        ? ''
        : formatarQuantidade(widget.diarista!.diaria!),
  );
  String? _erroNome;
  String? _erroDiaria;

  @override
  void dispose() {
    _nome.dispose();
    _funcao.dispose();
    _diaria.dispose();
    super.dispose();
  }

  void _salvar({bool ativo = true}) {
    final nome = _nome.text.trim();
    final textoDiaria = _diaria.text.trim();
    final diaria = textoDiaria.isEmpty ? 0.0 : lerNumero(textoDiaria);
    final diariaOk = !diaria.isNaN && diaria >= 0;
    setState(() {
      _erroNome = nome.isEmpty ? 'Diga o nome da pessoa.' : null;
      _erroDiaria = diariaOk ? null : 'Digite um valor válido.';
    });
    if (nome.isEmpty || !diariaOk) return;
    Navigator.pop(
      context,
      Diarista(
        id: widget.diarista?.id,
        nome: nome,
        funcao: _funcao.text.trim(),
        diaria: widget.comValor ? diaria : null,
        ativo: ativo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existente = widget.diarista;
    return AlertDialog(
      title: Text(existente == null ? 'Adicionar pessoa' : existente.nome),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoTexto(
              rotulo: 'Nome',
              controller: _nome,
              obrigatorio: true,
              erro: _erroNome,
              maxLength: 120,
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Função',
              controller: _funcao,
              dica: 'Ex.: pedreiro',
              maxLength: 60,
            ),
            if (widget.comValor) ...[
              const SizedBox(height: Espaco.s3),
              CampoTexto(
                rotulo: 'Valor da diária (R\$)',
                controller: _diaria,
                teclado: const TextInputType.numberWithOptions(decimal: true),
                erro: _erroDiaria,
                maxLength: 12,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (existente != null && existente.ativo)
          TextButton(
            onPressed: () => _salvar(ativo: false),
            child: const Text('Tirar da lista'),
          ),
        if (existente != null && !existente.ativo)
          TextButton(onPressed: _salvar, child: const Text('Voltar à lista')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => _salvar(ativo: existente?.ativo ?? true),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Data e etapa de um pagamento. Devolve o par escolhido.
class _JanelaPagamento extends StatefulWidget {
  const _JanelaPagamento({required this.obra, required this.total});
  final Obra obra;
  final double total;

  @override
  State<_JanelaPagamento> createState() => _JanelaPagamentoState();
}

class _JanelaPagamentoState extends State<_JanelaPagamento> {
  var _data = DateTime.now();
  EtapaId? _etapa;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Pagar as diárias'),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(brl.format(widget.total), style: t.titleLarge),
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Data do pagamento',
              valor: _data,
              ate: DateTime.now(),
              limpavel: false,
              aoMudar: (d) => setState(() => _data = d ?? _data),
            ),
            const SizedBox(height: Espaco.s3),
            const Rotulo('Etapa'),
            SeletorDeEtapa(
              etapas: nomesDasEtapas(
                Calculo.de(widget.obra.parametros).resultado,
              ),
              valor: _etapa,
              aoMudar: (v) => setState(() => _etapa = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_data, _etapa)),
          child: const Text('Registrar pagamento'),
        ),
      ],
    );
  }
}

/// Entrada na tela da obra.
class EntradaDaMaoDeObra extends StatefulWidget {
  const EntradaDaMaoDeObra({super.key, required this.obra});
  final Obra obra;

  @override
  State<EntradaDaMaoDeObra> createState() => _EntradaDaMaoDeObraState();
}

class _EntradaDaMaoDeObraState extends State<EntradaDaMaoDeObra> {
  String? _detalhe;
  bool _alerta = false;

  bool get _administra => widget.obra.funcao.administra;

  @override
  void initState() {
    super.initState();
    if (_administra) _carregar();
  }

  Future<void> _carregar() async {
    final servico = MaoDeObraService.instance;
    final id = widget.obra.id;
    try {
      final contratos = await servico.contratos(id);
      final diarias = totalEmAberto(
        diariasEmAberto(
          await servico.diaristas(id),
          await servico.presencas(id),
        ),
      );
      final aprovar = contratos.where((c) => c.aguardando).length;
      final aPagar = contratos.fold<double>(diarias, (s, c) => s + c.aPagar);
      if (!mounted) return;
      setState(() {
        _alerta = aprovar > 0;
        _detalhe = aprovar == 1
            ? '1 medição para aprovar'
            : aprovar > 1
            ? '$aprovar medições para aprovar'
            : aPagar > 0
            ? '${brl.format(aPagar)} a pagar'
            : null;
      });
    } on FalhaAoSalvar {
      // Sem os valores, a linha continua levando à tela, que mostra o motivo
    }
  }

  @override
  Widget build(BuildContext context) => EntradaDaObra(
    icone: Icons.engineering_outlined,
    titulo: 'Mão de obra',
    detalhe:
        _detalhe ??
        (_administra
            ? 'Diárias e empreiteiros'
            : 'Marque quem veio e lance as medições'),
    alerta: _alerta,
    aoTocar: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MaoDeObraScreen(obra: widget.obra)),
      );
      if (_administra) await _carregar();
    },
  );
}
