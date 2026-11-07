import 'package:flutter/material.dart';

import 'componentes.dart';
import 'secoes_loja.dart';

/// Financeiro da loja: como recebe, até quantas vezes parcela e para quem libera duplicata.
class FinanceiroScreen extends StatelessWidget {
  const FinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Recebimento'),
            Tab(text: 'Parcelamento'),
            Tab(text: 'Duplicata'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          ColunaCentral(child: SecaoPagamento()),
          ColunaCentral(child: SecaoParcelamento()),
          ColunaCentral(child: SecaoDuplicata()),
        ],
      ),
    ),
  );
}
