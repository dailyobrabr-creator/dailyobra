import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/carrinho_service.dart';
import '../services/catalogo_service.dart';
import '../services/compras_service.dart';
import '../services/diario_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';
import 'dia_obra_screen.dart';

const _prazos = [7, 15, 30];

enum _Aba { comprar, saldo, receber }

List<LinhaResultado> _etapasDa(Obra obra) =>
    Calculo.de(obra.parametros).resultado?.etapas ?? const [];

String _qtd(double q, String unidade) => '${formatarQuantidade(q)} $unidade';

/// O que comprar, o saldo de materiais e a conferência do que chega na obra.
class ComprasScreen extends StatefulWidget {
  const ComprasScreen({
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
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  DadosCompras? _dados;
  String? _erro;
  bool _ocupado = false;
  var _aba = _Aba.comprar;
  var _dias = _prazos.first;
  late final _etapas = _etapasDa(widget.obra);

  DateTime get _hoje => widget.hoje ?? DateTime.now();
  bool get _lidera => widget.obra.funcao.lidera;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await ComprasService.instance.carregar(widget.obra.id);
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

  double? _precoDe(String id) => CatalogoService.instance
      .resumoDoItem(id, hoje: _hoje)
      .oferta
      ?.precoVigente(_hoje);

  Future<void> _montar(ResultadoMateriais materiais) async {
    final catalogo = CatalogoService.instance;
    final lista = montarListaDaObra(
      materiais,
      catalogo.planilhaParaItem,
      catalogo.itemPorId,
      _precoDe,
    );
    if (lista.isEmpty) {
      avisar(context, 'Esta lista não tem materiais para esta obra.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      await ComprasService.instance.salvarLista(widget.obra.id, lista);
      await _carregar();
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cotar(List<ItemAComprar> itens) async {
    final carrinho = CarrinhoService.instance;
    final quantidades = {
      for (final i in itens)
        if (i.itemId != null)
          i.itemId!: quantidadeDeCompra(i.quantidade, i.unidade),
    };
    if (quantidades.isEmpty) {
      avisar(context, 'Estes materiais não estão no catálogo das lojas.');
      return;
    }
    if (!carrinho.vazio) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Trocar o orçamento atual?'),
          content: const Text(
            'O orçamento em montagem será trocado por estes materiais.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Trocar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    carrinho.substituirPor(quantidades, obraId: widget.obra.id);
    if (!mounted) return;
    irParaAba(context, Aba.orcamentos);
    avisar(
      context,
      '${quantidades.length == 1 ? '1 produto' : '${quantidades.length} produtos'} no orçamento. Confira as quantidades.',
    );
  }

  Future<void> _editarLista() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListaMateriaisScreen(obra: widget.obra, hoje: _hoje),
      ),
    );
    await _carregar();
  }

  Future<void> _receber({String? pedidoId, List<ItemAReceber>? itens}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecebimentoScreen(
          obra: widget.obra,
          pedidoId: pedidoId,
          itens: itens ?? const [],
          hoje: _hoje,
          escolherFoto: widget.escolherFoto,
        ),
      ),
    );
    await _carregar();
  }

  Future<void> _excluirRecebimento(Recebimento r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir este recebimento?'),
        content: Text('${r.nome}: ${_qtd(r.quantidade, r.unidade)}'),
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
    try {
      final foto = await ComprasService.instance.excluirRecebimento(r.id!);
      if (foto != null) await DiarioService.instance.apagarFotos([foto]);
      await _carregar();
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = _dados;
    return Scaffold(
      appBar: AppBar(title: const Text('Compras da obra')),
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
          : dados.materiais.isEmpty && dados.pedidos.isEmpty
          ? _semLista()
          : _conteudo(dados),
    );
  }

  Widget _semLista() {
    final t = Theme.of(context).textTheme;
    final obra = widget.obra;
    if (!_lidera) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s6),
          child: Text(
            'A lista de materiais ainda não foi montada.',
            textAlign: TextAlign.center,
            style: t.titleMedium,
          ),
        ),
      );
    }
    final calculavel = Calculo.de(obra.parametros).resultado != null;
    final materiais = calculavel
        ? listarMateriais(obra.parametros.paraEntrada())
        : null;
    final bases = basesParaOPadrao(obra.parametros.padrao);
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Text('Monte a lista de materiais', style: t.titleMedium),
        const SizedBox(height: Espaco.s2),
        Text(
          materiais is MateriaisDisponiveis
              ? 'A lista nasce do orçamento da obra, etapa por etapa. Depois você ajusta as quantidades.'
              : 'A lista própria do padrão médio ainda não existe. Escolha a base mais parecida com a sua obra e ajuste as quantidades.',
          style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
        ),
        const SizedBox(height: Espaco.s4),
        if (materiais is MateriaisDisponiveis)
          FilledButton(
            onPressed: _ocupado ? null : () => _montar(materiais),
            child: const Text('Usar a lista do orçamento'),
          ),
        if (calculavel)
          for (final base in bases) ...[
            OutlinedButton(
              onPressed: _ocupado
                  ? null
                  : () => _montar(materiaisComBase(obra.parametros, base)),
              child: Text('Usar a base ${base.rotulo}'),
            ),
            const SizedBox(height: Espaco.s2),
          ],
        TextButton(
          onPressed: _ocupado ? null : _editarLista,
          child: const Text('Montar à mão'),
        ),
      ],
    );
  }

  Widget _conteudo(DadosCompras dados) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s4,
        Espaco.s4,
        Espaco.s10,
      ),
      children: [
        Segmentado<_Aba>(
          valor: _aba,
          opcoes: const [
            (_Aba.comprar, 'Comprar'),
            (_Aba.saldo, 'Saldo'),
            (_Aba.receber, 'Receber'),
          ],
          onChanged: (a) => setState(() => _aba = a),
        ),
        const SizedBox(height: Espaco.s4),
        ...switch (_aba) {
          _Aba.comprar => _comprar(dados),
          _Aba.saldo => _saldo(dados),
          _Aba.receber => _recebimentos(dados),
        },
      ],
    );
  }

  List<Widget> _comprar(DadosCompras dados) {
    final t = Theme.of(context).textTheme;
    final itens = oQueComprar(
      etapas: _etapas,
      materiais: dados.materiais,
      pedidos: dados.pedidos,
      recebimentos: dados.recebimentos,
      datas: widget.obra.cronograma,
      status: widget.obra.statusEtapas,
      hoje: _hoje,
      dias: _dias,
    );
    final semCronograma = !widget.obra.cronograma.values.any(
      (d) => d.temPrevisto,
    );
    return [
      Segmentado<int>(
        valor: _dias,
        opcoes: [for (final d in _prazos) (d, '$d dias')],
        onChanged: (d) => setState(() => _dias = d),
      ),
      const SizedBox(height: Espaco.s3),
      if (semCronograma) ...[
        const Aviso(
          'Sem cronograma, a lista mostra só a etapa atual. Com as datas, ela acompanha o que vem pela frente.',
          tom: TomSelo.info,
        ),
        const SizedBox(height: Espaco.s3),
      ],
      if (itens.isEmpty)
        Padding(
          padding: const EdgeInsets.all(Espaco.s6),
          child: Text(
            'Nada para comprar neste período',
            style: t.titleMedium,
            textAlign: TextAlign.center,
          ),
        )
      else ...[
        Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, item) in itens.indexed) ...[
                if (i > 0) const Divider(),
                _LinhaDeCompra(item: item, etapas: _etapas, hoje: _hoje),
              ],
            ],
          ),
        ),
        const SizedBox(height: Espaco.s3),
        FilledButton(
          onPressed: () => _cotar(itens),
          child: const Text('Cotar estes materiais'),
        ),
      ],
    ];
  }

  List<Widget> _saldo(DadosCompras dados) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final saldo = calcularSaldo(
      materiais: dados.materiais,
      pedidos: dados.pedidos,
      recebimentos: dados.recebimentos,
    );
    return [
      if (_lidera) ...[
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _editarLista,
            child: const Text('Editar lista'),
          ),
        ),
        const SizedBox(height: Espaco.s1),
      ],
      Painel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, s) in saldo.indexed) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.all(Espaco.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.nome, style: t.titleSmall),
                    const SizedBox(height: Espaco.s1),
                    Text(
                      'Previsto ${formatarQuantidade(s.previsto)} · Comprado ${formatarQuantidade(s.comprado)} · Recebido ${formatarQuantidade(s.recebido)}',
                      style: suave,
                    ),
                    if (s.falta > 0 || s.aReceber > 0) ...[
                      const SizedBox(height: Espaco.s1),
                      Wrap(
                        spacing: Espaco.s2,
                        runSpacing: Espaco.s1,
                        children: [
                          if (s.falta > 0)
                            Selo(
                              'Falta ${_qtd(s.falta, s.unidade)}',
                              tom: TomSelo.aviso,
                            ),
                          if (s.aReceber > 0)
                            Selo(
                              'A receber ${_qtd(s.aReceber, s.unidade)}',
                              tom: TomSelo.info,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _recebimentos(DadosCompras dados) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final porPedido = <String, List<ItemDePedido>>{};
    for (final p in dados.pedidos) {
      (porPedido[p.pedidoId] ??= []).add(p);
    }
    double recebidoDe(ItemDePedido p) => dados.recebimentos
        .where(
          (r) =>
              r.pedidoId == p.pedidoId &&
              r.itemId == p.itemId &&
              r.nome == p.nome,
        )
        .fold(0, (s, r) => s + r.quantidade);
    return [
      if (porPedido.isEmpty)
        Text(
          'Os pedidos feitos para esta obra aparecem aqui para conferir a entrega.',
          style: suave,
        ),
      for (final entrada in porPedido.entries) ...[
        Builder(
          builder: (context) {
            final itens = entrada.value;
            final faltando = [
              for (final i in itens)
                if (recebidoDe(i) < i.quantidade)
                  ItemAReceber(
                    itemId: i.itemId,
                    nome: i.nome,
                    unidade: i.unidade,
                    quantidade: i.quantidade - recebidoDe(i),
                  ),
            ];
            return Painel(
              child: Padding(
                padding: const EdgeInsets.all(Espaco.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Pedido na ${itens.first.loja}',
                            style: t.titleSmall,
                          ),
                        ),
                        if (faltando.isEmpty)
                          const Selo('Recebido', tom: TomSelo.sucesso),
                      ],
                    ),
                    Text(dataCurta(itens.first.data), style: suave),
                    const SizedBox(height: Espaco.s2),
                    for (final i in itens)
                      Text(
                        '${i.nome}: ${formatarQuantidade(recebidoDe(i))} de ${_qtd(i.quantidade, i.unidade)}',
                        style: t.bodyMedium,
                      ),
                    if (faltando.isNotEmpty) ...[
                      const SizedBox(height: Espaco.s3),
                      FilledButton(
                        onPressed: () =>
                            _receber(pedidoId: entrada.key, itens: faltando),
                        child: const Text('Registrar o que chegou'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: Espaco.s3),
      ],
      const SizedBox(height: Espaco.s2),
      OutlinedButton(
        onPressed: _receber,
        child: const Text('Comprei fora do app'),
      ),
      if (dados.recebimentos.isNotEmpty) ...[
        const SizedBox(height: Espaco.s4),
        Painel(
          titulo: 'O que chegou',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, r) in dados.recebimentos.indexed) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s4,
                    Espaco.s2,
                    Espaco.s2,
                    Espaco.s2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.nome, style: t.bodyLarge),
                            Text(
                              [
                                dataCurta(r.data),
                                _qtd(r.quantidade, r.unidade),
                                if (r.pedidoId == null) 'Fora do app',
                                if (r.observacao.isNotEmpty) r.observacao,
                              ].join(' · '),
                              style: suave,
                            ),
                          ],
                        ),
                      ),
                      if (r.id != null)
                        IconButton(
                          tooltip: 'Excluir recebimento de ${r.nome}',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _excluirRecebimento(r),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }
}

class _LinhaDeCompra extends StatelessWidget {
  const _LinhaDeCompra({
    required this.item,
    required this.etapas,
    required this.hoje,
  });

  final ItemAComprar item;
  final List<LinhaResultado> etapas;
  final DateTime hoje;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: context.cores.textoSuave);
    final nomes = [
      for (final e in etapas)
        if (item.etapas.contains(e.etapa)) e.nome,
    ];
    final id = item.itemId;
    final oferta = id == null
        ? null
        : CatalogoService.instance.resumoDoItem(id, hoje: hoje).oferta;
    final preco = oferta?.precoVigente(hoje);
    final alerta = oferta == null
        ? null
        : alertaDePreco(
            base: item.precoBase,
            atual: preco,
            emPromocao: oferta.emPromocao(hoje),
          );
    return Padding(
      padding: const EdgeInsets.all(Espaco.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nome, style: t.bodyLarge),
                Text(
                  [
                    'Falta ${_qtd(quantidadeDeCompra(item.quantidade, item.unidade), item.unidade)}',
                    ...nomes,
                  ].join(' · '),
                  style: suave,
                ),
                if (alerta != null) ...[
                  const SizedBox(height: Espaco.s1),
                  Selo(
                    alerta.texto,
                    tom: alerta.bom ? TomSelo.sucesso : TomSelo.aviso,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Espaco.s2),
          if (id == null)
            Text('Fora do catálogo', style: suave)
          else if (preco == null)
            Text('Sem oferta', style: suave)
          else
            Text(
              brl.format(preco),
              style: t.bodyLarge?.copyWith(fontFeatures: numerosTabulares),
            ),
        ],
      ),
    );
  }
}

