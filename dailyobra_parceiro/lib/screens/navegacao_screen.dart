import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/loja_service.dart';
import '../services/ofertas_service.dart';
import '../services/propostas_loja_service.dart';
import '../services/resultados_service.dart';
import 'componentes.dart';
import 'inicio_screen.dart';
import 'layout_parceiros.dart';
import 'minha_loja_screen.dart';
import 'produtos_screen.dart';
import 'propostas_screen.dart';

/// Navegação do painel da loja: Início · Propostas · Produtos · Minha loja, na moldura de cada largura.
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
    ResultadosService.instance.limpar();
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
        // Propostas novas no número da aba; nome e logo da loja na barra do computador
        child: ListenableBuilder(
          listenable: Listenable.merge([
            PropostasLojaService.instance,
            LojaService.instance,
          ]),
          builder: (context, _) => LayoutParceiros(
            aba: aba,
            onAba: (a) => abaAtual.value = a,
            novas: PropostasLojaService.instance.novas.length,
            loja: LojaService.instance.minhaLoja,
            conteudo: IndexedStack(
              index: aba.index,
              children: [
                const InicioScreen(),
                const PropostasScreen(),
                const ProdutosScreen(),
                MinhaLojaScreen(tema: widget.tema),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
