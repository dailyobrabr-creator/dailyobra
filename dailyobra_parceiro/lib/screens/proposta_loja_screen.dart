import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/propostas_loja_service.dart';
import 'componentes.dart';
import 'pedido_loja_screen.dart';

/// Proposta recebida: quem pediu, produtos, valores e a resposta da loja.
class PropostaLojaScreen extends StatefulWidget {
  const PropostaLojaScreen({
    super.key,
    required this.id,
    this.embutida = false,
  });
  final String id;

  /// Ao lado da lista (Propostas no computador): sem barra de título própria.
  final bool embutida;

  @override
  State<PropostaLojaScreen> createState() => _PropostaLojaScreenState();
}

class _PropostaLojaScreenState extends State<PropostaLojaScreen> {
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

  Future<void> _recusar(PropostaResumo p) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoRecusa(),
    );
    if (motivo == null) return;
    await _executar(
      () => PropostasLojaService.instance.recusar(p.id, motivo),
      'Proposta recusada.',
    );
  }

  Future<void> _aceitar(PropostaResumo p) async {
    final pedido = p.modo == ModoProposta.pedido;
    final ok = await confirmar(
      context,
      titulo: pedido ? 'Confirmar o pedido?' : 'Aceitar a proposta?',
      texto:
          'Vira pedido de ${brl.format(p.total)} com o construtor, ao preço anunciado. '
          'Depois você marca a separação e a entrega.',
      acao: pedido ? 'Confirmar pedido' : 'Aceitar',
    );
    if (!ok) return;
    await _executar(
      () => PropostasLojaService.instance.aceitar(p.id),
      'Pedido criado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final servico = PropostasLojaService.instance;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final p = servico.proposta(widget.id);
        if (p == null) {
          const vazio = EstadoVazio(
            titulo: 'Proposta não encontrada',
            texto: 'Volte e puxe a lista para atualizar.',
          );
          return widget.embutida
              ? vazio
              : Scaffold(appBar: AppBar(), body: vazio);
        }
        final t = Theme.of(context).textTheme;
        final c = context.cores;
        final quem = servico.construtor(p.construtorId);
        final (selo, tom) = seloParaLoja(p);
        final aberta = p.status == StatusProposta.enviada;
        final corpo = ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s4,
            Espaco.s4,
            Espaco.s8,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quem.exibicao, style: t.titleLarge),
                      if (quem.empresa.isNotEmpty)
                        Text(
                          quem.empresa,
                          style: t.bodyMedium?.copyWith(color: c.textoSuave),
                        ),
                      if (quem.telefone != null)
                        SelectableText(
                          telefone(quem.telefone!),
                          style: t.bodyMedium,
                        ),
                    ],
                  ),
                ),
                Selo(selo, tom: tom),
              ],
            ),
            const SizedBox(height: Espaco.s3),
            Aviso(switch (p.status) {
              StatusProposta.enviada =>
                p.modo == ModoProposta.pedido
                    ? 'Pedido direto: confirme ou recuse até ${dataHora(p.validaAte)} (${prazo(p.validaAte)}).'
                    : 'Responda até ${dataHora(p.validaAte)} (${prazo(p.validaAte)}): aceite, recuse ou mande uma contraproposta.',
              StatusProposta.contraproposta =>
                'Contraproposta enviada. O construtor responde até ${dataHora(p.validaAte)}.',
              StatusProposta.aceita => 'Aceita. O pedido está em Pedidos.',
              StatusProposta.recusada =>
                'Recusada${p.motivoRecusa == null ? '' : ': ${p.motivoRecusa}'}',
              StatusProposta.cancelada =>
                'O construtor cancelou esta proposta.',
              StatusProposta.expirada => 'O prazo de resposta acabou.',
            }, tom: aberta ? TomSelo.aviso : TomSelo.info),
            if (p.mensagemConstrutor != null &&
                p.mensagemConstrutor!.isNotEmpty) ...[
              const SizedBox(height: Espaco.s3),
              Painel(
                titulo: 'Mensagem do construtor',
                child: Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: Text(p.mensagemConstrutor!, style: t.bodyMedium),
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
                        '${formatarQuantidade(i.quantidade)} ${i.unidade} · ${i.nome}',
                        brl.format(i.total),
                      ),
                  ],
                ),
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
                      LinhaValor('Desconto', '- ${brl.format(p.desconto)}'),
                    LinhaValor(
                      'Frete',
                      p.frete == 0 ? 'Grátis' : brl.format(p.frete),
                    ),
                    LinhaValor('Total', brl.format(p.total), destaque: true),
                    if (p.saldoAplicado > 0)
                      LinhaValor(
                        'Pago com saldo DailyObra',
                        brl.format(p.saldoAplicado),
                        cor: c.sucesso,
                      ),
                  ],
                ),
              ),
            ),
            if (p.saldoAplicado > 0) ...[
              const SizedBox(height: Espaco.s2),
              Text(
                'O construtor usou saldo do Clube DailyObra; esse valor é acertado pelo DailyObra.',
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
            ],
          ],
        );
        final rodape = switch (p.status) {
          StatusProposta.enviada => SafeArea(
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _ocupado ? null : () => _recusar(p),
                          child: const Text('Recusar'),
                        ),
                      ),
                      const SizedBox(width: Espaco.s2),
                      Expanded(
                        child: FilledButton(
                          onPressed: _ocupado ? null : () => _aceitar(p),
                          child: Text(
                            p.modo == ModoProposta.pedido
                                ? 'Confirmar'
                                : 'Aceitar',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (p.modo == ModoProposta.negociacao)
                    TextButton(
                      onPressed: _ocupado
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ContrapropostaScreen(propostaId: p.id),
                              ),
                            ),
                      child: const Text('Mandar contraproposta'),
                    ),
                ],
              ),
            ),
          ),
          StatusProposta.aceita when p.pedido != null => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s2,
                Espaco.s4,
                Espaco.s3,
              ),
              child: FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PedidoLojaScreen(pedidoId: p.pedido!.id),
                  ),
                ),
                child: const Text('Ver pedido'),
              ),
            ),
          ),
          _ => null,
        };
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
          appBar: AppBar(
            title: Text(
              p.modo == ModoProposta.pedido ? 'Pedido direto' : 'Proposta',
            ),
          ),
          body: ColunaCentral(child: corpo),
          bottomNavigationBar: rodape == null
              ? null
              : ColunaCentral(child: rodape),
        );
      },
    );
  }
}

