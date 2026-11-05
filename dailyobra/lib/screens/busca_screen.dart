import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/catalogo_service.dart';
import 'categoria_screen.dart';
import 'vitrine_do_inicio.dart';

/// A busca do catálogo. Na aba Busca ([naAba]) o teclado só abre quando a pessoa toca no campo e, antes de digitar, as
/// categorias ficam à mão.
class BuscaScreen extends StatefulWidget {
  const BuscaScreen({super.key, this.inicial = '', this.naAba = false});
  final String inicial;
  final bool naAba;

  @override
  State<BuscaScreen> createState() => _BuscaScreenState();
}

class _BuscaScreenState extends State<BuscaScreen> {
  late final _texto = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busca = _texto.text.trim();
    return Scaffold(
      backgroundColor: widget.naAba ? context.cores.superficie : null,
      appBar: AppBar(
        titleSpacing: widget.naAba ? Espaco.s4 : 0,
        title: TextField(
          controller: _texto,
          autofocus: widget.inicial.isEmpty && !widget.naAba,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar cimento, tijolo, torneira…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: busca.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar',
                    onPressed: () => setState(_texto.clear),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        actions: const [SizedBox(width: Espaco.s3)],
      ),
      body: ListenableBuilder(
        listenable: CatalogoService.instance,
        builder: (context, _) {
          final catalogo = CatalogoService.instance;
          final achados = catalogo.buscar(busca);
          if (busca.isEmpty) {
            if (catalogo.categorias.isEmpty) {
              return const EstadoVazio(
                icone: Icons.search,
                titulo: 'O que você precisa para a obra?',
                texto: 'Digite o nome do produto, como cimento, vergalhão 8 mm ou porcelanato.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(Espaco.s4),
              children: [
                const TituloSecao(
                  'Categorias',
                  margem: EdgeInsets.only(bottom: Espaco.s3),
                ),
                GradeDeCategorias(categorias: catalogo.categorias, todas: true),
              ],
            );
          }
          if (achados.isEmpty) {
            return EstadoVazio(
              icone: Icons.search_off,
              titulo: 'Nada encontrado para "$busca"',
              texto: 'Confira a escrita ou procure pela categoria.',
            );
          }
          return ListaProdutos(itens: achados, filtrarCategoria: true);
        },
      ),
    );
  }
}
