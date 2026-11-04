import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/compartilhar.dart';
import '../services/equipe_service.dart';
import '../services/mudancas_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';

/// Tudo o que saiu do combinado com o cliente. O responsável pede, o cliente responde, e a
/// resposta fica guardada com nome e data.
class MudancasScreen extends StatefulWidget {
  const MudancasScreen({super.key, required this.obra, this.compartilhar});
  final Obra obra;

  /// Os testes trocam o envio da mensagem.
  final Future<void> Function(String texto)? compartilhar;

  @override
  State<MudancasScreen> createState() => _MudancasScreenState();
}

class _MudancasScreenState extends State<MudancasScreen> {
  List<Mudanca>? _mudancas;
  String? _erro;
  bool _ocupado = false;
  bool _semCliente = false;

  bool get _administra => widget.obra.funcao.administra;
  bool get _cliente => widget.obra.funcao == FuncaoObra.cliente;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final mudancas = await MudancasService.instance.listar(widget.obra.id);
      if (mounted) {
        setState(() {
          _mudancas = mudancas;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
    if (_administra) await _verSeTemCliente();
  }

  Future<void> _verSeTemCliente() async {
    try {
      final equipe = await EquipeService.instance.equipe(widget.obra.id);
      if (mounted) {
        setState(() {
          _semCliente = !equipe.any((m) => m.funcao == FuncaoObra.cliente);
        });
      }
    } on FalhaAoSalvar {
      // É só uma dica: sem a equipe, a tela segue sem ela
    }
  }

  Future<void> _abrir([Mudanca? mudanca]) async {
    final salva = await Navigator.push<Mudanca>(
      context,
      MaterialPageRoute(
        builder: (_) => MudancaScreen(obra: widget.obra, mudanca: mudanca),
      ),
    );
    await _carregar();
    if (salva != null && mudanca == null && !_semCliente) {
      await _avisarCliente(salva);
    }
  }

  Future<void> _avisarCliente(Mudanca m) async {
    try {
      await (widget.compartilhar ?? compartilharTexto)(
        mensagemDaMudanca(nomeDaObra: widget.obra.nome, mudanca: m),
      );
    } catch (_) {
      if (mounted) avisar(context, 'Não foi possível abrir o envio.');
    }
  }

  Future<void> _responder(Mudanca m, {required bool aprovar}) async {
    final resposta = await showDialog<String>(
      context: context,
      builder: (_) => _JanelaResposta(mudanca: m, aprovar: aprovar),
    );
    if (resposta == null) return;
    setState(() => _ocupado = true);
    try {
      await MudancasService.instance.responder(
        m.id!,
        aprovar: aprovar,
        resposta: resposta.isEmpty ? null : resposta,
      );
      await _carregar();
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mudancas = _mudancas;
    return Scaffold(
      appBar: AppBar(title: const Text('Mudanças da obra')),
      floatingActionButton: _administra && mudancas != null
          ? FloatingActionButton.extended(
              onPressed: _ocupado ? null : _abrir,
              icon: const Icon(Icons.add),
              label: const Text('Nova mudança'),
            )
          : null,
      body: _erro != null && mudancas == null
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
          : mudancas == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : _lista(mudancas),
    );
  }

  Widget _lista(List<Mudanca> mudancas) {
    final t = Theme.of(context).textTheme;
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
          if (_semCliente) ...[
            const Aviso(
              'Esta obra ainda não tem cliente. Convide em Equipe para ele aprovar pelo app.',
              tom: TomSelo.aviso,
            ),
            const SizedBox(height: Espaco.s4),
          ],
          if (mudancas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Espaco.s6),
              child: Column(
                children: [
                  Text('Nenhuma mudança', style: t.titleMedium),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    _administra
                        ? 'Antes de fazer algo fora do combinado, peça a aprovação do cliente. Fica registrado quem aprovou e quando.'
                        : 'Quando o responsável pedir uma aprovação, ela aparece aqui.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          for (final m in mudancas) ...[
            _CartaoDaMudanca(
              mudanca: m,
              cliente: _cliente,
              ocupado: _ocupado,
              aoEditar: _administra && m.pendente ? () => _abrir(m) : null,
              aoAvisar: _administra && m.pendente && !_semCliente
                  ? () => _avisarCliente(m)
                  : null,
              aoAprovar: () => _responder(m, aprovar: true),
              aoRecusar: () => _responder(m, aprovar: false),
            ),
            const SizedBox(height: Espaco.s2),
          ],
        ],
      ),
    );
  }
}

class _CartaoDaMudanca extends StatelessWidget {
  const _CartaoDaMudanca({
    required this.mudanca,
    required this.cliente,
    required this.ocupado,
    required this.aoEditar,
    required this.aoAvisar,
    required this.aoAprovar,
    required this.aoRecusar,
  });

