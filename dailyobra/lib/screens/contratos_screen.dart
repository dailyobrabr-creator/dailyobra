import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/equipe_service.dart';
import '../services/mao_de_obra_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';
import 'dinheiro_screen.dart';

/// Lista de contratos. O empreiteiro chega aqui e vê só o dele; quem define isso é o banco.
class ContratosAba extends StatefulWidget {
  const ContratosAba({super.key, required this.obra, this.hoje});
  final Obra obra;
  final DateTime? hoje;

  @override
  State<ContratosAba> createState() => _ContratosAbaState();
}

class _ContratosAbaState extends State<ContratosAba> {
  List<ResumoContrato>? _contratos;
  String? _erro;

  bool get _administra => widget.obra.funcao.administra;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final c = await MaoDeObraService.instance.contratos(widget.obra.id);
      if (mounted) {
        setState(() {
          _contratos = c;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _novo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContratoFormScreen(obra: widget.obra)),
    );
    await _carregar();
  }

  Future<void> _abrir(ResumoContrato r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContratoScreen(
          obra: widget.obra,
          contratoId: r.contrato.id!,
          hoje: widget.hoje,
        ),
      ),
    );
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final contratos = _contratos;
    final t = Theme.of(context).textTheme;
    if (_erro != null && contratos == null) {
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
    if (contratos == null) {
      return Center(
        child: CircularProgressIndicator(color: context.cores.acao),
      );
    }
    final etapas = nomesDasEtapas(Calculo.de(widget.obra.parametros).resultado);
    return RefreshIndicator(
      color: context.cores.acao,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(Espaco.s4),
        children: [
          if (_administra) ...[
            OutlinedButton.icon(
              onPressed: _novo,
              icon: const Icon(Icons.add),
              label: const Text('Novo contrato'),
            ),
            const SizedBox(height: Espaco.s4),
          ],
          if (contratos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Espaco.s6),
              child: Column(
                children: [
                  Text('Nenhum contrato', style: t.titleMedium),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    _administra
                        ? 'Registre o serviço e o valor combinado com cada empreiteiro. As medições mostram quanto já pode ser pago.'
                        : 'Quando o responsável registrar um contrato, ele aparece aqui.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          for (final c in contratos) ...[
            _CartaoDoContrato(
              resumo: c,
              etapas: etapas,
              aoTocar: () => _abrir(c),
            ),
            const SizedBox(height: Espaco.s2),
          ],
        ],
      ),
    );
  }
}

/// A tela do empreiteiro: o contrato dele, sem as diárias.
class ContratosScreen extends StatelessWidget {
  const ContratosScreen({super.key, required this.obra, this.hoje});
  final Obra obra;
  final DateTime? hoje;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Meu contrato')),
    body: ContratosAba(obra: obra, hoje: hoje),
  );
}

(String, TomSelo)? _seloDe(ResumoContrato r) {
  if (r.contrato.encerrado) return ('Encerrado', TomSelo.neutro);
  if (r.aguardando) return (SituacaoMedicao.aguardando.rotulo, TomSelo.aviso);
  if (r.medicoes.any((m) => m.situacao == SituacaoMedicao.aprovada)) {
    return (SituacaoMedicao.aprovada.rotulo, TomSelo.info);
  }
  return null;
}

class _CartaoDoContrato extends StatelessWidget {
  const _CartaoDoContrato({
    required this.resumo,
    required this.etapas,
    required this.aoTocar,
  });

