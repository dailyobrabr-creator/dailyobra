import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/catalogo_service.dart';
import 'categoria_screen.dart';

class BuscaScreen extends StatefulWidget {
  const BuscaScreen({super.key, this.inicial = ''});
  final String inicial;

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
    final achados = CatalogoService.instance.buscar(busca);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _texto,
          autofocus: widget.inicial.isEmpty,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar produto',
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
      body: busca.isEmpty
          ? const EstadoVazio(
              icone: Icons.search,
              titulo: 'O que você precisa para a obra?',
              texto: 'Digite o nome do produto, como cimento, vergalhão 8 mm ou porcelanato.',
            )
          : achados.isEmpty
          ? EstadoVazio(
              icone: Icons.search_off,
              titulo: 'Nada encontrado para "$busca"',
              texto: 'Confira a escrita ou procure pela categoria na tela inicial.',
            )
          : ListaProdutos(itens: achados, filtrarCategoria: true),
    );
  }
}
