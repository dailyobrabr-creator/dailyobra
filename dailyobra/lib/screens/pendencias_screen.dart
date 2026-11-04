import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/diario_service.dart';
import '../services/equipe_service.dart';
import '../services/obras_service.dart';
import '../services/pendencias_service.dart';
import 'componentes.dart';
import 'dia_obra_screen.dart';

String _dias(int n) => n == 1 ? '1 dia' : '$n dias';

Map<EtapaId, String> _nomesDasEtapas(Obra obra) => {
  for (final e
      in Calculo.de(obra.parametros).resultado?.etapas ??
          const <LinhaResultado>[])
    e.etapa: e.nome,
};

/// O que ficou por resolver na obra. É assunto da equipe: o cliente não entra aqui.
class PendenciasScreen extends StatefulWidget {
  const PendenciasScreen({
    super.key,
    required this.obra,
    this.hoje,
    this.escolherFoto,
  });

  final Obra obra;

  /// Os testes fixam o dia.
  final DateTime? hoje;

  /// Câmera ([true]) ou galeria; os testes trocam por uma foto pronta.
  final Future<XFile?> Function(bool camera)? escolherFoto;

  @override
  State<PendenciasScreen> createState() => _PendenciasScreenState();
}

class _PendenciasScreenState extends State<PendenciasScreen> {
  List<Pendencia>? _lista;
  Map<String, String> _links = const {};
  String? _erro;
  bool _verResolvidas = false;
  late final _etapas = _nomesDasEtapas(widget.obra);

  DateTime get _hoje => widget.hoje ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await PendenciasService.instance.listar(widget.obra.id);
      final links = await DiarioService.instance.linksDasFotos([
        for (final p in lista) ?p.fotoPath,
      ]);
      if (mounted) {
        setState(() {
          _lista = lista;
          _links = links;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _abrir([Pendencia? p]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PendenciaScreen(
          obra: widget.obra,
          pendencia: p,
          link: p?.fotoPath == null ? null : _links[p!.fotoPath],
          escolherFoto: widget.escolherFoto,
        ),
      ),
    );
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;
    return Scaffold(
      appBar: AppBar(title: const Text('Pendências')),
      floatingActionButton: lista == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _abrir,
              icon: const Icon(Icons.add),
              label: const Text('Nova pendência'),
            ),
      body: _erro != null && lista == null
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
          : lista == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : _conteudo(lista),
    );
  }

