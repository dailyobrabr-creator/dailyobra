import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/anuncios_service.dart';
import '../services/ofertas_service.dart';
import 'componentes.dart';
import 'graficos_resultados.dart';

const _sugestoesDeProduto = 20;
const _maiorLadoDoBanner = 1920.0;

String _diaCurto(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

TomSelo _tomDa(SituacaoAnuncio s) => switch (s) {
  SituacaoAnuncio.ativo => TomSelo.sucesso,
  SituacaoAnuncio.agendado => TomSelo.info,
  SituacaoAnuncio.pausado => TomSelo.aviso,
  SituacaoAnuncio.encerrado => TomSelo.neutro,
};

/// Retail Media: os anúncios da loja com o resultado de cada um. O banner entra no carrossel do Início do construtor e o
/// destaque aparece primeiro na busca, sempre com o aviso de patrocinado.
class AnunciosScreen extends StatefulWidget {
  const AnunciosScreen({super.key});

  @override
  State<AnunciosScreen> createState() => _AnunciosScreenState();
}

class _AnunciosScreenState extends State<AnunciosScreen> {
  final _servico = AnunciosService.instance;

  @override
  void initState() {
    super.initState();
    _servico.carregar();
  }

  void _criar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnuncioFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _servico,
      builder: (context, _) {
        final hoje = DateTime.now();
        final lista = _servico.lista;
        final noAr = lista.where((a) => a.anuncio.noAr(hoje));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Retail Media'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: Espaco.s3),
                child: FilledButton.icon(
                  onPressed: _criar,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Criar anúncio'),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: context.cores.acao,
            onRefresh: _servico.carregar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s4,
                Espaco.s4,
                Espaco.s8,
              ),
              children: [
                if (_servico.erro != null) ...[
                  Aviso(_servico.erro!),
                  const SizedBox(height: Espaco.s3),
                ],
                if (!_servico.carregado && _servico.erro == null)
                  const Esqueleto(altura: 140)
                else if (lista.isEmpty && _servico.erro == null)
                  const EstadoVazio(
                    icone: Icons.campaign_outlined,
                    titulo: 'Nenhum anúncio ainda',
                    texto: 'Crie um banner para o Início do app ou destaque um produto na busca dos construtores.',
                  )
                else ...[
                  Text(
                    noAr.length == 1
                        ? '1 anúncio no ar'
                        : '${noAr.length} anúncios no ar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Espaco.s3),
                  for (final a in lista) ...[
                    _CartaoDoAnuncio(item: a, hoje: hoje),
                    const SizedBox(height: Espaco.s3),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CartaoDoAnuncio extends StatefulWidget {
  const _CartaoDoAnuncio({required this.item, required this.hoje});
  final AnuncioDaLoja item;
  final DateTime hoje;

  @override
  State<_CartaoDoAnuncio> createState() => _CartaoDoAnuncioState();
}

class _CartaoDoAnuncioState extends State<_CartaoDoAnuncio> {
  var _ocupado = false;

  Future<void> _executar(Future<void> Function() acao, String feito) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (mounted) avisar(context, feito);
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _excluir() async {
    if (await confirmar(
      context,
      titulo: 'Excluir o anúncio?',
      texto: 'Ele sai do app e o resultado dele é apagado.',
      acao: 'Excluir',
    )) {
      await _executar(
        () => AnunciosService.instance.excluir(widget.item.anuncio.id),
        'Anúncio excluído.',
      );
    }
  }

  void _editar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnuncioFormScreen(item: widget.item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final item = widget.item;
    final a = item.anuncio;
    final situacao = a.situacao(widget.hoje);
    final taxa = item.taxaDeCliques;
    final vendidos = item.vendidos;
    final url = a.imagemUrl;
    final encerrado = situacao == SituacaoAnuncio.encerrado;
    return Painel(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Espaco.s2,
              runSpacing: Espaco.s1,
              children: [
                Selo(a.tipo.rotulo, tom: TomSelo.info),
                Selo(situacao.rotulo, tom: _tomDa(situacao)),
              ],
            ),
            const SizedBox(height: Espaco.s2),
            if (url != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Raio.md),
                child: SizedBox(
                  height: 96,
                  child: ColoredBox(
                    color: c.cartaoEscuro,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      semanticLabel: a.titulo,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: double.infinity),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Espaco.s2),
            ],
            Text(a.titulo, style: t.titleSmall),
            Text(
              [
                ?item.itemNome,
                '${_diaCurto(a.inicio)} a ${_diaCurto(a.fim)}',
              ].join(' · '),
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
            const SizedBox(height: Espaco.s3),
            Wrap(
              spacing: Espaco.s6,
              runSpacing: Espaco.s2,
              children: [
                _Numero('Impressões', '${item.impressoes}'),
                _Numero('Cliques', '${item.cliques}'),
                _Numero(
                  'Taxa de cliques',
                  taxa == null ? '—' : textoPercentual(taxa),
                ),
                if (vendidos != null)
                  _Numero(
                    'Vendidos no período',
                    '${formatarQuantidade(vendidos)} ${item.unidade ?? ''}'
                        .trim(),
                  ),
              ],
            ),
            const SizedBox(height: Espaco.s3),
            Wrap(
              spacing: Espaco.s2,
              runSpacing: Espaco.s2,
              children: [
                if (!encerrado) ...[
                  OutlinedButton(
                    onPressed: _ocupado
                        ? null
                        : () => _executar(
                            () => AnunciosService.instance.pausar(
                              a.id,
                              pausado: !a.pausado,
                            ),
                            a.pausado
                                ? 'Anúncio retomado.'
                                : 'Anúncio pausado.',
                          ),
                    child: Text(a.pausado ? 'Retomar' : 'Pausar'),
                  ),
                  OutlinedButton(
                    onPressed: _ocupado ? null : _editar,
                    child: const Text('Editar'),
                  ),
                ],
                TextButton(
                  onPressed: _ocupado ? null : _excluir,
                  child: const Text('Excluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.rotulo, this.valor);
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor,
          style: t.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: numerosTabulares,
          ),
        ),
        Text(
          rotulo,
          style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
        ),
      ],
    );
  }
}

/// Cria ou altera um anúncio. O tipo não muda depois de criado.
class AnuncioFormScreen extends StatefulWidget {
  const AnuncioFormScreen({
    super.key,
    this.item,
    this.escolherImagem,
    this.hoje,
  });

  /// Anúncio em edição.
  final AnuncioDaLoja? item;

  /// Testes: entrega a imagem sem abrir a galeria.
  final Future<XFile?> Function()? escolherImagem;

  /// Relógio dos testes; no app, a hora do aparelho.
  final DateTime? hoje;

  @override
  State<AnuncioFormScreen> createState() => _AnuncioFormScreenState();
}

class _AnuncioFormScreenState extends State<AnuncioFormScreen> {
  late final _anuncio = widget.item?.anuncio;
  late var _tipo = _anuncio?.tipo ?? TipoAnuncio.banner;
  late final _titulo = TextEditingController(text: _anuncio?.titulo);
  late String? _imagem = _anuncio?.imagemCaminho;
  late String? _itemId = _anuncio?.itemId;
  late final _hoje = widget.hoje ?? DateTime.now();
  late var _inicio = _anuncio?.inicio ?? DateUtils.dateOnly(_hoje);
  late var _fim =
      _anuncio?.fim ?? DateUtils.dateOnly(_hoje).add(const Duration(days: 7));
  var _enviando = false;
  var _salvando = false;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  Future<XFile?> _daGaleria() => ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: _maiorLadoDoBanner,
    maxHeight: _maiorLadoDoBanner,
    imageQuality: 82,
  );

  Future<void> _escolherImagem() async {
    final arquivo = await (widget.escolherImagem ?? _daGaleria)();
    if (arquivo == null) return;
    setState(() => _enviando = true);
    try {
      final caminho = await AnunciosService.instance.enviarImagem(arquivo);
      if (mounted) setState(() => _imagem = caminho);
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _escolherData({required bool inicio}) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fim,
      firstDate: DateUtils.dateOnly(_hoje).subtract(const Duration(days: 365)),
      lastDate: DateUtils.dateOnly(_hoje).add(const Duration(days: 365)),
      helpText: inicio ? 'Início do anúncio' : 'Fim do anúncio',
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _inicio = escolhida;
        if (_fim.isBefore(escolhida)) _fim = escolhida;
      } else {
        _fim = escolhida;
        if (_inicio.isAfter(escolhida)) _inicio = escolhida;
      }
    });
  }

  String? _problema() {
    if (_titulo.text.trim().length < 3) {
      return 'Dê um título com pelo menos 3 letras.';
    }
    if (_tipo == TipoAnuncio.banner && _imagem == null) {
      return 'Envie a imagem do banner.';
    }
    if (_tipo == TipoAnuncio.destaque && _itemId == null) {
      return 'Escolha o produto do destaque.';
    }
    return null;
  }

  Future<void> _salvar() async {
    final problema = _problema();
    if (problema != null) return avisar(context, problema);
    setState(() => _salvando = true);
    try {
      await AnunciosService.instance.salvar(
        id: _anuncio?.id,
        tipo: _tipo,
        titulo: _titulo.text.trim(),
        imagem: _tipo == TipoAnuncio.banner ? _imagem : null,
        itemId: _tipo == TipoAnuncio.destaque ? _itemId : null,
        inicio: _inicio,
        fim: _fim,
      );
      if (mounted) {
        avisar(context, 'Anúncio salvo.');
        Navigator.pop(context);
      }
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final url = urlPublica(_imagem);
    return Scaffold(
      appBar: AppBar(
        title: Text(_anuncio == null ? 'Criar anúncio' : 'Editar anúncio'),
      ),
      body: ColunaCentral(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s4,
            Espaco.s4,
            Espaco.s8,
          ),
          children: [
            if (_anuncio == null) ...[
              Segmentado<TipoAnuncio>(
                valor: _tipo,
                opcoes: [for (final o in TipoAnuncio.values) (o, o.rotulo)],
                onChanged: (v) => setState(() => _tipo = v),
              ),
              const SizedBox(height: Espaco.s2),
            ],
            Text(
              _tipo == TipoAnuncio.banner
                  ? 'Aparece no carrossel do Início do app dos construtores. Tocar abre a sua loja.'
                  : 'O produto aparece primeiro na busca e nas categorias, com o seu preço e a sua logo.',
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
            const SizedBox(height: Espaco.s4),
            CampoTexto(
              rotulo: 'Título do anúncio',
              controller: _titulo,
              obrigatorio: true,
              ajuda: 'Só a sua loja vê: serve para reconhecer a campanha.',
            ),
            const SizedBox(height: Espaco.s4),
            if (_tipo == TipoAnuncio.banner) ...[
              if (url != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Raio.md),
                  child: Image.network(
                    url,
                    height: 160,
                    fit: BoxFit.contain,
                    semanticLabel: 'Imagem do banner',
                    errorBuilder: (_, _, _) => const SizedBox(height: 40),
                  ),
                ),
                const SizedBox(height: Espaco.s2),
              ],
              OutlinedButton.icon(
                onPressed: _enviando ? null : _escolherImagem,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  _enviando
                      ? 'Enviando…'
                      : url == null
                      ? 'Enviar imagem'
                      : 'Trocar imagem',
                ),
              ),
            ] else
              _EscolhaDoProduto(
                inicial: widget.item?.itemNome,
                aoEscolher: (id) => setState(() => _itemId = id),
              ),
            const SizedBox(height: Espaco.s4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: true),
                    child: Text('Início: ${_diaCurto(_inicio)}'),
                  ),
                ),
                const SizedBox(width: Espaco.s2),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: false),
                    child: Text('Fim: ${_diaCurto(_fim)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaco.s5),
            FilledButton(
              onPressed: _salvando || _enviando ? null : _salvar,
              child: Text(_salvando ? 'Salvando…' : 'Salvar anúncio'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Busca entre os produtos que a loja vende: só eles podem virar destaque.
class _EscolhaDoProduto extends StatelessWidget {
  const _EscolhaDoProduto({this.inicial, required this.aoEscolher});
  final String? inicial;
  final ValueChanged<String?> aoEscolher;

  Iterable<ItemCatalogo> _opcoes(String texto) {
    final ofertas = OfertasService.instance;
    final vendidos = [
      for (final item in ofertas.catalogo)
        if (ofertas.minhas[item.id]?.pausada == false) item,
    ];
    final achados = texto.trim().isEmpty
        ? vendidos
        : buscarItens(vendidos, texto);
    return achados.take(_sugestoesDeProduto);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ItemCatalogo>(
      initialValue: TextEditingValue(text: inicial ?? ''),
      optionsBuilder: (valor) => _opcoes(valor.text),
      displayStringForOption: (item) => item.nome,
      onSelected: (item) => aoEscolher(item.id),
      fieldViewBuilder: (context, controle, foco, enviar) => TextField(
        controller: controle,
        focusNode: foco,
        onChanged: (_) => aoEscolher(null),
        onSubmitted: (_) => enviar(),
        decoration: const InputDecoration(
          labelText: 'Produto em destaque',
          hintText: 'Busque entre os produtos com preço',
        ),
      ),
    );
  }
}
