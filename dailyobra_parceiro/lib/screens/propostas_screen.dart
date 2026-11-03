import 'package:flutter/material.dart';

import 'listas_da_loja.dart';

/// Propostas da loja em abas: novas, negociando e encerradas. Proposta aceita vai para Pedidos.
class PropostasScreen extends StatelessWidget {
  const PropostasScreen({super.key});

  @override
  Widget build(BuildContext context) => ListasDaLoja(
    titulo: 'Propostas',
    icone: Icons.inbox_outlined,
    escolhaTitulo: 'Escolha uma proposta',
    escolhaTexto: 'Toque numa proposta da lista para abrir aqui.',
    abas: (servico) => [
      (
        rotulo: servico.novas.isEmpty
            ? 'Novas'
            : 'Novas (${servico.novas.length})',
        lista: servico.novas,
        vazioTitulo: 'Nenhuma proposta nova',
        vazioTexto: 'Quando um construtor mandar orçamento para a loja, ele aparece aqui na hora.',
      ),
      (
        rotulo: 'Negociando',
        lista: servico.emNegociacao,
        vazioTitulo: 'Nenhuma negociação aberta',
        vazioTexto: 'As contrapropostas que você mandar ficam aqui até o construtor responder.',
      ),
      (
        rotulo: 'Encerradas',
        lista: servico.encerradas,
        vazioTitulo: 'Nada encerrado',
        vazioTexto:
            'Propostas recusadas, canceladas ou vencidas aparecem aqui.',
      ),
    ],
  );
}
