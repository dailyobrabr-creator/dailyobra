import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/propostas_loja_service.dart';
import 'componentes.dart';
import 'pedido_loja_screen.dart';

const _larguraDaTabela = 760.0;
const _tamanhoDoNumero = 40;

/// Faturamento / Caixa: os pedidos que precisam entrar no Santri. A loja lança lá e registra aqui o número da venda;
/// o DailyObra não escreve no Santri.
class FaturamentoScreen extends StatelessWidget {
  const FaturamentoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servico = PropostasLojaService.instance;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final abas = [
          (
            rotulo: 'Para lançar',
            lista: servico.paraFaturar,
            vazioTitulo: 'Nenhum pedido para lançar',
            vazioTexto: 'Os pedidos pagos ou com prazo aprovado aparecem aqui para entrar no Santri.',
          ),
          (
            rotulo: 'Aguardando pagamento',
            lista: servico.aguardandoPagamento,
            vazioTitulo: 'Nenhum pedido aguardando',
            vazioTexto: 'Pedidos sem pagamento confirmado ou com prazo por aprovar ficam aqui.',
          ),
          (
            rotulo: 'Lançados',
            lista: servico.faturados,
            vazioTitulo: 'Nenhum pedido lançado',
            vazioTexto: 'Os pedidos lançados no Santri ficam aqui, com o número da venda.',
          ),
        ];
        return DefaultTabController(
          length: abas.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Faturamento / Caixa'),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final a in abas)
                    Tab(text: '${a.rotulo} (${a.lista.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                for (final a in abas)
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
                            const Esqueleto(altura: 88),
                            const SizedBox(height: Espaco.s3),
                          ]
                        else if (a.lista.isEmpty)
                          EstadoVazio(
                            icone: Icons.point_of_sale_outlined,
                            titulo: a.vazioTitulo,
                            texto: a.vazioTexto,
                          )
                        else
                          for (final p in a.lista) ...[
                            _LinhaDoPedido(proposta: p),
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

/// Código curto do pedido, o mesmo em todas as linhas.
String codigoDoPedido(PedidoResumo pedido) =>
    '#${pedido.id.substring(0, 8).toUpperCase()}';

String textoDaForma(PedidoResumo pedido) {
  final forma = pedido.formaPagamento;
  if (forma == null) return 'Forma não escolhida';
  if (forma == FormaPagamento.crediario && pedido.prazo != null) {
    return 'Crediário: ${pedido.prazo} dias';
  }
  return forma.rotulo;
}

(String, TomSelo) situacaoNoFaturamento(PedidoResumo pedido) {
  if (pedido.erpNumero != null) {
    return pedido.status == StatusPedido.cancelado
        ? ('Cancelado: estornar no Santri', TomSelo.erro)
        : ('Lançado', TomSelo.sucesso);
  }
  if (pedido.prontoParaFaturar) return ('Pronto para lançar', TomSelo.aviso);
  if (pedido.formaPagamento == FormaPagamento.crediario) {
    return switch (pedido.prazoStatus) {
      StatusPrazo.recusado => ('Prazo recusado', TomSelo.erro),
      _ => ('Prazo para aprovar', TomSelo.aviso),
    };
  }
  if (pedido.pagamentoInformadoEm != null) {
    return ('Cliente informou o pagamento', TomSelo.info);
  }
  return ('Aguardando pagamento', TomSelo.neutro);
}

class _LinhaDoPedido extends StatefulWidget {
  const _LinhaDoPedido({required this.proposta});
  final PropostaResumo proposta;

  @override
  State<_LinhaDoPedido> createState() => _LinhaDoPedidoState();
}

class _LinhaDoPedidoState extends State<_LinhaDoPedido> {
  var _ocupado = false;

  void _ver() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PedidoLojaScreen(pedidoId: widget.proposta.pedido!.id),
      ),
    );
  }

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

  Future<void> _lancar() async {
    final pedido = widget.proposta.pedido!;
    final numero = await showDialog<String>(
      context: context,
      builder: (_) => _JanelaDoLancamento(pedido: pedido),
    );
    if (numero == null || !mounted) return;
    await _executar(
      () =>
          PropostasLojaService.instance.registrarFaturamento(pedido.id, numero),
      'Pedido lançado.',
    );
  }

