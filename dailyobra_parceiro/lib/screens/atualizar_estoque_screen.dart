import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/loja_service.dart';
import '../services/ofertas_service.dart';
import 'componentes.dart';
import 'importar_planilha_screen.dart';

enum _Passo { arquivo, lendo, resumo }

/// Atualiza preço e estoque pelo relatório "Valor do estoque analítico" do Santri: lê o arquivo no aparelho (o custo
/// não sai dele), mostra o que muda e as sugestões de ligação pelo catálogo, e grava tudo de uma vez.
class AtualizarEstoqueScreen extends StatefulWidget {
  const AtualizarEstoqueScreen({super.key, this.escolher});

  /// Testes: entrega o arquivo sem abrir o seletor do aparelho.
  final Future<ArquivoPlanilha?> Function()? escolher;

  @override
  State<AtualizarEstoqueScreen> createState() => _AtualizarEstoqueScreenState();
}

class _AtualizarEstoqueScreenState extends State<AtualizarEstoqueScreen> {
  _Passo _passo = _Passo.arquivo;
  String? _erro;
  bool _gravando = false;
  AtualizacaoEstoque? _atualizacao;

  /// Produtos de "Conferir" que a loja marcou.
  final _conferidos = <String>{};

  /// Por produto do catálogo: a opção mostrada, a escolhida para ligar e os pulados.
  final _opcaoDe = <String, int>{};
  final _ligados = <String, OpcaoLigacao>{};
  final _pulados = <String>{};

  static Future<ArquivoPlanilha?> _escolherNoAparelho() async {
    final arquivo = await FilePicker.pickFile(
      dialogTitle: 'Relatório de estoque do Santri',
      type: FileType.custom,
      allowedExtensions: const ['ods', 'xlsx', 'csv'],
    );
    if (arquivo == null) return null;
    return ArquivoPlanilha(arquivo.name, await arquivo.readAsBytes());
  }

  Future<void> _escolher() async {
    setState(() => _erro = null);
    final arquivo = await (widget.escolher ?? _escolherNoAparelho)();
    if (arquivo == null || !mounted) return;
    setState(() => _passo = _Passo.lendo);
    try {
      final relatorio = relatorioEstoqueSantri(
        await lerLinhas(arquivo.nome, arquivo.bytes),
      );
      final ofertas = OfertasService.instance;
      final ligacoes = await ofertas.carregarLigacoes();
      final atualizacao = montarAtualizacao(
        relatorio,
        ligacoes,
        ofertas.minhas,
        ofertas.catalogo,
      );
      if (!mounted) return;
      setState(() {
        _atualizacao = atualizacao;
        _conferidos.clear();
        _opcaoDe.clear();
        _ligados.clear();
        _pulados.clear();
        _passo = _Passo.resumo;
      });
    } on PlanilhaInvalida catch (e) {
      _voltar(e.mensagem);
    } on FalhaComMensagem catch (e) {
      _voltar(e.mensagem);
    }
  }

  void _voltar(String erro) {
    if (!mounted) return;
    setState(() {
      _erro = erro;
      _passo = _Passo.arquivo;
    });
  }

