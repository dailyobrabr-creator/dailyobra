import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/checklists_service.dart';
import '../services/compartilhar.dart';
import '../services/diario_service.dart';
import '../services/marca_service.dart';
import '../services/obras_service.dart';
import '../services/pdf_checklist.dart';
import 'componentes.dart';
import 'dia_obra_screen.dart' show MiniaturaFoto;
import 'dinheiro_screen.dart';

/// Histórico das verificações da obra.
class ChecklistsScreen extends StatefulWidget {
  const ChecklistsScreen({
    super.key,
    required this.obra,
    this.hoje,
    this.escolherFoto,
    this.enviarPdf,
  });
  final Obra obra;

  /// Os testes fixam o dia.
  final DateTime? hoje;

  /// Câmera ([true]) ou galeria; os testes trocam por uma foto pronta.
  final Future<XFile?> Function(bool camera)? escolherFoto;

  /// Os testes trocam o envio do PDF.
  final Future<void> Function(Checklist checklist)? enviarPdf;

  @override
  State<ChecklistsScreen> createState() => _ChecklistsScreenState();
}

class _ChecklistsScreenState extends State<ChecklistsScreen> {
  List<Checklist>? _checklists;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final c = await ChecklistsService.instance.listar(widget.obra.id);
      if (mounted) {
        setState(() {
          _checklists = c;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _abrir(Checklist c) async {
    final pendencias = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistScreen(
          obra: widget.obra,
          checklist: c,
          hoje: widget.hoje,
          escolherFoto: widget.escolherFoto,
          enviarPdf: widget.enviarPdf,
        ),
      ),
    );
    await _carregar();
    if (pendencias == null || !mounted) return;
    avisar(
      context,
      pendencias == 0
          ? 'Checklist concluído.'
          : pendencias == 1
          ? 'Checklist concluído. 1 pendência aberta.'
          : 'Checklist concluído. $pendencias pendências abertas.',
    );
  }

  Future<void> _novo() async {
    final modelo = await Navigator.push<ModeloChecklist>(
      context,
      MaterialPageRoute(builder: (_) => const EscolhaDeModeloScreen()),
    );
    if (modelo == null || !mounted) return;
    await _abrir(modelo.novo(widget.hoje ?? DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final checklists = _checklists;
    return Scaffold(
      appBar: AppBar(title: const Text('Qualidade e segurança')),
      floatingActionButton: checklists == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _novo,
              icon: const Icon(Icons.add),
              label: const Text('Novo checklist'),
            ),
      body: _erro != null && checklists == null
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
          : checklists == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : _lista(checklists),
    );
  }

  Widget _lista(List<Checklist> checklists) {
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
          if (checklists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Espaco.s6),
              child: Column(
                children: [
                  Text('Nenhum checklist', style: t.titleMedium),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    'Escolha um modelo pronto de qualidade ou segurança. O que não estiver conforme vira pendência.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          for (final c in checklists) ...[
            _CartaoDoChecklist(checklist: c, aoTocar: () => _abrir(c)),
            const SizedBox(height: Espaco.s2),
          ],
        ],
      ),
    );
  }
}

