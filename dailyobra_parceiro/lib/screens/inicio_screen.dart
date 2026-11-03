import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/loja_service.dart';
import '../services/ofertas_service.dart';
import '../services/propostas_loja_service.dart';
import 'componentes.dart';
import 'pedido_loja_screen.dart';
import 'proposta_loja_screen.dart';

/// Número com rótulo do painel (tocável quando leva a outra aba).
class Indicador extends StatelessWidget {
  const Indicador({
    super.key,
    required this.rotulo,
    required this.valor,
    this.destaque = false,
    this.onTap,
  });
  final String rotulo;
  final String valor;
  final bool destaque;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return Material(
      color: destaque ? c.acao : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
        side: BorderSide(color: destaque ? c.acao : c.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  valor,
                  style: t.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: destaque ? c.textoSobreAcao : c.texto,
                    fontFeatures: numerosTabulares,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rotulo,
                maxLines: 2,
                style: t.bodySmall?.copyWith(
                  color: destaque ? c.textoSobreAcao : c.textoSuave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painel da loja: o que precisa de resposta, pedidos em andamento, vendas do mês e atalhos.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loja = LojaService.instance;
    final propostas = PropostasLojaService.instance;
    final ofertas = OfertasService.instance;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([loja, propostas, ofertas]),
          builder: (context, _) {
            final t = Theme.of(context).textTheme;
            final c = context.cores;
            final minha = loja.minhaLoja;
            final novas = propostas.novas;
            final andamento = propostas.pedidosEmAndamento;
            final hoje = DateTime.now();
            return RefreshIndicator(
              color: c.acao,
              onRefresh: () async {
                await propostas.carregar();
                if (minha != null) await ofertas.carregar(minha.id);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s4,
                  Espaco.s4,
                  Espaco.s8,
                ),
                children: [
                  Row(
                    children: [
                      if (minha != null) LogoLoja(loja: minha, tamanho: 48),
                      const SizedBox(width: Espaco.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              minha?.nome ?? 'Sua loja',
                              style: t.titleLarge,
                              maxLines: 2,
                            ),
                            Text(
                              '${loja.meuPapel.rotulo} · ${minha == null ? '' : '${minha.cidade} · ${minha.uf}'}',
                              style: t.bodySmall?.copyWith(color: c.textoSuave),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (minha != null) ...[
                    const SizedBox(height: Espaco.s3),
                    _Abertura(aberta: minha.aberta, pode: loja.meuPapel.gere),
                  ],
                  if (propostas.erro != null) ...[
                    const SizedBox(height: Espaco.s3),
                    Aviso(propostas.erro!),
                  ],
                  const SizedBox(height: Espaco.s4),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: Espaco.s3,
                    crossAxisSpacing: Espaco.s3,
                    childAspectRatio: 1.55,
                    children: [
                      Indicador(
                        rotulo: 'Propostas novas',
                        valor: '${novas.length}',
                        destaque: novas.isNotEmpty,
                        onTap: () => irParaAba(context, Aba.propostas),
                      ),
                      Indicador(
                        rotulo: 'Pedidos em andamento',
                        valor: '${andamento.length}',
                        onTap: () => irParaAba(context, Aba.propostas),
                      ),
                      Indicador(
                        rotulo: 'Entregue no mês',
                        valor: brlInteiro.format(propostas.vendidoNoMes(hoje)),
                      ),
                      Indicador(
                        rotulo: 'Produtos com preço',
                        valor: '${ofertas.ativas}',
                        onTap: () => irParaAba(context, Aba.produtos),
                      ),
                    ],
                  ),
                  if (ofertas.carregado &&
                      ofertas.minhas.isEmpty &&
                      loja.meuPapel.gere) ...[
                    const SizedBox(height: Espaco.s4),
                    Painel(
                      child: Padding(
                        padding: const EdgeInsets.all(Espaco.s4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Coloque seus preços', style: t.titleSmall),
                            const SizedBox(height: Espaco.s1),
                            Text(
                              'Sem preço a loja não aparece nas cotações. Escolha os produtos do catálogo e informe o valor.',
                              style: t.bodySmall?.copyWith(color: c.textoSuave),
                            ),
                            const SizedBox(height: Espaco.s3),
                            FilledButton(
                              onPressed: () => irParaAba(context, Aba.produtos),
                              child: const Text('Cadastrar preços'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Espaco.s6,
                      bottom: Espaco.s3,
                    ),
                    child: Text('Precisa de resposta', style: t.titleMedium),
                  ),
                  if (!propostas.carregado)
                    const Esqueleto(altura: 88)
                  else if (novas.isEmpty && andamento.isEmpty)
                    const EstadoVazio(
                      icone: Icons.inbox_outlined,
                      titulo: 'Tudo respondido',
                      texto: 'Quando um construtor mandar orçamento para a loja, ele aparece aqui na hora.',
                    )
                  else ...[
                    for (final p in [...novas, ...andamento].take(6)) ...[
                      CartaoPropostaLoja(proposta: p),
                      const SizedBox(height: Espaco.s3),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Abertura extends StatelessWidget {
  const _Abertura({required this.aberta, required this.pode});
  final bool aberta;
  final bool pode;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Painel(
      child: SwitchListTile(
        value: aberta,
        onChanged: pode
            ? (v) async {
                try {
                  await LojaService.instance.abrirOuFechar(v);
                } on FalhaComMensagem catch (e) {
                  if (context.mounted) avisar(context, e.mensagem);
                }
              }
            : null,
        title: Text(aberta ? 'Loja aberta' : 'Loja fechada'),
        subtitle: Text(
          aberta
              ? 'Aparece nas cotações dos construtores.'
              : 'Fora das cotações até você abrir de novo.',
          style: TextStyle(color: c.textoSuave),
        ),
      ),
    );
  }
}

/// Cartão de proposta ou pedido na lista da loja.
class CartaoPropostaLoja extends StatelessWidget {
  const CartaoPropostaLoja({
    super.key,
    required this.proposta,
    this.onAbrir,
    this.selecionado = false,
  });
  final PropostaResumo proposta;

  /// Propostas no computador: abre ao lado da lista em vez de empilhar a tela.
  final ValueChanged<PropostaResumo>? onAbrir;

  /// A que está aberta ao lado da lista.
  final bool selecionado;

  @override
  Widget build(BuildContext context) {
    final p = proposta;
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final quem = PropostasLojaService.instance.construtor(p.construtorId);
    final (selo, tom) = seloParaLoja(p);
    final n = p.itens.length;
    final urgente = p.status == StatusProposta.enviada;
    final abrir = onAbrir;
    return Material(
      color: selecionado ? c.superficieSutil : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
        side: BorderSide(color: urgente ? c.acao : c.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: abrir != null
            ? () => abrir(p)
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => p.pedido == null
                      ? PropostaLojaScreen(id: p.id)
                      : PedidoLojaScreen(pedidoId: p.pedido!.id),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quem.exibicao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall,
                    ),
                  ),
                  const SizedBox(width: Espaco.s2),
                  Selo(selo, tom: tom),
                ],
              ),
              if (quem.empresa.isNotEmpty)
                Text(
                  quem.empresa,
                  style: t.bodySmall?.copyWith(color: c.textoSuave),
                ),
              const SizedBox(height: Espaco.s2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${n == 1 ? '1 produto' : '$n produtos'} · ${dataHora(p.criadaEm)}',
                      style: t.bodySmall?.copyWith(color: c.textoSuave),
                    ),
                  ),
                  Text(
                    brl.format(p.pedido?.total ?? p.total),
                    style: t.titleSmall?.copyWith(
                      fontFeatures: numerosTabulares,
                    ),
                  ),
                ],
              ),
              if (urgente) ...[
                const SizedBox(height: Espaco.s1),
                Text(
                  'Responder: ${prazo(p.validaAte)}',
                  style: t.bodySmall?.copyWith(
                    color: c.acao,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
