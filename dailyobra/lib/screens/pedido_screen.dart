import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/carteira_service.dart';
import '../services/negociacao_service.dart';
import '../services/perfil_service.dart';
import 'componentes.dart';
import 'quem_paga.dart';

const _passos = [
  StatusPedido.confirmado,
  StatusPedido.emSeparacao,
  StatusPedido.saiuEntrega,
  StatusPedido.entregue,
];

/// Acompanhamento do pedido: os passos que a loja marca, pagamento e cashback.
class PedidoScreen extends StatefulWidget {
  const PedidoScreen({
    super.key,
    required this.pedidoId,
    this.embutida = false,
  });
  final String pedidoId;

  /// Dentro de outra tela (Enviados no computador): sem barra de título própria.
  final bool embutida;

  @override
  State<PedidoScreen> createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  bool _ocupado = false;

  Future<void> _abrirLink(Uri uri) async {
    final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abriu && mounted) avisar(context, 'Não deu para abrir o WhatsApp.');
  }

  /// Na mesma aba, para não deixar uma aba em branco no celular quando nenhum banco abre o link.
  Future<void> _abrirBanco(Uri uri) async {
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
    } on Exception {
      // Sem app para o link: o código já foi copiado
    }
  }

  Future<void> _cancelar(PropostaResumo p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancelar o pedido?'),
        content: Text(
          'A ${p.lojaNome} ainda não começou a separar. O cashback previsto sai da carteira e o saldo usado volta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      await NegociacaoService.instance.cancelarPedido(widget.pedidoId);
      if (mounted) avisar(context, 'Pedido cancelado.');
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servico = NegociacaoService.instance;
    return ListenableBuilder(
      // Carteira e perfil entram no "Eu pago" (saldo e titular da nota)
      listenable: Listenable.merge([
        servico,
        CarteiraService.instance,
        PerfilService.instance,
      ]),
      builder: (context, _) {
        final p = servico.propostaDoPedido(widget.pedidoId);
        final pedido = p?.pedido;
        if (p == null || pedido == null) {
          return _moldura(
            titulo: null,
            corpo: const EstadoVazio(
              titulo: 'Pedido não encontrado',
              texto: 'Volte para Enviados e puxe a lista para atualizar.',
            ),
          );
        }
        return _moldura(
          titulo: 'Pedido',
          corpo: _corpo(context, p, pedido),
          rodape: pedido.status == StatusPedido.confirmado
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Espaco.s4,
                      Espaco.s2,
                      Espaco.s4,
                      Espaco.s3,
                    ),
                    child: OutlinedButton(
                      onPressed: _ocupado ? null : () => _cancelar(p),
                      child: const Text('Cancelar pedido'),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _moldura({
    required String? titulo,
    required Widget corpo,
    Widget? rodape,
  }) {
    if (widget.embutida) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: corpo),
          ?rodape,
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: titulo == null ? null : Text(titulo)),
      body: corpo,
      bottomNavigationBar: rodape,
    );
  }

  Widget _corpo(BuildContext context, PropostaResumo p, PedidoResumo pedido) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final loja =
        p.loja ?? Loja(id: p.lojaId, nome: p.lojaNome, cidade: '', uf: '');
    final atual = _passos.indexOf(pedido.status);
    final entregue = pedido.status == StatusPedido.entregue;
    final pago = pedido.pagamentoConfirmadoEm != null;
    final formas = p.loja?.formasPagamento ?? formasPadrao;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s4,
        Espaco.s4,
        Espaco.s8,
      ),
      children: [
        Row(
          children: [
            LogoLoja(loja: loja, tamanho: 48),
            const SizedBox(width: Espaco.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.lojaNome, style: t.titleMedium),
                  Text(
                    'Pedido feito em ${dataHora(pedido.criadoEm)}',
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Espaco.s3),
        Text(
          brl.format(p.aPagar),
          style: t.headlineSmall?.copyWith(fontFeatures: numerosTabulares),
        ),
        Text(
          p.saldoAplicado > 0
              ? 'a pagar, já com ${brl.format(p.saldoAplicado)} de saldo da carteira'
              : 'a pagar, com frete',
          style: t.bodySmall?.copyWith(color: c.textoSuave),
        ),
        const SizedBox(height: Espaco.s4),
        if (pedido.status == StatusPedido.cancelado)
          const Aviso(
            'Pedido cancelado. O cashback previsto foi estornado e o saldo usado voltou para a carteira.',
          )
        else
          Painel(
            titulo: 'Acompanhamento',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Espaco.s2),
              child: Column(
                children: [
                  for (var i = 0; i < _passos.length; i++)
                    _Passo(
                      rotulo: _passos[i].rotulo,
                      detalhe: switch (_passos[i]) {
                        StatusPedido.confirmado => 'A loja confirmou o pedido.',
                        StatusPedido.emSeparacao => 'Separando os materiais.',
                        StatusPedido.saiuEntrega => 'A caminho da obra.',
                        _ =>
                          pedido.entregueEm == null
                              ? 'Material na obra.'
                              : 'Recebido em ${dataHora(pedido.entregueEm!)}.',
                      },
                      estado: entregue || i < atual
                          ? _EstadoPasso.feito
                          : i == atual
                          ? _EstadoPasso.atual
                          : _EstadoPasso.depois,
                      ultimo: i == _passos.length - 1,
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Espaco.s3),
        if (pago)
          Painel(
            titulo: 'Pagamento',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Text(
                'Pagamento confirmado em ${dataHora(pedido.pagamentoConfirmadoEm!)}.',
                style: t.bodyMedium,
              ),
            ),
          )
        else if (pedido.status != StatusPedido.cancelado)
          QuemPaga(
            pedido: pedido,
            nomeLoja: p.lojaNome,
            nomeTitular: PerfilService.instance.nome,
            documentoDoPerfil: PerfilService.instance.documento,
            saldoDisponivel: CarteiraService.instance.disponivel,
            saldoNoPedido: p.saldoAplicado,
            formas: formas,
            formaSugerida: p.formaEscolhida,
            pix: () async => formas.contains(FormaPagamento.pix)
                ? NegociacaoService.instance.pixDoPedido(pedido.id)
                : null,
            pagarEuMesmo: (doc) =>
                NegociacaoService.instance.pagarEuMesmo(pedido.id, doc),
            usarSaldo: (usar) =>
                NegociacaoService.instance.usarSaldo(pedido.id, usar),
            escolherPagamento: (forma, prazo) => NegociacaoService.instance
                .escolherPagamento(pedido.id, forma, prazo: prazo),
            criarLink: (nome, zap, doc) => NegociacaoService.instance.criarLink(
              pedido.id,
              nome: nome,
              whatsapp: zap,
              documento: doc,
            ),
            abrirLink: _abrirLink,
            abrirBanco: _abrirBanco,
          ),
        if (p.cashbackPrevisto > 0 &&
            pedido.status != StatusPedido.cancelado) ...[
          const SizedBox(height: Espaco.s3),
          Painel(
            titulo: 'Cashback',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Text(
                entregue && pago
                    ? '${brl.format(p.cashbackPrevisto)} já estão disponíveis na sua carteira.'
                    : '${brl.format(p.cashbackPrevisto)} ficam disponíveis na carteira depois da entrega '
                          'e do pagamento confirmado pela loja.',
                style: t.bodyMedium?.copyWith(color: c.sucesso),
              ),
            ),
          ),
        ],
        const SizedBox(height: Espaco.s3),
        Painel(
          titulo: 'Produtos',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              children: [
                for (final i in p.itens)
                  LinhaValor(
                    '${formatarQuantidade(i.quantidade)} × ${i.nome}',
                    brl.format(i.total),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _EstadoPasso { feito, atual, depois }

class _Passo extends StatelessWidget {
  const _Passo({
    required this.rotulo,
    required this.detalhe,
    required this.estado,
    required this.ultimo,
  });
  final String rotulo;
  final String detalhe;
  final _EstadoPasso estado;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final (icone, cor, descricao) = switch (estado) {
      _EstadoPasso.feito => (Icons.check_circle, c.sucesso, 'concluído'),
      _EstadoPasso.atual => (Icons.radio_button_checked, c.acao, 'etapa atual'),
      _EstadoPasso.depois => (
        Icons.radio_button_unchecked,
        c.textoSuave,
        'próxima etapa',
      ),
    };
    return Semantics(
      label: '$rotulo: $descricao',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Icon(icone, color: cor),
                  if (!ultimo)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: estado == _EstadoPasso.feito
                            ? c.sucesso
                            : c.borda,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  right: Espaco.s4,
                  bottom: Espaco.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo,
                      style: t.bodyMedium?.copyWith(
                        fontWeight: estado == _EstadoPasso.atual
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: estado == _EstadoPasso.depois
                            ? c.textoSuave
                            : null,
                      ),
                    ),
                    Text(
                      detalhe,
                      style: t.bodySmall?.copyWith(color: c.textoSuave),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
