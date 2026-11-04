import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/caixa_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';

/// Quanto entrou, quanto saiu e como o saldo fica nas próximas semanas.
class CaixaScreen extends StatefulWidget {
  const CaixaScreen({super.key, required this.obra, this.hoje});
  final Obra obra;

  /// Os testes fixam o dia.
  final DateTime? hoje;

  @override
  State<CaixaScreen> createState() => _CaixaScreenState();
}

class _CaixaScreenState extends State<CaixaScreen> {
  DadosCaixa? _dados;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await CaixaService.instance.carregar(
        widget.obra,
        widget.hoje ?? DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _dados = dados;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _abrirEntrada([EntradaCaixa? e]) async {
    final resposta = await showDialog<_RespostaEntrada>(
      context: context,
      builder: (_) => _JanelaEntrada(entrada: e, hoje: widget.hoje),
    );
    if (resposta == null) return;
    try {
      final nova = resposta.entrada;
      if (nova == null) {
        await CaixaService.instance.excluir(e!.id!);
      } else {
        await CaixaService.instance.salvar(widget.obra.id, nova);
      }
      await _carregar();
    } on FalhaAoSalvar catch (erro) {
      if (mounted) avisar(context, erro.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;
    return Scaffold(
      appBar: AppBar(title: const Text('Caixa da obra')),
      floatingActionButton: dados == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _abrirEntrada,
              icon: const Icon(Icons.add),
              label: const Text('Nova entrada'),
            ),
      body: _erro != null && dados == null
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
          : dados == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : _conteudo(dados),
    );
  }

  Widget _conteudo(DadosCaixa dados) {
    final t = Theme.of(context).textTheme;
    final p = dados.previsao;
    final alerta = p.alerta;
    return RefreshIndicator(
      color: context.cores.acao,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Espaco.s4,
          Espaco.s4,
          Espaco.s4,
          Espaco.s10 * 2,
        ),
        children: [
          Painel(
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Saldo em caixa', style: t.bodyMedium),
                  Text(
                    brl.format(p.saldoAtual),
                    style: t.headlineMedium?.copyWith(
                      fontFeatures: numerosTabulares,
                      color: p.saldoAtual < 0 ? context.cores.erro : null,
                    ),
                  ),
                  const SizedBox(height: Espaco.s3),
                  LinhaValor('Recebido', brl.format(p.recebido)),
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('Pago', brl.format(p.pago)),
                  if (p.aPagarAgora > 0) ...[
                    const SizedBox(height: Espaco.s2),
                    LinhaValor('A pagar agora', brl.format(p.aPagarAgora)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Espaco.s4),
          if (!p.temEntradas) ...[
            const Aviso(
              'Lance o que o cliente já pagou e o que vai pagar para ver o saldo das próximas semanas.',
              tom: TomSelo.info,
            ),
            const SizedBox(height: Espaco.s4),
          ],
          if (alerta != null) ...[
            Aviso(alerta, tom: TomSelo.aviso),
            const SizedBox(height: Espaco.s4),
          ],
          Painel(
            titulo: 'Próximas semanas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, s) in p.semanas.indexed) ...[
                  if (i > 0) const Divider(),
                  _LinhaDaSemana(semana: s),
                ],
              ],
            ),
          ),
          if (p.semData > 0 || p.depois > 0) ...[
            const SizedBox(height: Espaco.s2),
            Text(
              [
                if (p.semData > 0)
                  '${brl.format(p.semData)} ainda sem data no cronograma.',
                if (p.depois > 0)
                  '${brl.format(p.depois)} depois destas semanas.',
              ].join(' '),
              style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
            ),
          ],
          const SizedBox(height: Espaco.s4),
          if (dados.entradas.isNotEmpty)
            Painel(
              titulo: 'Entradas',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, e) in dados.entradas.indexed) ...[
                    if (i > 0) const Divider(),
                    _LinhaDaEntrada(
                      entrada: e,
                      aoTocar: () => _abrirEntrada(e),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaDaSemana extends StatelessWidget {
  const _LinhaDaSemana({required this.semana});
  final SemanaDeCaixa semana;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = semana;
    return Padding(
      padding: const EdgeInsets.all(Espaco.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.semana.texto,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Entra ${brlInteiro.format(s.entradas)} · Sai ${brlInteiro.format(s.saidas)}',
                  style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.s2),
          Text(
            brlInteiro.format(s.saldo),
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: numerosTabulares,
              color: s.saldo < 0 ? context.cores.erro : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaDaEntrada extends StatelessWidget {
  const _LinhaDaEntrada({required this.entrada, required this.aoTocar});
  final EntradaCaixa entrada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = entrada;
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.descricao, style: t.bodyLarge),
                  Text(
                    '${brl.format(e.valor)} · ${dataCurta(e.data)}',
                    style: t.bodySmall?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espaco.s2),
            Selo(
              e.recebido ? 'Recebido' : 'Previsto',
              tom: e.recebido ? TomSelo.sucesso : TomSelo.neutro,
            ),
          ],
        ),
      ),
    );
  }
}

/// Com [entrada] nula, o usuário pediu para excluir.
class _RespostaEntrada {
  const _RespostaEntrada(this.entrada);
  final EntradaCaixa? entrada;
}

class _JanelaEntrada extends StatefulWidget {
  const _JanelaEntrada({required this.entrada, this.hoje});
  final EntradaCaixa? entrada;
  final DateTime? hoje;

  @override
  State<_JanelaEntrada> createState() => _JanelaEntradaState();
}

class _JanelaEntradaState extends State<_JanelaEntrada> {
  late final _descricao = TextEditingController(
    text: widget.entrada?.descricao,
  );
  late final _valor = TextEditingController(
    text: widget.entrada == null
        ? ''
        : formatarQuantidade(widget.entrada!.valor),
  );
  late DateTime _data = widget.entrada?.data ?? widget.hoje ?? DateTime.now();
  late bool _recebido = widget.entrada?.recebido ?? true;
  String? _erroDescricao;
  String? _erroValor;

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    super.dispose();
  }

  void _salvar() {
    final texto = _descricao.text.trim();
    final valor = lerNumero(_valor.text);
    final valorOk = !valor.isNaN && valor > 0;
    setState(() {
      _erroDescricao = texto.isEmpty ? 'Diga de onde vem o dinheiro.' : null;
      _erroValor = valorOk ? null : 'Digite um valor maior que zero.';
    });
    if (texto.isEmpty || !valorOk) return;
    Navigator.pop(
      context,
      _RespostaEntrada(
        EntradaCaixa(
          id: widget.entrada?.id,
          descricao: texto,
          valor: valor,
          data: _data,
          recebido: _recebido,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entrada == null ? 'Nova entrada' : 'Editar entrada'),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoTexto(
              rotulo: 'De onde vem',
              controller: _descricao,
              obrigatorio: true,
              dica: 'Ex.: parcela do cliente',
              erro: _erroDescricao,
              maxLength: 200,
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Valor (R\$)',
              controller: _valor,
              obrigatorio: true,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erroValor,
              maxLength: 16,
            ),
            const SizedBox(height: Espaco.s3),
            CampoData(
              rotulo: 'Data',
              valor: _data,
              limpavel: false,
              aoMudar: (d) => setState(() => _data = d ?? _data),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Já recebido'),
              value: _recebido,
              onChanged: (v) => setState(() => _recebido = v),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.entrada != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _RespostaEntrada(null)),
            child: const Text('Excluir'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}

/// Entrada na tela da obra, só para o responsável.
class EntradaDoCaixa extends StatefulWidget {
  const EntradaDoCaixa({super.key, required this.obra});
  final Obra obra;

  @override
  State<EntradaDoCaixa> createState() => _EntradaDoCaixaState();
}

class _EntradaDoCaixaState extends State<EntradaDoCaixa> {
  PrevisaoCaixa? _previsao;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final d = await CaixaService.instance.carregar(
        widget.obra,
        DateTime.now(),
      );
      if (mounted) setState(() => _previsao = d.previsao);
    } on FalhaAoSalvar {
      // Sem os valores, a linha continua levando à tela, que mostra o motivo
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _previsao;
    return EntradaDaObra(
      icone: Icons.account_balance_wallet_outlined,
      titulo: 'Caixa da obra',
      detalhe:
          p?.alerta ??
          (p != null && p.temEntradas
              ? 'Saldo de ${brl.format(p.saldoAtual)}'
              : 'Entradas e previsão das próximas semanas'),
      alerta: p?.alerta != null,
      aoTocar: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CaixaScreen(obra: widget.obra)),
        );
        await _carregar();
      },
    );
  }
}
