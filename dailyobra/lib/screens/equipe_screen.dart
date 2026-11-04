import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/equipe_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';

/// Quem está na obra. O responsável convida, muda funções e tira pessoas; os outros veem a equipe
/// e podem sair.
class EquipeScreen extends StatefulWidget {
  const EquipeScreen({super.key, required this.obra, this.compartilhar});
  final Obra obra;

  /// Os testes trocam o envio do convite.
  final Future<void> Function(String texto)? compartilhar;

  @override
  State<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends State<EquipeScreen> {
  List<MembroObra>? _membros;
  List<ConviteObra> _convites = const [];
  String? _erro;
  bool _ocupado = false;

  bool get _administra => widget.obra.funcao.administra;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final servico = EquipeService.instance;
    try {
      final membros = await servico.equipe(widget.obra.id);
      final convites = _administra
          ? await servico.convites(widget.obra.id)
          : const <ConviteObra>[];
      if (mounted) {
        setState(() {
          _membros = membros;
          _convites = convites;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  /// Faz a ação, avisa se der errado e atualiza a lista. Devolve se deu certo.
  Future<bool> _fazer(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      await _carregar();
      return true;
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
      return false;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String _mensagem(ConviteObra c) => mensagemDoConvite(
    nomeDaObra: widget.obra.nome,
    funcao: c.funcao,
    codigo: c.codigo,
  );

  static Future<void> _compartilhar(String texto) async {
    if (kIsWeb) {
      final link = 'https://wa.me/?text=${Uri.encodeComponent(texto)}';
      await launchUrl(Uri.parse(link), webOnlyWindowName: '_blank');
      return;
    }
    await SharePlus.instance.share(ShareParams(text: texto));
  }

  Future<void> _enviar(ConviteObra c) async {
    try {
      await (widget.compartilhar ?? _compartilhar)(_mensagem(c));
    } catch (_) {
      if (mounted) {
        avisar(context, 'Não foi possível abrir o envio. Use Copiar.');
      }
    }
  }

  Future<void> _copiar(ConviteObra c) async {
    await Clipboard.setData(ClipboardData(text: _mensagem(c)));
    if (mounted) avisar(context, 'Convite copiado.');
  }

  Future<void> _convidar() async {
    final funcao = await showDialog<FuncaoObra>(
      context: context,
      builder: (_) => const _EscolhaDeFuncao(
        titulo: 'Convidar para a obra',
        confirmar: 'Criar convite',
      ),
    );
    if (funcao == null) return;
    ConviteObra? novo;
    final ok = await _fazer(() async {
      novo = await EquipeService.instance.convidar(widget.obra.id, funcao);
    });
    if (ok && novo != null) await _enviar(novo!);
  }

  Future<void> _mudarFuncao(MembroObra m) async {
    final funcao = await showDialog<FuncaoObra>(
      context: context,
      builder: (_) => _EscolhaDeFuncao(
        titulo: 'Função de ${m.nome}',
        confirmar: 'Salvar',
        inicial: m.funcao,
      ),
    );
    if (funcao == null || funcao == m.funcao) return;
    await _fazer(
      () => EquipeService.instance.mudarFuncao(widget.obra.id, m.id, funcao),
    );
  }

  Future<bool> _confirmar({
    required String titulo,
    required String texto,
    required String acao,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.cores.erro),
            onPressed: () => Navigator.pop(c, true),
            child: Text(acao),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _remover(MembroObra m) async {
    final ok = await _confirmar(
      titulo: 'Remover ${m.nome}?',
      texto: 'A pessoa deixa de ver esta obra. O que ela registrou no diário continua lá.',
      acao: 'Remover',
    );
    if (!ok) return;
    await _fazer(() => EquipeService.instance.remover(widget.obra.id, m.id));
  }

  Future<void> _sair(MembroObra eu) async {
    final ok = await _confirmar(
      titulo: 'Sair desta obra?',
      texto: 'Você deixa de ver esta obra. Para voltar, precisa de um novo convite.',
      acao: 'Sair',
    );
    if (!ok || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await EquipeService.instance.remover(widget.obra.id, eu.id);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membros = _membros;
    return Scaffold(
      appBar: AppBar(title: const Text('Equipe da obra')),
      floatingActionButton: _administra && membros != null
          ? FloatingActionButton.extended(
              onPressed: _ocupado ? null : _convidar,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Convidar'),
            )
          : null,
      body: _erro != null && membros == null
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
          : membros == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : _lista(membros),
    );
  }

  Widget _lista(List<MembroObra> membros) {
    final eu = membros.where((m) => m.eu).firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s4,
        Espaco.s4,
        Espaco.s10 * 2,
      ),
      children: [
        Painel(
          titulo: widget.obra.nome,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, m) in membros.indexed) ...[
                if (i > 0) const Divider(),
                _LinhaDaPessoa(
                  membro: m,
                  opcoes: _administra && !m.eu && !_ocupado,
                  aoMudarFuncao: () => _mudarFuncao(m),
                  aoRemover: () => _remover(m),
                ),
              ],
            ],
          ),
        ),
        if (_administra && membros.length == 1 && _convites.isEmpty) ...[
          const SizedBox(height: Espaco.s4),
          const Aviso(
            'Convide o mestre, o estagiário, o empreiteiro e o cliente. Cada um entra com o seu acesso.',
            tom: TomSelo.info,
          ),
        ],
        if (_convites.isNotEmpty) ...[
          const SizedBox(height: Espaco.s4),
          Painel(
            titulo: 'Convites abertos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in _convites.indexed) ...[
                  if (i > 0) const Divider(),
                  _LinhaDoConvite(
                    convite: c,
                    aoEnviar: () => _enviar(c),
                    aoCopiar: () => _copiar(c),
                    aoCancelar: _ocupado
                        ? null
                        : () => _fazer(
                            () => EquipeService.instance.cancelarConvite(c.id),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (eu != null && !eu.funcao.administra) ...[
          const SizedBox(height: Espaco.s4),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.cores.erro,
            ),
            onPressed: _ocupado ? null : () => _sair(eu),
            child: const Text('Sair da obra'),
          ),
        ],
      ],
    );
  }
}

class _LinhaDaPessoa extends StatelessWidget {
  const _LinhaDaPessoa({
    required this.membro,
    required this.opcoes,
    required this.aoMudarFuncao,
    required this.aoRemover,
  });

  final MembroObra membro;
  final bool opcoes;
  final VoidCallback aoMudarFuncao;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s3,
        Espaco.s2,
        Espaco.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membro.eu ? '${membro.nome} (você)' : membro.nome,
                  style: t.bodyLarge,
                ),
                Text(
                  membro.funcao.rotulo,
                  style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
                ),
              ],
            ),
          ),
          if (opcoes)
            PopupMenuButton<String>(
              tooltip: 'Opções de ${membro.nome}',
              onSelected: (v) => v == 'funcao' ? aoMudarFuncao() : aoRemover(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'funcao', child: Text('Mudar função')),
                PopupMenuItem(value: 'remover', child: Text('Remover da obra')),
              ],
            ),
        ],
      ),
    );
  }
}