class _DialogoRecusa extends StatefulWidget {
  const _DialogoRecusa();

  @override
  State<_DialogoRecusa> createState() => _DialogoRecusaState();
}

class _DialogoRecusaState extends State<_DialogoRecusa> {
  final _motivo = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recusar a proposta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'O construtor vê o motivo. Seja direto: falta de estoque, prazo de entrega, região.',
          ),
          const SizedBox(height: Espaco.s3),
          TextField(
            controller: _motivo,
            maxLength: 300,
            maxLines: 3,
            minLines: 2,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Motivo da recusa',
              errorText: _erro,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () {
            if (_motivo.text.trim().length < 3) {
              setState(() => _erro = 'Informe o motivo da recusa.');
              return;
            }
            Navigator.pop(context, _motivo.text.trim());
          },
          child: const Text('Recusar proposta'),
        ),
      ],
    );
  }
}

typedef EnviarContraproposta = Future<void> Function(
  Map<String, double> precos,
  double desconto,
  int validadeHoras,
  String? mensagem,
);

/// Contraproposta: preço por produto (só para baixo), desconto no total, prazo e mensagem.
class ContrapropostaScreen extends StatefulWidget {
  const ContrapropostaScreen({
    super.key,
    required this.propostaId,
    this.enviar,
  });
  final String propostaId;

  /// Quem envia; o padrão é a função responder_proposta do servidor.
  final EnviarContraproposta? enviar;

  @override
  State<ContrapropostaScreen> createState() => _ContrapropostaScreenState();
}

class _ContrapropostaScreenState extends State<ContrapropostaScreen> {
  final Map<String, TextEditingController> _precos = {};
  final _desconto = TextEditingController();
  final _mensagem = TextEditingController();
  int _validade = 48;
  Map<String, String> _erros = const {};
  String? _erroDesconto;
  bool _enviando = false;

  PropostaResumo? get _p =>
      PropostasLojaService.instance.proposta(widget.propostaId);