  Future<void> _confirmar() async {
    final a = _atualizacao;
    final loja = LojaService.instance.minhaLoja;
    if (a == null || loja == null) return;
    final ofertas = [
      for (final m in a.mudancas)
        if (m.grupo != GrupoMudanca.semMudanca &&
            (m.grupo != GrupoMudanca.conferir ||
                _conferidos.contains(m.item.id)))
          Oferta(
            lojaId: loja.id,
            itemId: m.item.id,
            preco: m.precoNovo,
            disponibilidade: m.disponibilidadeNova,
          ),
      for (final MapEntry(key: itemId, value: o) in _ligados.entries)
        Oferta(
          lojaId: loja.id,
          itemId: itemId,
          preco: o.linha.preco!,
          disponibilidade: o.linha.disponivel > 0
              ? Disponibilidade.disponivel
              : Disponibilidade.semEstoque,
        ),
    ];
    final ligacoes = [
      for (final MapEntry(key: itemId, value: o) in _ligados.entries)
        LigacaoProduto(
          codigo: o.linha.codigo,
          itemId: itemId,
          nome: o.linha.nome,
          unidade: o.linha.unidade,
        ),
    ];
    setState(() => _gravando = true);
    try {
      final n = await OfertasService.instance.importarEstoque(
        ofertas: ofertas,
        ligacoes: ligacoes,
      );
      if (!mounted) return;
      avisar(context, 'Estoque atualizado: $n produtos.');
      Navigator.maybePop(context);
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _gravando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _atualizacao;
    return Scaffold(
      appBar: AppBar(title: const Text('Atualizar pelo Santri')),
      body: ColunaCentral(
        child: switch (_passo) {
          _Passo.arquivo => _passoArquivo(context),
          _Passo.lendo => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: Espaco.s3),
                Text('Lendo o relatório…'),
              ],
            ),
          ),
          _Passo.resumo => _resumo(context, a!),
        },
      ),
      bottomNavigationBar: _passo == _Passo.resumo
          ? ColunaCentral(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s4,
                    Espaco.s2,
                    Espaco.s4,
                    Espaco.s3,
                  ),
                  child: FilledButton(
                    onPressed: _gravando ? null : _confirmar,
                    child: Text(_gravando ? 'Gravando…' : 'Confirmar'),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _passoArquivo(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Text(
          'Exporte do Santri o relatório "Valor do estoque analítico" e escolha o arquivo aqui. Só preço e estoque saem do seu computador; o custo fica nele.',
          style: t.bodyMedium,
        ),
        if (_erro != null) ...[
          const SizedBox(height: Espaco.s3),
          Aviso(_erro!),
        ],
        const SizedBox(height: Espaco.s4),
        FilledButton.icon(
          onPressed: _escolher,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Escolher relatório'),
        ),
      ],
    );
  }

  Widget _resumo(BuildContext context, AtualizacaoEstoque a) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    int quantos(GrupoMudanca g) => a.mudancas.where((m) => m.grupo == g).length;
    final mudam = [
      for (final m in a.mudancas)
        if (m.grupo != GrupoMudanca.semMudanca &&
            m.grupo != GrupoMudanca.conferir)
          m,
    ];
    final conferir = [
      for (final m in a.mudancas)
        if (m.grupo == GrupoMudanca.conferir) m,
    ];
    final sugestoes = [
      for (final s in a.sugestoes)
        if (!_pulados.contains(s.item.id)) s,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s4,
        Espaco.s4,
        Espaco.s8,
      ),
      children: [
        Wrap(
          spacing: Espaco.s2,
          runSpacing: Espaco.s2,
          children: [
            for (final g in [
              GrupoMudanca.precoNovo,
              GrupoMudanca.voltouAoEstoque,
              GrupoMudanca.ficouSemEstoque,
              GrupoMudanca.semMudanca,
            ])
              _Contagem(
                key: Key('grupo-${g.name}'),
                rotulo: g.rotulo,
                n: quantos(g),
              ),
            _Contagem(
              key: const Key('grupo-naoVeio'),
              rotulo: 'Não veio no relatório',
              n: a.naoVieram.length,
            ),
            _Contagem(
              key: const Key('grupo-conferir'),
              rotulo: GrupoMudanca.conferir.rotulo,
              n: conferir.length,
            ),
          ],
        ),
        if (a.naoVieram.isNotEmpty) ...[
          const SizedBox(height: Espaco.s3),
          Text(
            'Não veio no relatório: ${a.naoVieram.map((i) => i.nome).join(', ')}. A oferta deles fica como está.',
            style: t.bodySmall?.copyWith(color: c.textoSuave),
          ),
        ],
        if (a.semPreco > 0) ...[
          const SizedBox(height: Espaco.s2),
          Text(
            a.semPreco == 1
                ? '1 produto ligado veio sem preço e ficou de fora.'
                : '${a.semPreco} produtos ligados vieram sem preço e ficaram de fora.',
            style: t.bodySmall?.copyWith(color: c.textoSuave),
          ),
        ],
        if (mudam.isNotEmpty) ...[
          const SizedBox(height: Espaco.s4),
          Text('O que muda', style: t.titleMedium),
          for (final m in mudam)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m.item.nome),
              subtitle: Text(_mudanca(m)),
              trailing: Text(m.grupo.rotulo, style: t.bodySmall),
            ),
        ],
        if (conferir.isNotEmpty) ...[
          const SizedBox(height: Espaco.s4),
          Text('Conferir', style: t.titleMedium),
          Text(
            'O preço mudou mais de 30% ou ficou em R\$ 1,00 ou menos. Marque o que estiver certo.',
            style: t.bodySmall?.copyWith(color: c.textoSuave),
          ),
          for (final m in conferir)
            CheckboxListTile(
              key: Key('conferir-${m.item.id}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _conferidos.contains(m.item.id),
              onChanged: (v) => setState(
                () => v == true
                    ? _conferidos.add(m.item.id)
                    : _conferidos.remove(m.item.id),
              ),
              title: Text(m.item.nome),
              subtitle: Text(_mudanca(m)),
            ),
        ],
        if (sugestoes.isNotEmpty) ...[
          const SizedBox(height: Espaco.s4),
          Text('Produtos do catálogo para ligar', style: t.titleMedium),
          Text(
            'Confira se é o mesmo produto: o que você ligar atualiza sozinho nos próximos dias.',
            style: t.bodySmall?.copyWith(color: c.textoSuave),
          ),
          for (final s in sugestoes) ...[
            const SizedBox(height: Espaco.s3),
            ?_sugestao(context, s),
          ],
        ],
      ],
    );
  }

  String _mudanca(MudancaOferta m) {
    final antes = m.precoAntigo == null
        ? ''
        : '${brl.format(m.precoAntigo)} → ';
    return '$antes${brl.format(m.precoNovo)} · ${m.disponibilidadeNova.rotulo}';
  }

  /// Busca no relatório quando a linha certa não veio entre as sugestões (fora as que já vão para outro produto).
  Future<void> _procurar(SugestaoLigacao s, Set<String> usadas) async {
    final linha = await Navigator.push<LinhaEstoque>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProcurarLinha(
          item: s.item,
          linhas: [
            for (final l in _atualizacao!.paraLigar)
              if (!usadas.contains(l.codigo)) l,
          ],
        ),
      ),
    );
    if (linha == null || !mounted) return;
    setState(() => _ligados[s.item.id] = OpcaoLigacao.para(linha, s.item));
  }

  /// Cartão de uma sugestão. A linha do Santri que já vai para outro produto sai das opções deste.
  Widget? _sugestao(BuildContext context, SugestaoLigacao s) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final ligada = _ligados[s.item.id];
    final usadas = {
      for (final e in _ligados.entries)
        if (e.key != s.item.id) e.value.linha.codigo,
    };
    final opcoes = [
      for (final o in s.opcoes)
        if (!usadas.contains(o.linha.codigo)) o,
    ];
    if (ligada == null && opcoes.isEmpty) return null;
    final i = opcoes.isEmpty ? 0 : (_opcaoDe[s.item.id] ?? 0) % opcoes.length;
    final o = ligada ?? opcoes[i];
    return Material(
      key: Key('sugestao-${s.item.id}'),
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
        side: BorderSide(color: ligada != null ? c.sucesso : c.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.item.nome} (${s.item.unidade})', style: t.titleSmall),
            const SizedBox(height: Espaco.s1),
            Text(o.linha.nome, style: t.bodyMedium),
            Text(
              '${o.linha.unidade ?? 'sem unidade'} · ${brl.format(o.linha.preco)} · Disponível: ${formatarQuantidade(o.linha.disponivel)}',
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
            if (o.unidadeDiferente) ...[
              const SizedBox(height: Espaco.s1),
              Text(
                'Unidade diferente: confira se é o mesmo produto e tamanho.',
                style: t.bodySmall?.copyWith(color: c.aviso),
              ),
            ],
            const SizedBox(height: Espaco.s2),
            Wrap(
              spacing: Espaco.s2,
              runSpacing: Espaco.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: ligada != null
                  ? [
                      Text(
                        'Vai ser ligado',
                        style: t.bodyMedium?.copyWith(color: c.sucesso),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _ligados.remove(s.item.id)),
                        child: const Text('Desfazer'),
                      ),
                    ]
                  : [
                      FilledButton.tonal(
                        onPressed: () =>
                            setState(() => _ligados[s.item.id] = o),
                        child: const Text('Ligar'),
                      ),
                      if (opcoes.length > 1)
                        TextButton(
                          onPressed: () =>
                              setState(() => _opcaoDe[s.item.id] = i + 1),
                          child: const Text('Outro'),
                        ),
                      TextButton(
                        onPressed: () => _procurar(s, usadas),
                        child: const Text('Procurar'),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _pulados.add(s.item.id)),
                        child: const Text('Pular'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Procura por nome ou código nas linhas do relatório que ainda podem ser ligadas; devolve a escolhida.
class _ProcurarLinha extends StatefulWidget {
  const _ProcurarLinha({required this.item, required this.linhas});
  final ItemCatalogo item;
  final List<LinhaEstoque> linhas;

  @override
  State<_ProcurarLinha> createState() => _ProcurarLinhaState();
}

class _ProcurarLinhaState extends State<_ProcurarLinha> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final vazia = _busca.text.trim().isEmpty;
    final achadas = procurarLinhas(widget.linhas, _busca.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Procurar no relatório')),
      body: ColunaCentral(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s4,
                Espaco.s4,
                Espaco.s2,
              ),
              child: TextField(
                key: const Key('procurar-linha'),
                controller: _busca,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Para ${widget.item.nome}',
                  hintText: 'Nome ou código no Santri',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: vazia || achadas.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Espaco.s4),
                      child: Text(
                        vazia
                            ? 'Digite parte do nome ou o código.'
                            : 'Nada encontrado no relatório.',
                        style: t.bodyMedium?.copyWith(color: c.textoSuave),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        Espaco.s2,
                        0,
                        Espaco.s2,
                        Espaco.s8,
                      ),
                      itemCount: achadas.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final l = achadas[i];
                        return ListTile(
                          title: Text(l.nome),
                          subtitle: Text(
                            '${l.unidade ?? 'sem unidade'} · ${brl.format(l.preco)} · Disponível: ${formatarQuantidade(l.disponivel)}',
                          ),
                          onTap: () => Navigator.pop(context, l),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Número e rótulo de um grupo do resumo.
class _Contagem extends StatelessWidget {
  const _Contagem({super.key, required this.rotulo, required this.n});
  final String rotulo;
  final int n;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.s3,
        vertical: Espaco.s2,
      ),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(Raio.md),
        border: Border.all(color: c.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$n', style: t.titleLarge),
          Text(rotulo, style: t.bodySmall?.copyWith(color: c.textoSuave)),
        ],
      ),
    );
  }
}
