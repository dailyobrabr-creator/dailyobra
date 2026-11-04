import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/dinheiro_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';
import 'dia_obra_screen.dart';

// Mesmo laranja do "real" no cronograma, validado para os dois temas
const _realClaro = Color(0xFFA43F05);
const _realEscuro = Color(0xFFE8641C);

Color _corReal(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _realEscuro : _realClaro;

Map<EtapaId, String> _nomesDasEtapas(ResultadoOrcamento? o) => {
  for (final e in o?.etapas ?? const <LinhaResultado>[]) e.etapa: e.nome,
};

ResumoDinheiro _resumo(Obra obra, DadosDinheiro d) {
  final o = Calculo.de(obra.parametros).resultado;
  return resumirDinheiro(
    etapas: o?.etapas ?? const [],
    adicionais: o?.totalAdicionais ?? 0,
    orcado: d.orcado,
    lancamentos: d.lancamentos,
  );
}

/// Orçado x realizado, para o responsável. O mestre entra aqui para lançar e ver o que lançou.
class DinheiroScreen extends StatefulWidget {
  const DinheiroScreen({super.key, required this.obra, this.escolherFoto});
  final Obra obra;

  /// Câmera ([true]) ou galeria; os testes trocam por uma foto pronta.
  final Future<XFile?> Function(bool camera)? escolherFoto;

  @override
  State<DinheiroScreen> createState() => _DinheiroScreenState();
}

class _DinheiroScreenState extends State<DinheiroScreen> {
  DadosDinheiro? _dados;
  String? _erro;
  bool _verLancamentos = false;
  late final _orcamento = Calculo.de(widget.obra.parametros).resultado;
  late final _etapas = _nomesDasEtapas(_orcamento);

  bool get _administra => widget.obra.funcao.administra;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await DinheiroService.instance.carregar(widget.obra.id);
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

  Future<void> _abrirGasto([LancamentoObra? g]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GastoScreen(
          obra: widget.obra,
          gasto: g,
          escolherFoto: widget.escolherFoto,
        ),
      ),
    );
    await _carregar();
  }

  Future<void> _mudarOrcado(LinhaDinheiro linha) async {
    final resposta = await showDialog<_Orcado>(
      context: context,
      builder: (_) => _JanelaOrcado(linha: linha),
    );
    if (resposta == null) return;
    try {
      await DinheiroService.instance.definirOrcado(
        widget.obra.id,
        linha.etapa,
        resposta.valor,
      );
      await _carregar();
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  Future<void> _mudarEtapaDoPedido(LancamentoObra pedido) async {
    final escolha = await showDialog<_Etapa>(
      context: context,
      builder: (_) => _JanelaEtapa(
        titulo: pedido.descricao,
        etapas: _etapas,
        atual: pedido.etapa,
      ),
    );
    if (escolha == null) return;
    try {
      await DinheiroService.instance.classificarPedido(
        pedido.id!,
        escolha.etapa,
      );
      await _carregar();
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;
    return Scaffold(
      appBar: AppBar(
        title: Text(_administra ? 'Dinheiro da obra' : 'Gastos da obra'),
      ),
      floatingActionButton: dados == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _abrirGasto,
              icon: const Icon(Icons.add),
              label: const Text('Lançar gasto'),
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

  Widget _conteudo(DadosDinheiro dados) {
    final resumo = _resumo(widget.obra, dados);
    final lista = _ListaDeLancamentos(
      lancamentos: dados.lancamentos,
      etapas: _etapas,
      aoTocar: (l) {
        if (l.doPedido) {
          _mudarEtapaDoPedido(l);
        } else {
          _abrirGasto(l);
        }
      },
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s4,
        Espaco.s4,
        Espaco.s10 * 2,
      ),
      children: [
        if (!_administra) ...[
          const Aviso(
            'Aqui aparecem os gastos que você lançou. O total da obra fica com o responsável.',
            tom: TomSelo.info,
          ),
          const SizedBox(height: Espaco.s4),
          lista,
        ] else ...[
          _Resumo(resumo: resumo),
          if (resumo.alerta != null) ...[
            const SizedBox(height: Espaco.s3),
            Aviso(resumo.alerta!, tom: TomSelo.aviso),
          ],
          const SizedBox(height: Espaco.s4),
          Segmentado<bool>(
            valor: _verLancamentos,
            opcoes: [
              (false, 'Por etapa'),
              (true, 'Lançamentos (${dados.lancamentos.length})'),
            ],
            onChanged: (v) => setState(() => _verLancamentos = v),
          ),
          const SizedBox(height: Espaco.s4),
          if (_verLancamentos)
            lista
          else
            Painel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, l) in resumo.linhas.indexed) ...[
                    if (i > 0) const Divider(),
                    _LinhaDaEtapa(linha: l, aoTocar: () => _mudarOrcado(l)),
                  ],
                  if (resumo.semEtapa > 0) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(Espaco.s4),
                      child: LinhaValor(
                        'Sem etapa',
                        brl.format(resumo.semEtapa),
                      ),
                    ),
                  ],
                  if (resumo.adicionais > 0) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(Espaco.s4),
                      child: LinhaValor(
                        'Adicionais orçados',
                        brl.format(resumo.adicionais),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.resumo});
  final ResumoDinheiro resumo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodyMedium?.copyWith(color: context.cores.textoSuave);
    final saldo = resumo.saldo;
    return Painel(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Realizado', style: t.labelMedium),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                brl.format(resumo.realizado),
                style: t.headlineMedium?.copyWith(
                  fontFeatures: numerosTabulares,
                ),
              ),
            ),
            Text('de ${brl.format(resumo.orcado)} orçados', style: suave),
            const SizedBox(height: Espaco.s3),
            BarraDoOrcado(
              fracao: resumo.orcado > 0 ? resumo.realizado / resumo.orcado : 0,
            ),
            const SizedBox(height: Espaco.s2),
            Text(
              saldo >= 0
                  ? 'Sobram ${brl.format(saldo)}'
                  : 'Passou ${brl.format(-saldo)}',
              style: suave,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quanto do orçado já foi. Passando de 100%, a barra enche e muda de cor; o texto ao lado diz quanto passou.
class BarraDoOrcado extends StatelessWidget {
  const BarraDoOrcado({super.key, required this.fracao});
  final double fracao;

  @override
  Widget build(BuildContext context) {
    final cor = fracao > 1 ? context.cores.erro : _corReal(context);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: fracao.clamp(0, 1).toDouble(),
          minHeight: 6,
          color: cor,
          backgroundColor: context.cores.segPrevista,
        ),
      ),
    );
  }
}