  final Mudanca mudanca;
  final bool cliente;
  final bool ocupado;
  final VoidCallback? aoEditar;
  final VoidCallback? aoAvisar;
  final VoidCallback aoAprovar;
  final VoidCallback aoRecusar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final m = mudanca;
    final registro = m.registroDaResposta;
    return Painel(
      child: InkWell(
        onTap: aoEditar,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Selo(
                m.situacao.rotulo,
                tom: switch (m.situacao) {
                  SituacaoMudanca.pendente => TomSelo.aviso,
                  SituacaoMudanca.aprovada => TomSelo.sucesso,
                  SituacaoMudanca.recusada => TomSelo.erro,
                },
              ),
              const SizedBox(height: Espaco.s2),
              Text(m.titulo, style: t.titleSmall),
              if (m.impacto.isNotEmpty) ...[
                const SizedBox(height: Espaco.s1),
                Text(
                  m.impacto,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: numerosTabulares,
                  ),
                ),
              ],
              if (m.descricao.isNotEmpty) ...[
                const SizedBox(height: Espaco.s1),
                Text(
                  m.descricao,
                  style: t.bodyMedium?.copyWith(
                    color: context.cores.textoSuave,
                  ),
                ),
              ],
              if (registro.isNotEmpty) ...[
                const SizedBox(height: Espaco.s2),
                Text(registro, style: suave),
              ],
              if (m.resposta.isNotEmpty) ...[
                const SizedBox(height: Espaco.s1),
                Text('“${m.resposta}”', style: t.bodySmall),
              ],
              if (cliente && m.pendente) ...[
                const SizedBox(height: Espaco.s3),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: ocupado ? null : aoRecusar,
                        child: const Text('Recusar'),
                      ),
                    ),
                    const SizedBox(width: Espaco.s2),
                    Expanded(
                      child: FilledButton(
                        onPressed: ocupado ? null : aoAprovar,
                        child: const Text('Aprovar'),
                      ),
                    ),
                  ],
                ),
              ],
              if (aoAvisar != null) ...[
                const SizedBox(height: Espaco.s1),
                TextButton(
                  onPressed: aoAvisar,
                  child: const Text('Avisar o cliente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirma a resposta do cliente. Devolve o comentário, vazio quando não há.
class _JanelaResposta extends StatefulWidget {
  const _JanelaResposta({required this.mudanca, required this.aprovar});
  final Mudanca mudanca;
  final bool aprovar;

  @override
  State<_JanelaResposta> createState() => _JanelaRespostaState();
}

class _JanelaRespostaState extends State<_JanelaResposta> {
  final _comentario = TextEditingController();

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = widget.mudanca;
    return AlertDialog(
      title: Text(
        widget.aprovar ? 'Aprovar esta mudança?' : 'Recusar esta mudança?',
      ),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(m.titulo, style: t.titleSmall),
            if (m.impacto.isNotEmpty) Text(m.impacto, style: t.bodyMedium),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Comentário',
              controller: _comentario,
              maxLength: 500,
            ),
            const SizedBox(height: Espaco.s2),
            Text(
              'Fica registrado com o seu nome e a data. Não dá para trocar a resposta depois.',
              style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _comentario.text.trim()),
          child: Text(widget.aprovar ? 'Aprovar' : 'Recusar'),
        ),
      ],
    );
  }
}

/// Pedido de aprovação: o que muda, quanto custa e quanto muda no prazo.
class MudancaScreen extends StatefulWidget {
  const MudancaScreen({super.key, required this.obra, this.mudanca});
  final Obra obra;
  final Mudanca? mudanca;

  @override
  State<MudancaScreen> createState() => _MudancaScreenState();
}

class _MudancaScreenState extends State<MudancaScreen> {
  late final _existente = widget.mudanca;
  late final _titulo = TextEditingController(text: _existente?.titulo);
  late final _descricao = TextEditingController(text: _existente?.descricao);
  late final _valor = TextEditingController(
    text: (_existente?.valor ?? 0) == 0
        ? ''
        : formatarQuantidade(_existente!.valor!.abs()),
  );
  late final _dias = TextEditingController(
    text: (_existente?.dias ?? 0) == 0 ? '' : '${_existente!.dias!.abs()}',
  );

