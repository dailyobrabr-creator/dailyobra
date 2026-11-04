import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/propostas_loja_service.dart';
import 'componentes.dart';
import 'graficos_resultados.dart';
import 'proposta_loja_screen.dart';

/// Mesa do Gerente: o que só o dono ou o gerente decide. Ofertas de preço dos construtores e prazos do crediário, do que
/// espera há mais tempo ao mais novo.
class MesaScreen extends StatelessWidget {
  const MesaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servico = PropostasLojaService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Mesa do Gerente')),
      body: ListenableBuilder(
        listenable: servico,
        builder: (context, _) {
          final ofertas = servico.ofertasPendentes;
          final prazos = servico.prazosPendentes;
          return RefreshIndicator(
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
                ColunaCentral(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (servico.erro != null) ...[
                        Aviso(servico.erro!),
                        const SizedBox(height: Espaco.s3),
                      ],
                      if (!servico.carregado)
                        const Esqueleto(altura: 200)
                      else if (ofertas.isEmpty && prazos.isEmpty)
                        const EstadoVazio(
                          icone: Icons.fact_check_outlined,
                          titulo: 'Nada esperando você',
                          texto: 'Ofertas de clientes e prazos do crediário aparecem aqui.',
                        ),
                      for (final p in ofertas) ...[
                        CartaoDaOferta(key: ValueKey(p.id), proposta: p),
                        const SizedBox(height: Espaco.s3),
                      ],
                      for (final p in prazos) ...[
                        _CartaoPrazo(key: ValueKey(p.id), proposta: p),
                        const SizedBox(height: Espaco.s3),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Entrada para a Mesa do Gerente no Início e em Mais.
class EntradaDaMesa extends StatelessWidget {
  const EntradaDaMesa({super.key, required this.decisoes});
  final int decisoes;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.fact_check_outlined),
    title: const Text('Mesa do Gerente'),
    subtitle: Text(
      decisoes == 0
          ? 'Ofertas de clientes e prazos do crediário'
          : '$decisoes esperando sua decisão',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => irParaAba(context, Aba.mesa),
  );
}

/// "Ana Souza", "Souza Obras" e o que o cliente já comprou da loja: o que o gerente olha antes de decidir.
class _QuemPediu extends StatelessWidget {
  const _QuemPediu({required this.proposta, required this.selo, this.tom});
  final PropostaResumo proposta;
  final String selo;
  final TomSelo? tom;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final servico = PropostasLojaService.instance;
    final quem = servico.construtor(proposta.construtorId);
    final compras = servico.comprasDe(proposta.construtorId);
    final historico = compras.pedidos == 0
        ? 'Primeira compra com a loja'
        : '${compras.pedidos == 1 ? '1 pedido' : '${compras.pedidos} pedidos'} com a loja · ${brl.format(compras.total)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Selo(selo, tom: tom ?? TomSelo.aviso),
        const SizedBox(height: Espaco.s2),
        Text(
          quem.exibicao,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleMedium,
        ),
        Text(
          quem.empresa.isEmpty ? historico : '${quem.empresa} · $historico',
          style: t.bodySmall?.copyWith(color: c.textoSuave),
        ),
      ],
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.filhos});
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) => Painel(
    child: Padding(
      padding: const EdgeInsets.all(Espaco.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: filhos,
      ),
    ),
  );
}

/// Uma oferta na fila: valor da proposta, oferta, desconto pedido e produtos. A margem do modelo original não aparece
/// porque o custo da loja não entra no DailyObra.
class CartaoDaOferta extends StatelessWidget {
  const CartaoDaOferta({super.key, required this.proposta});
  final PropostaResumo proposta;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final p = proposta;
    final suave = t.bodySmall?.copyWith(color: c.textoSuave);
    final percentual = textoPercentual(p.descontoDaOferta / p.total);
    return _Cartao(
      filhos: [
        _QuemPediu(proposta: p, selo: 'Oferta do cliente'),
        const SizedBox(height: Espaco.s3),
        LinhaValor('Total da proposta', brl.format(p.total)),
        LinhaValor(
          'Oferta do cliente',
          brl.format(p.ofertaValor),
          destaque: true,
        ),
        LinhaValor(
          'Desconto pedido',
          '- ${brl.format(p.descontoDaOferta)} ($percentual)',
        ),
        const SizedBox(height: Espaco.s2),
        Text(
          [
            for (final i in p.itens)
              '${formatarQuantidade(i.quantidade)} ${i.unidade} ${i.nome}',
          ].join(' + '),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: suave,
        ),
        if (p.ofertaMensagem != null) ...[
          const SizedBox(height: Espaco.s2),
          Text('Mensagem do cliente: ${p.ofertaMensagem}', style: t.bodyMedium),
        ],
        const SizedBox(height: Espaco.s2),
        Text('Responda até ${dataHora(p.validaAte)}.', style: suave),
        const SizedBox(height: Espaco.s3),
        BotoesDaOferta(proposta: p),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PropostaLojaScreen(id: p.id)),
          ),
          child: const Text('Ver a proposta'),
        ),
      ],
    );
  }
}