class _LinhaDoConvite extends StatelessWidget {
  const _LinhaDoConvite({
    required this.convite,
    required this.aoEnviar,
    required this.aoCopiar,
    required this.aoCancelar,
  });

  final ConviteObra convite;
  final VoidCallback aoEnviar;
  final VoidCallback aoCopiar;
  final VoidCallback? aoCancelar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final local = convite.expiraEm.toLocal();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s3,
        Espaco.s4,
        Espaco.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            convite.codigo,
            style: t.titleMedium?.copyWith(fontFeatures: numerosTabulares),
          ),
          Text(
            '${convite.funcao.rotulo} · vale até ${dataCurta(local)}',
            style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
          ),
          Wrap(
            spacing: Espaco.s1,
            children: [
              TextButton(onPressed: aoEnviar, child: const Text('Enviar')),
              TextButton(onPressed: aoCopiar, child: const Text('Copiar')),
              TextButton(onPressed: aoCancelar, child: const Text('Cancelar')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Janela com as funções e o que cada uma pode fazer.
class _EscolhaDeFuncao extends StatefulWidget {
  const _EscolhaDeFuncao({
    required this.titulo,
    required this.confirmar,
    this.inicial = FuncaoObra.mestre,
  });

  final String titulo;
  final String confirmar;
  final FuncaoObra inicial;

  @override
  State<_EscolhaDeFuncao> createState() => _EscolhaDeFuncaoState();
}

class _EscolhaDeFuncaoState extends State<_EscolhaDeFuncao> {
  late FuncaoObra _funcao = widget.inicial;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.titulo),
      scrollable: true,
      contentPadding: const EdgeInsets.symmetric(vertical: Espaco.s3),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in FuncaoObra.convidaveis)
              InkWell(
                onTap: () => setState(() => _funcao = f),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Espaco.s5,
                    vertical: Espaco.s2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        f == _funcao
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: f == _funcao
                            ? context.cores.acao
                            : context.cores.textoSuave,
                      ),
                      const SizedBox(width: Espaco.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.rotulo, style: t.titleSmall),
                            Text(
                              f.descricao,
                              style: t.bodySmall?.copyWith(
                                color: context.cores.textoSuave,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
          onPressed: () => Navigator.pop(context, _funcao),
          child: Text(widget.confirmar),
        ),
      ],
    );
  }
}

/// Entrada da equipe na tela da obra.
class EntradaDaEquipe extends StatelessWidget {
  const EntradaDaEquipe({super.key, required this.obra});
  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Painel(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EquipeScreen(obra: obra)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s4),
          child: Row(
            children: [
              Icon(Icons.groups_outlined, color: context.cores.textoSuave),
              const SizedBox(width: Espaco.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Equipe', style: t.titleSmall),
                    Text(
                      obra.pessoas == 1
                          ? '1 pessoa'
                          : '${obra.pessoas} pessoas',
                      style: t.bodySmall?.copyWith(
                        color: context.cores.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.cores.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}