  /// Tirar algo da obra reduz o valor e o prazo; o mesmo sinal vale para os dois.
  late bool _reduz =
      (_existente?.valor ?? 0) < 0 || (_existente?.dias ?? 0) < 0;
  String? _erroTitulo;
  String? _erroValor;
  String? _erroDias;
  bool _ocupado = false;

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _valor.dispose();
    _dias.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final titulo = _titulo.text.trim();
    final textoValor = _valor.text.trim();
    final textoDias = _dias.text.trim();
    final valor = textoValor.isEmpty ? null : lerNumero(textoValor);
    final dias = textoDias.isEmpty ? null : int.tryParse(textoDias);
    final valorOk = valor == null || (!valor.isNaN && valor >= 0);
    final diasOk = textoDias.isEmpty || (dias != null && dias >= 0);
    setState(() {
      _erroTitulo = titulo.isEmpty ? 'Diga qual é a mudança.' : null;
      _erroValor = valorOk ? null : 'Digite um valor válido.';
      _erroDias = diasOk ? null : 'Digite um número de dias.';
    });
    if (titulo.isEmpty || !valorOk || !diasOk) return;
    final sinal = _reduz ? -1 : 1;
    final nova = Mudanca(
      id: _existente?.id,
      titulo: titulo,
      descricao: _descricao.text.trim(),
      valor: valor == null ? null : valor * sinal,
      dias: dias == null ? null : dias * sinal,
    );
    setState(() => _ocupado = true);
    try {
      final id = await MudancasService.instance.salvar(widget.obra.id, nova);
      if (!mounted) return;
      Navigator.pop(
        context,
        Mudanca(
          id: id,
          titulo: nova.titulo,
          descricao: nova.descricao,
          valor: nova.valor,
          dias: nova.dias,
        ),
      );
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
        title: const Text('Excluir esta mudança?'),
        content: const Text('O pedido sai da lista do cliente.'),
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
      await MudancasService.instance.excluir(_existente!.id!);
      if (mounted) Navigator.pop(context);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existente == null ? 'Nova mudança' : 'Editar mudança'),
        actions: [
          if (_existente != null)
            IconButton(
              tooltip: 'Excluir mudança',
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
              rotulo: 'O que muda',
              controller: _titulo,
              obrigatorio: true,
              dica: 'Ex.: trocar o piso da sala',
              erro: _erroTitulo,
              maxLength: 120,
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Detalhes'),
            TextField(
              key: const Key('descricao'),
              controller: _descricao,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Efeito na obra'),
            Segmentado<bool>(
              valor: _reduz,
              opcoes: const [(false, 'Acrescenta'), (true, 'Reduz')],
              onChanged: (v) => setState(() => _reduz = v),
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(
              rotulo: 'Valor (R\$)',
              controller: _valor,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erroValor,
              maxLength: 16,
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(
              rotulo: 'Dias no prazo',
              controller: _dias,
              teclado: TextInputType.number,
              erro: _erroDias,
              maxLength: 4,
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
            child: Text(_existente == null ? 'Pedir aprovação' : 'Salvar'),
          ),
        ),
      ),
    );
  }
}

/// Entrada na tela da obra. Para o cliente, avisa o que espera a resposta dele.
class EntradaDasMudancas extends StatefulWidget {
  const EntradaDasMudancas({super.key, required this.obra});
  final Obra obra;

  @override
  State<EntradaDasMudancas> createState() => _EntradaDasMudancasState();
}

class _EntradaDasMudancasState extends State<EntradaDasMudancas> {
  List<Mudanca>? _mudancas;

  bool get _cliente => widget.obra.funcao == FuncaoObra.cliente;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final m = await MudancasService.instance.listar(widget.obra.id);
      if (mounted) setState(() => _mudancas = m);
    } on FalhaAoSalvar {
      // Sem a lista, a linha continua levando à tela, que mostra o motivo
    }
  }

  String _detalhe(List<Mudanca>? mudancas) {
    if (mudancas == null || mudancas.isEmpty) {
      return _cliente ? 'Nada para aprovar' : 'Peça a aprovação do cliente';
    }
    final abertas = mudancas.where((m) => m.pendente).length;
    if (abertas == 0) {
      return mudancas.length == 1
          ? '1 mudança respondida'
          : '${mudancas.length} mudanças respondidas';
    }
    if (_cliente) {
      return abertas == 1
          ? '1 mudança espera a sua aprovação'
          : '$abertas mudanças esperam a sua aprovação';
    }
    return abertas == 1
        ? '1 aguardando o cliente'
        : '$abertas aguardando o cliente';
  }

  @override
  Widget build(BuildContext context) {
    final mudancas = _mudancas;
    return EntradaDaObra(
      icone: Icons.approval_outlined,
      titulo: 'Mudanças',
      detalhe: _detalhe(mudancas),
      alerta: _cliente && (mudancas?.any((m) => m.pendente) ?? false),
      aoTocar: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MudancasScreen(obra: widget.obra)),
        );
        await _carregar();
      },
    );
  }
}