class _CartaoDoChecklist extends StatelessWidget {
  const _CartaoDoChecklist({required this.checklist, required this.aoTocar});
  final Checklist checklist;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final c = checklist;
    return Painel(
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.titulo, style: t.titleSmall),
                    Text(
                      [
                        dataCurta(c.data),
                        c.tipo.rotulo,
                        if (c.local.isNotEmpty) c.local,
                      ].join(' · '),
                      style: suave,
                    ),
                    const SizedBox(height: Espaco.s1),
                    Text(c.resumo, style: t.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: Espaco.s2),
              Selo(
                c.concluido ? 'Concluído' : 'Rascunho',
                tom: c.concluido ? TomSelo.sucesso : TomSelo.aviso,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista dos modelos prontos. Devolve o escolhido.
class EscolhaDeModeloScreen extends StatelessWidget {
  const EscolhaDeModeloScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Novo checklist')),
      body: ListView(
        padding: const EdgeInsets.all(Espaco.s4),
        children: [
          for (final tipo in TipoChecklist.values.reversed) ...[
            Painel(
              titulo: tipo.rotulo,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, m)
                      in modelosDeChecklist
                          .where((x) => x.tipo == tipo)
                          .indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(m.titulo, style: t.bodyLarge),
                      subtitle: Text(
                        m.itens.isEmpty
                            ? 'Monte com os seus itens'
                            : '${m.itens.length} itens',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, m),
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

/// Um item enquanto está sendo preenchido.
class _Item {
  _Item(ItemChecklist i)
    : texto = i.texto,
      resultado = i.resultado,
      foto = i.fotoPath,
      observacao = TextEditingController(text: i.observacao);

  final String texto;
  ResultadoItem? resultado;
  String? foto;
  final TextEditingController observacao;

  ItemChecklist paraChecklist() => ItemChecklist(
    texto: texto,
    resultado: resultado,
    observacao: observacao.text.trim(),
    fotoPath: foto,
  );
}

/// Preenche um checklist. Depois de concluído, a tela só mostra o que foi registrado.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({
    super.key,
    required this.obra,
    required this.checklist,
    this.hoje,
    this.escolherFoto,
    this.enviarPdf,
  });
  final Obra obra;
  final Checklist checklist;
  final DateTime? hoje;
  final Future<XFile?> Function(bool camera)? escolherFoto;
  final Future<void> Function(Checklist checklist)? enviarPdf;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late final _base = widget.checklist;
  late final _titulo = TextEditingController(text: _base.titulo);
  late final _local = TextEditingController(text: _base.local);
  late final _observacoes = TextEditingController(text: _base.observacoes);
  late final List<_Item> _itens = [for (final i in _base.itens) _Item(i)];
  late DateTime _data = _base.data;
  late EtapaId? _etapa = _base.etapa;
  final _bytes = <String, Uint8List>{};
  Map<String, String> _links = const {};
  String? _erroTitulo;
  bool _ocupado = false;

  bool get _somenteLeitura => _base.concluido;
  bool get _lidera => widget.obra.funcao.lidera;

  @override
  void initState() {
    super.initState();
    _carregarFotos();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _local.dispose();
    _observacoes.dispose();
    for (final i in _itens) {
      i.observacao.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarFotos() async {
    final links = await DiarioService.instance.linksDasFotos([
      for (final i in _itens) ?i.foto,
    ]);
    if (mounted) setState(() => _links = links);
  }

  Checklist _montar() => Checklist(
    id: _base.id,
    modelo: _base.modelo,
    tipo: _base.tipo,
    titulo: _titulo.text.trim(),
    etapa: _etapa,
    local: _local.text.trim(),
    data: _data,
    observacoes: _observacoes.text.trim(),
    concluido: _base.concluido,
    concluidoPor: _base.concluidoPor,
    concluidoEm: _base.concluidoEm,
    itens: [for (final i in _itens) i.paraChecklist()],
  );

  Future<XFile?> _abrirSeletor(bool camera) => ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 80,
  );

  Future<void> _pegarFoto(_Item item, bool camera) async {
    final XFile? foto;
    try {
      foto = await (widget.escolherFoto ?? _abrirSeletor)(camera);
    } catch (_) {
      if (mounted) avisar(context, 'Não foi possível abrir a foto.');
      return;
    }
    if (foto == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final bytes = await foto.readAsBytes();
      if (bytes.length > DiarioService.tamanhoMaximo) {
        if (mounted) avisar(context, 'Use uma foto de até 5 MB.');
        return;
      }
      final caminho = await DiarioService.instance.enviarFoto(
        obraId: widget.obra.id,
        data: _data,
        bytes: bytes,
        nome: foto.name,
      );
      if (mounted) {
        setState(() {
          item.foto = caminho;
          _bytes[caminho] = bytes;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _adicionarItem() async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => const _JanelaNovoItem(),
    );
    if (texto == null || texto.isEmpty || !mounted) return;
    setState(() => _itens.add(_Item(ItemChecklist(texto: texto))));
  }

  Future<void> _salvar({bool concluir = false}) async {
    final c = _montar();
    setState(() {
      _erroTitulo = c.titulo.isEmpty ? 'Diga o nome do checklist.' : null;
    });
    if (c.titulo.isEmpty) return;
    if (c.itens.isEmpty) {
      avisar(context, 'Adicione pelo menos um item.');
      return;
    }
    if (concluir) {
      if (c.faltam > 0) {
        avisar(
          context,
          c.faltam == 1
              ? 'Falta responder 1 item.'
              : 'Faltam responder ${c.faltam} itens.',
        );
        return;
      }
      if (!await _confirmarConclusao(c) || !mounted) return;
    }
    setState(() => _ocupado = true);
    try {
      await ChecklistsService.instance.salvar(
        widget.obra.id,
        c,
        concluir: concluir,
      );
      if (mounted) {
        Navigator.pop(context, concluir ? c.naoConformes : null);
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  Future<bool> _confirmarConclusao(Checklist c) async {
    final n = c.naoConformes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concluir o checklist?'),
        content: Text(
          [
            'Depois de concluído ele não pode ser alterado.',
            if (n == 1) '1 item não conforme vira pendência.',
            if (n > 1) '$n itens não conformes viram pendências.',
          ].join(' '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir este checklist?'),
        content: Text(
          _somenteLeitura
              ? 'As pendências abertas por ele continuam na obra.'
              : 'O que foi preenchido será perdido.',
        ),
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
      await ChecklistsService.instance.excluir(_base.id!);
      if (mounted) Navigator.pop(context);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _gerarPdf() async {
    setState(() => _ocupado = true);
    try {
      await (widget.enviarPdf ?? _enviarPdf)(_montar());
    } catch (_) {
      if (mounted) {
        avisar(context, 'Não foi possível gerar o PDF. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _enviarPdf(Checklist c) async {
    final marcas = MarcaService.instance;
    final marca = await marcas.daObra(widget.obra.id);
    final bytes = await pdfDoChecklist(
      obra: widget.obra,
      checklist: c,
      marca: marca,
      logo: await marcas.logoBytes(marca?.logoPath),
      fotos: await DiarioService.instance.bytesDe([
        for (final i in c.itens)
          if (i.fotoPath != null) FotoDia(caminho: i.fotoPath!),
      ]),
    );
    await compartilharPdf(bytes, nomeDoChecklist(c), titulo: c.titulo);
  }

  Widget _imagem(String caminho) {
    final bytes = _bytes[caminho];
    final link = _links[caminho];
    Widget vazio(BuildContext c) =>
        Center(child: Icon(Icons.image_outlined, color: c.cores.textoSuave));
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (c, _, _) => vazio(c),
      );
    }
    if (link != null) {
      return Image.network(
        link,
        fit: BoxFit.cover,
        errorBuilder: (c, _, _) => vazio(c),
      );
    }
    return vazio(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_base.tipo.rotulo),
        actions: [
          if (_somenteLeitura)
            IconButton(
              tooltip: 'Gerar PDF',
              onPressed: _ocupado ? null : _gerarPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (_base.id != null && widget.obra.funcao.administra)
            IconButton(
              tooltip: 'Excluir checklist',
              onPressed: _ocupado ? null : _excluir,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _somenteLeitura ? _registro() : _formulario(),
      bottomNavigationBar: _somenteLeitura
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s2,
                  Espaco.s4,
                  Espaco.s3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _ocupado ? null : _salvar,
                        child: const Text('Salvar'),
                      ),
                    ),
                    if (_lidera) ...[
                      const SizedBox(width: Espaco.s2),
                      Expanded(
                        child: FilledButton(
                          onPressed: _ocupado
                              ? null
                              : () => _salvar(concluir: true),
                          child: const Text('Concluir'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _formulario() {
    final etapas = nomesDasEtapas(Calculo.de(widget.obra.parametros).resultado);
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        CampoTexto(
          rotulo: 'Nome',
          controller: _titulo,
          obrigatorio: true,
          erro: _erroTitulo,
          maxLength: 160,
        ),
        const SizedBox(height: Espaco.s3),
        CampoTexto(
          rotulo: 'Local',
          controller: _local,
          dica: 'Ex.: sala e cozinha',
          maxLength: 120,
        ),
        const SizedBox(height: Espaco.s3),
        CampoData(
          rotulo: 'Data',
          valor: _data,
          ate: widget.hoje ?? DateTime.now(),
          limpavel: false,
          aoMudar: (d) => setState(() => _data = d ?? _data),
        ),
        const SizedBox(height: Espaco.s3),
        const Rotulo('Etapa'),
        SeletorDeEtapa(
          etapas: etapas,
          valor: _etapa,
          aoMudar: (v) => setState(() => _etapa = v),
        ),
        const SizedBox(height: Espaco.s4),
        for (final (i, item) in _itens.indexed) ...[
          _CartaoDoItem(
            numero: i + 1,
            item: item,
            imagem: item.foto == null ? null : _imagem(item.foto!),
            ocupado: _ocupado,
            aoResponder: (r) => setState(() => item.resultado = r),
            aoPegarFoto: (camera) => _pegarFoto(item, camera),
            aoTirarFoto: () => setState(() => item.foto = null),
          ),
          const SizedBox(height: Espaco.s2),
        ],
        OutlinedButton.icon(
          onPressed: _ocupado ? null : _adicionarItem,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar item'),
        ),
        const SizedBox(height: Espaco.s4),
        const Rotulo('Observações'),
        TextField(
          key: const Key('observacoes'),
          controller: _observacoes,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _registro() {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final c = _base;
    final em = c.concluidoEm;
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Text(c.titulo, style: t.titleLarge),
        Text(
          [dataCurta(c.data), if (c.local.isNotEmpty) c.local].join(' · '),
          style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
        ),
        const SizedBox(height: Espaco.s4),
        Painel(
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinhaValor('Conformes', '${c.conformes}'),
                const SizedBox(height: Espaco.s2),
                LinhaValor('Não conformes', '${c.naoConformes}'),
                const SizedBox(height: Espaco.s2),
                LinhaValor('Não se aplica', '${c.naoSeAplica}'),
                if (c.conformidade != null) ...[
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('Conformidade', '${c.conformidade}%'),
                ],
              ],
            ),
          ),
        ),
        if (c.concluidoPor.isNotEmpty) ...[
          const SizedBox(height: Espaco.s2),
          Text(
            [
              'Concluído por ${c.concluidoPor}',
              if (em != null) 'em ${dataCurta(em)}',
            ].join(' '),
            style: suave,
          ),
        ],
        const SizedBox(height: Espaco.s4),
        Painel(
          titulo: 'Itens',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, item) in c.itens.indexed) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.texto, style: t.bodyLarge),
                      const SizedBox(height: Espaco.s1),
                      Selo(
                        item.resultado?.rotulo ?? 'Sem resposta',
                        tom: switch (item.resultado) {
                          ResultadoItem.ok => TomSelo.sucesso,
                          ResultadoItem.nao => TomSelo.erro,
                          _ => TomSelo.neutro,
                        },
                      ),
                      if (item.observacao.isNotEmpty) ...[
                        const SizedBox(height: Espaco.s1),
                        Text(item.observacao, style: t.bodyMedium),
                      ],
                      if (item.fotoPath != null) ...[
                        const SizedBox(height: Espaco.s2),
                        MiniaturaFoto(
                          imagem: _imagem(item.fotoPath!),
                          aoTocar: () {},
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (c.observacoes.isNotEmpty) ...[
          const SizedBox(height: Espaco.s4),
          Painel(
            titulo: 'Observações',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Text(c.observacoes, style: t.bodyMedium),
            ),
          ),
        ],
      ],
    );
  }
}

/// A janela cuida do próprio campo: ele ainda aparece enquanto ela fecha.
class _JanelaNovoItem extends StatefulWidget {
  const _JanelaNovoItem();

  @override
  State<_JanelaNovoItem> createState() => _JanelaNovoItemState();
}

class _JanelaNovoItemState extends State<_JanelaNovoItem> {
  final _controle = TextEditingController();

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adicionar item'),
    content: SizedBox(
      width: 380,
      child: CampoTexto(
        rotulo: 'O que verificar',
        controller: _controle,
        maxLength: 300,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controle.text.trim()),
        child: const Text('Adicionar'),
      ),
    ],
  );
}

class _CartaoDoItem extends StatelessWidget {
  const _CartaoDoItem({
    required this.numero,
    required this.item,
    required this.imagem,
    required this.ocupado,
    required this.aoResponder,
    required this.aoPegarFoto,
    required this.aoTirarFoto,
  });

  final int numero;
  final _Item item;
  final Widget? imagem;
  final bool ocupado;
  final ValueChanged<ResultadoItem?> aoResponder;
  final ValueChanged<bool> aoPegarFoto;
  final VoidCallback aoTirarFoto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final imagemDoItem = imagem;
    return Painel(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$numero. ${item.texto}', style: t.bodyLarge),
            const SizedBox(height: Espaco.s2),
            Segmentado<ResultadoItem?>(
              valor: item.resultado,
              opcoes: const [
                (ResultadoItem.ok, 'Conforme'),
                (ResultadoItem.nao, 'Não'),
                (ResultadoItem.na, 'N/A'),
              ],
              onChanged: aoResponder,
            ),
            if (item.resultado == ResultadoItem.nao) ...[
              const SizedBox(height: Espaco.s3),
              CampoTexto(
                rotulo: 'O que está errado',
                controller: item.observacao,
                maxLength: 500,
              ),
              const SizedBox(height: Espaco.s2),
              if (imagemDoItem != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: MiniaturaFoto(
                    imagem: imagemDoItem,
                    aoTocar: () {},
                    aoRemover: aoTirarFoto,
                  ),
                )
              else
                Wrap(
                  spacing: Espaco.s2,
                  children: [
                    OutlinedButton.icon(
                      onPressed: ocupado ? null : () => aoPegarFoto(true),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Tirar foto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: ocupado ? null : () => aoPegarFoto(false),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galeria'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Entrada na tela da obra.
class EntradaDosChecklists extends StatefulWidget {
  const EntradaDosChecklists({super.key, required this.obra});
  final Obra obra;

  @override
  State<EntradaDosChecklists> createState() => _EntradaDosChecklistsState();
}

class _EntradaDosChecklistsState extends State<EntradaDosChecklists> {
  List<Checklist>? _checklists;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final c = await ChecklistsService.instance.listar(widget.obra.id);
      if (mounted) setState(() => _checklists = c);
    } on FalhaAoSalvar {
      // Sem a lista, a linha continua levando à tela, que mostra o motivo
    }
  }

  String _detalhe(List<Checklist>? c) {
    if (c == null || c.isEmpty) return 'Modelos prontos para verificar a obra';
    final rascunhos = c.where((x) => !x.concluido).length;
    if (rascunhos == 1) return '1 rascunho para concluir';
    if (rascunhos > 1) return '$rascunhos rascunhos para concluir';
    return c.length == 1 ? '1 checklist' : '${c.length} checklists';
  }

  @override
  Widget build(BuildContext context) => EntradaDaObra(
    icone: Icons.fact_check_outlined,
    titulo: 'Qualidade e segurança',
    detalhe: _detalhe(_checklists),
    aoTocar: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChecklistsScreen(obra: widget.obra)),
      );
      await _carregar();
    },
  );
}
