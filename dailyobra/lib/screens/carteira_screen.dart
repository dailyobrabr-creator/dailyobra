import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carteira_service.dart';
import '../services/catalogo_service.dart';
import '../services/economia_service.dart';
import 'componentes.dart';
import 'layout_adaptativo.dart';

/// Clube DailyObra: saldo de cashback, como ganhar por nível e o extrato.
class CarteiraScreen extends StatelessWidget {
  const CarteiraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final carteira = CarteiraService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Carteira')),
      body: ListenableBuilder(
        listenable: Listenable.merge([carteira, CatalogoService.instance]),
        builder: (context, _) {
          final t = Theme.of(context).textTheme;
          final c = context.cores;
          final largo = formatoDoContexto(context) == Formato.computador;
          final esquerda = <Widget>[
            if (carteira.erro != null) ...[
              Aviso(carteira.erro!),
              const SizedBox(height: Espaco.s3),
            ],
            _Saldo(
              disponivel: carteira.disponivel,
              pendente: carteira.pendente,
              reservado: carteira.reservado,
            ),
            const SizedBox(height: Espaco.s3),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: carteira.disponivel > 0
                        ? () => irParaAba(context, Aba.orcamentos)
                        : null,
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: const Text('Usar no orçamento'),
                  ),
                ),
                const SizedBox(width: Espaco.s2),
                const Expanded(
                  child: OutlinedButton(onPressed: null, child: Text('Sacar')),
                ),
              ],
            ),
            const SizedBox(height: Espaco.s1),
            Text(
              'Em breve: saque para a sua conta, com taxa de 5%. Por enquanto o saldo vale como desconto nos pedidos.',
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
            const SizedBox(height: Espaco.s4),
            const _Economia(),
            const TituloSecao('Como ganhar'),
            const _Niveis(),
          ];
          final extrato = <Widget>[
            TituloSecao(
              'Extrato',
              margem: largo
                  ? const EdgeInsets.only(bottom: Espaco.s3)
                  : const EdgeInsets.only(top: Espaco.s6, bottom: Espaco.s3),
            ),
            if (carteira.extrato.isEmpty)
              const EstadoVazio(
                icone: Icons.receipt_long_outlined,
                titulo: 'Nenhum lançamento ainda',
                texto: 'O cashback de cada pedido aparece aqui, primeiro como "a liberar" e, depois da entrega e do pagamento, como disponível.',
              )
            else
              Painel(
                child: Column(
                  children: [
                    if (largo) const _CabecalhoExtrato(),
                    for (var i = 0; i < carteira.extrato.length; i++) ...[
                      if (i > 0 || largo) const Divider(height: 1),
                      largo
                          ? _LinhaExtrato(l: carteira.extrato[i])
                          : _Lancamento(l: carteira.extrato[i]),
                    ],
                  ],
                ),
              ),
          ];
          return RefreshIndicator(
            color: c.acao,
            onRefresh: () => Future.wait([
              carteira.carregar(),
              EconomiaService.instance.carregar(),
            ]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: largo
                  ? const EdgeInsets.fromLTRB(
                      Espaco.s8,
                      Espaco.s6,
                      Espaco.s8,
                      Espaco.s10,
                    )
                  : const EdgeInsets.fromLTRB(
                      Espaco.s4,
                      Espaco.s4,
                      Espaco.s4,
                      Espaco.s8,
                    ),
              children: [
                if (largo)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: esquerda,
                        ),
                      ),
                      const SizedBox(width: Espaco.s6),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: extrato,
                        ),
                      ),
                    ],
                  )
                else ...[
                  ...esquerda,
                  ...extrato,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Economia do mês: total, barras dos 6 meses e a divisão comparando, negociando e cashback.
class _Economia extends StatelessWidget {
  const _Economia();

  @override
  Widget build(BuildContext context) {
    final eco = EconomiaService.instance;
    return ListenableBuilder(
      listenable: eco,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        if (!eco.carregado) {
          if (eco.erro == null) return const EsqueletoBrilho(altura: 160);
          return Painel(
            titulo: 'Economia',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Text(
                'Não deu para carregar a economia agora. ${eco.erro}',
                style: t.bodyMedium,
              ),
            ),
          );
        }
        final c = context.cores;
        final atual = eco.atual;
        final mes = atual?.mes ?? DateTime.now();
        final semNada = eco.meses.every((m) => m.total == 0);
        return Painel(
          titulo: 'Economia em ${mesesExtenso[mes.month - 1]}',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: semNada
                ? Text(
                    'Feche seu primeiro pedido pelo app para ver a economia aqui.',
                    style: t.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          brl.format(atual!.total),
                          style: t.headlineSmall?.copyWith(
                            color: c.sucesso,
                            fontWeight: FontWeight.w700,
                            fontFeatures: numerosTabulares,
                          ),
                        ),
                      ),
                      const SizedBox(height: Espaco.s2),
                      SizedBox(
                        height: 72,
                        child: GraficoMeses(
                          meses: [
                            for (final m in eco.meses)
                              (mesesCurtos[m.mes.month - 1], m.total),
                          ],
                        ),
                      ),
                      const SizedBox(height: Espaco.s3),
                      LinhaValor(
                        'Comparando lojas',
                        brl.format(atual.comparando),
                      ),
                      LinhaValor('Negociando', brl.format(atual.negociando)),
                      LinhaValor('Cashback', brl.format(atual.cashback)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _CabecalhoExtrato extends StatelessWidget {
  const _CabecalhoExtrato();

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: context.cores.textoSuave,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.s4,
        vertical: Espaco.s3,
      ),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text('Data', style: estilo)),
          Expanded(flex: 3, child: Text('Descrição', style: estilo)),
          Expanded(flex: 2, child: Text('Loja', style: estilo)),
          SizedBox(width: 64, child: Text('Nível', style: estilo)),
          SizedBox(
            width: 110,
            child: Text('Valor', textAlign: TextAlign.end, style: estilo),
          ),
        ],
      ),
    );
  }
}