  Widget _conteudo(List<Pendencia> lista) {
    final abertas = lista.where((p) => !p.resolvida).toList();
    final resolvidas = lista.where((p) => p.resolvida).toList();
    final visiveis = _verResolvidas ? resolvidas : abertas;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s4,
        Espaco.s4,
        Espaco.s10 * 2,
      ),
      children: [
        Segmentado<bool>(
          valor: _verResolvidas,
          opcoes: [
            (false, 'Abertas (${abertas.length})'),
            (true, 'Resolvidas (${resolvidas.length})'),
          ],
          onChanged: (v) => setState(() => _verResolvidas = v),
        ),
        const SizedBox(height: Espaco.s4),
        if (visiveis.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Espaco.s6),
            child: Column(
              children: [
                Text(
                  _verResolvidas
                      ? 'Nenhuma pendência resolvida'
                      : 'Nenhuma pendência aberta',
                  style: t.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (!_verResolvidas) ...[
                  const SizedBox(height: Espaco.s2),
                  Text(
                    'Anote o que precisa ser resolvido, com foto, quem resolve e até quando.',
                    style: t.bodyMedium?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        for (final p in visiveis) ...[
          _CartaoDaPendencia(
            pendencia: p,
            nomeDaEtapa: _etapas[p.etapa],
            link: _links[p.fotoPath],
            hoje: _hoje,
            aoTocar: () => _abrir(p),
          ),
          const SizedBox(height: Espaco.s2),
        ],
      ],
    );
  }
}

class _CartaoDaPendencia extends StatelessWidget {
  const _CartaoDaPendencia({
    required this.pendencia,
    required this.nomeDaEtapa,
    required this.link,
    required this.hoje,
    required this.aoTocar,
  });

  final Pendencia pendencia;
  final String? nomeDaEtapa;
  final String? link;
  final DateTime hoje;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = pendencia;
    final prazo = p.prazo;
    final detalhe = [
      ?nomeDaEtapa,
      ?p.responsavelNome,
      if (prazo != null) 'até ${dataCurta(prazo)}',
    ].join(' · ');
    final vencida = p.diasVencida(hoje);
    return Painel(
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (link != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Raio.sm),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.network(
                      link!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          Icon(Icons.image_outlined, color: c.cores.textoSuave),
                    ),
                  ),
                ),
                const SizedBox(width: Espaco.s3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.descricao, style: t.bodyLarge),
                    if (detalhe.isNotEmpty) ...[
                      const SizedBox(height: Espaco.s1),
                      Text(
                        detalhe,
                        style: t.bodySmall?.copyWith(
                          color: context.cores.textoSuave,
                        ),
                      ),
                    ],
                    if (vencida > 0) ...[
                      const SizedBox(height: Espaco.s1),
                      Selo('${_dias(vencida)} vencida', tom: TomSelo.erro),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nova pendência, ou uma que já existe. Quem não pode mexer só lê.
class PendenciaScreen extends StatefulWidget {
  const PendenciaScreen({
    super.key,
    required this.obra,
    this.pendencia,
    this.link,
    this.escolherFoto,
  });

  final Obra obra;
  final Pendencia? pendencia;

  /// Link da foto que já está salva.
  final String? link;
  final Future<XFile?> Function(bool camera)? escolherFoto;

  @override
  State<PendenciaScreen> createState() => _PendenciaScreenState();
}

class _PendenciaScreenState extends State<PendenciaScreen> {
  late final _descricao = TextEditingController(
    text: widget.pendencia?.descricao,
  );
  late EtapaId? _etapa = widget.pendencia?.etapa;
  late String? _responsavel = widget.pendencia?.responsavelId;
  late DateTime? _prazo = widget.pendencia?.prazo;
  late String? _foto = widget.pendencia?.fotoPath;
  Uint8List? _bytes;
  List<MembroObra> _equipe = const [];
  late final _etapas = _nomesDasEtapas(widget.obra);
  String? _erro;
  bool _ocupado = false;

  Pendencia? get _existente => widget.pendencia;
  bool get _edita => _existente?.possoMexer ?? true;

  @override
  void initState() {
    super.initState();
    _carregarEquipe();
  }

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _carregarEquipe() async {
    try {
      final equipe = await EquipeService.instance.equipe(widget.obra.id);
      if (mounted) setState(() => _equipe = equipe);
    } on FalhaAoSalvar {
      // Sem a lista, a pendência continua podendo ser salva sem responsável
    }
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
      if (bytes.length > DiarioService.tamanhoMaximo) {
        if (mounted) {
          avisar(context, 'Esta foto passou de 5 MB. Escolha outra.');
        }
        return;
      }
      final caminho = await DiarioService.instance.enviarFoto(
        obraId: widget.obra.id,
        data: DateTime.now(),
        bytes: bytes,
        nome: foto.name,
      );
      if (mounted) {
        setState(() {
          _foto = caminho;
          _bytes = bytes;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Faz a ação e volta para a lista; se der errado, fica aqui com o aviso.
  Future<void> _fazer(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (mounted) Navigator.pop(context);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _salvar() async {
    final texto = _descricao.text.trim();
    if (texto.isEmpty) {
      setState(() => _erro = 'Descreva a pendência.');
      return;
    }
    await _fazer(() async {
      await PendenciasService.instance.salvar(
        widget.obra.id,
        Pendencia(
          id: _existente?.id,
          descricao: texto,
          etapa: _etapa,
          responsavelId: _responsavel,
          responsavelNome: _equipe
              .where((m) => m.id == _responsavel)
              .firstOrNull
              ?.nome,
          prazo: _prazo,
          fotoPath: _foto,
        ),
      );
      final antiga = _existente?.fotoPath;
      if (antiga != null && antiga != _foto) {
        await DiarioService.instance.apagarFotos([antiga]);
      }
    });
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir esta pendência?'),
        content: const Text('Ela some para toda a equipe.'),
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
    await _fazer(() async {
      final foto = await PendenciasService.instance.excluir(_existente!.id!);
      if (foto != null) await DiarioService.instance.apagarFotos([foto]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final existente = _existente;
    return Scaffold(
      appBar: AppBar(
        title: Text(existente == null ? 'Nova pendência' : 'Pendência'),
        actions: [
          if (existente != null && existente.possoMexer)
            IconButton(
              tooltip: 'Excluir',
              onPressed: _ocupado ? null : _excluir,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.s4),
        child: _edita ? _formulario() : _leitura(existente!),
      ),
      bottomNavigationBar: _edita ? _rodape() : null,
    );
  }

  Widget _leitura(Pendencia p) {
    final t = Theme.of(context).textTheme;
    final prazo = p.prazo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.descricao, style: t.titleMedium),
        const SizedBox(height: Espaco.s2),
        for (final linha in [
          ?_etapas[p.etapa],
          ?p.responsavelNome,
          if (prazo != null) 'Prazo: ${dataCurta(prazo)}/${prazo.year}',
          if (p.resolvida) 'Resolvida',
        ])
          Text(
            linha,
            style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
          ),
        if (widget.link != null) ...[
          const SizedBox(height: Espaco.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(Raio.sm),
            child: Image.network(widget.link!),
          ),
        ],
      ],
    );
  }

  Widget _miniatura() {
    final bytes = _bytes;
    final link = _foto == _existente?.fotoPath ? widget.link : null;
    final Widget imagem = bytes != null
        ? Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => const SizedBox(),
          )
        : link != null
        ? Image.network(link, fit: BoxFit.cover)
        : const Icon(Icons.image_outlined);
    return MiniaturaFoto(
      imagem: imagem,
      aoTocar: () {},
      aoRemover: () => setState(() {
        _foto = null;
        _bytes = null;
      }),
    );
  }

  Widget _formulario() {
    final responsaveis = [
      for (final m in _equipe)
        if (m.funcao != FuncaoObra.cliente) (m.id, m.nome),
    ];
    final estilo = Theme.of(context).textTheme.bodyLarge;
    // Quem saiu da obra continua aparecendo até trocarem
    final atual = _existente;
    if (_responsavel != null &&
        !responsaveis.any((r) => r.$1 == _responsavel)) {
      responsaveis.add((_responsavel!, atual?.responsavelNome ?? 'Sem nome'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Rotulo('O que precisa ser resolvido', obrigatorio: true),
        TextField(
          key: const Key('descricao'),
          controller: _descricao,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(errorText: _erro, counterText: ''),
        ),
        const SizedBox(height: Espaco.s4),
        const Rotulo('Etapa'),
        DropdownButtonFormField<EtapaId?>(
          initialValue: _etapa,
          isExpanded: true,
          style: estilo,
          items: [
            const DropdownMenuItem(child: Text('Sem etapa')),
            for (final e in _etapas.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _etapa = v),
        ),
        const SizedBox(height: Espaco.s4),
        const Rotulo('Quem resolve'),
        DropdownButtonFormField<String?>(
          key: ValueKey(responsaveis.length),
          initialValue: _responsavel,
          isExpanded: true,
          style: estilo,
          items: [
            const DropdownMenuItem(child: Text('Sem responsável')),
            for (final (id, nome) in responsaveis)
              DropdownMenuItem(value: id, child: Text(nome)),
          ],
          onChanged: (v) => setState(() => _responsavel = v),
        ),
        const SizedBox(height: Espaco.s4),
        CampoData(
          rotulo: 'Prazo',
          valor: _prazo,
          aoMudar: (d) => setState(() => _prazo = d),
        ),
        const SizedBox(height: Espaco.s4),
        const Rotulo('Foto'),
        if (_foto != null)
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
    );
  }

  Widget _rodape() {
    final existente = _existente;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaco.s4,
          Espaco.s2,
          Espaco.s4,
          Espaco.s3,
        ),
        child: Row(
          children: [
            if (existente != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _ocupado
                      ? null
                      : () => _fazer(
                          () => PendenciasService.instance.resolver(
                            existente.id!,
                            !existente.resolvida,
                          ),
                        ),
                  child: Text(
                    existente.resolvida ? 'Reabrir' : 'Marcar como resolvida',
                  ),
                ),
              ),
              const SizedBox(width: Espaco.s2),
            ],
            Expanded(
              child: FilledButton(
                onPressed: _ocupado ? null : _salvar,
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada das pendências na tela da obra.
class EntradaDasPendencias extends StatelessWidget {
  const EntradaDasPendencias({super.key, required this.obra});
  final Obra obra;

  String _texto(int abertas, int vencidas) {
    if (abertas == 0) return 'Nenhuma aberta';
    final partes = abertas == 1 ? '1 aberta' : '$abertas abertas';
    if (vencidas == 0) return partes;
    return '$partes · ${vencidas == 1 ? '1 vencida' : '$vencidas vencidas'}';
  }

  @override
  Widget build(BuildContext context) {
    final vencidas = obra.pendenciasVencidas(DateTime.now());
    return EntradaDaObra(
      icone: Icons.checklist_outlined,
      titulo: 'Pendências',
      detalhe: _texto(obra.pendenciasAbertas, vencidas),
      alerta: vencidas > 0,
      aoTocar: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PendenciasScreen(obra: obra)),
      ),
    );
  }
}