  Future<void> _desfazer() async {
    final pedido = widget.proposta.pedido!;
    if (await confirmar(
      context,
      titulo: 'Desfazer o lançamento?',
      texto: 'O pedido volta para a fila. Se a venda já entrou no Santri, estorne por lá.',
      acao: 'Desfazer',
    )) {
      await _executar(
        () => PropostasLojaService.instance.desfazerFaturamento(pedido.id),
        'Lançamento desfeito.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final p = widget.proposta;
    final pedido = p.pedido!;
    final quem = PropostasLojaService.instance.construtor(p.construtorId);
    final (situacao, tom) = situacaoNoFaturamento(pedido);
    final numero = pedido.erpNumero;
    final lancadoEm = pedido.erpLancadoEm;
    final cliente = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          codigoDoPedido(pedido),
          style: t.labelMedium?.copyWith(
            color: c.acao,
            fontWeight: FontWeight.w700,
            fontFeatures: numerosTabulares,
          ),
        ),
        Text(
          quem.exibicao,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleSmall,
        ),
        Text(
          [
            if (quem.empresa.isNotEmpty) quem.empresa,
            dataHora(pedido.criadoEm),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(color: c.textoSuave),
        ),
      ],
    );
    final valor = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          brl.format(pedido.total),
          style: t.titleSmall?.copyWith(fontFeatures: numerosTabulares),
        ),
        Text(
          textoDaForma(pedido),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(color: c.textoSuave),
        ),
      ],
    );
    final selo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Selo(situacao, tom: tom),
        if (numero != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Venda nº $numero${lancadoEm == null ? '' : ' · ${dataHora(lancadoEm)}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
          ),
      ],
    );
    final acoes = Wrap(
      spacing: Espaco.s2,
      runSpacing: Espaco.s2,
      children: [
        if (numero == null && pedido.prontoParaFaturar)
          FilledButton(
            onPressed: _ocupado ? null : _lancar,
            child: const Text('Lançar no Santri'),
          ),
        OutlinedButton(onPressed: _ver, child: const Text('Ver pedido')),
        if (numero != null)
          TextButton(
            onPressed: _ocupado ? null : _desfazer,
            child: const Text('Desfazer'),
          ),
      ],
    );
    return Painel(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s3),
        child: LayoutBuilder(
          builder: (context, limites) {
            if (limites.maxWidth < _larguraDaTabela) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cliente,
                  const SizedBox(height: Espaco.s2),
                  valor,
                  const SizedBox(height: Espaco.s2),
                  selo,
                  const SizedBox(height: Espaco.s3),
                  acoes,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: cliente),
                const SizedBox(width: Espaco.s3),
                Expanded(flex: 2, child: valor),
                const SizedBox(width: Espaco.s3),
                Expanded(flex: 2, child: selo),
                const SizedBox(width: Espaco.s3),
                Expanded(flex: 3, child: acoes),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Pede o número da venda no Santri; devolve o número digitado.
class _JanelaDoLancamento extends StatefulWidget {
  const _JanelaDoLancamento({required this.pedido});
  final PedidoResumo pedido;

  @override
  State<_JanelaDoLancamento> createState() => _JanelaDoLancamentoState();
}

class _JanelaDoLancamentoState extends State<_JanelaDoLancamento> {
  final _numero = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  void _salvar() {
    final numero = _numero.text.trim();
    if (numero.isEmpty) {
      setState(() => _erro = 'Informe o número da venda.');
      return;
    }
    if (numero.length > _tamanhoDoNumero) {
      setState(() => _erro = 'Use no máximo $_tamanhoDoNumero caracteres.');
      return;
    }
    Navigator.pop(context, numero);
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    return AlertDialog(
      title: Text('Lançar ${codigoDoPedido(pedido)}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Lance a venda de ${brl.format(pedido.total)} no Santri e informe o número que ele gerou.',
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Número da venda no Santri',
              controller: _numero,
              obrigatorio: true,
              erro: _erro,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Registrar')),
      ],
    );
  }
}
