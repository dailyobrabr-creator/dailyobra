import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/negociacao_service.dart';
import 'componentes.dart';
import 'pedido_screen.dart';

/// Detalhe de uma proposta: itens com o preço anunciado e o ofertado, valores e a decisão.
class PropostaScreen extends StatefulWidget {
  const PropostaScreen({super.key, required this.id, this.embutida = false});
  final String id;

  /// Dentro de outra tela (Enviados no computador): sem barra de título própria.
  final bool embutida;

  @override
  State<PropostaScreen> createState() => _PropostaScreenState();
}

class _PropostaScreenState extends State<PropostaScreen> {
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

  Future<void> _fazerOferta(NegociacaoService servico, PropostaResumo p) async {
    final oferta = await showDialog<(double, String?)>(
      context: context,
      builder: (_) => _DialogoOferta(proposta: p),
    );
    if (oferta == null) return;
    await _executar(
      () => servico.fazerOferta(p.id, oferta.$1, oferta.$2),
      'Oferta enviada para a loja.',
    );
  }

  Future<bool> _confirmar(String titulo, String texto, String acao) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(acao),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final servico = NegociacaoService.instance;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final p = servico.proposta(widget.id);
        if (p == null) {
          return _moldura(
            titulo: null,
            corpo: const EstadoVazio(
              titulo: 'Proposta não encontrada',
              texto: 'Volte para Enviados e puxe a lista para atualizar.',
            ),
          );
        }
        return _moldura(
          titulo: p.modo == ModoProposta.pedido ? 'Pedido direto' : 'Proposta',
          corpo: _corpo(context, p),
          rodape: _acoes(context, servico, p),
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

  Widget _corpo(BuildContext context, PropostaResumo p) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final (selo, tom) = seloDaProposta(p.status, p.pedido?.status);
    final loja =
        p.loja ?? Loja(id: p.lojaId, nome: p.lojaNome, cidade: '', uf: '');
    final (aviso, tomAviso) = switch (p.status) {
      StatusProposta.enviada => (
        'Aguardando a ${p.lojaNome}. Ela responde até ${dataHora(p.validaAte)}.',
        TomSelo.info,
      ),
      StatusProposta.contraproposta => (
        'A loja mandou uma contraproposta. Responda até ${dataHora(p.validaAte)}.',
        TomSelo.aviso,
      ),
      StatusProposta.aceita => (
        'Proposta aceita. O pedido foi criado.',
        TomSelo.sucesso,
      ),
      StatusProposta.recusada => (
        p.motivoRecusa == null || p.motivoRecusa!.isEmpty
            ? 'A loja recusou esta proposta.'
            : 'A loja recusou: ${p.motivoRecusa}',
        TomSelo.erro,
      ),
      StatusProposta.cancelada => (
        'Você cancelou esta proposta.',
        TomSelo.info,
      ),
      StatusProposta.expirada => (
        'O prazo de resposta acabou. Monte a cotação de novo para pedir preço.',
        TomSelo.info,
      ),
    };
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
                    'Enviada em ${dataHora(p.criadaEm)}',
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                ],
              ),
            ),
            Selo(selo, tom: tom),
          ],
        ),
        const SizedBox(height: Espaco.s4),
        Aviso(aviso, tom: tomAviso),
        if (_avisoDaOferta(p) case (final texto, final tomDaOferta)?) ...[
          const SizedBox(height: Espaco.s3),
          Aviso(texto, tom: tomDaOferta),
        ],
        if (p.mensagemLoja != null && p.mensagemLoja!.isNotEmpty) ...[
          const SizedBox(height: Espaco.s3),
          Painel(
            titulo: 'Mensagem da loja',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Text(p.mensagemLoja!, style: t.bodyMedium),
            ),
          ),
        ],
        if (p.mensagemConstrutor != null &&
            p.mensagemConstrutor!.isNotEmpty) ...[
          const SizedBox(height: Espaco.s3),
          Painel(
            titulo: 'Sua mensagem',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Text(p.mensagemConstrutor!, style: t.bodyMedium),
            ),
          ),
        ],
        const SizedBox(height: Espaco.s3),
        Painel(
          titulo: 'Produtos',
          child: Column(
            children: [for (final item in p.itens) _ItemProposta(item: item)],
          ),
        ),
        const SizedBox(height: Espaco.s3),
        Painel(
          titulo: 'Valores',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              children: [
                LinhaValor('Produtos', brl.format(p.subtotalFinal)),
                if (p.desconto > 0)
                  LinhaValor(
                    'Desconto da loja',
                    '- ${brl.format(p.desconto)}',
                    cor: c.sucesso,
                  ),
                LinhaValor(
                  'Frete',
                  p.frete == 0 ? 'Grátis' : brl.format(p.frete),
                ),
                LinhaValor('Total', brl.format(p.total), destaque: true),
                if (p.saldoAplicado > 0) ...[
                  LinhaValor(
                    'Saldo da carteira',
                    '- ${brl.format(p.saldoAplicado)}',
                    cor: c.sucesso,
                  ),
                  LinhaValor('A pagar', brl.format(p.aPagar), destaque: true),
                ],
                if (p.cashbackPrevisto > 0)
                  LinhaValor(
                    'Cashback previsto',
                    '+ ${brl.format(p.cashbackPrevisto)}',
                    cor: c.sucesso,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Em que pé está a oferta do construtor; nulo sem oferta ou quando ela já não importa.
  (String, TomSelo)? _avisoDaOferta(PropostaResumo p) {
    final valor = p.ofertaValor;
    if (valor == null) return null;
    final oferta = brl.format(valor);
    return switch (p.ofertaStatus) {
      StatusOferta.aprovada => (
        'A loja aprovou sua oferta de $oferta.',
        TomSelo.sucesso,
      ),
      _ when !p.status.aberta => null,
      StatusOferta.pendente => (
        'Sua oferta de $oferta está com a ${p.lojaNome}. A resposta aparece aqui.',
        TomSelo.info,
      ),
      StatusOferta.recusada =>
        p.ofertaMotivo == null || p.ofertaMotivo!.isEmpty
            ? ('A loja recusou sua oferta de $oferta.', TomSelo.aviso)
            : (
                'A loja recusou sua oferta de $oferta: ${p.ofertaMotivo}',
                TomSelo.aviso,
              ),
      null => null,
    };
  }

  Widget? _acoes(
    BuildContext context,
    NegociacaoService servico,
    PropostaResumo p,
  ) {
    final t = Theme.of(context).textTheme;
    Widget barra(List<Widget> filhos) => SafeArea(
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
          children: filhos,
        ),
      ),
    );
    switch (p.status) {
      case StatusProposta.contraproposta:
        return barra([
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _ocupado
                      ? null
                      : () async {
                          if (await _confirmar(
                            'Recusar a contraproposta?',
                            'A negociação com a ${p.lojaNome} termina aqui. O saldo reservado volta para a carteira.',
                            'Recusar',
                          )) {
                            await _executar(
                              () => servico.recusarContraproposta(p.id),
                              'Contraproposta recusada.',
                            );
                          }
                        },
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: Espaco.s2),
              Expanded(
                child: FilledButton(
                  onPressed: _ocupado
                      ? null
                      : () => _executar(
                          () => servico.aceitarContraproposta(p.id),
                          'Contraproposta aceita. Virou pedido.',
                        ),
                  child: const Text('Aceitar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espaco.s1),
          Text(
            'Aceitando, vira pedido com a ${p.lojaNome} por ${brl.format(p.total)}.',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
          ),
          if (p.aceitaOferta)
            TextButton(
              onPressed: _ocupado ? null : () => _fazerOferta(servico, p),
              child: const Text('Fazer uma oferta'),
            ),
        ]);
      case StatusProposta.enviada:
        return barra([
          if (p.aceitaOferta) ...[
            FilledButton(
              onPressed: _ocupado ? null : () => _fazerOferta(servico, p),
              child: const Text('Fazer uma oferta'),
            ),
            const SizedBox(height: Espaco.s2),
          ],
          OutlinedButton(
            onPressed: _ocupado
                ? null
                : () async {
                    if (await _confirmar(
                      'Cancelar a proposta?',
                      'A ${p.lojaNome} não poderá mais responder. O saldo reservado volta para a carteira.',
                      'Cancelar proposta',
                    )) {
                      await _executar(
                        () => servico.cancelar(p.id),
                        'Proposta cancelada.',
                      );
                    }
                  },
            child: const Text('Cancelar proposta'),
          ),
        ]);
      case StatusProposta.aceita when p.pedido != null:
        return barra([
          FilledButton(
            onPressed: () {
              final rota = MaterialPageRoute<void>(
                builder: (_) => PedidoScreen(pedidoId: p.pedido!.id),
              );
              // Embutida, a tela de baixo é a navegação principal: não pode ser trocada
              widget.embutida
                  ? Navigator.push(context, rota)
                  : Navigator.pushReplacement(context, rota);
            },
            child: const Text('Acompanhar pedido'),
          ),
        ]);
      default:
        return null;
    }
  }
}

/// Pede o valor da oferta, com as mesmas regras do servidor. Devolve o valor e a mensagem.
class _DialogoOferta extends StatefulWidget {
  const _DialogoOferta({required this.proposta});
  final PropostaResumo proposta;

  @override
  State<_DialogoOferta> createState() => _DialogoOfertaState();
}

class _DialogoOfertaState extends State<_DialogoOferta> {
  final _valor = TextEditingController();
  final _mensagem = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    _mensagem.dispose();
    super.dispose();
  }

  void _enviar() {
    final p = widget.proposta;
    final valor = lerPreco(_valor.text);
    final erro = valor == null
        ? 'Digite o valor da oferta.'
        : valor >= p.total
        ? 'Precisa ser menor que ${brl.format(p.total)}.'
        : valor <= p.frete
        ? 'Precisa ser maior que o frete de ${brl.format(p.frete)}.'
        : null;
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    final mensagem = _mensagem.text.trim();
    Navigator.pop(context, (valor!, mensagem.isEmpty ? null : mensagem));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposta;
    return AlertDialog(
      title: const Text('Fazer uma oferta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'O total hoje é ${brl.format(p.total)}, com frete. Diga quanto quer pagar no total. Se a ${p.lojaNome} aprovar, vira pedido na hora.',
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Sua oferta (R\$)',
              controller: _valor,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erro,
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Mensagem para a loja',
              controller: _mensagem,
              maxLength: 300,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton(onPressed: _enviar, child: const Text('Enviar oferta')),
      ],
    );
  }
}

class _ItemProposta extends StatelessWidget {
  const _ItemProposta({required this.item});
  final ItemProposta item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s3,
        Espaco.s4,
        Espaco.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${formatarQuantidade(item.quantidade)} ${item.unidade} · total ${brl.format(item.total)}',
                  style: t.bodySmall?.copyWith(
                    color: c.textoSuave,
                    fontFeatures: numerosTabulares,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.s2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.mudou)
                Text(
                  brl.format(item.precoAnunciado),
                  style: t.bodySmall?.copyWith(
                    color: c.textoSuave,
                    decoration: TextDecoration.lineThrough,
                    fontFeatures: numerosTabulares,
                  ),
                ),
              Text(
                brl.format(item.precoFinal),
                style: t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: item.mudou ? c.acao : null,
                  fontFeatures: numerosTabulares,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
