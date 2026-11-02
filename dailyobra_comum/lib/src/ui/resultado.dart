import 'package:flutter/material.dart';

import '../obras/obra.dart';
import '../orcamento/materiais.dart';
import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import '../tema/tema.dart';
import '../tema/cores.dart';
import 'faixa_obra.dart';
import 'ui.dart';

/// Total, custo por m² e divisão entre mão de obra, materiais e adicionais
class BlocoTotal extends StatelessWidget {
  const BlocoTotal({super.key, required this.r});
  final ResultadoOrcamento r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final area = r.etapas.isEmpty ? 0.0 : r.etapas.first.area;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Total estimado', style: t.labelLarge?.copyWith(color: context.cores.textoSuave)),
        const SizedBox(height: Espaco.s1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            brl.format(r.total),
            style: t.headlineMedium?.copyWith(fontSize: 34, height: 1.05, letterSpacing: -0.5, fontFeatures: numerosTabulares),
          ),
        ),
        if (area > 0) ...[
          const SizedBox(height: Espaco.s2),
          Text('${brlInteiro.format(r.totalEtapas / area)} por m² construído', style: t.bodyMedium?.copyWith(color: context.cores.textoSuave)),
        ],
        const SizedBox(height: Espaco.s4),
        const Divider(),
        const SizedBox(height: Espaco.s3),
        _Indicador(rotulo: 'Mão de obra', valor: r.maoDeObra, total: r.total),
        _Indicador(rotulo: 'Materiais', valor: r.material, total: r.total),
        _Indicador(rotulo: 'Adicionais', valor: r.totalAdicionais, total: r.total),
      ],
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.rotulo, required this.valor, required this.total});
  final String rotulo;
  final double valor;
  final double total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pct = total > 0 ? (valor / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(rotulo, style: t.bodyMedium?.copyWith(color: context.cores.textoSuave))),
        Text(brl.format(valor), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: numerosTabulares)),
        SizedBox(
          width: 44,
          child: Text('$pct%', textAlign: TextAlign.right, style: t.bodySmall?.copyWith(fontFeatures: numerosTabulares)),
        ),
      ]),
    );
  }
}

class NotaEstimativa extends StatelessWidget {
  const NotaEstimativa({super.key});

  @override
  Widget build(BuildContext context) => Container(
        color: context.cores.superficieSutil,
        padding: const EdgeInsets.symmetric(horizontal: Espaco.s4, vertical: Espaco.s3),
        child: Text(
          'Estimativa pela tabela de custos por m² (data-base 09/2025). Não substitui orçamento com projeto, cotação e revisão técnica.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}

/// Peso de cada etapa no custo (simulador): a faixa sem situação
class PainelComposicao extends StatelessWidget {
  const PainelComposicao({super.key, required this.r});
  final ResultadoOrcamento r;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Peso de cada etapa no custo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Espaco.s3),
          FaixaObra(
            etapas: r.etapas,
            padrao: Text('Toque ou arraste o dedo sobre a faixa para ver o valor de cada etapa.', style: TextStyle(color: context.cores.textoSuave)),
          ),
        ]),
      );
}

/// Lista de etapas; [situacao] permite à tela da obra pôr o controle de status em cada linha
class ListaEtapas extends StatelessWidget {
  const ListaEtapas({super.key, required this.r, this.situacao, this.chaves});
  final ResultadoOrcamento r;
  final Widget Function(LinhaResultado l)? situacao;

  /// Uma chave por etapa, para a faixa da obra rolar até a linha
  final Map<EtapaId, GlobalKey>? chaves;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Painel(
      titulo: 'Etapas da obra',
      acao: Text('${r.etapas.length} etapas', style: t.bodySmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < r.etapas.length; i++)
            Container(
              key: chaves?[r.etapas[i].etapa],
              padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s3, Espaco.s4, Espaco.s3),
              decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: context.cores.borda))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 28,
                  child: Text((i + 1).toString().padLeft(2, '0'),
                      style: t.labelLarge?.copyWith(color: context.cores.textoSuave, fontFeatures: numerosTabulares)),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(r.etapas[i].nome, style: t.titleSmall)),
                      const SizedBox(width: Espaco.s3),
                      Text(brl.format(r.etapas[i].total), style: t.titleSmall?.copyWith(fontFeatures: numerosTabulares)),
                    ]),
                    const SizedBox(height: 2),
                    Text(r.etapas[i].descricao, style: t.bodyMedium?.copyWith(color: context.cores.textoSuave)),
                    const SizedBox(height: Espaco.s1),
                    Text('${brl.format(r.etapas[i].custoM2)} por m²', style: t.bodySmall?.copyWith(fontFeatures: numerosTabulares)),
                    if (situacao != null) ...[const SizedBox(height: Espaco.s2), situacao!(r.etapas[i])],
                  ]),
                ),
              ]),
            ),
          Container(
            color: context.cores.superficieSutil,
            padding: const EdgeInsets.symmetric(horizontal: Espaco.s4, vertical: Espaco.s3),
            child: Row(children: [
              Expanded(child: Text('Total das etapas', style: t.titleSmall)),
              Text(brl.format(r.totalEtapas), style: t.titleSmall?.copyWith(fontFeatures: numerosTabulares)),
            ]),
          ),
          if (r.adicionais.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s4, Espaco.s4, Espaco.s1),
              child: Text('Adicionais', style: t.titleSmall),
            ),
            for (final a in r.adicionais)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Espaco.s4, vertical: Espaco.s2),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.item.rotulo, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                      Text('${numero.format(a.quantidade)} ${a.unidade} × ${brl.format(a.precoUnitario)}',
                          style: t.bodySmall?.copyWith(fontFeatures: numerosTabulares)),
                    ]),
                  ),
                  Text(brl.format(a.total), style: t.titleSmall?.copyWith(fontFeatures: numerosTabulares)),
                ]),
              ),
            const SizedBox(height: Espaco.s2),
          ],
        ],
      ),
    );
  }
}

