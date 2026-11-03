import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import 'componentes.dart';

const _itens = [
  (Aba.inicio, Icons.dashboard_outlined, Icons.dashboard, 'Início'),
  (Aba.propostas, Icons.inbox_outlined, Icons.inbox, 'Propostas'),
  (Aba.pedidos, Icons.receipt_long_outlined, Icons.receipt_long, 'Pedidos'),
  (Aba.produtos, Icons.sell_outlined, Icons.sell, 'Produtos'),
  (Aba.configuracoes, Icons.settings_outlined, Icons.settings, 'Configurações'),
];

/// Moldura do painel por largura: abas embaixo no celular, trilho no tablet e, no computador,
/// menu lateral com a barra laranja da loja no topo. O conteúdo fica com no máximo 1320 px.
class LayoutParceiros extends StatelessWidget {
  const LayoutParceiros({
    super.key,
    required this.aba,
    required this.onAba,
    required this.novas,
    this.pedidos = 0,
    required this.loja,
    required this.conteudo,
  });
  final Aba aba;
  final ValueChanged<Aba> onAba;

  /// Número sobre Propostas (propostas novas esperando a loja).
  final int novas;

  /// Número sobre Pedidos (pedidos em andamento).
  final int pedidos;
  final Loja? loja;
  final Widget conteudo;

  int _numero(Aba a) => switch (a) {
    Aba.propostas => novas,
    Aba.pedidos => pedidos,
    _ => 0,
  };

  Widget _icone(Aba a, IconData icone) => _numero(a) > 0
      ? Badge(label: Text('${_numero(a)}'), child: Icon(icone))
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
            child: NavigationBar(
              selectedIndex: aba.index,
              onDestinationSelected: (i) => onAba(Aba.values[i]),
              destinations: [
                for (final (a, icone, selecionado, rotulo) in _itens)
                  NavigationDestination(
                    icon: _icone(a, icone),
                    selectedIcon: _icone(a, selecionado),
                    // "Configurações" não cabe em cinco abas no celular
                    label: a == Aba.configuracoes ? 'Ajustes' : rotulo,
                  ),
              ],
            ),
          ),
        );
      case Formato.tablet:
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: aba.index,
                onDestinationSelected: (i) => onAba(Aba.values[i]),
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
              _MenuLateral(aba: aba, onAba: onAba, numero: _numero),
              Expanded(
                child: Column(
                  children: [
                    _BarraDaLoja(loja: loja),
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

/// Menu do computador, no estilo do menu lateral do site do construtor.
class _MenuLateral extends StatelessWidget {
  const _MenuLateral({
    required this.aba,
    required this.onAba,
    required this.numero,
  });
  final Aba aba;
  final ValueChanged<Aba> onAba;
  final int Function(Aba) numero;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('menu-lateral'),
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
                            if (numero(a) > 0)
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
                                  '${numero(a)}',
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

/// Barra laranja do computador com a logo e o nome da loja.
class _BarraDaLoja extends StatelessWidget {
  const _BarraDaLoja({required this.loja});
  final Loja? loja;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final loja = this.loja;
    return Material(
      key: const Key('barra-da-loja'),
      color: c.topo,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaco.s8,
          vertical: 18,
        ),
        child: Row(
          children: [
            if (loja != null) ...[
              LogoLoja(loja: loja, tamanho: 36),
              const SizedBox(width: Espaco.s3),
              Expanded(
                child: Text(
                  loja.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    color: c.textoSobreTopo,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