  @override
  void initState() {
    super.initState();
    for (final i in _p?.itens ?? const <ItemProposta>[]) {
      _precos[i.itemId] = TextEditingController(
        text: numero.format(i.precoAnunciado),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _precos.values) {
      c.dispose();
    }
    _desconto.dispose();
    _mensagem.dispose();
    super.dispose();
  }

  ({double subtotal, double desconto}) _calcular(PropostaResumo p) {
    var subtotal = 0.0;
    for (final i in p.itens) {
      final v = lerNumero(_precos[i.itemId]!.text);
      subtotal += (v.isNaN ? i.precoAnunciado : v) * i.quantidade;
    }
    final d = _desconto.text.trim().isEmpty ? 0.0 : lerNumero(_desconto.text);
    return (
      subtotal: (subtotal * 100).roundToDouble() / 100,
      desconto: d.isNaN ? 0 : d,
    );
  }

  Future<void> _enviar(PropostaResumo p) async {
    final erros = <String, String>{};
    final precos = <String, double>{};
    for (final i in p.itens) {
      final v = lerNumero(_precos[i.itemId]!.text);
      if (v.isNaN || v <= 0) {
        erros[i.itemId] = 'Preço inválido.';
      } else if (v > i.precoAnunciado + 0.0001) {
        erros[i.itemId] = 'O preço só pode baixar.';
      } else if (v < i.precoAnunciado) {
        precos[i.itemId] = (v * 100).roundToDouble() / 100;
      }
    }
    final calc = _calcular(p);
    String? erroDesconto;
    final d = _desconto.text.trim().isEmpty ? 0.0 : lerNumero(_desconto.text);
    if (d.isNaN || d < 0) {
      erroDesconto = 'Desconto inválido.';
    } else if (d > calc.subtotal) {
      erroDesconto =
          'O desconto não pode passar de ${brl.format(calc.subtotal)}.';
    }
    setState(() {
      _erros = erros;
      _erroDesconto = erroDesconto;
    });
    if (erros.isNotEmpty || erroDesconto != null) return;
    if (precos.isEmpty && calc.desconto == 0) {
      avisar(context, 'Baixe o preço de algum produto ou dê desconto.');
      return;
    }
    setState(() => _enviando = true);
    try {
      final enviar =
          widget.enviar ??
          (precos, desconto, validade, mensagem) =>
              PropostasLojaService.instance.contrapropor(
                p.id,
                precos: precos,
                desconto: desconto,
                validadeHoras: validade,
                mensagem: mensagem,
              );
      await enviar(precos, calc.desconto, _validade, _mensagem.text);
      if (mounted) {
        avisar(context, 'Contraproposta enviada.');
        Navigator.maybePop(context);
      }
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVazio(
          titulo: 'Proposta não encontrada',
          texto: 'Volte e puxe a lista para atualizar.',
        ),
      );
    }
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final calc = _calcular(p);
    final total = calc.subtotal - calc.desconto + p.frete;
    final formatos = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Scaffold(
      appBar: AppBar(title: const Text('Contraproposta')),
      body: ColunaCentral(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s4,
            Espaco.s4,
            Espaco.s8,
          ),
          children: [
            Text(
              'Baixe o preço de algum produto ou dê desconto no total. O construtor aceita ou recusa.',
              style: t.bodyMedium?.copyWith(color: c.textoSuave),
            ),
            const SizedBox(height: Espaco.s4),
            for (final i in p.itens) ...[
              Text(i.nome, style: t.titleSmall),
              Text(
                '${formatarQuantidade(i.quantidade)} ${i.unidade} · anunciado ${brl.format(i.precoAnunciado)}',
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
              const SizedBox(height: Espaco.s1),
              TextField(
                controller: _precos[i.itemId],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: formatos,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixText: 'R\$ ',
                  suffixText: '/ ${i.unidade}',
                  errorText: _erros[i.itemId],
                ),
              ),
              const SizedBox(height: Espaco.s4),
            ],
            const Rotulo('Desconto no total (R\$)'),
            TextField(
              controller: _desconto,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: formatos,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0,00',
                prefixText: 'R\$ ',
                errorText: _erroDesconto,
              ),
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Prazo para o construtor responder'),
            Segmentado<int>(
              valor: _validade,
              opcoes: const [(24, '24 h'), (48, '48 h'), (72, '72 h')],
              onChanged: (v) => setState(() => _validade = v),
            ),
            const SizedBox(height: Espaco.s4),
            const Rotulo('Mensagem (opcional)'),
            TextField(
              controller: _mensagem,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ex.: entrego na sexta pela manhã',
              ),
            ),
            const SizedBox(height: Espaco.s3),
            Painel(
              child: Padding(
                padding: const EdgeInsets.all(Espaco.s4),
                child: Column(
                  children: [
                    LinhaValor('Produtos', brl.format(calc.subtotal)),
                    if (calc.desconto > 0)
                      LinhaValor('Desconto', '- ${brl.format(calc.desconto)}'),
                    LinhaValor(
                      'Frete',
                      p.frete == 0 ? 'Grátis' : brl.format(p.frete),
                    ),
                    LinhaValor(
                      'Novo total',
                      brl.format(total < 0 ? 0 : total),
                      destaque: true,
                    ),
                    LinhaValor('Total anterior', brl.format(p.total)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ColunaCentral(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s2,
              Espaco.s4,
              Espaco.s3,
            ),
            child: FilledButton(
              onPressed: _enviando ? null : () => _enviar(p),
              child: Text(_enviando ? 'Enviando…' : 'Enviar contraproposta'),
            ),
          ),
        ),
      ),
    );
  }
}
