import 'dart:math' as math;

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carrinho_service.dart';
import '../services/catalogo_service.dart';
import '../services/leitura_lista_service.dart';
import 'busca_screen.dart';
import 'componentes.dart';
import 'leitura_da_lista.dart';

/// Resultado da lista inteligente: o que foi reconhecido (com quantidade editável), o que precisa
/// de escolha e o que não está no catálogo. Dá para ir juntando fotos e PDFs: cada um lido entra no fim da lista.
class SmartListScreen extends StatefulWidget {
  const SmartListScreen({
    super.key,
    required this.texto,
    this.lidos = const [],
  });
  final String texto;

  /// Fotos e PDFs que já viraram a lista (vindas do Início).
  final List<ArquivoLido> lidos;

  @override
  State<SmartListScreen> createState() => _SmartListScreenState();
}

class _SmartListScreenState extends State<SmartListScreen> {
  late List<LinhaSmartList> _linhas = interpretarLista(
    widget.texto,
    CatalogoService.instance.itens,
  );

  /// Texto da lista, editável ao lado dos itens no computador.
  late final _texto = TextEditingController(text: widget.texto);

  late final _lidos = [...widget.lidos];
  bool _lendo = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  List<LinhaSmartList> get _reconhecidas =>
      _linhas.where((l) => l.item != null).toList();

  void _reinterpretar(String texto) => setState(
    () => _linhas = interpretarLista(texto, CatalogoService.instance.itens),
  );