class _LinhaExtrato extends StatelessWidget {
  const _LinhaExtrato({required this.l});
  final Lancamento l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final entrada = l.valor >= 0;
    final cor = l.pendente
        ? c.textoSuave
        : entrada
        ? c.sucesso
        : c.erro;
    final suave = t.bodySmall?.copyWith(color: c.textoSuave);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.s4,
        vertical: Espaco.s3,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(dataHora(l.data).split(' ').first, style: suave),
          ),
          Expanded(
            flex: 3,
            child: Text(
              l.pendente ? '${l.descricao} (a liberar)' : l.descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodyMedium,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l.loja ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: suave,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(l.tier == null ? '—' : '${l.tier}', style: suave),
          ),
          SizedBox(
            width: 110,
            child: Text(
              '${entrada ? '+' : '-'} ${brl.format(l.valor.abs())}',
              textAlign: TextAlign.end,
              style: t.bodyMedium?.copyWith(
                color: cor,
                fontWeight: FontWeight.w600,
                fontFeatures: numerosTabulares,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Saldo extends StatelessWidget {
  const _Saldo({
    required this.disponivel,
    required this.pendente,
    required this.reservado,
  });
  final double disponivel;
  final double pendente;
  final double reservado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final sobre = c.textoSobreAcao;
    return Container(
      padding: const EdgeInsets.all(Espaco.s4),
      decoration: BoxDecoration(
        color: c.acao,
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo disponível', style: t.labelLarge?.copyWith(color: sobre)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              brl.format(disponivel),
              style: t.headlineMedium?.copyWith(
                color: sobre,
                fontWeight: FontWeight.w700,
                fontFeatures: numerosTabulares,
              ),
            ),
          ),
          const SizedBox(height: Espaco.s3),
          Wrap(
            spacing: Espaco.s6,
            runSpacing: Espaco.s2,
            children: [
              _Valor(rotulo: 'A liberar', valor: pendente, cor: sobre),
              if (reservado > 0)
                _Valor(
                  rotulo: 'Reservado em propostas',
                  valor: reservado,
                  cor: sobre,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Valor extends StatelessWidget {
  const _Valor({required this.rotulo, required this.valor, required this.cor});
  final String rotulo;
  final double valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: t.bodySmall?.copyWith(color: cor)),
        Text(
          brl.format(valor),
          style: t.titleSmall?.copyWith(
            color: cor,
            fontWeight: FontWeight.w700,
            fontFeatures: numerosTabulares,
          ),
        ),
      ],
    );
  }
}

/// Percentual de cada nível e as categorias que caem nele, a partir do catálogo.
class _Niveis extends StatelessWidget {
  const _Niveis();

  @override
  Widget build(BuildContext context) {
    final catalogo = CatalogoService.instance;
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final nomes = {for (final cat in catalogo.categorias) cat.id: cat.nome};
    final porNivel = <int, Set<String>>{};
    for (final i in catalogo.itens) {
      final nome = nomes[i.categoriaId];
      if (nome != null) (porNivel[i.tier] ??= {}).add(nome);
    }
    final niveis = catalogo.percentualPorTier.keys.toList()..sort();
    return Painel(
      child: Column(
        children: [
          for (var i = 0; i < niveis.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaco.s4,
                vertical: Espaco.s3,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: Espaco.s1),
                    decoration: BoxDecoration(
                      color: c.sucesso.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Raio.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${(catalogo.percentualPorTier[niveis[i]]! * 100).toStringAsFixed(0)}%',
                      style: t.titleSmall?.copyWith(color: c.sucesso),
                    ),
                  ),
                  const SizedBox(width: Espaco.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nível ${niveis[i]}', style: t.bodyMedium),
                        Text(
                          (porNivel[niveis[i]]?.toList() ?? const ['—']).join(
                            ', ',
                          ),
                          style: t.bodySmall?.copyWith(color: c.textoSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Lancamento extends StatelessWidget {
  const _Lancamento({required this.l});
  final Lancamento l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final entrada = l.valor >= 0;
    final cor = l.pendente
        ? c.textoSuave
        : entrada
        ? c.sucesso
        : c.erro;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.s4,
        vertical: Espaco.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            l.pendente
                ? Icons.schedule
                : entrada
                ? Icons.add_circle_outline
                : Icons.remove_circle_outline,
            color: cor,
            size: 20,
          ),
          const SizedBox(width: Espaco.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.descricao, style: t.bodyMedium),
                Text(
                  [
                    dataHora(l.data),
                    ?l.loja,
                    if (l.tier != null) 'Nível ${l.tier}',
                    if (l.pendente) 'a liberar',
                  ].join(' · '),
                  style: t.bodySmall?.copyWith(color: c.textoSuave),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.s2),
          Text(
            '${entrada ? '+' : '-'} ${brl.format(l.valor.abs())}',
            style: t.bodyMedium?.copyWith(
              color: cor,
              fontWeight: FontWeight.w600,
              fontFeatures: numerosTabulares,
            ),
          ),
        ],
      ),
    );
  }
}
