import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import 'componentes.dart';
import 'topo_vitrine.dart';

const _itens = [
  (Aba.inicio, Icons.home_outlined, Icons.home, 'Início'),
  (Aba.busca, Icons.search, Icons.search, 'Busca'),
  (Aba.obras, Icons.home_work_outlined, Icons.home_work, 'Obras'),
  (
    Aba.orcamentos,
    Icons.request_quote_outlined,
    Icons.request_quote,
    'Orçamentos',
  ),
  (Aba.perfil, Icons.person_outline, Icons.person, 'Perfil'),
];

/// Moldura da navegação: abas embaixo no celular, trilho no tablet e, no computador, menu
/// lateral e a barra laranja no topo. O conteúdo fica com no máximo 1320 px.
class LayoutAdaptativo extends StatelessWidget {
  const LayoutAdaptativo({
    super.key,
    required this.aba,
    required this.onAba,
    required this.conteudo,
    required this.pendencias,
    this.tema,
    this.novidades,
    this.onSino,
  });
  final Aba aba;
  final ValueChanged<Aba> onAba;
  final Widget conteudo;

  /// Número sobre Orçamentos (produtos no orçamento + contrapropostas esperando).
  final int pendencias;
  final PreferenciaTema? tema;
  final int? novidades;
  final VoidCallback? onSino;

  Widget _icone(Aba a, IconData icone) => a == Aba.orcamentos
      ? Badge(
          isLabelVisible: pendencias > 0,
          label: Text('$pendencias'),
          child: Icon(icone),
        )
      : Icon(icone);

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final corpo = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: KeyedSubtree(
          key: const Key('conteudo-adaptativo'),
          child: conteudo,
        ),
      ),
    );
    switch (formatoDoContexto(context)) {
      case Formato.celular:
        return Scaffold(
          body: corpo,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.borda)),
            ),
            // Como nas lojas de entrega: a aba ativa só fica mais forte, sem pílula em volta
            child: NavigationBarTheme(
              data: NavigationBarTheme.of(context).copyWith(
                indicatorColor: Colors.transparent,
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (estado) => Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: estado.contains(WidgetState.selected)
                        ? c.texto
                        : c.textoSuave,
                    fontWeight: estado.contains(WidgetState.selected)
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (estado) => IconThemeData(
                    color: estado.contains(WidgetState.selected)
                        ? c.texto
                        : c.textoSuave,
                    size: 25,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _itens.indexWhere((e) => e.$1 == aba),
                onDestinationSelected: (i) => onAba(_itens[i].$1),
                destinations: [
                  for (final (a, icone, selecionado, rotulo) in _itens)
                    NavigationDestination(
                      icon: _icone(a, icone),
                      selectedIcon: _icone(a, selecionado),
                      label: rotulo,
                    ),
                ],
              ),
            ),
          ),
        );
      case Formato.tablet:
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _itens.indexWhere((e) => e.$1 == aba),
                onDestinationSelected: (i) => onAba(_itens[i].$1),
                labelType: NavigationRailLabelType.none,
                minWidth: 80,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: Espaco.s4),
                  child: MarcaDailyObra(soSimbolo: true, altura: 36),
                ),
                destinations: [
                  for (final (a, icone, selecionado, rotulo) in _itens)
                    NavigationRailDestination(
                      icon: Tooltip(message: rotulo, child: _icone(a, icone)),
                      selectedIcon: _icone(a, selecionado),
                      label: Text(rotulo),
                    ),
                ],
              ),
              VerticalDivider(width: 1, color: c.borda),
              Expanded(child: corpo),
            ],
          ),
        );
      case Formato.computador:
        return Scaffold(
          body: Row(
            children: [
              _MenuLateral(aba: aba, onAba: onAba, pendencias: pendencias),
              Expanded(
                child: Column(
                  children: [
                    TopoVitrine(
                      compacto: false,
                      tema: tema,
                      novidades: novidades,
                      onSino: onSino,
                    ),
                    Expanded(child: corpo),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _MenuLateral extends StatelessWidget {
  const _MenuLateral({
    required this.aba,
    required this.onAba,
    required this.pendencias,
  });
  final Aba aba;
  final ValueChanged<Aba> onAba;
  final int pendencias;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: c.superficie,
        border: Border(right: BorderSide(color: c.borda)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s5,
            Espaco.s4,
            Espaco.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MarcaDailyObra(soSimbolo: false),
                ),
              ),
              for (final (a, icone, selecionado, rotulo) in _itens)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: a == aba ? c.destaqueSuave : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onAba(a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              a == aba ? selecionado : icone,
                              size: 22,
                              color: a == aba ? c.acao : c.textoSuave,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                rotulo,
                                style: t.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: a == aba ? c.acao : c.textoSuave,
                                ),
                              ),
                            ),
                            if (a == Aba.orcamentos && pendencias > 0)
                              Container(
                                constraints: const BoxConstraints(minWidth: 22),
                                height: 22,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: c.topo,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$pendencias',
                                  style: t.labelSmall?.copyWith(
                                    color: c.textoSobreTopo,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
