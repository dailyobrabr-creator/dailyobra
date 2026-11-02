import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/loja_service.dart';
import '../services/ofertas_service.dart';
import '../services/propostas_loja_service.dart';
import 'componentes.dart';
import 'inicio_screen.dart';
import 'minha_loja_screen.dart';
import 'produtos_screen.dart';
import 'propostas_screen.dart';

/// Navegação do painel da loja: Início · Propostas · Produtos · Minha loja.
class NavegacaoScreen extends StatefulWidget {
  const NavegacaoScreen({super.key, required this.tema});
  final PreferenciaTema tema;

  @override
  State<NavegacaoScreen> createState() => _NavegacaoScreenState();
}

class _NavegacaoScreenState extends State<NavegacaoScreen> {
  @override
  void initState() {
    super.initState();
    abaAtual.value = Aba.inicio;
    final loja = LojaService.instance.minhaLoja;
    if (loja != null) {
      PropostasLojaService.instance.iniciar(loja.id);
      OfertasService.instance.carregar(loja.id);
    }
  }

  @override
  void dispose() {
    PropostasLojaService.instance.parar();
    OfertasService.instance.limpar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Aba>(
      valueListenable: abaAtual,
      builder: (context, aba, _) => PopScope(
        canPop: aba == Aba.inicio,
        onPopInvokedWithResult: (saiu, _) {
          if (!saiu) abaAtual.value = Aba.inicio;
        },
        child: Scaffold(
          body: IndexedStack(
            index: aba.index,
            children: [
              const InicioScreen(),
              const PropostasScreen(),
              const ProdutosScreen(),
              MinhaLojaScreen(tema: widget.tema),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.cores.borda)),
            ),
            child: ListenableBuilder(
              listenable: PropostasLojaService.instance,
              builder: (context, _) {
                final novas = PropostasLojaService.instance.novas.length;
                return NavigationBar(
                  selectedIndex: aba.index,
                  onDestinationSelected: (i) => abaAtual.value = Aba.values[i],
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Início',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: novas > 0,
                        label: Text('$novas'),
                        child: const Icon(Icons.inbox_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: novas > 0,
                        label: Text('$novas'),
                        child: const Icon(Icons.inbox),
                      ),
                      label: 'Propostas',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.sell_outlined),
                      selectedIcon: Icon(Icons.sell),
                      label: 'Produtos',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.storefront_outlined),
                      selectedIcon: Icon(Icons.storefront),
                      label: 'Minha loja',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
