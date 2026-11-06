import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/mercado_service.dart';
import '../services/ofertas_service.dart';
import '../services/resultados_service.dart';
import 'graficos_resultados.dart';

const _precosComparados = 5;

/// O que cada faixa de cashback vende, pelo nome que o lojista reconhece.
const _nomesDasFaixas = {
  1: ('Faixa 1: Commodities', 'Cimento, aço, tijolo e areia'),
  2: ('Faixa 2: Básico avançado', 'PVC, fios e argamassas'),
  3: ('Faixa 3: Hidráulica e elétrica', 'Conexões, disjuntores e ferramentas'),
  4: ('Faixa 4: Acabamentos', 'Porcelanatos, tintas, louças e metais'),
};

/// Painel com título e uma frase, para o bloco continuar no lugar enquanto não há dados.
class PainelSemDados extends StatelessWidget {
  const PainelSemDados({super.key, required this.titulo, required this.texto});
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Painel(
      titulo: titulo,
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Text(
          texto,
          style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
        ),
      ),
    );
  }
}

/// Vendas do mês em cada faixa de cashback, com a parte de cada uma no total.
class VendasPorFaixa extends StatelessWidget {
  const VendasPorFaixa({super.key, required this.faixas});
  final List<VendaDaFaixa> faixas;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final total = faixas.fold(0.0, (soma, f) => soma + f.total);
    final cores = {1: c.acento, 2: c.info, 3: c.sucesso, 4: c.aviso};
    return Painel(
      titulo: 'Vendas e cashback por faixa',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, f) in faixas.indexed) ...[
              if (i > 0) const SizedBox(height: Espaco.s4),
              _LinhaDaFaixa(faixa: f, total: total, cor: cores[f.tier]!),
            ],
            const SizedBox(height: Espaco.s3),
            Divider(height: 1, color: c.borda),
            const SizedBox(height: Espaco.s3),
            Text(
              'Total vendido em produtos: ${brl.format(total)}',
              style: t.bodySmall?.copyWith(
                color: c.textoSuave,
                fontFeatures: numerosTabulares,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaDaFaixa extends StatelessWidget {
  const _LinhaDaFaixa({
    required this.faixa,
    required this.total,
    required this.cor,
  });
  final VendaDaFaixa faixa;
  final double total;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final parte = total == 0 ? 0.0 : faixa.total / total;
    final (nome, itens) = _nomesDasFaixas[faixa.tier]!;
    final percentual = faixa.percentual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome, style: t.titleSmall),
                  Text(
                    itens,
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espaco.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  brl.format(faixa.total),
                  style: t.titleSmall?.copyWith(fontFeatures: numerosTabulares),
                ),
                Text(
                  percentual == null
                      ? textoPercentual(parte)
                      : '${textoPercentual(parte)} · cashback ${textoPercentual(percentual)}',
                  style: t.bodySmall?.copyWith(
                    color: c.textoSuave,
                    fontFeatures: numerosTabulares,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Espaco.s2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: parte,
            minHeight: 6,
            color: cor,
            backgroundColor: c.segPrevista,
          ),
        ),
      ],
    );
  }
}

/// Um preço da loja ao lado da referência de mercado do mesmo produto.
class PrecoComparado {
  const PrecoComparado({
    required this.item,
    required this.preco,
    required this.referencia,
  });
  final ItemCatalogo item;
  final double preco;
  final double referencia;

  /// Acima de zero, a loja cobra mais que a referência.
  double get diferenca => preco / referencia - 1;
}

/// Os preços ativos da loja que mais se afastam da referência, do maior afastamento para o menor.
List<PrecoComparado> compararComReferencia(
  List<ItemCatalogo> catalogo,
  Map<String, Oferta> minhas,
  DateTime hoje, {
  int limite = _precosComparados,
}) {
  final lista = <PrecoComparado>[];
  for (final item in catalogo) {
    final referencia = item.precoReferencia;
    final oferta = minhas[item.id];
    if (referencia == null || referencia <= 0 || oferta == null) continue;
    if (oferta.pausada) continue;
    final preco = oferta.precoVigente(hoje);
    if (preco == null) continue;
    lista.add(PrecoComparado(item: item, preco: preco, referencia: referencia));
  }
  lista.sort((a, b) => b.diferenca.abs().compareTo(a.diferenca.abs()));
  return lista.take(limite).toList();
}

String _fonteDasReferencias(List<PrecoComparado> precos) {
  final fontes = {
    for (final p in precos)
      if (p.item.fonteReferencia case final fonte? when fonte.isNotEmpty) fonte,
  };
  return fontes.isEmpty
      ? 'Percentual sobre a referência do catálogo.'
      : 'Percentual sobre a referência ${fontes.join(', ')}.';
}

/// Dólar do momento e como os preços da loja estão perto da referência de mercado. Só mostra o que tem fonte.
class PainelDeMercado extends StatefulWidget {
  const PainelDeMercado({super.key, this.agora});

  /// Relógio dos testes; no app, a hora do aparelho.
  final DateTime Function()? agora;

  @override
  State<PainelDeMercado> createState() => _PainelDeMercadoState();
}

class _PainelDeMercadoState extends State<PainelDeMercado> {
  DateTime _agora() => (widget.agora ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    MercadoService.instance.carregar(agora: _agora());
  }

  @override
  Widget build(BuildContext context) {
    final mercado = MercadoService.instance;
    final ofertas = OfertasService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([mercado, ofertas]),
      builder: (context, _) {
        final dolar = mercado.dolar;
        final precos = compararComReferencia(
          ofertas.catalogo,
          ofertas.minhas,
          _agora(),
        );
        if (dolar == null && precos.isEmpty) {
          return const PainelSemDados(
            titulo: 'Cotações de mercado',
            texto: 'Coloque preços nos produtos para comparar com a referência de mercado.',
          );
        }
        return Painel(
          titulo: 'Cotações de mercado',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dolar != null)
                  _LinhaDeMercado(
                    nome: 'Dólar comercial',
                    valor: brl.format(dolar.valor),
                    variacao: dolar.variacao / 100,
                  ),
                if (precos.isNotEmpty) ...[
                  if (dolar != null) const SizedBox(height: Espaco.s3),
                  Text(
                    'Seus preços x referência',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: Espaco.s2),
                  for (final p in precos)
                    _LinhaDeMercado(
                      nome: p.item.nome,
                      valor: brl.format(p.preco),
                      variacao: p.diferenca,
                    ),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    _fonteDasReferencias(precos),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: context.cores.textoSuave),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LinhaDeMercado extends StatelessWidget {
  const _LinhaDeMercado({
    required this.nome,
    required this.valor,
    required this.variacao,
  });
  final String nome;
  final String valor;

  /// Fração: 0,12 é +12%.
  final double variacao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final sinal = variacao > 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaco.s1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall,
            ),
          ),
          const SizedBox(width: Espaco.s2),
          Text(
            valor,
            style: t.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: numerosTabulares,
            ),
          ),
          const SizedBox(width: Espaco.s2),
          Text(
            '$sinal${textoPercentual(variacao)}',
            style: t.bodySmall?.copyWith(
              color: c.textoSuave,
              fontFeatures: numerosTabulares,
            ),
          ),
        ],
      ),
    );
  }
}