/// Recusar ou aprovar a oferta. Na Mesa e na tela da proposta.
class BotoesDaOferta extends StatefulWidget {
  const BotoesDaOferta({super.key, required this.proposta});
  final PropostaResumo proposta;

  @override
  State<BotoesDaOferta> createState() => _BotoesDaOfertaState();
}

class _BotoesDaOfertaState extends State<BotoesDaOferta> {
  bool _ocupado = false;

  Future<void> _responder(bool aprovar, String? motivo, String feito) async {
    setState(() => _ocupado = true);
    try {
      await PropostasLojaService.instance.responderOferta(
        widget.proposta.id,
        aprovar: aprovar,
        motivo: motivo,
      );
      if (mounted) avisar(context, feito);
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _aprovar() async {
    final ok = await confirmar(
      context,
      titulo: 'Aprovar a oferta?',
      texto:
          'Vira pedido de ${brl.format(widget.proposta.ofertaValor)} na hora, com a diferença como desconto.',
      acao: 'Aprovar',
    );
    if (ok) await _responder(true, null, 'Oferta aprovada. Pedido criado.');
  }

  Future<void> _recusar() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const DialogoRecusa(
        titulo: 'Recusar a oferta?',
        texto: 'O construtor vê o motivo. A proposta continua aberta no valor de antes.',
        acao: 'Recusar oferta',
      ),
    );
    if (motivo != null) await _responder(false, motivo, 'Oferta recusada.');
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: _ocupado ? null : _recusar,
          child: const Text('Recusar oferta'),
        ),
      ),
      const SizedBox(width: Espaco.s2),
      Expanded(
        child: FilledButton(
          onPressed: _ocupado ? null : _aprovar,
          child: const Text('Aprovar negociação'),
        ),
      ),
    ],
  );
}

/// Um pedido no crediário esperando o prazo ser aprovado.
class _CartaoPrazo extends StatefulWidget {
  const _CartaoPrazo({super.key, required this.proposta});
  final PropostaResumo proposta;

  @override
  State<_CartaoPrazo> createState() => _CartaoPrazoState();
}

class _CartaoPrazoState extends State<_CartaoPrazo> {
  bool _ocupado = false;

  Future<void> _responder(bool aprovar) async {
    setState(() => _ocupado = true);
    try {
      await PropostasLojaService.instance.responderPrazo(
        widget.proposta.pedido!.id,
        aprovar,
      );
      if (mounted) {
        avisar(context, aprovar ? 'Prazo aprovado.' : 'Prazo recusado.');
      }
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposta;
    final pedido = p.pedido!;
    return _Cartao(
      filhos: [
        _QuemPediu(proposta: p, selo: 'Prazo do crediário', tom: TomSelo.info),
        const SizedBox(height: Espaco.s3),
        LinhaValor('Total do pedido', brl.format(p.total), destaque: true),
        LinhaValor('Prazo pedido', '${pedido.prazo} dias'),
        const SizedBox(height: Espaco.s3),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _ocupado ? null : () => _responder(false),
                child: const Text('Recusar prazo'),
              ),
            ),
            const SizedBox(width: Espaco.s2),
            Expanded(
              child: FilledButton(
                onPressed: _ocupado ? null : () => _responder(true),
                child: const Text('Aprovar prazo'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
