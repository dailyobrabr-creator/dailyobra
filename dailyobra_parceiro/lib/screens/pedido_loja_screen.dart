import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/loja_service.dart';
import '../services/propostas_loja_service.dart';
import 'componentes.dart';

const _passos = [
  StatusPedido.confirmado,
  StatusPedido.emSeparacao,
  StatusPedido.saiuEntrega,
  StatusPedido.entregue,
];

/// Pedido da loja: avança passo a passo até a entrega e confirma o pagamento
/// (o cashback do construtor só libera com entrega + pagamento).
class PedidoLojaScreen extends StatefulWidget {
  const PedidoLojaScreen({super.key, required this.pedidoId});
  final String pedidoId;

  @override
  State<PedidoLojaScreen> createState() => _PedidoLojaScreenState();
}

class _PedidoLojaScreenState extends State<PedidoLojaScreen> {
  bool _ocupado = false;

  Future<void> _executar(Future<void> Function() acao, String feito) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (mounted) avisar(context, feito);
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _confirmarPagamento(String pedidoId) async {
    if (await confirmar(
      context,
      titulo: 'Confirmar o pagamento?',
      texto: 'Confirme só depois de receber. Com a entrega feita, o cashback do construtor é liberado.',
      acao: 'Confirmar',
    )) {
      await _executar(
        () => PropostasLojaService.instance.confirmarPagamento(pedidoId),
        'Pagamento confirmado.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final servico = PropostasLojaService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([servico, LojaService.instance]),
      builder: (context, _) {
        final p = servico.propostaDoPedido(widget.pedidoId);
        final pedido = p?.pedido;
        if (p == null || pedido == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EstadoVazio(
              titulo: 'Pedido não encontrado',
              texto: 'Volte e puxe a lista para atualizar.',
            ),
          );
        }
        final t = Theme.of(context).textTheme;
        final c = context.cores;
        final quem = servico.construtor(p.construtorId);
        final gere = LojaService.instance.meuPapel.gere;
        final proximo = pedido.status.proximo;
        final pago = pedido.pagamentoConfirmadoEm != null;
        final podeCancelar =
            pedido.status == StatusPedido.confirmado ||
            pedido.status == StatusPedido.emSeparacao;
        final atual = _passos.indexOf(pedido.status);
        return Scaffold(
          appBar: AppBar(title: const Text('Pedido')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s4,
              Espaco.s4,
              Espaco.s8,
            ),
            children: [
              Text(quem.exibicao, style: t.titleLarge),
              if (quem.empresa.isNotEmpty)
                Text(
                  quem.empresa,
                  style: t.bodyMedium?.copyWith(color: c.textoSuave),
                ),
              if (quem.telefone != null)
                SelectableText(telefone(quem.telefone!), style: t.bodyMedium),
              const SizedBox(height: Espaco.s2),
              Text(
                brl.format(pedido.total),
                style: t.headlineSmall?.copyWith(
                  fontFeatures: numerosTabulares,
                ),
              ),
              Text(
                'Pedido de ${dataHora(pedido.criadoEm)}${p.saldoAplicado > 0 ? ' · ${brl.format(p.saldoAplicado)} pagos com saldo DailyObra' : ''}',
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
              const SizedBox(height: Espaco.s4),
              if (pedido.status == StatusPedido.cancelado)
                const Aviso('Pedido cancelado.')
              else
                Painel(
                  titulo: 'Andamento',
                  child: Column(
                    children: [
                      for (var i = 0; i < _passos.length; i++)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            i < atual || pedido.status == StatusPedido.entregue
                                ? Icons.check_circle
                                : i == atual
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: i <= atual
                                ? (i == atual &&
                                          pedido.status != StatusPedido.entregue
                                      ? c.acao
                                      : c.sucesso)
                                : c.textoSuave,
                          ),
                          title: Text(_passos[i].rotulo),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: Espaco.s3),
              Painel(
                titulo: 'Pagamento',
                child: Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: Text(
                    pago
                        ? 'Confirmado em ${dataHora(pedido.pagamentoConfirmadoEm!)}.'
                        : 'Combine com o construtor e confirme aqui quando receber.',
                    style: t.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: Espaco.s3),
              Painel(
                titulo: 'Produtos',
                child: Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: Column(
                    children: [
                      for (final i in p.itens)
                        LinhaValor(
                          '${formatarQuantidade(i.quantidade)} ${i.unidade} · ${i.nome}',
                          brl.format(i.total),
                        ),
                      if (p.desconto > 0)
                        LinhaValor('Desconto', '- ${brl.format(p.desconto)}'),
                      LinhaValor(
                        'Frete',
                        p.frete == 0 ? 'Grátis' : brl.format(p.frete),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s2,
                Espaco.s4,
                Espaco.s3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (proximo != null)
                    FilledButton(
                      onPressed: _ocupado
                          ? null
                          : () => _executar(
                              () => servico.atualizarPedido(pedido.id, proximo),
                              'Pedido: ${proximo.rotulo.toLowerCase()}.',
                            ),
                      child: Text(
                        'Marcar como ${proximo.rotulo.toLowerCase()}',
                      ),
                    ),
                  if (gere &&
                      !pago &&
                      pedido.status != StatusPedido.cancelado) ...[
                    if (proximo != null) const SizedBox(height: Espaco.s2),
                    if (pedido.status == StatusPedido.entregue)
                      FilledButton(
                        onPressed: _ocupado
                            ? null
                            : () => _confirmarPagamento(pedido.id),
                        child: const Text('Confirmar pagamento'),
                      )
                    else
                      OutlinedButton(
                        onPressed: _ocupado
                            ? null
                            : () => _confirmarPagamento(pedido.id),
                        child: const Text('Confirmar pagamento'),
                      ),
                  ],
                  if (podeCancelar)
                    TextButton(
                      onPressed: _ocupado
                          ? null
                          : () async {
                              if (await confirmar(
                                context,
                                titulo: 'Cancelar o pedido?',
                                texto: 'O construtor é avisado e o cashback previsto dele é estornado.',
                                acao: 'Cancelar pedido',
                              )) {
                                await _executar(
                                  () => servico.atualizarPedido(
                                    pedido.id,
                                    StatusPedido.cancelado,
                                  ),
                                  'Pedido cancelado.',
                                );
                              }
                            },
                      child: const Text('Cancelar pedido'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
