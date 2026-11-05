import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';

import '../services/obras_service.dart';
import 'componentes.dart';
import 'convite_screen.dart';
import 'obra_form_screen.dart';
import 'obra_screen.dart';
import 'propostas_comerciais_screen.dart';

final _data = DateFormat("d 'de' MMM 'de' y", 'pt_BR');

const _larguraDeDuasColunas = 900.0;
const _larguraDaLateral = 320.0;

/// Em que pé a obra está, do que pede atenção para o resto.
enum _Situacao {
  bloqueada('Com bloqueio', TomSelo.erro),
  atrasada('Atrasada', TomSelo.erro),
  concluida('Concluída', TomSelo.sucesso),
  emObra('Em obra', TomSelo.info),
  planejamento('Planejamento', TomSelo.neutro);

  const _Situacao(this.rotulo, this.tom);
  final String rotulo;
  final TomSelo tom;
}

_Situacao _situacaoDa(Obra obra) {
  final etapas = Calculo.de(obra.parametros).resultado?.etapas ?? const [];
  final situacoes = obra.statusEtapas.values;
  if (situacoes.contains(StatusEtapa.bloqueada)) return _Situacao.bloqueada;
  final emDia = resumirCronograma(
    etapas: [for (final e in etapas) e.etapa],
    datas: obra.cronograma,
    status: obra.statusEtapas,
    hoje: DateTime.now(),
  ).emDia;
  if (!emDia) return _Situacao.atrasada;
  if (etapas.isNotEmpty && etapaAtual(etapas, obra.statusEtapas) == null) {
    return _Situacao.concluida;
  }
  final comecou = situacoes.any(
    (s) => s == StatusEtapa.iniciada || s == StatusEtapa.concluida,
  );
  return comecou ? _Situacao.emObra : _Situacao.planejamento;
}

/// Filtros da lista de obras; bloqueada e atrasada são obra em andamento.
enum _Filtro {
  todas('Todas'),
  emObra('Em obra'),
  planejamento('Planejamento'),
  concluidas('Concluídas');

  const _Filtro(this.rotulo);
  final String rotulo;

  bool aceita(Obra obra) {
    final situacao = _situacaoDa(obra);
    return switch (this) {
      _Filtro.todas => true,
      _Filtro.emObra => const {
        _Situacao.bloqueada,
        _Situacao.atrasada,
        _Situacao.emObra,
      }.contains(situacao),
      _Filtro.planejamento => situacao == _Situacao.planejamento,
      _Filtro.concluidas => situacao == _Situacao.concluida,
    };
  }
}

/// Cadastra a obra, deixa ela ativa e abre a tela dela.
Future<void> novaObra(BuildContext context) async {
  final id = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const ObraFormScreen()),
  );
  if (id == null) return;
  ObrasService.instance.fixarAtiva(id);
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ObraScreen(id: id)),
    );
  }
}

/// A aba Obras: todas as obras organizadas por situação e o cadastro de uma nova. O que se faz em cada uma fica dentro dela.
class ObrasScreen extends StatefulWidget {
  const ObrasScreen({super.key});

