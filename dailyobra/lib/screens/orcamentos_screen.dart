import 'dart:math' as math;

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carrinho_service.dart';
import '../services/carteira_service.dart';
import '../services/catalogo_service.dart';
import '../services/negociacao_service.dart';
import 'componentes.dart';
import 'layout_adaptativo.dart';
import 'pedido_screen.dart';
import 'proposta_screen.dart';

/// Cotação do orçamento entre as lojas e as propostas já enviadas.
class OrcamentosScreen extends StatefulWidget {
  const OrcamentosScreen({super.key});

  @override
  State<OrcamentosScreen> createState() => _OrcamentosScreenState();
}

class _OrcamentosScreenState extends State<OrcamentosScreen>
    with SingleTickerProviderStateMixin {
  late final _abas = TabController(length: 2, vsync: this);
  ModoCotacao _modo = ModoCotacao.menorPrecoGlobal;
  bool _usarSaldo = false;
  bool _enviando = false;
  String? _avisoEnvio;
  TomSelo _tomAviso = TomSelo.sucesso;

  /// Proposta aberta ao lado da lista em Enviados (computador).
  String? _aberta;

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  Future<void> _proposta(ResultadoCotacao r) async {
    final mensagem = await mostrarJanela<String>(
      context,
      construtor: (_) => _FolhaProposta(lojas: r.grupos.length),
    );
    if (mensagem != null) await _enviar(ModoProposta.negociacao, r, mensagem);
  }

  Future<void> _fecharPedido(ResultadoCotacao r, double aPagar) async {
    final n = r.grupos.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Fechar pedido?'),
        content: Text(
          'Vamos enviar um pedido direto para ${n == 1 ? '1 loja' : '$n lojas'}, '
          'no total de ${brl.format(aPagar)}, ao preço anunciado. Cada loja confirma ou recusa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar pedido'),
          ),
        ],
      ),
    );
    if (ok == true) await _enviar(ModoProposta.pedido, r, null);
  }

  Future<void> _enviar(
    ModoProposta modo,
    ResultadoCotacao r,
    String? mensagem,
  ) async {
    setState(() => _enviando = true);
    try {
      final res = await NegociacaoService.instance.enviar(
        modo: modo,
        cotacao: r,
        usarSaldo: _usarSaldo && CarteiraService.instance.disponivel > 0,
        mensagem: mensagem,
      );
      CarrinhoService.instance.limpar();
      if (!mounted) return;
      final quem = res.lojas == 1 ? '1 loja' : '${res.lojas} lojas';
      final oQue = modo == ModoProposta.pedido
          ? 'Pedido enviado'
          : 'Proposta enviada';
      setState(() {
        _usarSaldo = false;
        _avisoEnvio = res.precosAtualizados
            ? '$oQue para $quem. Os preços foram atualizados pelas lojas: confira os valores abaixo.'
            : '$oQue para $quem. As respostas aparecem aqui.';
        _tomAviso = res.precosAtualizados ? TomSelo.aviso : TomSelo.sucesso;
      });
      _abas.animateTo(1);
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _trocarLoja(ItemCatalogo item, String? atual) {
    final catalogo = CatalogoService.instance;
    final precos = catalogo
        .precosDoItem(item.id)
        .where((p) => p.$2.aberta)
        .toList();
    mostrarJanela<void>(
      context,
      construtor: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Espaco.s4),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                0,
                Espaco.s4,
                Espaco.s2,
              ),
              child: Text(
                'Comprar ${item.nome} em',
                style: Theme.of(c).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Loja mais barata (automático)'),
              trailing: atual == null ? const Icon(Icons.check) : null,
              onTap: () {
                CarrinhoService.instance.fixarLoja(item.id, null);
                Navigator.pop(c);
              },
            ),
            for (final (oferta, loja) in precos)
              ListTile(
                leading: LogoLoja(loja: loja, tamanho: 36),
                title: Text(loja.nome),
                subtitle: Text(
                  '${brl.format(oferta.precoVigente(DateTime.now())!)} / ${item.unidade}',
                ),
                trailing: atual == loja.id ? const Icon(Icons.check) : null,
                onTap: () {
                  CarrinhoService.instance.fixarLoja(item.id, loja.id);
                  Navigator.pop(c);
                  if (_modo == ModoCotacao.melhorPorLoja) {
                    setState(() => _modo = ModoCotacao.menorPrecoGlobal);
                    avisar(
                      context,
                      'Produto fixado na ${loja.nome}. A cotação voltou para menor preço global.',
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamentos'),
        bottom: TabBar(
          controller: _abas,
          tabs: [
            const Tab(text: 'Cotação'),
            Tab(
              child: ListenableBuilder(
                listenable: NegociacaoService.instance,
                builder: (context, _) {
                  final n = NegociacaoService.instance.aguardandoVoce;
                  return Badge(
                    isLabelVisible: n > 0,
                    label: Text('$n'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Espaco.s2),
                      child: Text('Enviados'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _abas,
        children: [_cotacao(context), _enviados(context)],
      ),
    );
  }

  Widget _cotacao(BuildContext context) {
    final carrinho = CarrinhoService.instance;
    final catalogo = CatalogoService.instance;
    final carteira = CarteiraService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([carrinho, catalogo, carteira]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final c = context.cores;
        if (carrinho.vazio) {
          return Center(
            child: SingleChildScrollView(
              child: EstadoVazio(
                icone: Icons.request_quote_outlined,
                titulo: 'Seu orçamento está vazio',
                texto: 'Adicione produtos pela busca, pelas lojas ou cole a lista da obra na lista inteligente.',
                acao: FilledButton.tonal(
                  onPressed: () => irParaAba(context, Aba.inicio),
                  child: const Text('Ver produtos'),
                ),
              ),
            ),
          );
        }
        final r = cotar(
          itens: carrinho.itens,
          catalogo: catalogo.itemPorId,
          ofertas: catalogo.ofertas,
          lojas: catalogo.lojaPorId,
          modo: _modo,
          hoje: DateTime.now(),
          percentualPorTier: catalogo.percentualPorTier,
          cidade: catalogo.cidade,
        );
        final fixadas = {
          for (final i in carrinho.itens)
            if (i.lojaFixada != null) i.itemId: i.lojaFixada!,
        };
        final quantidades = {
          for (final i in carrinho.itens) i.itemId: i.quantidade,
        };
        final abaixo = r.grupos.where((g) => g.abaixoMinimo).toList();
        final motivo = r.grupos.isEmpty
            ? 'Nenhum produto do orçamento tem oferta agora.'
            : abaixo.isNotEmpty
            ? 'Para enviar, complete o pedido mínimo da ${abaixo.map((g) => g.loja.nome).join(', ')} '
                  'ou troque os produtos de loja.'
            : null;
        final disponivel = carteira.disponivel;
        final aplicado = _usarSaldo ? math.min(disponivel, r.total) : 0.0;
        final pode = motivo == null && !_enviando;
        final largo = formatoDoContexto(context) == Formato.computador;
        final modo = <Widget>[
          Segmentado<ModoCotacao>(
            valor: _modo,
            opcoes: [for (final m in ModoCotacao.values) (m, m.rotulo)],
            onChanged: (m) => setState(() => _modo = m),
          ),
          const SizedBox(height: Espaco.s2),
          Text(
            _modo == ModoCotacao.menorPrecoGlobal
                ? 'Cada produto na loja mais barata. Pode dar mais de uma entrega.'
                : 'Uma loja só, a que atende mais produtos pelo menor total.',
            style: t.bodySmall?.copyWith(color: c.textoSuave),
          ),
        ];
        final grupos = <Widget>[
          for (final g in r.grupos) ...[
            _GrupoCotado(
              grupo: g,
              fixadas: fixadas,
              onTrocar: (item) => _trocarLoja(item, fixadas[item.id]),
            ),
            const SizedBox(height: Espaco.s3),
          ],
          if (r.semOferta.isNotEmpty) ...[
            Painel(
              titulo: _modo == ModoCotacao.melhorPorLoja
                  ? 'Sem oferta nesta loja'
                  : 'Sem oferta no momento',
              child: Column(
                children: [
                  for (final item in r.semOferta)
                    ListTile(
                      leading: ImagemProduto(item: item, tamanho: 40),
                      title: Text(item.nome),
                      subtitle: Text(
                        '${formatarQuantidade(quantidades[item.id] ?? 0)} ${item.unidade}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Tirar do orçamento',
                        onPressed: () => carrinho.remover(item.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Espaco.s3),
          ],
        ];
        const previa =
            'Prévia com os preços de agora. No envio, cada loja confirma o preço dela.';
        final saldo = disponivel > 0
            ? SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Usar saldo da carteira (${brl.format(disponivel)})',
                ),
                value: _usarSaldo,
                onChanged: (v) => setState(() => _usarSaldo = v),
              )
            : null;
        final aviso = motivo == null
            ? null
            : Text(motivo, style: t.bodySmall?.copyWith(color: c.aviso));
        final proposta = OutlinedButton(
          onPressed: pode ? () => _proposta(r) : null,
          child: const Text('Proposta'),
        );
        final fechar = FilledButton(
          onPressed: pode ? () => _fecharPedido(r, r.total - aplicado) : null,
          child: _enviando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Fechar pedido'),
        );
        final rotuloTotal = aplicado > 0 ? 'Total com saldo' : 'Total';

        if (largo) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  key: const Key('grupos-cotacao'),
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s6,
                    Espaco.s5,
                    Espaco.s3,
                    Espaco.s8,
                  ),
                  children: grupos,
                ),
              ),
              SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s3,
                    Espaco.s5,
                    Espaco.s6,
                    Espaco.s8,
                  ),
                  child: Painel(
                    key: const Key('resumo-cotacao'),
                    titulo: 'Resumo',
                    child: Padding(
                      padding: const EdgeInsets.all(Espaco.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...modo,
                          const Divider(height: Espaco.s6),
                          for (final g in r.grupos)
                            LinhaValor(g.loja.nome, brl.format(g.total)),
                          if (aplicado > 0)
                            LinhaValor(
                              'Saldo da carteira',
                              '- ${brl.format(aplicado)}',
                              cor: c.sucesso,
                            ),
                          LinhaValor(
                            rotuloTotal,
                            brl.format(r.total - aplicado),
                            destaque: true,
                          ),
                          if (r.cashbackPrevisto > 0)
                            LinhaValor(
                              'Cashback previsto',
                              '+ ${brl.format(r.cashbackPrevisto)}',
                              cor: c.sucesso,
                            ),
                          if (saldo != null) ...[
                            const SizedBox(height: Espaco.s2),
                            saldo,
                          ],
                          if (aviso != null) ...[
                            const SizedBox(height: Espaco.s2),
                            aviso,
                          ],
                          const SizedBox(height: Espaco.s4),
                          fechar,
                          const SizedBox(height: Espaco.s2),
                          proposta,
                          const SizedBox(height: Espaco.s3),
                          Text(
                            previa,
                            style: t.bodySmall?.copyWith(color: c.textoSuave),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s4,
                  Espaco.s4,
                  Espaco.s6,
                ),
                children: [
                  ...modo,
                  const SizedBox(height: Espaco.s4),
                  ...grupos,
                  Text(
                    previa,
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                ],
              ),
            ),
            RodapeTotal(
              rotulo: rotuloTotal,
              total: r.total - aplicado,
              cashback: r.cashbackPrevisto,
              extra: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?saldo,
                  if (aviso != null) ...[
                    const SizedBox(height: Espaco.s2),
                    aviso,
                  ],
                ],
              ),
              acoes: [proposta, fechar],
            ),
          ],
        );
      },
    );
  }

  void _abrir(PropostaResumo p, bool largo) {
    if (largo) {
      setState(() => _aberta = p.id);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => p.pedido == null
            ? PropostaScreen(id: p.id)
            : PedidoScreen(pedidoId: p.pedido!.id),
      ),
    );
  }

  Widget _enviados(BuildContext context) {
    final servico = NegociacaoService.instance;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final propostas = servico.propostas;
        final largo = formatoDoContexto(context) == Formato.computador;
        final lista = RefreshIndicator(
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
              if (_avisoEnvio != null) ...[
                Aviso(_avisoEnvio!, tom: _tomAviso),
                const SizedBox(height: Espaco.s3),
              ],
              if (servico.erro != null) ...[
                Aviso(servico.erro!),
                const SizedBox(height: Espaco.s3),
              ],
              if (!servico.carregado)
                for (var i = 0; i < 3; i++) ...[
                  const Esqueleto(altura: 96),
                  const SizedBox(height: Espaco.s3),
                ]
              else if (propostas.isEmpty)
                const EstadoVazio(
                  icone: Icons.outbox_outlined,
                  titulo: 'Nenhuma proposta enviada ainda',
                  texto: 'Monte a cotação e toque em Proposta ou Fechar pedido. As respostas das lojas aparecem aqui.',
                )
              else
                for (final p in propostas) ...[
                  _CartaoProposta(
                    proposta: p,
                    selecionada: largo && p.id == _aberta,
                    onTap: () => _abrir(p, largo),
                  ),
                  const SizedBox(height: Espaco.s3),
                ],
            ],
          ),
        );
        if (!largo) return lista;
        final aberta = propostas.where((p) => p.id == _aberta).firstOrNull;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 420, child: lista),
            VerticalDivider(width: 1, color: context.cores.borda),
            Expanded(
              child: aberta == null
                  ? const Center(
                      child: SingleChildScrollView(
                        child: EstadoVazio(
                          icone: Icons.touch_app_outlined,
                          titulo: 'Escolha uma proposta',
                          texto: 'O detalhe aparece aqui, sem sair da lista.',
                        ),
                      ),
                    )
                  : aberta.pedido == null
                  ? PropostaScreen(
                      key: ValueKey('proposta-${aberta.id}'),
                      id: aberta.id,
                      embutida: true,
                    )
                  : PedidoScreen(
                      key: ValueKey('pedido-${aberta.pedido!.id}'),
                      pedidoId: aberta.pedido!.id,
                      embutida: true,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GrupoCotado extends StatelessWidget {
  const _GrupoCotado({
    required this.grupo,
    required this.fixadas,
    required this.onTrocar,
  });
  final GrupoLoja grupo;
  final Map<String, String> fixadas;
  final ValueChanged<ItemCatalogo> onTrocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final loja = grupo.loja;
    return Painel(
      titulo: loja.nome,
      acao: Text(
        loja.freteFixo == 0
            ? 'Frete grátis'
            : 'Frete ${brl.format(loja.freteFixo)}',
        style: t.bodySmall?.copyWith(color: c.textoSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final l in grupo.linhas)
            _LinhaCotada(
              linha: l,
              fixada: fixadas[l.item.id] == loja.id,
              onTrocar: () => onTrocar(l.item),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s2,
              Espaco.s4,
              Espaco.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: Espaco.s3),
                LinhaValor('Produtos', brl.format(grupo.subtotal)),
                LinhaValor(
                  'Frete',
                  grupo.frete == 0 ? 'Grátis' : brl.format(grupo.frete),
                ),
                LinhaValor(
                  'Total nesta loja',
                  brl.format(grupo.total),
                  destaque: true,
                ),
                if (grupo.abaixoMinimo) ...[
                  const SizedBox(height: Espaco.s2),
                  Aviso(
                    'Faltam ${brl.format(grupo.faltaParaMinimo)} para o pedido mínimo de '
                    '${brl.format(loja.pedidoMinimo)} nesta loja.',
                    tom: TomSelo.aviso,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaCotada extends StatelessWidget {
  const _LinhaCotada({
    required this.linha,
    required this.fixada,
    required this.onTrocar,
  });
  final LinhaCotada linha;
  final bool fixada;
  final VoidCallback onTrocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final carrinho = CarrinhoService.instance;
    final item = linha.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s3, Espaco.s1, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImagemProduto(item: item, tamanho: 40),
          const SizedBox(width: Espaco.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: Espaco.s2),
                    Text(
                      brl.format(linha.total),
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: numerosTabulares,
                      ),
                    ),
                  ],
                ),
                Text(
                  [
                    '${brl.format(linha.precoUnitario)} / ${item.unidade}',
                    if (linha.sobConsulta) 'estoque sob consulta',
                    if (fixada) 'loja escolhida por você',
                  ].join(' · '),
                  style: t.bodySmall?.copyWith(
                    color: fixada ? c.acao : c.textoSuave,
                    fontFeatures: numerosTabulares,
                  ),
                ),
                const SizedBox(height: Espaco.s1),
                SeletorQuantidade(
                  valor: linha.quantidade,
                  unidade: item.unidade,
                  minimo: 0.001,
                  onChanged: (q) => carrinho.alterarQuantidade(item.id, q),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções do produto',
            onSelected: (v) {
              if (v == 'trocar') onTrocar();
              if (v == 'remover') carrinho.remover(item.id);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'trocar', child: Text('Trocar de loja')),
              PopupMenuItem(
                value: 'remover',
                child: Text('Tirar do orçamento'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FolhaProposta extends StatefulWidget {
  const _FolhaProposta({required this.lojas});
  final int lojas;

  @override
  State<_FolhaProposta> createState() => _FolhaPropostaState();
}

class _FolhaPropostaState extends State<_FolhaProposta> {
  final _mensagem = TextEditingController();

  @override
  void dispose() {
    _mensagem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Espaco.s4,
        0,
        Espaco.s4,
        Espaco.s4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enviar proposta', style: t.titleMedium),
          const SizedBox(height: Espaco.s1),
          Text(
            'Cada loja recebe a parte dela e pode aceitar, recusar ou mandar uma contraproposta em até 48 horas.',
            style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
          ),
          const SizedBox(height: Espaco.s3),
          TextField(
            controller: _mensagem,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Mensagem para as lojas (opcional). Ex.: entrega na obra até sexta.',
            ),
          ),
          const SizedBox(height: Espaco.s2),
          FilledButton(
            onPressed: () => Navigator.pop(context, _mensagem.text),
            child: Text(
              widget.lojas == 1
                  ? 'Enviar para 1 loja'
                  : 'Enviar para ${widget.lojas} lojas',
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoProposta extends StatelessWidget {
  const _CartaoProposta({
    required this.proposta,
    required this.onTap,
    this.selecionada = false,
  });
  final PropostaResumo proposta;
  final VoidCallback onTap;
  final bool selecionada;

  @override
  Widget build(BuildContext context) {
    final p = proposta;
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final (selo, tom) = seloDaProposta(p.status, p.pedido?.status);
    final loja =
        p.loja ?? Loja(id: p.lojaId, nome: p.lojaNome, cidade: '', uf: '');
    final n = p.itens.length;
    return Material(
      color: selecionada ? c.destaqueSuave : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.md),
        side: BorderSide(
          color: selecionada
              ? c.acao
              : p.status == StatusProposta.contraproposta
              ? c.aviso
              : c.borda,
          width: selecionada ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LogoLoja(loja: loja, tamanho: 44),
              const SizedBox(width: Espaco.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.lojaNome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.modo.rotulo} · ${n == 1 ? '1 produto' : '$n produtos'} · ${dataHora(p.criadaEm)}',
                      style: t.bodySmall?.copyWith(color: c.textoSuave),
                    ),
                    const SizedBox(height: Espaco.s2),
                    Wrap(
                      spacing: Espaco.s2,
                      runSpacing: Espaco.s1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Selo(selo, tom: tom),
                        Text(
                          brl.format(p.total),
                          style: t.titleSmall?.copyWith(
                            fontFeatures: numerosTabulares,
                          ),
                        ),
                      ],
                    ),
                    if (p.status.aberta) ...[
                      const SizedBox(height: Espaco.s1),
                      Text(
                        p.status == StatusProposta.contraproposta
                            ? 'Responda até ${dataHora(p.validaAte)}'
                            : 'A loja responde até ${dataHora(p.validaAte)}',
                        style: t.bodySmall?.copyWith(
                          color: p.status == StatusProposta.contraproposta
                              ? c.aviso
                              : c.textoSuave,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
