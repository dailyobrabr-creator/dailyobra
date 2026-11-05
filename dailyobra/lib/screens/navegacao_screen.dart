import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carrinho_service.dart';
import '../services/carteira_service.dart';
import '../services/catalogo_service.dart';
import '../services/economia_service.dart';
import '../services/negociacao_service.dart';
import '../services/novidades_service.dart';
import '../services/perfil_service.dart';
import 'busca_screen.dart';
import 'componentes.dart';
import 'inicio_screen.dart';
import 'layout_adaptativo.dart';
import 'obras_screen.dart';
import 'orcamentos_screen.dart';
import 'perfil_screen.dart';

/// Navegação principal depois do login: Início, Busca, Obras, Orçamentos e Perfil. A Carteira fica dentro do Perfil.
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
    // O perfil vem primeiro: a cidade dele ordena as lojas do catálogo
    PerfilService.instance.carregar();
    CatalogoService.instance.carregar();
    CarrinhoService.instance.carregar();
    CarteiraService.instance.carregar();
    NegociacaoService.instance.iniciar();
    NovidadesService.instance.carregar();
    EconomiaService.instance.carregar();
  }

  @override
  void dispose() {
    // Saiu da conta: nada do usuário anterior fica na memória
    NegociacaoService.instance.parar();
    CarteiraService.instance.limpar();
    NovidadesService.instance.limpar();
    EconomiaService.instance.limpar();
    PerfilService.instance.limpar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Aba>(
      valueListenable: abaAtual,
      builder: (context, aba, _) => PopScope(
        // Voltar numa aba que não é o Início leva ao Início antes de fechar o app
        canPop: aba == Aba.inicio,
        onPopInvokedWithResult: (saiu, _) {
          if (!saiu) abaAtual.value = Aba.inicio;
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([
            CarrinhoService.instance,
            NegociacaoService.instance,
          ]),
          builder: (context, _) => LayoutAdaptativo(
            aba: aba,
            onAba: (a) => abaAtual.value = a,
            tema: widget.tema,
            pendencias:
                CarrinhoService.instance.itens.length +
                NegociacaoService.instance.aguardandoVoce,
            conteudo: IndexedStack(
              index: aba.index,
              children: [
                InicioScreen(tema: widget.tema),
                const BuscaScreen(naAba: true),
                const ObrasScreen(),
                const OrcamentosScreen(),
                PerfilScreen(tema: widget.tema),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