  final ResumoContrato resumo;
  final Map<EtapaId, String> etapas;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final c = resumo.contrato;
    final selo = _seloDe(resumo);
    final valor = c.valor;
    return Painel(
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selo != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Selo(selo.$1, tom: selo.$2),
                ),
                const SizedBox(height: Espaco.s2),
              ],
              Text(c.servico, style: t.titleSmall),
              Text([c.empreiteiro, ?etapas[c.etapa]].join(' · '), style: suave),
              const SizedBox(height: Espaco.s2),
              ClipRRect(
                borderRadius: BorderRadius.circular(Raio.sm),
                child: LinearProgressIndicator(
                  value: resumo.percentual / 100,
                  minHeight: 6,
                  color: context.cores.acao,
                  backgroundColor: context.cores.superficieSutil,
                ),
              ),
              const SizedBox(height: Espaco.s1),
              Text(
                valor == null
                    ? '${textoDePercentual(resumo.percentual)} pronto'
                    : '${textoDePercentual(resumo.percentual)} pronto · ${brlInteiro.format(resumo.medido)} de ${brlInteiro.format(valor)}',
                style: suave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Um contrato com as medições. O mestre lança o percentual; o responsável aprova e paga.
class ContratoScreen extends StatefulWidget {
  const ContratoScreen({
    super.key,
    required this.obra,
    required this.contratoId,
    this.hoje,
  });
  final Obra obra;
  final String contratoId;
  final DateTime? hoje;

  @override
  State<ContratoScreen> createState() => _ContratoScreenState();
}

class _ContratoScreenState extends State<ContratoScreen> {
  ResumoContrato? _resumo;
  String? _erro;
  bool _ocupado = false;

  bool get _administra => widget.obra.funcao.administra;
  bool get _lidera => widget.obra.funcao.lidera;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final todos = await MaoDeObraService.instance.contratos(widget.obra.id);
      if (!mounted) return;
      final r = todos.where((c) => c.contrato.id == widget.contratoId);
      setState(() {
        _resumo = r.firstOrNull;
        _erro = r.isEmpty ? 'Contrato não encontrado.' : null;
      });
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _fazer(Future<void> Function() acao, {String? pronto}) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      await _carregar();
      if (mounted && pronto != null) avisar(context, pronto);
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _lancar(ResumoContrato r) async {
    final nova = await showDialog<(double, DateTime, String)>(
      context: context,
      builder: (_) => _JanelaMedicao(resumo: r, hoje: widget.hoje),
    );
    if (nova == null) return;
    await _fazer(
      () => MaoDeObraService.instance.lancarMedicao(
        r.contrato.id!,
        nova.$2,
        nova.$1,
        nova.$3.isEmpty ? null : nova.$3,
      ),
    );
  }

  Future<void> _pagar(Medicao m) async {
    final data = await showDialog<DateTime>(
      context: context,
      builder: (_) => _JanelaPagarMedicao(medicao: m),
    );
    if (data == null) return;
    await _fazer(
      () => MaoDeObraService.instance.pagarMedicao(m.id!, data),
      pronto: 'Pagamento lançado no dinheiro da obra.',
    );
  }

  Future<void> _excluir(Medicao m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Excluir a medição ${m.numero}?'),
        content: const Text('O contrato volta para o percentual anterior.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.cores.erro),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _fazer(() => MaoDeObraService.instance.excluirMedicao(m.id!));
  }

  Future<void> _editar(ResumoContrato r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContratoFormScreen(obra: widget.obra, resumo: r),
      ),
    );
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final r = _resumo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrato'),
        actions: [
          if (_administra && r != null)
            IconButton(
              tooltip: 'Editar contrato',
              onPressed: () => _editar(r),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: r == null
          ? _erro != null
                ? Padding(
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
                  )
                : Center(
                    child: CircularProgressIndicator(color: context.cores.acao),
                  )
          : _conteudo(r),
      bottomNavigationBar: _lidera && r != null && r.podeMedir
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s2,
                  Espaco.s4,
                  Espaco.s3,
                ),
                child: FilledButton(
                  onPressed: _ocupado ? null : () => _lancar(r),
                  child: const Text('Lançar medição'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _conteudo(ResumoContrato r) {
    final t = Theme.of(context).textTheme;
    final c = r.contrato;
    final valor = c.valor;
    final etapa = nomesDasEtapas(
      Calculo.de(widget.obra.parametros).resultado,
    )[c.etapa];
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Text(c.servico, style: t.titleLarge),
        Text(
          [c.empreiteiro, ?etapa].join(' · '),
          style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
        ),
        const SizedBox(height: Espaco.s4),
        if (c.encerrado) ...[
          const Aviso('Contrato encerrado.', tom: TomSelo.info),
          const SizedBox(height: Espaco.s4),
        ],
        Painel(
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinhaValor('Pronto', textoDePercentual(r.percentual)),
                if (valor != null) ...[
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('Valor do contrato', brl.format(valor)),
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('Medido', brl.format(r.medido)),
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('Pago', brl.format(r.pago)),
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('A pagar', brl.format(r.aPagar)),
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('A medir', brl.format(r.aMedir)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.s4),
        if (r.medicoes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Text(
              'Nenhuma medição ainda.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
            ),
          )
        else
          Painel(
            titulo: 'Medições',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, m) in r.medicoes.indexed) ...[
                  if (i > 0) const Divider(),
                  _LinhaDaMedicao(
                    medicao: m,
                    aoAprovar:
                        _administra &&
                            !_ocupado &&
                            m.situacao == SituacaoMedicao.aguardando
                        ? () => _fazer(
                            () =>
                                MaoDeObraService.instance.aprovarMedicao(m.id!),
                          )
                        : null,
                    aoPagar:
                        _administra &&
                            !_ocupado &&
                            m.situacao == SituacaoMedicao.aprovada
                        ? () => _pagar(m)
                        : null,
                    aoExcluir:
                        !_ocupado &&
                            m == r.ultima &&
                            !m.paga &&
                            (_administra || (_lidera && !m.aprovada))
                        ? () => _excluir(m)
                        : null,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LinhaDaMedicao extends StatelessWidget {
  const _LinhaDaMedicao({
    required this.medicao,
    required this.aoAprovar,
    required this.aoPagar,
    required this.aoExcluir,
  });

  final Medicao medicao;
  final VoidCallback? aoAprovar;
  final VoidCallback? aoPagar;
  final VoidCallback? aoExcluir;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final m = medicao;
    final pagaEm = m.pagaEm;
    return Padding(
      padding: const EdgeInsets.all(Espaco.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Medição ${m.numero} · ${dataCurta(m.data)}',
                  style: t.titleSmall,
                ),
              ),
              Selo(
                m.situacao.rotulo,
                tom: switch (m.situacao) {
                  SituacaoMedicao.aguardando => TomSelo.aviso,
                  SituacaoMedicao.aprovada => TomSelo.info,
                  SituacaoMedicao.paga => TomSelo.sucesso,
                },
              ),
            ],
          ),
          const SizedBox(height: Espaco.s1),
          Text(
            [
              '${textoDePercentual(m.percentual)} pronto',
              if (m.valor != null) brl.format(m.valor),
            ].join(' · '),
            style: t.bodyMedium?.copyWith(fontFeatures: numerosTabulares),
          ),
          if (pagaEm != null)
            Text('Paga em ${dataCurta(pagaEm)}', style: suave),
          if (m.observacao.isNotEmpty) Text(m.observacao, style: suave),
          if (aoAprovar != null || aoPagar != null || aoExcluir != null) ...[
            const SizedBox(height: Espaco.s2),
            Wrap(
              spacing: Espaco.s2,
              children: [
                if (aoAprovar != null)
                  FilledButton(
                    onPressed: aoAprovar,
                    child: const Text('Aprovar'),
                  ),
                if (aoPagar != null)
                  FilledButton(onPressed: aoPagar, child: const Text('Pagar')),
                if (aoExcluir != null)
                  TextButton(
                    onPressed: aoExcluir,
                    child: const Text('Excluir'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Devolve o percentual, a data e o comentário.
class _JanelaMedicao extends StatefulWidget {
  const _JanelaMedicao({required this.resumo, this.hoje});
  final ResumoContrato resumo;
  final DateTime? hoje;

  @override
  State<_JanelaMedicao> createState() => _JanelaMedicaoState();
}

class _JanelaMedicaoState extends State<_JanelaMedicao> {
  final _percentual = TextEditingController();
  final _observacao = TextEditingController();
  late DateTime _data = widget.hoje ?? DateTime.now();
  String? _erro;

  @override
  void dispose() {
    _percentual.dispose();
    _observacao.dispose();
    super.dispose();
  }

  double get _anterior => widget.resumo.percentual;

  void _salvar() {
    final p = lerNumero(_percentual.text);
    final ok = !p.isNaN && p > _anterior && p <= 100;
    if (!ok) {
      setState(() {
        _erro =
            'Digite um percentual acima de ${textoDePercentual(_anterior)} e até 100%.';
      });
      return;
    }
    Navigator.pop(context, (p, _data, _observacao.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final valor = widget.resumo.contrato.valor;
    final p = lerNumero(_percentual.text);
    final previa = valor == null || p.isNaN || p <= _anterior || p > 100
        ? null
        : valor * p / 100 - widget.resumo.medido;
    return AlertDialog(
      title: const Text('Lançar medição'),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Até agora: ${textoDePercentual(_anterior)} pronto.',
              style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Total pronto (%)',
              controller: _percentual,
              obrigatorio: true,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erro,
              maxLength: 6,
              onChanged: (_) => setState(() {}),
            ),
            if (previa != null) ...[
              const SizedBox(height: Espaco.s1),
              Text('Esta medição: ${brl.format(previa)}', style: t.titleSmall),
            ],
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Data',
              valor: _data,
              ate: widget.hoje ?? DateTime.now(),
              limpavel: false,
              aoMudar: (d) => setState(() => _data = d ?? _data),
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Observação',
              controller: _observacao,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Lançar')),
      ],
    );
  }
}

class _JanelaPagarMedicao extends StatefulWidget {
  const _JanelaPagarMedicao({required this.medicao});
  final Medicao medicao;

  @override
  State<_JanelaPagarMedicao> createState() => _JanelaPagarMedicaoState();
}

class _JanelaPagarMedicaoState extends State<_JanelaPagarMedicao> {
  var _data = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('Pagar a medição ${widget.medicao.numero}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(brl.format(widget.medicao.valor ?? 0), style: t.titleLarge),
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Data do pagamento',
              valor: _data,
              ate: DateTime.now(),
              limpavel: false,
              aoMudar: (d) => setState(() => _data = d ?? _data),
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
          onPressed: () => Navigator.pop(context, _data),
          child: const Text('Registrar pagamento'),
        ),
      ],
    );
  }
}

/// Novo contrato ou alterar um existente.
class ContratoFormScreen extends StatefulWidget {
  const ContratoFormScreen({super.key, required this.obra, this.resumo});
  final Obra obra;
  final ResumoContrato? resumo;

  @override
  State<ContratoFormScreen> createState() => _ContratoFormScreenState();
}

class _ContratoFormScreenState extends State<ContratoFormScreen> {
  late final _existente = widget.resumo?.contrato;
  late final _empreiteiro = TextEditingController(
    text: _existente?.empreiteiro,
  );
  late final _servico = TextEditingController(text: _existente?.servico);
  late final _valor = TextEditingController(
    text: _existente?.valor == null
        ? ''
        : formatarQuantidade(_existente!.valor!),
  );
  late EtapaId? _etapa = _existente?.etapa;
  late String? _usuario = _existente?.usuario;
  late bool _encerrado = _existente?.encerrado ?? false;
  List<MembroObra> _empreiteiros = const [];
  String? _erroEmpreiteiro;
  String? _erroServico;
  String? _erroValor;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _carregarEquipe();
  }

  @override
  void dispose() {
    _empreiteiro.dispose();
    _servico.dispose();
    _valor.dispose();
    super.dispose();
  }

  Future<void> _carregarEquipe() async {
    try {
      final equipe = await EquipeService.instance.equipe(widget.obra.id);
      if (mounted) {
        setState(() {
          _empreiteiros = [
            for (final m in equipe)
              if (m.funcao == FuncaoObra.empreiteiro) m,
          ];
        });
      }
    } on FalhaAoSalvar {
      // Sem a equipe, o contrato segue sem ligação com alguém do app
    }
  }

  Future<void> _salvar() async {
    final nome = _empreiteiro.text.trim();
    final servico = _servico.text.trim();
    final valor = lerNumero(_valor.text);
    final valorOk = !valor.isNaN && valor > 0;
    setState(() {
      _erroEmpreiteiro = nome.isEmpty ? 'Diga quem é o empreiteiro.' : null;
      _erroServico = servico.isEmpty ? 'Diga qual é o serviço.' : null;
      _erroValor = valorOk ? null : 'Digite um valor maior que zero.';
    });
    if (nome.isEmpty || servico.isEmpty || !valorOk) return;
    setState(() => _ocupado = true);
    try {
      await MaoDeObraService.instance.salvarContrato(
        widget.obra.id,
        Contrato(
          id: _existente?.id,
          empreiteiro: nome,
          usuario: _usuario,
          servico: servico,
          etapa: _etapa,
          valor: valor,
          encerrado: _encerrado,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir este contrato?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.cores.erro),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await MaoDeObraService.instance.excluirContrato(_existente!.id!);
      if (mounted) {
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final podeExcluir = widget.resumo?.medicoes.isEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_existente == null ? 'Novo contrato' : 'Editar contrato'),
        actions: [
          if (podeExcluir)
            IconButton(
              tooltip: 'Excluir contrato',
              onPressed: _ocupado ? null : _excluir,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoTexto(
              rotulo: 'Empreiteiro',
              controller: _empreiteiro,
              obrigatorio: true,
              erro: _erroEmpreiteiro,
              maxLength: 120,
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(
              rotulo: 'Serviço',
              controller: _servico,
              obrigatorio: true,
              dica: 'Ex.: reboco interno',
              erro: _erroServico,
              maxLength: 200,
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(
              rotulo: 'Valor do contrato (R\$)',
              controller: _valor,
              obrigatorio: true,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erroValor,
              maxLength: 16,
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Etapa'),
            SeletorDeEtapa(
              etapas: nomesDasEtapas(
                Calculo.de(widget.obra.parametros).resultado,
              ),
              valor: _etapa,
              aoMudar: (v) => setState(() => _etapa = v),
            ),
            if (_empreiteiros.isNotEmpty) ...[
              const SizedBox(height: Espaco.s4),
              const Rotulo('Quem acompanha pelo app'),
              DropdownButtonFormField<String?>(
                initialValue: _empreiteiros.any((m) => m.id == _usuario)
                    ? _usuario
                    : null,
                isExpanded: true,
                style: Theme.of(context).textTheme.bodyLarge,
                items: [
                  const DropdownMenuItem(child: Text('Ninguém')),
                  for (final m in _empreiteiros)
                    DropdownMenuItem(value: m.id, child: Text(m.nome)),
                ],
                onChanged: (v) => setState(() => _usuario = v),
              ),
            ],
            if (_existente != null) ...[
              const SizedBox(height: Espaco.s3),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Contrato encerrado'),
                subtitle: const Text('Não recebe mais medições'),
                value: _encerrado,
                onChanged: (v) => setState(() => _encerrado = v),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s2,
            Espaco.s4,
            Espaco.s3,
          ),
          child: FilledButton(
            onPressed: _ocupado ? null : _salvar,
            child: const Text('Salvar'),
          ),
        ),
      ),
    );
  }
}

/// Entrada do empreiteiro na tela da obra.
class EntradaDoContrato extends StatelessWidget {
  const EntradaDoContrato({super.key, required this.obra});
  final Obra obra;

  @override
  Widget build(BuildContext context) => EntradaDaObra(
    icone: Icons.handshake_outlined,
    titulo: 'Meu contrato',
    detalhe: 'Medições e pagamentos',
    aoTocar: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContratosScreen(obra: obra)),
    ),
  );
}
