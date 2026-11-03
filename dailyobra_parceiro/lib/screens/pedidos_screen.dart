import 'package:flutter/material.dart';

import 'listas_da_loja.dart';

/// Pedidos da loja em abas: em andamento, entregues e cancelados.
class PedidosScreen extends StatelessWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context) => ListasDaLoja(
    titulo: 'Pedidos',
    icone: Icons.receipt_long_outlined,
    escolhaTitulo: 'Escolha um pedido',
    escolhaTexto: 'Toque num pedido da lista para abrir aqui.',
    abas: (servico) => [
      (
        rotulo: servico.pedidosEmAndamento.isEmpty
            ? 'Em andamento'
            : 'Em andamento (${servico.pedidosEmAndamento.length})',
        lista: servico.pedidosEmAndamento,
        vazioTitulo: 'Nenhum pedido em andamento',
        vazioTexto:
            'Proposta aceita vira pedido. Você marca cada passo até a entrega.',
      ),
      (
        rotulo: 'Entregues',
        lista: servico.pedidosEntregues,
        vazioTitulo: 'Nenhum pedido entregue',
        vazioTexto: 'Os pedidos entregues ficam guardados aqui.',
      ),
      (
        rotulo: 'Cancelados',
        lista: servico.pedidosCancelados,
        vazioTitulo: 'Nenhum pedido cancelado',
        vazioTexto: 'Os pedidos cancelados aparecem aqui.',
      ),
    ],
  );
}