  /// Lê a foto ou os arquivos e põe os materiais no fim da lista, sem perder as escolhas já feitas.
  Future<void> _ler(Future<List<ArquivoLista>> Function() escolher) async {
    try {
      final arquivos = await escolher();
      if (arquivos.isEmpty || !mounted) return;
      setState(() => _lendo = true);
      final r = await lerArquivosDaLista(arquivos);
      if (!mounted) return;
      if (r.lidos.isNotEmpty) {
        final atual = _texto.text.trimRight();
        _texto.text = atual.isEmpty ? r.texto : '$atual\n${r.texto}';
        final novas = interpretarLista(r.texto, CatalogoService.instance.itens);
        setState(() {
          _linhas = [..._linhas, ...novas];
          _lidos.addAll(r.lidos);
        });
        final n = novas.length;
        avisar(
          context,
          avisoDaLeitura(r) ??
              (n == 1
                  ? '1 material entrou na lista'
                  : '$n materiais entraram na lista'),
        );
      } else {
        final aviso = avisoDaLeitura(r);
        if (aviso != null) avisar(context, aviso);
      }
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _lendo = false);
    }
  }

  Future<void> _tirarFoto() => _ler(() async {
    final foto = await LeituraListaService.instance.tirarFoto();
    return [?foto];
  });

  Future<void> _anexar() => _ler(LeituraListaService.instance.escolher);

  void _adicionar() {
    final carrinho = CarrinhoService.instance;
    final soma = somarPorItem(_linhas);
    for (final MapEntry(key: id, value: q) in soma.entries) {
      carrinho.adicionar(id, q);
    }
    final n = soma.length;
    irParaAba(context, Aba.orcamentos);
    avisar(
      context,
      n == 1
          ? '1 produto adicionado ao orçamento'
          : '$n produtos adicionados ao orçamento',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final rec = _linhas.where((l) => l.tipo == TipoLinha.reconhecido).length;
    final esc = _linhas.where((l) => l.tipo == TipoLinha.escolher).length;
    final nao = _linhas.where((l) => l.tipo == TipoLinha.naoReconhecido).length;
    final produtos = somarPorItem(_linhas).length;
    final largo = formatoDoContexto(context) == Formato.computador;
    final vazio = EstadoVazio(
      icone: Icons.playlist_add,
      titulo: 'Nenhum material na lista',
      texto: largo
          ? 'Escreva um material por linha, com a quantidade, ou tire uma foto da lista.'
          : 'Tire uma foto da lista ou anexe um PDF. Ex.: 100 sacos de cimento.',
    );
    final botao = FilledButton(
      key: const Key('adicionar-ao-orcamento'),
      onPressed: _reconhecidas.isEmpty ? null : _adicionar,
      child: Text(
        produtos == 0
            ? 'Nenhum produto reconhecido'
            : produtos == 1
            ? 'Adicionar 1 item ao orçamento'
            : 'Adicionar $produtos itens ao orçamento',
      ),
    );
    final resumo = Wrap(
      spacing: Espaco.s2,
      runSpacing: Espaco.s1,
      children: [
        Selo(
          rec == 1 ? '1 reconhecido' : '$rec reconhecidos',
          tom: rec > 0 ? TomSelo.sucesso : TomSelo.neutro,
        ),
        if (esc > 0)
          Selo(
            esc == 1 ? '1 para escolher' : '$esc para escolher',
            tom: TomSelo.info,
          ),
        if (nao > 0)
          Selo(
            nao == 1 ? '1 não reconhecido' : '$nao não reconhecidos',
            tom: TomSelo.aviso,
          ),
      ],
    );
    final linhas = <Widget>[
      for (var i = 0; i < _linhas.length; i++) ...[
        _Linha(
          linha: _linhas[i],
          onEscolher: (item) =>
              setState(() => _linhas[i] = _linhas[i].escolher(item)),
          onQuantidade: (q) =>
              setState(() => _linhas[i] = _linhas[i].comQuantidade(q)),
          onRemover: () => setState(() => _linhas = [..._linhas]..removeAt(i)),
        ),
        if (i < _linhas.length - 1) const SizedBox(height: Espaco.s3),
      ],
    ];
    final acoes = _AcoesDeFoto(
      lendo: _lendo,
      onTirarFoto: _tirarFoto,
      onAnexar: _anexar,
    );

    if (largo) {
      final m = margemLateral(MediaQuery.sizeOf(context).width);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lista inteligente'),
          // O título começa na mesma linha do conteúdo
          titleSpacing: math.max(
            0,
            m -
                ((ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
                    ? kToolbarHeight
                    : 0),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(m, Espaco.s6, m, Espaco.s8),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Cabecalho('Sua lista'),
                      Painel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _texto,
                              minLines: 10,
                              maxLines: 18,
                              keyboardType: TextInputType.multiline,
                              onChanged: _reinterpretar,
                              style: t.bodyLarge,
                              decoration: const InputDecoration(
                                hintText: 'Um material por linha, com a quantidade.\nEx.: 100 sacos de cimento',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.all(Espaco.s4),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(Espaco.s3),
                              decoration: BoxDecoration(
                                color: c.superficieSutil,
                                border: Border(top: BorderSide(color: c.borda)),
                              ),
                              child: acoes,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Espaco.s2),
                      Text(
                        'Mudou o texto? A lista ao lado é lida de novo.',
                        style: t.bodySmall,
                      ),
                      if (_lidos.isNotEmpty) ...[
                        const SizedBox(height: Espaco.s5),
                        Text('Fotos e arquivos lidos', style: t.labelLarge),
                        const SizedBox(height: Espaco.s2),
                        MiniaturasDaLista(lidos: _lidos),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Espaco.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Cabecalho(
                        'Materiais encontrados',
                        direita: _linhas.isEmpty ? null : resumo,
                      ),
                      if (_linhas.isEmpty) vazio else ...linhas,
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _linhas.isEmpty
            ? null
            : _Rodape(
                margem: m,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        produtos == 1
                            ? '1 produto pronto para o orçamento'
                            : '$produtos produtos prontos para o orçamento',
                        style: t.bodyMedium?.copyWith(color: c.textoSuave),
                      ),
                    ),
                    const SizedBox(width: Espaco.s4),
                    SizedBox(width: 320, child: botao),
                  ],
                ),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lista inteligente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Espaco.s4,
          Espaco.s4,
          Espaco.s4,
          Espaco.s8,
        ),
        children: [
          Painel(
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  acoes,
                  if (_lidos.isNotEmpty) ...[
                    const SizedBox(height: Espaco.s3),
                    MiniaturasDaLista(lidos: _lidos),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Espaco.s5),
          if (_linhas.isEmpty)
            vazio
          else ...[
            resumo,
            const SizedBox(height: Espaco.s3),
            ...linhas,
          ],
        ],
      ),
      bottomNavigationBar: _linhas.isEmpty
          ? null
          : _Rodape(margem: Espaco.s4, child: botao),
    );
  }
}

