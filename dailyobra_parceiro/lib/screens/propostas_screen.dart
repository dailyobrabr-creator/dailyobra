import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/propostas_loja_service.dart';
import 'inicio_screen.dart';
import 'pedido_loja_screen.dart';
import 'proposta_loja_screen.dart';

/// Propostas e pedidos da loja em abas: novas, negociando, pedidos e encerradas.
/// No computador, a proposta ou o pedido tocado abre ao lado da lista.
class PropostasScreen extends StatefulWidget {
  const PropostasScreen({super.key});

  @override
  State<PropostasScreen> createState() => _PropostasScreenState();
}

class _PropostasScreenState extends State<PropostasScreen> {
  /// Proposta aberta ao lado da lista (computador).
  String? _aberta;

  @override
  Widget build(BuildContext context) {
    final servico = PropostasLojaService.instance;
    final aoLado = formatoDoContexto(context) == Formato.computador;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final abas = <(String, List<PropostaResumo>, String, String)>[
          (
            servico.novas.isEmpty ? 'Novas' : 'Novas (${servico.novas.length})',
            servico.novas,
            'Nenhuma proposta nova',
            'Quando um construtor mandar orçamento para a loja, ele aparece aqui na hora.',
          ),
          (
            'Negociando',
            servico.emNegociacao,
            'Nenhuma negociação aberta',
            'As contrapropostas que você mandar ficam aqui até o construtor responder.',
          ),
          (
            servico.pedidosEmAndamento.isEmpty
                ? 'Pedidos'
                : 'Pedidos (${servico.pedidosEmAndamento.length})',
            servico.pedidos,
            'Nenhum pedido ainda',
            'Proposta aceita vira pedido. Você marca cada passo até a entrega.',
          ),
          (
            'Encerradas',
            servico.encerradas,
            'Nada encerrado',
            'Propostas recusadas, canceladas ou vencidas aparecem aqui.',
          ),
        ];
        final listas = TabBarView(
          children: [
            for (final (_, lista, vazioTitulo, vazioTexto) in abas)
              RefreshIndicator(
                color: context.cores.acao,
                onRefresh: servico.carregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s4,
                    Espaco.s4,
                    Espaco.s4,
                    Espaco.s8,
                  ),
                  children: [
                    if (servico.erro != null) ...[
                      Aviso(servico.erro!),
                      const SizedBox(height: Espaco.s3),
                    ],
                    if (!servico.carregado)
                      for (var i = 0; i < 3; i++) ...[
                        const Esqueleto(altura: 96),
                        const SizedBox(height: Espaco.s3),
                      ]
                    else if (lista.isEmpty)
                      EstadoVazio(
                        icone: Icons.inbox_outlined,
                        titulo: vazioTitulo,
                        texto: vazioTexto,
                      )
                    else
                      for (final p in lista) ...[
                        CartaoPropostaLoja(
                          proposta: p,
                          onAbrir: aoLado
                              ? (p) => setState(() => _aberta = p.id)
                              : null,
                          selecionado: aoLado && p.id == _aberta,
                        ),
                        const SizedBox(height: Espaco.s3),
                      ],
                  ],
                ),
              ),
          ],
        );
        return DefaultTabController(
          length: abas.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Propostas'),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final a in abas) Tab(text: a.$1)],
              ),
            ),
            body: aoLado
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 440, child: listas),
                      VerticalDivider(width: 1, color: context.cores.borda),
                      Expanded(child: _aberto(servico)),
                    ],
                  )
                : listas,
          ),
        );
      },
    );
  }

  /// Coluna da direita: a proposta aberta (ou o pedido em que ela virou), ou o aviso para escolher.
  Widget _aberto(PropostasLojaService servico) {
    final id = _aberta;
    final p = id == null ? null : servico.proposta(id);
    if (p == null) {
      return const EstadoVazio(
        icone: Icons.inbox_outlined,
        titulo: 'Escolha uma proposta ou pedido',
        texto: 'Toque numa proposta ou pedido da lista para abrir aqui.',
      );
    }
    final pedido = p.pedido;
    return pedido == null
        ? PropostaLojaScreen(key: ValueKey(p.id), id: p.id, embutida: true)
        : PedidoLojaScreen(
            key: ValueKey(pedido.id),
            pedidoId: pedido.id,
            embutida: true,
          );
  }
}
