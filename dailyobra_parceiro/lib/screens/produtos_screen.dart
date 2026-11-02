import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/loja_service.dart';
import '../services/ofertas_service.dart';
import 'componentes.dart';
import 'importar_planilha_screen.dart';
import 'oferta_screen.dart';

/// Catálogo mestre com o preço da loja em cada produto. Dono e gerente editam; vendedor só consulta.
class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

enum _Filtro { todos, comPreco, semPreco }

class _ProdutosScreenState extends State<ProdutosScreen> {
  final _busca = TextEditingController();
  _Filtro _filtro = _Filtro.todos;
  String? _categoria;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ofertas = OfertasService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos e preços'),
        actions: [
          if (LojaService.instance.meuPapel.gere)
            IconButton(
              tooltip: 'Importar planilha',
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ImportarPlanilhaScreen(),
                ),
              ),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([ofertas, LojaService.instance]),
        builder: (context, _) {
          final t = Theme.of(context).textTheme;
          final c = context.cores;
          final gere = LojaService.instance.meuPapel.gere;
          final hoje = DateTime.now();
          var itens = _busca.text.trim().isEmpty
              ? ofertas.catalogo
              : buscarItens(ofertas.catalogo, _busca.text);
          itens = [
            for (final i in itens)
              if ((_categoria == null || i.categoriaId == _categoria) &&
                  switch (_filtro) {
                    _Filtro.todos => true,
                    _Filtro.comPreco => ofertas.minhas.containsKey(i.id),
                    _Filtro.semPreco => !ofertas.minhas.containsKey(i.id),
                  })
                i,
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s3,
                  Espaco.s4,
                  Espaco.s2,
                ),
                child: TextField(
                  controller: _busca,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Buscar no catálogo',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Espaco.s4),
                  children: [
                    for (final (f, rotulo) in const [
                      (_Filtro.todos, 'Todos'),
                      (_Filtro.comPreco, 'Com preço'),
                      (_Filtro.semPreco, 'Sem preço'),
                    ]) ...[
                      ChoiceChip(
                        label: Text(rotulo),
                        selected: _filtro == f,
                        onSelected: (_) => setState(() => _filtro = f),
                      ),
                      const SizedBox(width: Espaco.s2),
                    ],
                    DropdownButton<String?>(
                      value: _categoria,
                      hint: const Text('Categoria'),
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas as categorias'),
                        ),
                        for (final cat in ofertas.categorias)
                          DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.nome),
                          ),
                      ],
                      onChanged: (v) => setState(() => _categoria = v),
                    ),
                  ],
                ),
              ),
              if (!gere)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    Espaco.s4,
                    Espaco.s2,
                    Espaco.s4,
                    0,
                  ),
                  child: Aviso(
                    'Só o dono ou o gerente muda preços.',
                    tom: TomSelo.info,
                  ),
                ),
              if (ofertas.erro != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s4,
                    Espaco.s2,
                    Espaco.s4,
                    0,
                  ),
                  child: Aviso(ofertas.erro!),
                ),
              Expanded(
                child: !ofertas.carregado
                    ? const Center(child: CircularProgressIndicator())
                    : itens.isEmpty
                    ? const SingleChildScrollView(
                        child: EstadoVazio(
                          icone: Icons.search_off,
                          titulo: 'Nenhum produto encontrado',
                          texto:
                              'Confira a escrita ou escolha outra categoria.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Espaco.s4,
                          Espaco.s3,
                          Espaco.s4,
                          Espaco.s8,
                        ),
                        itemCount: itens.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Espaco.s2),
                        itemBuilder: (context, i) {
                          final item = itens[i];
                          final o = ofertas.minhas[item.id];
                          final detalhes = <String>[
                            if (o == null)
                              'Sem preço'
                            else
                              '${brl.format(o.precoVigente(hoje) ?? o.preco)} / ${item.unidade}',
                            if (o != null && o.emPromocao(hoje))
                              'promoção até ${dataHora(o.promoAte!).split(' ').first}',
                            if (o != null && o.pausada) 'pausado',
                            if (o != null &&
                                o.disponibilidade != Disponibilidade.disponivel)
                              o.disponibilidade.rotulo.toLowerCase(),
                          ];
                          void abrir() => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OfertaScreen(itemId: item.id),
                            ),
                          );
                          return Material(
                            color: c.superficie,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Raio.lg),
                              side: BorderSide(color: c.borda),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: gere ? abrir : null,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Espaco.s3,
                                  Espaco.s3,
                                  Espaco.s1,
                                  Espaco.s3,
                                ),
                                child: Row(
                                  children: [
                                    ImagemProduto(item: item, tamanho: 48),
                                    const SizedBox(width: Espaco.s3),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.nome,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.titleSmall,
                                          ),
                                          Text(
                                            detalhes.join(' · '),
                                            style: t.bodySmall?.copyWith(
                                              color: o == null || o.pausada
                                                  ? c.textoSuave
                                                  : c.texto,
                                              fontFeatures: numerosTabulares,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (gere)
                                      IconButton(
                                        tooltip: 'Editar preço',
                                        onPressed: abrir,
                                        icon: Icon(
                                          o == null
                                              ? Icons.add_circle_outline
                                              : Icons.edit_outlined,
                                        ),
                                      )
                                    else
                                      const SizedBox(width: Espaco.s3),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