  @override
  State<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends State<ObrasScreen> {
  var _filtro = _Filtro.todas;

  @override
  Widget build(BuildContext context) {
    final servico = ObrasService.instance;
    final celular = formatoDoContexto(context) == Formato.celular;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obras'),
        actions: [
          if (!celular)
            Padding(
              padding: const EdgeInsets.only(right: Espaco.s4),
              child: FilledButton.icon(
                onPressed: () => novaObra(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Cadastrar obra'),
              ),
            ),
        ],
      ),
      floatingActionButton: celular
          ? FloatingActionButton.extended(
              onPressed: () => novaObra(context),
              backgroundColor: context.cores.acao,
              foregroundColor: context.cores.textoSobreAcao,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Raio.md),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar obra'),
            )
          : null,
      body: ListenableBuilder(
        listenable: servico,
        builder: (context, _) {
          final obras = servico.obras;
          final contagem = {
            for (final f in _Filtro.values)
              f: obras?.where(f.aceita).length ?? 0,
          };
          // A obra pode mudar de situação e deixar o filtro vazio: aí vale "Todas"
          final filtro = contagem[_filtro]! > 0 ? _filtro : _Filtro.todas;
          final visiveis = obras?.where(filtro.aceita).toList();
          final filtros = (obras?.length ?? 0) < 2
              ? null
              : _Filtros(
                  atual: filtro,
                  contagem: contagem,
                  aoEscolher: (f) => setState(() => _filtro = f),
                );
          return LayoutBuilder(
            builder: (context, limites) {
              final m = margemLateral(limites.maxWidth);
              final largo = limites.maxWidth >= _larguraDeDuasColunas;
              return RefreshIndicator(
                color: context.cores.acao,
                onRefresh: servico.carregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    m,
                    Espaco.s5,
                    m,
                    celular ? 96 : Espaco.s8,
                  ),
                  children: [
                    if (servico.erro != null) ...[
                      Aviso(servico.erro!),
                      const SizedBox(height: Espaco.s4),
                    ],
                    if (obras == null && servico.erro == null)
                      for (var i = 0; i < 3; i++) ...[
                        const Esqueleto(altura: 168),
                        const SizedBox(height: Espaco.s3),
                      ]
                    else if (obras != null && obras.isEmpty) ...[
                      _Vazio(
                        onNova: () => novaObra(context),
                        onCodigo: () => entrarComConvite(context),
                      ),
                      // A proposta vem antes da obra existir
                      const SizedBox(height: Espaco.s3),
                      const EntradaDasPropostas(),
                    ] else if (visiveis != null && largo)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (filtros != null) ...[
                                  filtros,
                                  const SizedBox(height: Espaco.s3),
                                ],
                                for (final (i, o) in visiveis.indexed) ...[
                                  if (i > 0) const SizedBox(height: Espaco.s3),
                                  _CartaoObra(obra: o, largo: true),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: Espaco.s5),
                          SizedBox(
                            width: _larguraDaLateral,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Resumo(obras: obras!, emColuna: true),
                                const SizedBox(height: Espaco.s3),
                                ..._caminhos(context),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (visiveis != null) ...[
                      _Resumo(obras: obras!),
                      const SizedBox(height: Espaco.s3),
                      if (filtros != null) ...[
                        filtros,
                        const SizedBox(height: Espaco.s3),
                      ],
                      for (final o in visiveis) ...[
                        _CartaoObra(obra: o),
                        const SizedBox(height: Espaco.s3),
                      ],
                      ..._caminhos(context),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _caminhos(BuildContext context) => [
    const EntradaDasPropostas(),
    const SizedBox(height: Espaco.s2),
    EntradaDaObra(
      icone: Icons.vpn_key_outlined,
      titulo: 'Tenho um código de convite',
      detalhe: 'Entre na obra de outra pessoa',
      aoTocar: () => entrarComConvite(context),
    ),
  ];
}

/// Pílulas com a situação e quantas obras há em cada uma. As que não têm obra não aparecem.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.atual,
    required this.contagem,
    required this.aoEscolher,
  });
  final _Filtro atual;
  final Map<_Filtro, int> contagem;
  final ValueChanged<_Filtro> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _Filtro.values)
            if (contagem[f]! > 0)
              Padding(
                padding: const EdgeInsets.only(right: Espaco.s2),
                child: ChoiceChip(
                  label: Text('${f.rotulo} ${contagem[f]}'),
                  selected: f == atual,
                  showCheckmark: false,
                  backgroundColor: c.superficie,
                  selectedColor: c.superficie,
                  labelStyle: TextStyle(
                    color: f == atual ? c.texto : c.textoSuave,
                    fontWeight: f == atual ? FontWeight.w700 : FontWeight.w500,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: f == atual ? c.texto : c.borda,
                      width: f == atual ? 1.5 : 1,
                    ),
                  ),
                  onSelected: (_) => aoEscolher(f),
                ),
              ),
        ],
      ),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.obras, this.emColuna = false});
  final List<Obra> obras;

  /// Na lateral das telas largas, uma medida por linha.
  final bool emColuna;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    double total = 0;
    var emAndamento = 0;
    for (final o in obras) {
      if (o.funcao.veValores) {
        total += Calculo.de(o.parametros).resultado?.total ?? 0;
      }
      if (o.statusEtapas.values.any(
        (s) => s == StatusEtapa.iniciada || s == StatusEtapa.concluida,
      )) {
        emAndamento++;
      }
    }
    final comValores = obras.any((o) => o.funcao.veValores);
    if (emColuna) {
      Widget linha(String rotulo, String valor) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaco.s4,
          vertical: Espaco.s3,
        ),
        child: Row(
          children: [
            Expanded(child: Text(rotulo, style: t.bodyMedium)),
            const SizedBox(width: Espaco.s2),
            Text(
              valor,
              style: t.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: numerosTabulares,
              ),
            ),
          ],
        ),
      );
      return Painel(
        titulo: 'Resumo',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            linha('Obras', '${obras.length}'),
            const Divider(height: 1),
            linha('Em andamento', '$emAndamento'),
            if (comValores) ...[
              const Divider(height: 1),
              linha('Soma das estimativas', brlInteiro.format(total)),
            ],
          ],
        ),
      );
    }
    Widget item(String rotulo, String valor) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: t.labelMedium),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                valor,
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: numerosTabulares,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Painel(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            item('Obras', '${obras.length}'),
            const VerticalDivider(width: 1),
            item('Em andamento', '$emAndamento'),
            if (comValores) ...[
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    item('Soma das estimativas', brlInteiro.format(total)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartaoObra extends StatelessWidget {
  const _CartaoObra({required this.obra, this.largo = false});
  final Obra obra;

  /// Nas telas largas o valor fica à direita, na altura do nome.
  final bool largo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Calculo.de(obra.parametros);
    final etapas = c.resultado?.etapas ?? const [];
    final pct = progresso(etapas, obra.statusEtapas);
    final atual = etapaAtual(etapas, obra.statusEtapas);
    final situacao = _situacaoDa(obra);
    final selo = Selo(situacao.rotulo, tom: situacao.tom);
    final local = [
      obra.dados.cidade,
      obra.dados.uf,
    ].where((s) => s.isNotEmpty).join(' – ');

    final valor = Text(
      c.resultado == null
          ? 'Revisar parâmetros'
          : brl.format(c.resultado!.total),
      style: t.titleLarge?.copyWith(fontFeatures: numerosTabulares),
    );
    final tamanho = Text(
      '${obra.parametros.area} m², ${obra.parametros.padrao.rotulo.toLowerCase()}',
      style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
    );

    return Material(
      color: context.cores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.md),
        side: BorderSide(color: context.cores.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ObraScreen(id: obra.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obra.nome,
                          style: t.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (local.isNotEmpty)
                          Text(
                            local,
                            style: t.bodyMedium?.copyWith(
                              color: context.cores.textoSuave,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Espaco.s2),
                  selo,
                ],
              ),
              const SizedBox(height: Espaco.s4),
              if (largo)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: tamanho),
                    if (obra.funcao.veValores) valor,
                  ],
                )
              else ...[
                if (obra.funcao.veValores) valor,
                tamanho,
              ],
              if (etapas.isNotEmpty) ...[
                const SizedBox(height: Espaco.s4),
                FaixaMini(etapas: etapas, status: obra.statusEtapas),
                const SizedBox(height: Espaco.s2),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        atual == null
                            ? const TextSpan(text: 'Todas as etapas concluídas')
                            : TextSpan(
                                text: 'Etapa: ',
                                children: [
                                  TextSpan(
                                    text: atual.nome,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: context.cores.texto,
                                    ),
                                  ),
                                ],
                              ),
                        style: t.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: t.labelLarge?.copyWith(
                        fontFeatures: numerosTabulares,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Espaco.s3),
              const Divider(),
              const SizedBox(height: Espaco.s2),
              Text(
                'Atualizada em ${_data.format(obra.atualizadaEm.toLocal())}',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.onNova, required this.onCodigo});
  final VoidCallback onNova;
  final VoidCallback onCodigo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.s5,
        vertical: Espaco.s10,
      ),
      decoration: BoxDecoration(
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(Raio.md),
        border: Border.all(color: context.cores.borda),
      ),
      child: Column(
        children: [
          Text(
            'Nenhuma obra cadastrada',
            style: t.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaco.s2),
          Text(
            'Cadastre a obra com área, padrão e cobertura para ver a estimativa por etapa e a lista de materiais para cotação.',
            style: t.bodyLarge?.copyWith(color: context.cores.textoSuave),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaco.s5),
          FilledButton(
            onPressed: onNova,
            child: const Text('Cadastrar primeira obra'),
          ),
          const SizedBox(height: Espaco.s2),
          TextButton(
            onPressed: onCodigo,
            child: const Text('Tenho um código de convite'),
          ),
        ],
      ),
    );
  }
}
