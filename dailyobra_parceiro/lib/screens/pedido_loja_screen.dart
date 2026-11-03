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
  const PedidoLojaScreen({
    super.key,
    required this.pedidoId,
    this.embutida = false,
  });
  final String pedidoId;

  /// Ao lado da lista (Propostas no computador): sem barra de título própria.
  final bool embutida;

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
          const vazio = EstadoVazio(
            titulo: 'Pedido não encontrado',
            texto: 'Volte e puxe a lista para atualizar.',
          );
          return widget.embutida
              ? vazio
              : Scaffold(appBar: AppBar(), body: vazio);
        }
        final t = Theme.of(context).textTheme;
        final c = context.cores;
        final quem = servico.construtor(p.construtorId);
        final gere = LojaService.instance.meuPapel.gere;
        final proximo = pedido.status.proximo;
        final pago = pedido.pagamentoConfirmadoEm != null;
        final informado = pedido.pagamentoInformadoEm;
        final podeCancelar =
            pedido.status == StatusPedido.confirmado ||
            pedido.status == StatusPedido.emSeparacao;
        final atual = _passos.indexOf(pedido.status);
        final forma = pedido.formaPagamento;
        // Pedido cancelado não tem mais prazo para responder
        final prazo =
            forma == FormaPagamento.crediario &&
                pedido.status != StatusPedido.cancelado
            ? pedido.prazoStatus
            : null;
        final corpo = ListView(
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
              style: t.headlineSmall?.copyWith(fontFeatures: numerosTabulares),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (forma != null) ...[
                      _Dado(
                        'Forma de pagamento',
                        forma == FormaPagamento.crediario &&
                                pedido.prazo != null
                            ? 'Crediário: ${pedido.prazo} dias'
                            : forma.rotulo,
                      ),
                      if (prazo == StatusPrazo.pendente && gere) ...[
                        const SizedBox(height: Espaco.s2),
                        Wrap(
                          spacing: Espaco.s2,
                          runSpacing: Espaco.s2,
                          children: [
                            FilledButton(
                              onPressed: _ocupado
                                  ? null
                                  : () => _executar(
                                      () => servico.responderPrazo(
                                        pedido.id,
                                        true,
                                      ),
                                      'Prazo aprovado.',
                                    ),
                              child: const Text('Aprovar prazo'),
                            ),
                            OutlinedButton(
                              onPressed: _ocupado
                                  ? null
                                  : () => _executar(
                                      () => servico.responderPrazo(
                                        pedido.id,
                                        false,
                                      ),
                                      'Prazo recusado.',
                                    ),
                              child: const Text('Recusar'),
                            ),
                          ],
                        ),
                      ] else if (prazo != null) ...[
                        const SizedBox(height: Espaco.s2),
                        Text(switch (prazo) {
                          StatusPrazo.pendente =>
                            'Aguardando o gerente aprovar o prazo.',
                          StatusPrazo.aprovado => 'Prazo aprovado.',
                          StatusPrazo.recusado => 'Prazo recusado.',
                        }, style: t.bodyMedium),
                      ],
                      const SizedBox(height: Espaco.s3),
                    ],
                    if (!pago && informado != null) ...[
                      Aviso(
                        'Cliente informou o pagamento ${quando(informado)}, confira no banco.',
                      ),
                      const SizedBox(height: Espaco.s3),
                    ],
                    Text(
                      pago
                          ? 'Confirmado em ${dataHora(pedido.pagamentoConfirmadoEm!)}.'
                          : pedido.pagador == Pagador.cliente
                          ? 'O cliente do construtor paga por PIX direto à loja. Confirme aqui quando receber.'
                          : 'Combine com o construtor e confirme aqui quando receber.',
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Espaco.s3),
            if (pedido.status != StatusPedido.cancelado) ...[
              Painel(
                titulo: 'Dados para a nota',
                child: Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: _DadosDaNota(pedido: pedido),
                ),
              ),
              const SizedBox(height: Espaco.s3),
            ],
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
        );
        final rodape = SafeArea(
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
                    child: Text('Marcar como ${proximo.rotulo.toLowerCase()}'),
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
        );
        if (widget.embutida) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: corpo),
              rodape,
            ],
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Pedido')),
          body: ColunaCentral(child: corpo),
          bottomNavigationBar: ColunaCentral(child: rodape),
        );
      },
    );
  }
}

/// Quem paga e em nome de quem sai a nota. O CPF/CNPJ vem de pedido_documentos (só a equipe da loja lê).
class _DadosDaNota extends StatefulWidget {
  const _DadosDaNota({required this.pedido});
  final PedidoResumo pedido;

  @override
  State<_DadosDaNota> createState() => _DadosDaNotaState();
}

class _DadosDaNotaState extends State<_DadosDaNota> {
  String? _documento;
  bool _falhou = false;
  int _busca = 0;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void didUpdateWidget(_DadosDaNota antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.pedido.id != widget.pedido.id ||
        antigo.pedido.documentoInformadoEm !=
            widget.pedido.documentoInformadoEm) {
      _buscar();
    }
  }

  /// Zera o que já tinha e busca de novo; só a busca mais recente atualiza a tela.
  Future<void> _buscar() async {
    final minha = ++_busca;
    _documento = null;
    _falhou = false;
    if (widget.pedido.documentoInformadoEm == null) return;
    try {
      final doc = await PropostasLojaService.instance.documentoDoPagador(
        widget.pedido.id,
      );
      if (mounted && minha == _busca) setState(() => _documento = doc);
    } catch (_) {
      if (mounted && minha == _busca) setState(() => _falhou = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final pagador = p.pagador;
    if (pagador == null) {
      return Text(
        'O construtor ainda não escolheu quem paga.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final documento = p.documentoInformadoEm == null
        ? 'Aguardando o cliente'
        : _falhou
        ? 'Não carregou'
        : _documento == null
        ? '…'
        : formatarDocumento(_documento!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Dado(
          'Quem paga',
          pagador == Pagador.proprio
              ? 'O próprio construtor'
              : 'Cliente do construtor',
        ),
        if (p.pagadorNome != null) _Dado('Nome', p.pagadorNome!),
        _Dado('CPF/CNPJ', documento),
        if (_falhou)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _falhou = false);
                _buscar();
              },
              child: const Text('Tentar de novo'),
            ),
          ),
        if (p.pagadorWhatsapp != null)
          _Dado('WhatsApp', telefone(p.pagadorWhatsapp!)),
      ],
    );
  }
}

/// Linha rótulo/valor que quebra nomes longos e deixa copiar o valor para a nota.
class _Dado extends StatelessWidget {
  const _Dado(this.rotulo, this.valor);
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
          ),
          const SizedBox(width: Espaco.s3),
          Expanded(
            child: SelectableText(
              valor,
              textAlign: TextAlign.end,
              style: t.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
