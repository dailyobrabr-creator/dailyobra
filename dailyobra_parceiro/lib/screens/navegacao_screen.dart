import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/clientes_service.dart';
import '../services/loja_service.dart';
import '../services/ofertas_service.dart';
import '../services/propostas_loja_service.dart';
import '../services/resultados_service.dart';
import 'clientes_screen.dart';
import 'componentes.dart';
import 'configuracoes_screen.dart';
import 'inicio_screen.dart';
import 'layout_parceiros.dart';
import 'mesa_screen.dart';
import 'pedidos_screen.dart';
import 'produtos_screen.dart';
import 'propostas_screen.dart';

/// Navegação do painel da loja: Início · Propostas · Pedidos · Mesa do Gerente · Produtos · Clientes · Configurações,
/// na moldura de cada largura.
class NavegacaoScreen extends StatefulWidget {
  const NavegacaoScreen({super.key, required this.tema});
  final PreferenciaTema tema;

  @override
  State<NavegacaoScreen> createState() => _NavegacaoScreenState();
}

class _NavegacaoScreenState extends State<NavegacaoScreen> {
  /// Clientes só busca no banco quando abre pela primeira vez; depois fica montada.
  var _clientesAberta = false;

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
    ClientesService.instance.limpar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Aba>(
      valueListenable: abaAtual,
      builder: (context, aba, _) {
        if (aba == Aba.clientes) _clientesAberta = true;
        return PopScope(
          canPop: aba == Aba.inicio,
          onPopInvokedWithResult: (saiu, _) {
            if (!saiu) abaAtual.value = Aba.inicio;
          },
          // Propostas novas e pedidos em andamento nos números das abas; nome e logo da loja na barra do computador
          child: ListenableBuilder(
            listenable: Listenable.merge([
              PropostasLojaService.instance,
              LojaService.instance,
            ]),
            builder: (context, _) => LayoutParceiros(
              aba: aba,
              onAba: (a) => abaAtual.value = a,
              novas: PropostasLojaService.instance.novas.length,
              pedidos: PropostasLojaService.instance.pedidosEmAndamento.length,
              mesa: PropostasLojaService.instance.naMesa,
              gere: LojaService.instance.meuPapel.gere,
              loja: LojaService.instance.minhaLoja,
              conteudo: IndexedStack(
                index: aba.index,
                children: [
                  const InicioScreen(),
                  const PropostasScreen(),
                  const PedidosScreen(),
                  const MesaScreen(),
                  const ProdutosScreen(),
                  if (_clientesAberta)
                    const ClientesScreen()
                  else
                    const SizedBox.shrink(),
                  ConfiguracoesScreen(tema: widget.tema),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