class ListaMateriais extends StatefulWidget {
  const ListaMateriais({super.key, required this.m});
  final ResultadoMateriais m;

  @override
  State<ListaMateriais> createState() => _ListaMateriaisState();
}

class _ListaMateriaisState extends State<ListaMateriais> {
  bool _porEtapa = true;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = widget.m;
    return Painel(
      titulo: 'Lista de materiais estimada',
      child: switch (m) {
        MateriaisIndisponiveis(:final motivo) => Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Text(motivo, style: t.bodyMedium?.copyWith(color: context.cores.textoSuave)),
          ),
        MateriaisDisponiveis() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.all(Espaco.s3),
              child: Segmentado<bool>(
                valor: _porEtapa,
                opcoes: const [(true, 'Por etapa'), (false, 'Para cotação')],
                onChanged: (v) => setState(() => _porEtapa = v),
              ),
            ),
            const Divider(),
            if (_porEtapa)
              for (final e in m.etapas)
                Theme(
                  // Sem as linhas que o ExpansionTile desenha ao abrir: as divisórias já separam as etapas
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: Espaco.s4),
                    childrenPadding: EdgeInsets.zero,
                    title: Text(e.nome, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text('${e.itens.length} itens', style: t.bodySmall),
                    trailing: Text(brl.format(e.totalRef), style: t.labelLarge?.copyWith(fontFeatures: numerosTabulares)),
                    children: [_Itens(itens: e.itens)],
                  ),
                )
            else
              _Itens(itens: m.consolidado),
            Container(
              color: context.cores.superficieSutil,
              padding: const EdgeInsets.symmetric(horizontal: Espaco.s4, vertical: Espaco.s3),
              child: Row(children: [
                Expanded(child: Text('Total de referência', style: t.titleSmall)),
                Text(brl.format(m.totalRef), style: t.titleSmall?.copyWith(fontFeatures: numerosTabulares)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s2, Espaco.s4, Espaco.s4),
              child: Text(
                'Quantidades estimadas a partir das casas de referência da planilha Projetos Calculos. Preços de referência, '
                'a substituir pela cotação nas lojas.${m.etapasSemLista.isEmpty ? '' : ' Ainda sem lista: ${m.etapasSemLista.join(', ')}.'}',
                style: t.bodySmall,
              ),
            ),
          ]),
      },
    );
  }
}

class _Itens extends StatelessWidget {
  const _Itens({required this.itens});
  final List<ItemMaterial> itens;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      for (final i in itens)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Espaco.s4, vertical: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: context.cores.borda))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.item, style: t.bodyMedium),
                Text('${numero.format(i.quantidade)} ${i.unidade} × ${brl.format(i.precoRef)}',
                    style: t.bodySmall?.copyWith(fontFeatures: numerosTabulares)),
              ]),
            ),
            const SizedBox(width: Espaco.s3),
            Text(brl.format(i.totalRef), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontFeatures: numerosTabulares)),
          ]),
        ),
    ]);
  }
}

/// Botão da situação de uma etapa: abre uma lista para escolher. Mostra a mesma amostra da faixa.
class BotaoSituacao extends StatelessWidget {
  const BotaoSituacao({super.key, required this.nome, required this.valor, this.onChanged});
  final String nome;
  final StatusEtapa valor;

  /// null = só leitura (cliente da obra)
  final ValueChanged<StatusEtapa>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final conteudo = Row(mainAxisSize: MainAxisSize.min, children: [
      Amostra(valor),
      const SizedBox(width: Espaco.s2),
      Text(valor.rotulo, style: t.labelLarge),
      if (onChanged != null) ...[const SizedBox(width: Espaco.s1), Icon(Icons.expand_more, size: 18, color: context.cores.textoSuave)],
    ]);
    if (onChanged == null) return conteudo;
    return Semantics(
      label: 'Situação da etapa $nome: ${valor.rotulo}. Toque para mudar.',
      button: true,
      excludeSemantics: true,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: Espaco.s3)),
        onPressed: () async {
          final escolha = await showModalBottomSheet<StatusEtapa>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Espaco.s5, 0, Espaco.s5, Espaco.s2),
                  child: Text(nome, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final s in StatusEtapa.values)
                  ListTile(
                    leading: Amostra(s, tamanho: 16),
                    title: Text(s.rotulo),
                    trailing: s == valor ? Icon(Icons.check, color: context.cores.acao) : null,
                    onTap: () => Navigator.pop(context, s),
                  ),
                const SizedBox(height: Espaco.s2),
              ]),
            ),
          );
          if (escolha != null && escolha != valor) onChanged!(escolha);
        },
        child: conteudo,
      ),
    );
  }
}
