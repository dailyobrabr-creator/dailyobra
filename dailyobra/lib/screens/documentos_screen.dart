import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/documentos_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';

/// Os papéis da obra num lugar só, com o aviso do que vai vencer.
class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({
    super.key,
    required this.obra,
    this.hoje,
    this.abrirLink,
    this.escolherArquivo,
  });
  final Obra obra;

  /// Os testes fixam o dia.
  final DateTime? hoje;

  /// Os testes trocam a abertura do arquivo.
  final Future<bool> Function(Uri uri)? abrirLink;

  /// Nome e conteúdo do arquivo; os testes trocam a escolha no aparelho.
  final Future<(String, Uint8List)?> Function()? escolherArquivo;

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  List<Documento>? _documentos;
  String? _erro;

  DateTime get _hoje => widget.hoje ?? DateTime.now();
  bool get _lidera => widget.obra.funcao.lidera;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final d = await DocumentosService.instance.listar(widget.obra.id);
      if (mounted) {
        setState(() {
          _documentos = d;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _abrirForm([Documento? d]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentoScreen(
          obra: widget.obra,
          documento: d,
          escolherArquivo: widget.escolherArquivo,
        ),
      ),
    );
    await _carregar();
  }

  static Future<bool> _abrirNoAparelho(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _abrirArquivo(Documento d) async {
    final caminho = d.caminho;
    if (caminho == null) {
      avisar(context, 'Este documento não tem arquivo.');
      return;
    }
    final link = await DocumentosService.instance.link(caminho);
    if (!mounted) return;
    if (link == null) {
      avisar(context, 'Não foi possível abrir o arquivo. Tente de novo.');
      return;
    }
    final abriu = await (widget.abrirLink ?? _abrirNoAparelho)(Uri.parse(link));
    if (!abriu && mounted) {
      avisar(context, 'Não foi possível abrir o arquivo. Tente de novo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentos = _documentos;
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos da obra')),
      floatingActionButton: _lidera && documentos != null
          ? FloatingActionButton.extended(
              onPressed: _abrirForm,
              icon: const Icon(Icons.add),
              label: const Text('Novo documento'),
            )
          : null,
      body: _erro != null && documentos == null
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
          : documentos == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : _lista(documentos),
    );
  }

  Widget _lista(List<Documento> documentos) {
    final t = Theme.of(context).textTheme;
    final alerta = alertaDeDocumentos(documentos, _hoje);
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
          if (alerta != null) ...[
            Aviso(alerta, tom: TomSelo.aviso),
            const SizedBox(height: Espaco.s4),
          ],
          if (documentos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Espaco.s6),
              child: Column(
                children: [
                  Text('Nenhum documento', style: t.titleMedium),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    _lidera
                        ? 'Guarde a ART, os projetos, o alvará e os contratos. O app avisa antes de vencer.'
                        : 'Quando o responsável liberar um documento, ele aparece aqui.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          for (final tipo in TipoDocumento.values)
            if (documentos.any((d) => d.tipo == tipo)) ...[
              Painel(
                titulo: tipo.rotulo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, d)
                        in documentos.where((x) => x.tipo == tipo).indexed) ...[
                      if (i > 0) const Divider(),
                      _LinhaDoDocumento(
                        documento: d,
                        hoje: _hoje,
                        mostrarAcesso: _lidera,
                        aoAbrir: () => _abrirArquivo(d),
                        aoEditar: d.possoMexer ? () => _abrirForm(d) : null,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Espaco.s3),
            ],
        ],
      ),
    );
  }
}

class _LinhaDoDocumento extends StatelessWidget {
  const _LinhaDoDocumento({
    required this.documento,
    required this.hoje,
    required this.mostrarAcesso,
    required this.aoAbrir,
    required this.aoEditar,
  });

  final Documento documento;
  final DateTime hoje;
  final bool mostrarAcesso;
  final VoidCallback aoAbrir;
  final VoidCallback? aoEditar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final d = documento;
    final situacao = d.situacao(hoje);
    final detalhe = [
      if (d.numero.isNotEmpty) d.numero,
      if (situacao == SituacaoValidade.emDia) d.textoDaValidade(hoje),
    ].join(' · ');
    return InkWell(
      onTap: aoAbrir,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaco.s4,
          Espaco.s3,
          Espaco.s2,
          Espaco.s3,
        ),
        child: Row(
          children: [
            Icon(
              d.caminho == null
                  ? Icons.description_outlined
                  : Icons.attach_file,
              color: context.cores.textoSuave,
            ),
            const SizedBox(width: Espaco.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.titulo, style: t.bodyLarge),
                  if (detalhe.isNotEmpty) Text(detalhe, style: suave),
                  if (mostrarAcesso) Text(d.acesso.rotulo, style: suave),
                  if (situacao == SituacaoValidade.vencido ||
                      situacao == SituacaoValidade.vencendo) ...[
                    const SizedBox(height: Espaco.s1),
                    Selo(
                      d.textoDaValidade(hoje),
                      tom: situacao == SituacaoValidade.vencido
                          ? TomSelo.erro
                          : TomSelo.aviso,
                    ),
                  ],
                ],
              ),
            ),
            if (aoEditar != null)
              IconButton(
                tooltip: 'Editar ${d.titulo}',
                onPressed: aoEditar,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

/// Novo documento ou alterar um existente. O arquivo só sobe ao salvar.
class DocumentoScreen extends StatefulWidget {
  const DocumentoScreen({
    super.key,
    required this.obra,
    this.documento,
    this.escolherArquivo,
  });
  final Obra obra;
  final Documento? documento;
  final Future<(String, Uint8List)?> Function()? escolherArquivo;

  @override
  State<DocumentoScreen> createState() => _DocumentoScreenState();
}

class _DocumentoScreenState extends State<DocumentoScreen> {
  late final _existente = widget.documento;
  late final _titulo = TextEditingController(text: _existente?.titulo);
  late final _numero = TextEditingController(text: _existente?.numero);
  late var _tipo = _existente?.tipo ?? TipoDocumento.art;
  late var _acesso = _existente?.acesso ?? AcessoDocumento.lideres;
  late DateTime? _validade = _existente?.validade;
  late String? _caminho = _existente?.caminho;
  late String _nomeArquivo = _existente?.nomeArquivo ?? '';
  Uint8List? _novoArquivo;
  String? _erroTitulo;
  bool _ocupado = false;

  @override
  void dispose() {
    _titulo.dispose();
    _numero.dispose();
    super.dispose();
  }

  static Future<(String, Uint8List)?> _escolherNoAparelho() async {
    final arquivo = await FilePicker.pickFile(
      dialogTitle: 'Arquivo do documento',
      type: FileType.custom,
      allowedExtensions: DocumentosService.extensoes,
    );
    if (arquivo == null) return null;
    return (arquivo.name, await arquivo.readAsBytes());
  }

  Future<void> _escolher() async {
    final (String, Uint8List)? escolhido;
    try {
      escolhido = await (widget.escolherArquivo ?? _escolherNoAparelho)();
    } catch (_) {
      if (mounted) avisar(context, 'Não foi possível abrir o arquivo.');
      return;
    }
    if (escolhido == null || !mounted) return;
    final (nome, bytes) = escolhido;
    final extensao = nome.toLowerCase().split('.').last;
    if (!DocumentosService.extensoes.contains(extensao)) {
      avisar(context, 'Use um arquivo PDF ou uma imagem.');
      return;
    }
    if (bytes.length > DocumentosService.tamanhoMaximo) {
      avisar(context, 'Use um arquivo de até 20 MB.');
      return;
    }
    setState(() {
      _novoArquivo = bytes;
      _nomeArquivo = nome;
    });
  }

  Future<void> _salvar() async {
    final titulo = _titulo.text.trim();
    setState(() {
      _erroTitulo = titulo.isEmpty ? 'Diga o nome do documento.' : null;
    });
    if (titulo.isEmpty) return;
    setState(() => _ocupado = true);
    final servico = DocumentosService.instance;
    try {
      final antigo = _existente?.caminho;
      final novo = _novoArquivo;
      if (novo != null) {
        _caminho = await servico.enviar(
          obraId: widget.obra.id,
          bytes: novo,
          nome: _nomeArquivo,
        );
      }
      await servico.salvar(
        widget.obra.id,
        Documento(
          id: _existente?.id,
          tipo: _tipo,
          titulo: titulo,
          numero: _numero.text.trim(),
          validade: _validade,
          caminho: _caminho,
          nomeArquivo: _nomeArquivo,
          acesso: _acesso,
        ),
      );
      if (antigo != null && antigo != _caminho) {
        await servico.apagarArquivo(antigo);
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
        title: const Text('Excluir este documento?'),
        content: const Text('O arquivo também será apagado.'),
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
      await DocumentosService.instance.excluir(_existente!.id!);
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
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_existente == null ? 'Novo documento' : 'Editar documento'),
        actions: [
          if (_existente != null)
            IconButton(
              tooltip: 'Excluir documento',
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
            const Rotulo('Tipo'),
            DropdownButtonFormField<TipoDocumento>(
              initialValue: _tipo,
              isExpanded: true,
              style: t.bodyLarge,
              items: [
                for (final v in TipoDocumento.values)
                  DropdownMenuItem(value: v, child: Text(v.rotulo)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(
              rotulo: 'Nome',
              controller: _titulo,
              obrigatorio: true,
              dica: 'Ex.: ART de execução',
              erro: _erroTitulo,
              maxLength: 160,
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(rotulo: 'Número', controller: _numero, maxLength: 60),
            const SizedBox(height: Espaco.s4),
            CampoData(
              rotulo: 'Vencimento',
              valor: _validade,
              aoMudar: (d) => setState(() => _validade = d),
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Quem pode ver'),
            DropdownButtonFormField<AcessoDocumento>(
              initialValue: _acesso,
              isExpanded: true,
              style: t.bodyLarge,
              items: [
                for (final v in AcessoDocumento.values)
                  DropdownMenuItem(value: v, child: Text(v.rotulo)),
              ],
              onChanged: (v) => setState(() => _acesso = v ?? _acesso),
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Arquivo'),
            if (_nomeArquivo.isNotEmpty) ...[
              Text(_nomeArquivo, style: t.bodyMedium),
              const SizedBox(height: Espaco.s2),
            ],
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _escolher,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _nomeArquivo.isEmpty ? 'Escolher arquivo' : 'Trocar arquivo',
              ),
            ),
            const SizedBox(height: Espaco.s1),
            Text(
              'PDF ou imagem de até 20 MB.',
              style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
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

/// Entrada na tela da obra. O aviso de vencimento é para quem cuida dos documentos.
class EntradaDosDocumentos extends StatefulWidget {
  const EntradaDosDocumentos({super.key, required this.obra});
  final Obra obra;

  @override
  State<EntradaDosDocumentos> createState() => _EntradaDosDocumentosState();
}

class _EntradaDosDocumentosState extends State<EntradaDosDocumentos> {
  List<Documento>? _documentos;

  bool get _lidera => widget.obra.funcao.lidera;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final d = await DocumentosService.instance.listar(widget.obra.id);
      if (mounted) setState(() => _documentos = d);
    } on FalhaAoSalvar {
      // Sem a lista, a linha continua levando à tela, que mostra o motivo
    }
  }

  String _detalhe(List<Documento>? d) {
    if (d == null || d.isEmpty) {
      return _lidera ? 'ART, projetos, alvará e contratos' : 'Nenhum documento';
    }
    return d.length == 1 ? '1 documento' : '${d.length} documentos';
  }

  @override
  Widget build(BuildContext context) {
    final d = _documentos;
    final alerta = !_lidera || d == null
        ? null
        : alertaDeDocumentos(d, DateTime.now());
    return EntradaDaObra(
      icone: Icons.folder_outlined,
      titulo: 'Documentos',
      detalhe: alerta ?? _detalhe(d),
      alerta: alerta != null,
      aoTocar: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentosScreen(obra: widget.obra),
          ),
        );
        await _carregar();
      },
    );
  }
}