class _LinhaDaEtapa extends StatelessWidget {
  const _LinhaDaEtapa({required this.linha, required this.aoTocar});
  final LinhaDinheiro linha;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final l = linha;
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(l.nome, style: t.titleSmall)),
                if (l.estourou || l.perto) ...[
                  const SizedBox(width: Espaco.s2),
                  Selo(
                    l.estourou
                        ? 'Passou ${brlInteiro.format(l.excedente)}'
                        : 'Perto do limite',
                    tom: l.estourou ? TomSelo.erro : TomSelo.aviso,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Espaco.s2),
            BarraDoOrcado(fracao: l.estourou ? 1.01 : l.fracao),
            const SizedBox(height: Espaco.s2),
            Text(
              '${brlInteiro.format(l.realizado)} de ${brlInteiro.format(l.orcado)}${l.proprio ? ' (seu valor)' : ''}',
              style: suave?.copyWith(fontFeatures: numerosTabulares),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaDeLancamentos extends StatelessWidget {
  const _ListaDeLancamentos({
    required this.lancamentos,
    required this.etapas,
    required this.aoTocar,
  });

  final List<LancamentoObra> lancamentos;
  final Map<EtapaId, String> etapas;
  final ValueChanged<LancamentoObra> aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (lancamentos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Espaco.s6),
        child: Column(
          children: [
            Text(
              'Nenhum gasto lançado',
              style: t.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Espaco.s2),
            Text(
              'Lance o que foi pago fora do app, com a foto da nota. Os pedidos feitos para esta obra entram sozinhos.',
              style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Painel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, l) in lancamentos.indexed) ...[
            if (i > 0) const Divider(),
            InkWell(
              onTap: l.possoMexer ? () => aoTocar(l) : null,
              child: Padding(
                padding: const EdgeInsets.all(Espaco.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.descricao, style: t.bodyLarge),
                          Text(
                            [
                              dataCurta(l.data),
                              if (l.doPedido) 'Pedido do app',
                              etapas[l.etapa] ?? 'Sem etapa',
                              if (!l.doPedido && l.fornecedor.isNotEmpty)
                                l.fornecedor,
                            ].join(' · '),
                            style: t.bodySmall?.copyWith(
                              color: context.cores.textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Espaco.s2),
                    Text(
                      brl.format(l.valor),
                      style: t.bodyLarge?.copyWith(
                        fontFeatures: numerosTabulares,
                      ),
                    ),
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

/// Resposta da janela: valor nulo quer dizer "usar a estimativa".
class _Orcado {
  const _Orcado(this.valor);
  final double? valor;
}

class _JanelaOrcado extends StatefulWidget {
  const _JanelaOrcado({required this.linha});
  final LinhaDinheiro linha;

  @override
  State<_JanelaOrcado> createState() => _JanelaOrcadoState();
}

class _JanelaOrcadoState extends State<_JanelaOrcado> {
  late final _valor = TextEditingController(
    text: widget.linha.proprio ? formatarQuantidade(widget.linha.orcado) : '',
  );
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  void _salvar() {
    final v = lerNumero(_valor.text);
    if (v.isNaN || v < 0) {
      setState(() => _erro = 'Digite um valor.');
      return;
    }
    Navigator.pop(context, _Orcado(v));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.linha;
    return AlertDialog(
      title: Text(l.nome),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Estimativa do app: ${brl.format(l.estimado)}'),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Seu valor orçado (R\$)',
              controller: _valor,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erro,
              maxLength: 16,
            ),
            if (l.proprio) ...[
              const SizedBox(height: Espaco.s2),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, const _Orcado(null)),
                  child: const Text('Usar a estimativa'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}

/// Resposta da janela: etapa nula quer dizer "sem etapa".
class _Etapa {
  const _Etapa(this.etapa);
  final EtapaId? etapa;
}

class _JanelaEtapa extends StatefulWidget {
  const _JanelaEtapa({
    required this.titulo,
    required this.etapas,
    required this.atual,
  });

  final String titulo;
  final Map<EtapaId, String> etapas;
  final EtapaId? atual;

  @override
  State<_JanelaEtapa> createState() => _JanelaEtapaState();
}

class _JanelaEtapaState extends State<_JanelaEtapa> {
  late EtapaId? _etapa = widget.atual;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Rotulo('Em qual etapa este pedido entra'),
            _SeletorDeEtapa(
              etapas: widget.etapas,
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
          onPressed: () => Navigator.pop(context, _Etapa(_etapa)),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _SeletorDeEtapa extends StatelessWidget {
  const _SeletorDeEtapa({
    required this.etapas,
    required this.valor,
    required this.aoMudar,
  });

  final Map<EtapaId, String> etapas;
  final EtapaId? valor;
  final ValueChanged<EtapaId?> aoMudar;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<EtapaId?>(
    initialValue: etapas.containsKey(valor) ? valor : null,
    isExpanded: true,
    style: Theme.of(context).textTheme.bodyLarge,
    items: [
      const DropdownMenuItem(child: Text('Sem etapa')),
      for (final e in etapas.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: aoMudar,
  );
}

/// Lançar ou alterar um gasto de fora do app, com a foto da nota.
class GastoScreen extends StatefulWidget {
  const GastoScreen({
    super.key,
    required this.obra,
    this.gasto,
    this.escolherFoto,
  });

  final Obra obra;
  final LancamentoObra? gasto;
  final Future<XFile?> Function(bool camera)? escolherFoto;

  @override
  State<GastoScreen> createState() => _GastoScreenState();
}

class _GastoScreenState extends State<GastoScreen> {
  late final _descricao = TextEditingController(text: widget.gasto?.descricao);
  late final _valor = TextEditingController(
    text: widget.gasto == null ? '' : formatarQuantidade(widget.gasto!.valor),
  );
  late final _fornecedor = TextEditingController(
    text: widget.gasto?.fornecedor,
  );
  late DateTime _data = widget.gasto?.data ?? DateTime.now();
  late EtapaId? _etapa = widget.gasto?.etapa;
  late TipoGasto _tipo = widget.gasto?.tipo ?? TipoGasto.material;
  late String? _nota = widget.gasto?.notaPath;
  Uint8List? _bytes;
  String? _link;
  String? _erroDescricao;
  String? _erroValor;
  bool _ocupado = false;
  late final _etapas = _nomesDasEtapas(
    Calculo.de(widget.obra.parametros).resultado,
  );

  LancamentoObra? get _existente => widget.gasto;

  @override
  void initState() {
    super.initState();
    _carregarLink();
  }

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    _fornecedor.dispose();
    super.dispose();
  }

  Future<void> _carregarLink() async {
    final nota = _nota;
    if (nota == null) return;
    final links = await DinheiroService.instance.linksDasNotas([nota]);
    if (mounted) setState(() => _link = links[nota]);
  }

  Future<XFile?> _abrirSeletor(bool camera) => ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 80,
  );

  Future<void> _pegarFoto(bool camera) async {
    final XFile? foto;
    try {
      foto = await (widget.escolherFoto ?? _abrirSeletor)(camera);
    } catch (_) {
      if (mounted) {
        avisar(
          context,
          camera
              ? 'Não foi possível abrir a câmera. Confira a permissão do app.'
              : 'Não foi possível abrir a galeria.',
        );
      }
      return;
    }
    if (foto == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final bytes = await foto.readAsBytes();
      if (bytes.length > DinheiroService.tamanhoMaximo) {
        if (mounted) {
          avisar(context, 'Esta foto passou de 5 MB. Escolha outra.');
        }
        return;
      }
      final caminho = await DinheiroService.instance.enviarNota(
        obraId: widget.obra.id,
        bytes: bytes,
        nome: foto.name,
      );
      if (mounted) {
        setState(() {
          _nota = caminho;
          _bytes = bytes;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _salvar() async {
    final texto = _descricao.text.trim();
    final valor = lerNumero(_valor.text);
    final valorOk = !valor.isNaN && valor > 0;
    setState(() {
      _erroDescricao = texto.isEmpty ? 'Diga o que foi pago.' : null;
      _erroValor = valorOk ? null : 'Digite um valor maior que zero.';
    });
    if (texto.isEmpty || !valorOk) return;
    setState(() => _ocupado = true);
    try {
      await DinheiroService.instance.salvarGasto(
        widget.obra.id,
        LancamentoObra(
          id: _existente?.id,
          descricao: texto,
          valor: valor,
          data: _data,
          etapa: _etapa,
          tipo: _tipo,
          fornecedor: _fornecedor.text.trim(),
          notaPath: _nota,
        ),
      );
      final antiga = _existente?.notaPath;
      if (antiga != null && antiga != _nota) {
        await DinheiroService.instance.apagarNotas([antiga]);
      }
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
        title: const Text('Excluir este gasto?'),
        content: const Text('Ele sai da conta da obra.'),
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
    setState(() => _ocupado = true);
    try {
      await DinheiroService.instance.excluirGasto(_existente!.id!);
      if (mounted) Navigator.pop(context);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  Widget _miniatura() {
    final bytes = _bytes;
    final link = _link;
    final Widget imagem = bytes != null
        ? Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => const SizedBox(),
          )
        : link != null
        ? Image.network(link, fit: BoxFit.cover)
        : const Icon(Icons.receipt_long_outlined);
    return MiniaturaFoto(
      imagem: imagem,
      aoTocar: () {},
      aoRemover: () => setState(() {
        _nota = null;
        _bytes = null;
        _link = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existente = _existente;
    return Scaffold(
      appBar: AppBar(
        title: Text(existente == null ? 'Lançar gasto' : 'Gasto'),
        actions: [
          if (existente != null)
            IconButton(
              tooltip: 'Excluir',
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
              rotulo: 'O que foi pago',
              controller: _descricao,
              obrigatorio: true,
              dica: 'Ex.: diária do pedreiro',
              erro: _erroDescricao,
              maxLength: 200,
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(
              rotulo: 'Valor (R\$)',
              controller: _valor,
              obrigatorio: true,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erroValor,
              maxLength: 16,
            ),
            const SizedBox(height: Espaco.s4),
            CampoData(
              rotulo: 'Data',
              valor: _data,
              ate: DateTime.now(),
              limpavel: false,
              aoMudar: (d) => setState(() => _data = d ?? _data),
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Etapa'),
            _SeletorDeEtapa(
              etapas: _etapas,
              valor: _etapa,
              aoMudar: (v) => setState(() => _etapa = v),
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Tipo'),
            DropdownButtonFormField<TipoGasto>(
              initialValue: _tipo,
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyLarge,
              items: [
                for (final t in TipoGasto.values)
                  DropdownMenuItem(value: t, child: Text(t.rotulo)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(
              rotulo: 'Fornecedor',
              controller: _fornecedor,
              maxLength: 120,
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Foto da nota'),
            if (_nota != null)
              Align(alignment: Alignment.centerLeft, child: _miniatura())
            else
              Wrap(
                spacing: Espaco.s2,
                runSpacing: Espaco.s2,
                children: [
                  OutlinedButton.icon(
                    onPressed: _ocupado ? null : () => _pegarFoto(true),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Tirar foto'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _ocupado ? null : () => _pegarFoto(false),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Da galeria'),
                  ),
                ],
              ),
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

/// Entrada na tela da obra: o responsável vê a conta; o mestre, o caminho para lançar.
class EntradaDoDinheiro extends StatefulWidget {
  const EntradaDoDinheiro({super.key, required this.obra});
  final Obra obra;

  @override
  State<EntradaDoDinheiro> createState() => _EntradaDoDinheiroState();
}

class _EntradaDoDinheiroState extends State<EntradaDoDinheiro> {
  ResumoDinheiro? _resumoAtual;

  bool get _administra => widget.obra.funcao.administra;

  @override
  void initState() {
    super.initState();
    if (_administra) _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await DinheiroService.instance.carregar(widget.obra.id);
      if (mounted) setState(() => _resumoAtual = _resumo(widget.obra, dados));
    } on FalhaAoSalvar {
      // Sem os valores, a linha continua levando à tela, que mostra o motivo
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _resumoAtual;
    return EntradaDaObra(
      icone: Icons.payments_outlined,
      titulo: _administra ? 'Dinheiro da obra' : 'Gastos da obra',
      detalhe: !_administra
          ? 'Lance o que foi pago na obra'
          : resumo?.alerta ?? resumo?.texto ?? 'Orçado x realizado',
      alerta: resumo?.alerta != null,
      aoTocar: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DinheiroScreen(obra: widget.obra)),
        );
        if (_administra) await _carregar();
      },
    );
  }
}
