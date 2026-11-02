import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/propostas_loja_service.dart';
import 'inicio_screen.dart';

/// Propostas e pedidos da loja em abas: novas, negociando, pedidos e encerradas.
class PropostasScreen extends StatelessWidget {
  const PropostasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servico = PropostasLojaService.instance;
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
            body: TabBarView(
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
                            CartaoPropostaLoja(proposta: p),
                            const SizedBox(height: Espaco.s3),
                          ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