/// Título de coluna com a mesma altura dos dois lados, para as colunas começarem na mesma linha.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho(this.titulo, {this.direita});
  final String titulo;
  final Widget? direita;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Espaco.s3),
    child: SizedBox(
      height: 32,
      child: Row(
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: Espaco.s3),
          const Spacer(),
          ?direita,
        ],
      ),
    ),
  );
}

/// Tirar foto (abre a câmera direto) e anexar PDF ou fotos da galeria. Cada leitura entra no fim da lista.
class _AcoesDeFoto extends StatelessWidget {
  const _AcoesDeFoto({
    required this.lendo,
    required this.onTirarFoto,
    required this.onAnexar,
  });
  final bool lendo;
  final VoidCallback onTirarFoto;
  final VoidCallback onAnexar;

  @override
  Widget build(BuildContext context) {
    if (lendo) {
      return SizedBox(
        height: 40,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Espaco.s3),
            Expanded(
              child: Text(
                'Lendo a lista…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            key: const Key('lista-tirar-foto'),
            onPressed: onTirarFoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('Tirar foto'),
          ),
        ),
        const SizedBox(width: Espaco.s2),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('lista-anexar'),
            onPressed: onAnexar,
            icon: const Icon(Icons.attach_file_rounded, size: 20),
            label: const Text('Anexar arquivo', maxLines: 1),
          ),
        ),
      ],
    );
  }
}

/// Faixa fixa embaixo com o botão principal, alinhada com o conteúdo.
class _Rodape extends StatelessWidget {
  const _Rodape({required this.margem, required this.child});
  final double margem;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        border: Border(top: BorderSide(color: c.borda)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(margem, Espaco.s3, margem, Espaco.s3),
          child: child,
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.linha,
    required this.onEscolher,
    required this.onQuantidade,
    required this.onRemover,
  });
  final LinhaSmartList linha;
  final ValueChanged<ItemCatalogo> onEscolher;
  final ValueChanged<double> onQuantidade;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final remover = IconButton(
      tooltip: 'Tirar da lista',
      onPressed: onRemover,
      icon: const Icon(Icons.close),
    );
    final item = linha.item;

    if (item != null) {
      return Painel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s3,
            Espaco.s3,
            Espaco.s1,
            Espaco.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImagemProduto(item: item, tamanho: 48),
              const SizedBox(width: Espaco.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nome, style: t.titleSmall),
                    Text(
                      'Você escreveu: ${linha.original}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: c.textoSuave),
                    ),
                    const SizedBox(height: Espaco.s2),
                    SeletorQuantidade(
                      valor: linha.quantidade,
                      unidade: item.unidade,
                      minimo: 0.001,
                      onChanged: onQuantidade,
                    ),
                  ],
                ),
              ),
              remover,
            ],
          ),
        ),
      );
    }

    if (linha.tipo == TipoLinha.escolher) {
      return Painel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s3,
            Espaco.s3,
            Espaco.s1,
            Espaco.s2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(linha.original, style: t.titleSmall)),
                  remover,
                ],
              ),
              Text(
                'Qual destes?',
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
              const SizedBox(height: Espaco.s1),
              for (final candidato in linha.candidatos)
                ListTile(
                  contentPadding: const EdgeInsets.only(right: Espaco.s2),
                  leading: ImagemProduto(item: candidato, tamanho: 40),
                  title: Text(candidato.nome, style: t.bodyMedium),
                  subtitle: Text(
                    'por ${candidato.unidade}',
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                  trailing: Icon(
                    Icons.radio_button_unchecked,
                    color: c.textoSuave,
                  ),
                  onTap: () => onEscolher(candidato),
                ),
            ],
          ),
        ),
      );
    }

    return Painel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaco.s3,
          Espaco.s3,
          Espaco.s1,
          Espaco.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    linha.original,
                    style: t.titleSmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Espaco.s2),
                  const Selo('Não reconhecido', tom: TomSelo.aviso),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    'Este produto não está no catálogo com esse nome. Procure por outro nome ou deixe de fora.',
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BuscaScreen(inicial: linha.original),
                      ),
                    ),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Buscar no catálogo'),
                  ),
                ],
              ),
            ),
            remover,
          ],
        ),
      ),
    );
  }
}
