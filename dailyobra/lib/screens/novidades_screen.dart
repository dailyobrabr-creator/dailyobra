import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/novidades_service.dart';
import 'componentes.dart';
import 'layout_adaptativo.dart';
import 'pedido_screen.dart';
import 'proposta_screen.dart';

/// Abre as novidades: painel de 380 px à direita no computador, tela própria no celular e no
/// tablet. Abrir conta tudo como visto.
Future<void> abrirNovidades(BuildContext context) async {
  NovidadesService.instance.marcarVistas();
  if (formatoDoContexto(context) == Formato.computador) {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar novidades',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (contexto, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          key: const Key('painel-novidades'),
          color: contexto.cores.superficie,
          child: SizedBox(
            width: 380,
            height: double.infinity,
            child: SafeArea(
              left: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Espaco.s5,
                      Espaco.s4,
                      Espaco.s2,
                      Espaco.s2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Novidades',
                            style: Theme.of(contexto).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.pop(contexto),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: contexto.cores.borda),
                  const Expanded(child: _ListaNovidades()),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animacao, _, filho) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animacao, curve: Curves.easeOut)),
        child: filho,
      ),
    );
  } else {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NovidadesScreen()),
    );
  }
}

class NovidadesScreen extends StatelessWidget {
  const NovidadesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novidades')),
      body: const _ListaNovidades(),
    );
  }
}

String _quando(DateTime d) {
  final agora = DateTime.now();
  final diferenca = agora.difference(d);
  if (diferenca.inMinutes < 1) return 'agora';
  if (diferenca.inHours < 1) return 'há ${diferenca.inMinutes} min';
  if (diferenca.inDays < 1) return 'há ${diferenca.inHours} h';
  if (diferenca.inDays == 1) return 'ontem';
  return dataHora(d).split(' ').first;
}

class _ListaNovidades extends StatelessWidget {
  const _ListaNovidades();

  void _abrir(BuildContext context, Novidade n) {
    if (n.tipo == TipoNovidade.cashbackLiberado) {
      irParaAba(context, Aba.carteira);
      return;
    }
    final Widget? tela = n.propostaId != null
        ? PropostaScreen(id: n.propostaId!)
        : n.pedidoId != null
        ? PedidoScreen(pedidoId: n.pedidoId!)
        : null;
    if (tela == null) return;
    // No painel lateral, fecha o painel antes de abrir a tela
    final navegador = Navigator.of(context);
    if (ModalRoute.of(context) is! MaterialPageRoute) navegador.pop();
    navegador.push(MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    final servico = NovidadesService.instance;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final itens = servico.itens;
        final c = context.cores;
        final t = Theme.of(context).textTheme;
        if (itens.isEmpty) {
          return const Center(
            child: SingleChildScrollView(
              child: EstadoVazio(
                icone: Icons.notifications_none,
                titulo: 'Tudo em dia',
                texto: 'Nenhuma novidade por aqui. Quando uma loja responder, aparece neste lugar.',
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: Espaco.s2),
          itemCount: itens.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, indent: 72, color: c.borda),
          itemBuilder: (context, i) {
            final n = itens[i];
            final (icone, cor) = switch (n.tipo) {
              TipoNovidade.contraproposta => (Icons.swap_horiz, c.acao),
              TipoNovidade.aceita ||
              TipoNovidade.entregue ||
              TipoNovidade.pagamentoConfirmado => (
                Icons.check_circle_outline,
                c.sucesso,
              ),
              TipoNovidade.recusada ||
              TipoNovidade.cancelado => (Icons.cancel_outlined, c.erro),
              TipoNovidade.expirada => (Icons.schedule, c.textoSuave),
              TipoNovidade.emSeparacao || TipoNovidade.saiuEntrega => (
                Icons.local_shipping_outlined,
                c.info,
              ),
              TipoNovidade.cashbackLiberado => (
                Icons.savings_outlined,
                c.sucesso,
              ),
            };
            return ListTile(
              onTap: () => _abrir(context, n),
              leading: CircleAvatar(
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(icone, color: cor),
              ),
              title: Text(
                n.texto,
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (n.detalhe != null && n.detalhe!.isNotEmpty) n.detalhe!,
                  _quando(n.quando),
                ].join(' · '),
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
            );
          },
        );
      },
    );
  }
}