/// A lista de materiais da obra, para quem lidera ajustar.
class ListaMateriaisScreen extends StatefulWidget {
  const ListaMateriaisScreen({super.key, required this.obra, this.hoje});
  final Obra obra;
  final DateTime? hoje;

  @override
  State<ListaMateriaisScreen> createState() => _ListaMateriaisScreenState();
}

class _ListaMateriaisScreenState extends State<ListaMateriaisScreen> {
  List<MaterialObra>? _lista;
  String? _erro;
  late final _etapas = _etapasDa(widget.obra);

  DateTime get _hoje => widget.hoje ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await ComprasService.instance.carregar(widget.obra.id);
      if (mounted) {
        setState(() {
          _lista = dados.materiais;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _editar([MaterialObra? m]) async {
    final novo = await showDialog<MaterialObra>(
      context: context,
      builder: (_) =>
          _JanelaMaterial(material: m, etapas: _etapas, hoje: _hoje),
    );
    if (novo == null) return;
    try {
      await ComprasService.instance.salvarMaterial(widget.obra.id, novo);
      await _carregar();
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  Future<void> _excluir(MaterialObra m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir este material?'),
        content: Text(m.nome),
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
    try {
      await ComprasService.instance.excluirMaterial(m.id!);
      await _carregar();
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;
    final t = Theme.of(context).textTheme;
    final nomes = {for (final e in _etapas) e.etapa: e.nome};
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de materiais')),
      floatingActionButton: lista == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _editar,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar material'),
            ),
      body: _erro != null && lista == null
          ? Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Aviso(_erro!),
            )
          : lista == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s4,
                Espaco.s4,
                Espaco.s10 * 2,
              ),
              children: [
                if (lista.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Espaco.s6),
                    child: Text(
                      'Nenhum material na lista',
                      style: t.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Painel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, m) in lista.indexed) ...[
                          if (i > 0) const Divider(),
                          InkWell(
                            onTap: () => _editar(m),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Espaco.s4,
                                Espaco.s2,
                                Espaco.s2,
                                Espaco.s2,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m.nome, style: t.bodyLarge),
                                        Text(
                                          [
                                            _qtd(m.quantidade, m.unidade),
                                            nomes[m.etapa] ?? 'Sem etapa',
                                          ].join(' · '),
                                          style: t.bodySmall?.copyWith(
                                            color: context.cores.textoSuave,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Excluir ${m.nome}',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _excluir(m),
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                            ),
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

class _JanelaMaterial extends StatefulWidget {
  const _JanelaMaterial({
    required this.material,
    required this.etapas,
    required this.hoje,
  });

  final MaterialObra? material;
  final List<LinhaResultado> etapas;
  final DateTime hoje;

  @override
  State<_JanelaMaterial> createState() => _JanelaMaterialState();
}

class _JanelaMaterialState extends State<_JanelaMaterial> {
  late final _unidade = TextEditingController(text: widget.material?.unidade);
  late final _quantidade = TextEditingController(
    text: widget.material == null
        ? ''
        : formatarQuantidade(widget.material!.quantidade),
  );
  late String _nome = widget.material?.nome ?? '';
  late String? _itemId = widget.material?.itemId;
  late EtapaId? _etapa = widget.material?.etapa;
  String? _erroNome;
  String? _erroUnidade;
  String? _erroQuantidade;

  @override
  void dispose() {
    _unidade.dispose();
    _quantidade.dispose();
    super.dispose();
  }

  void _salvar() {
    final q = lerNumero(_quantidade.text);
    final nome = _nome.trim();
    final unidade = _unidade.text.trim();
    final quantidadeOk = !q.isNaN && q > 0;
    setState(() {
      _erroNome = nome.isEmpty ? 'Diga qual é o material.' : null;
      _erroUnidade = unidade.isEmpty ? 'Diga a unidade.' : null;
      _erroQuantidade = quantidadeOk
          ? null
          : 'Digite uma quantidade maior que zero.';
    });
    if (nome.isEmpty || unidade.isEmpty || !quantidadeOk) return;
    final id = _itemId;
    final atual = widget.material;
    final mesmoItem = atual != null && atual.itemId == id;
    Navigator.pop(
      context,
      MaterialObra(
        id: atual?.id,
        etapa: _etapa,
        itemId: id,
        nome: nome,
        unidade: unidade,
        quantidade: q,
        // Trocar a quantidade não muda a base do alerta de preço
        precoBase: mesmoItem
            ? atual.precoBase
            : id == null
            ? null
            : CatalogoService.instance
                  .resumoDoItem(id, hoje: widget.hoje)
                  .oferta
                  ?.precoVigente(widget.hoje),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final atual = widget.material;
    return AlertDialog(
      title: Text(atual == null ? 'Adicionar material' : 'Material'),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Rotulo('Material', obrigatorio: true),
            Autocomplete<ItemCatalogo>(
              initialValue: TextEditingValue(text: _nome),
              displayStringForOption: (i) => i.nome,
              optionsBuilder: (v) {
                final busca = v.text.trim().toLowerCase();
                if (busca.length < 2) return const [];
                return CatalogoService.instance.itemPorId.values
                    .where((i) => i.nome.toLowerCase().contains(busca))
                    .take(6);
              },
              onSelected: (i) => setState(() {
                _nome = i.nome;
                _itemId = i.id;
                _unidade.text = i.unidade;
              }),
              fieldViewBuilder: (context, controle, foco, aoEnviar) =>
                  TextField(
                    key: const Key('material'),
                    controller: controle,
                    focusNode: foco,
                    maxLength: 160,
                    onChanged: (v) => setState(() {
                      _nome = v;
                      _itemId = null;
                    }),
                    decoration: InputDecoration(
                      errorText: _erroNome,
                      counterText: '',
                      hintText: 'Digite para buscar no catálogo',
                    ),
                  ),
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Unidade',
              controller: _unidade,
              erro: _erroUnidade,
              maxLength: 20,
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Quantidade',
              controller: _quantidade,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erroQuantidade,
              maxLength: 14,
            ),
            const SizedBox(height: Espaco.s3),
            const Rotulo('Etapa'),
            DropdownButtonFormField<EtapaId?>(
              initialValue: _etapa,
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyLarge,
              items: [
                const DropdownMenuItem(child: Text('Sem etapa')),
                for (final e in widget.etapas)
                  DropdownMenuItem(value: e.etapa, child: Text(e.nome)),
              ],
              onChanged: (v) => setState(() => _etapa = v),
            ),
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

/// O que ainda falta chegar de um pedido.
class ItemAReceber {
  const ItemAReceber({
    required this.itemId,
    required this.nome,
    required this.unidade,
    required this.quantidade,
  });

  final String? itemId;
  final String nome;
  final String unidade;
  final double quantidade;
}

/// Conferir o que chegou. Com [pedidoId], cada item do pedido traz o que falta; sem ele, é compra de fora do app.
class RecebimentoScreen extends StatefulWidget {
  const RecebimentoScreen({
    super.key,
    required this.obra,
    this.pedidoId,
    this.itens = const [],
    this.hoje,
    this.escolherFoto,
  });

  final Obra obra;
  final String? pedidoId;
  final List<ItemAReceber> itens;
  final DateTime? hoje;
  final Future<XFile?> Function(bool camera)? escolherFoto;

  @override
  State<RecebimentoScreen> createState() => _RecebimentoScreenState();
}

class _RecebimentoScreenState extends State<RecebimentoScreen> {
  late final _quantidades = [
    for (final i in widget.itens)
      TextEditingController(text: formatarQuantidade(i.quantidade)),
  ];
  final _nome = TextEditingController();
  final _unidade = TextEditingController();
  final _quantidade = TextEditingController();
  final _observacao = TextEditingController();
  late DateTime _data = widget.hoje ?? DateTime.now();
  String? _foto;
  Uint8List? _bytes;
  String? _erroNome;
  String? _erroUnidade;
  String? _erroQuantidade;
  bool _ocupado = false;

  bool get _doPedido => widget.pedidoId != null;

  @override
  void dispose() {
    for (final c in _quantidades) {
      c.dispose();
    }
    _nome.dispose();
    _unidade.dispose();
    _quantidade.dispose();
    _observacao.dispose();
    super.dispose();
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
        data: _data,
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

  List<Recebimento>? _itensDigitados() {
    if (_doPedido) {
      final itens = <Recebimento>[];
      for (final (i, item) in widget.itens.indexed) {
        final q = lerNumero(_quantidades[i].text);
        if (q.isNaN || q <= 0) continue;
        itens.add(
          Recebimento(
            itemId: item.itemId,
            nome: item.nome,
            unidade: item.unidade,
            quantidade: q,
            data: _data,
          ),
        );
      }
      if (itens.isEmpty) {
        avisar(context, 'Informe pelo menos um material.');
        return null;
      }
      return itens;
    }
    final nome = _nome.text.trim();
    final unidade = _unidade.text.trim();
    final q = lerNumero(_quantidade.text);
    final quantidadeOk = !q.isNaN && q > 0;
    setState(() {
      _erroNome = nome.isEmpty ? 'Diga qual é o material.' : null;
      _erroUnidade = unidade.isEmpty ? 'Diga a unidade.' : null;
      _erroQuantidade = quantidadeOk
          ? null
          : 'Digite uma quantidade maior que zero.';
    });
    if (nome.isEmpty || unidade.isEmpty || !quantidadeOk) return null;
    return [
      Recebimento(nome: nome, unidade: unidade, quantidade: q, data: _data),
    ];
  }

  Future<void> _salvar() async {
    final itens = _itensDigitados();
    if (itens == null) return;
    setState(() => _ocupado = true);
    try {
      await ComprasService.instance.registrarRecebimento(
        widget.obra.id,
        pedidoId: widget.pedidoId,
        itens: itens,
        data: _data,
        observacao: _observacao.text.trim(),
        foto: _foto,
      );
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
    final bytes = _bytes;
    return Scaffold(
      appBar: AppBar(
        title: Text(_doPedido ? 'O que chegou' : 'Comprei fora do app'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_doPedido) ...[
              Text(
                'Confira cada item. Se chegou menos, troque a quantidade.',
                style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
              ),
              const SizedBox(height: Espaco.s3),
              for (final (i, item) in widget.itens.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Espaco.s3),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.nome, style: t.bodyLarge)),
                      const SizedBox(width: Espaco.s2),
                      SizedBox(
                        width: 92,
                        child: TextField(
                          key: Key('quantidade-${item.itemId ?? item.nome}'),
                          controller: _quantidades[i],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(suffixText: item.unidade),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              CampoTexto(
                rotulo: 'Material',
                controller: _nome,
                obrigatorio: true,
                erro: _erroNome,
                maxLength: 160,
              ),
              const SizedBox(height: Espaco.s3),
              CampoTexto(
                rotulo: 'Unidade',
                controller: _unidade,
                obrigatorio: true,
                erro: _erroUnidade,
                maxLength: 20,
              ),
              const SizedBox(height: Espaco.s3),
              CampoTexto(
                rotulo: 'Quantidade',
                controller: _quantidade,
                obrigatorio: true,
                teclado: const TextInputType.numberWithOptions(decimal: true),
                erro: _erroQuantidade,
                maxLength: 14,
              ),
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
            const Rotulo('Observação'),
            TextField(
              key: const Key('observacao'),
              controller: _observacao,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ex.: faltaram 5 sacos, chegou molhado',
                counterText: '',
              ),
            ),
            const SizedBox(height: Espaco.s3),
            const Rotulo('Foto da entrega'),
            if (_foto != null)
              Align(
                alignment: Alignment.centerLeft,
                child: MiniaturaFoto(
                  imagem: bytes == null
                      ? const Icon(Icons.image_outlined)
                      : Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const SizedBox(),
                        ),
                  aoTocar: () {},
                  aoRemover: () {
                    final foto = _foto;
                    setState(() {
                      _foto = null;
                      _bytes = null;
                    });
                    if (foto != null) {
                      DiarioService.instance.apagarFotos([foto]);
                    }
                  },
                ),
              )
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

/// Entrada na tela da obra.
class EntradaDasCompras extends StatefulWidget {
  const EntradaDasCompras({super.key, required this.obra});
  final Obra obra;

  @override
  State<EntradaDasCompras> createState() => _EntradaDasComprasState();
}

class _EntradaDasComprasState extends State<EntradaDasCompras> {
  DadosCompras? _dados;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await ComprasService.instance.carregar(widget.obra.id);
      if (mounted) setState(() => _dados = dados);
    } on FalhaAoSalvar {
      // Sem os dados, a linha continua levando à tela, que mostra o motivo
    }
  }

  String _detalhe() {
    final dados = _dados;
    if (dados == null) return 'O que comprar, saldo e recebimento';
    if (dados.materiais.isEmpty) return 'Monte a lista de materiais';
    final n = oQueComprar(
      etapas: _etapasDa(widget.obra),
      materiais: dados.materiais,
      pedidos: dados.pedidos,
      recebimentos: dados.recebimentos,
      datas: widget.obra.cronograma,
      status: widget.obra.statusEtapas,
      hoje: DateTime.now(),
    ).length;
    if (n == 0) return 'Nada para os próximos 7 dias';
    return n == 1
        ? '1 material para os próximos 7 dias'
        : '$n materiais para os próximos 7 dias';
  }

  @override
  Widget build(BuildContext context) => EntradaDaObra(
    icone: Icons.shopping_cart_outlined,
    titulo: 'Compras da obra',
    detalhe: _detalhe(),
    aoTocar: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ComprasScreen(obra: widget.obra)),
      );
      await _carregar();
    },
  );
}
