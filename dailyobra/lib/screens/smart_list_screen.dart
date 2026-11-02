import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carrinho_service.dart';
import '../services/catalogo_service.dart';
import 'busca_screen.dart';
import 'componentes.dart';
import 'layout_adaptativo.dart';

/// Resultado da lista inteligente: o que foi reconhecido (com quantidade editável), o que precisa
/// de escolha e o que não está no catálogo.
class SmartListScreen extends StatefulWidget {
  const SmartListScreen({super.key, required this.texto});
  final String texto;

  @override
  State<SmartListScreen> createState() => _SmartListScreenState();
}

class _SmartListScreenState extends State<SmartListScreen> {
  late List<LinhaSmartList> _linhas = interpretarLista(
    widget.texto,
    CatalogoService.instance.itens,
  );

  /// Texto colado, editável ao lado dos itens no computador.
  late final _texto = TextEditingController(text: widget.texto);

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
      icone: Icons.playlist_remove,
      titulo: 'Nenhum material na lista',
      texto:
          '${largo ? 'Escreva' : 'Volte e escreva'} um material por linha, com a quantidade. Ex.: 100 sacos de cimento.',
    );
    final botao = FilledButton(
      onPressed: _reconhecidas.isEmpty ? null : _adicionar,
      child: Text(
        produtos == 0
            ? 'Nenhum produto reconhecido'
            : produtos == 1
            ? 'Adicionar 1 item ao orçamento'
            : 'Adicionar $produtos itens ao orçamento',
      ),
    );
    final resumo = Text(
      [
        rec == 1 ? '1 reconhecido' : '$rec reconhecidos',
        if (esc > 0) esc == 1 ? '1 para escolher' : '$esc para escolher',
        if (nao > 0) nao == 1 ? '1 não reconhecido' : '$nao não reconhecidos',
      ].join(' · '),
      style: t.bodyMedium?.copyWith(color: c.textoSuave),
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
        const SizedBox(height: Espaco.s3),
      ],
    ];

    if (largo) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lista inteligente')),
        body: LayoutBuilder(
          builder: (context, limites) {
            final m = margemLateral(limites.maxWidth);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: m + 420,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(m, Espaco.s5, 0, Espaco.s8),
                    children: [
                      Text('Sua lista', style: t.titleMedium),
                      const SizedBox(height: Espaco.s2),
                      TextField(
                        controller: _texto,
                        minLines: 12,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        onChanged: _reinterpretar,
                        decoration: const InputDecoration(
                          hintText: 'Um material por linha, com a quantidade.',
                        ),
                      ),
                      const SizedBox(height: Espaco.s1),
                      Text(
                        'Ao editar, a lista é lida de novo e as escolhas feitas ao lado recomeçam.',
                        style: t.bodySmall?.copyWith(color: c.textoSuave),
                      ),
                      const SizedBox(height: Espaco.s4),
                      if (_linhas.isNotEmpty) botao,
                    ],
                  ),
                ),
                const SizedBox(width: Espaco.s6),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(0, Espaco.s5, m, Espaco.s8),
                    children: _linhas.isEmpty
                        ? [vazio]
                        : [
                            resumo,
                            const SizedBox(height: Espaco.s3),
                            ...linhas,
                          ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lista inteligente')),
      body: _linhas.isEmpty
          ? vazio
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s4,
                Espaco.s4,
                Espaco.s8,
              ),
              children: [
                resumo,
                const SizedBox(height: Espaco.s3),
                ...linhas,
              ],
            ),
      bottomNavigationBar: _linhas.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s2,
                  Espaco.s4,
                  Espaco.s3,
                ),
                child: botao,
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
