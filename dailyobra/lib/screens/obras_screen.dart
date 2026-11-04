import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';

import '../services/obras_service.dart';
import 'componentes.dart';
import 'convite_screen.dart';
import 'obra_form_screen.dart';
import 'obra_screen.dart';

final _data = DateFormat("d 'de' MMM 'de' y", 'pt_BR');

class ObrasScreen extends StatelessWidget {
  const ObrasScreen({super.key});

  Future<void> _nova(BuildContext context) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ObraFormScreen()),
    );
    if (id != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ObraScreen(id: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final servico = ObrasService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const MarcaDailyObra(soSimbolo: false, altura: 24),
        actions: [_MenuConta()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nova(context),
        backgroundColor: context.cores.acao,
        foregroundColor: context.cores.textoSobreAcao,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Raio.md),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nova obra'),
      ),
      body: ListenableBuilder(
        listenable: servico,
        builder: (context, _) {
          final obras = servico.obras;
          final formato = formatoDoContexto(context);
          return LayoutBuilder(
            builder: (context, limites) {
              final m = margemLateral(limites.maxWidth);
              return RefreshIndicator(
                color: context.cores.acao,
                onRefresh: servico.carregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(m, Espaco.s5, m, 96),
                  children: [
                    Text(
                      'Minhas obras',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: Espaco.s1),
                    Text(
                      'Orçamento estimado, materiais e andamento de cada obra.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: context.cores.textoSuave),
                    ),
                    const SizedBox(height: Espaco.s5),
                    if (servico.erro != null) ...[
                      Aviso(servico.erro!),
                      const SizedBox(height: Espaco.s4),
                    ],
                    if (obras == null && servico.erro == null)
                      for (var i = 0; i < 3; i++) ...[
                        const Esqueleto(altura: 168),
                        const SizedBox(height: Espaco.s3),
                      ]
                    else if (obras != null && obras.isEmpty)
                      _Vazio(
                        onNova: () => _nova(context),
                        onCodigo: () => entrarComConvite(context),
                      )
                    else if (obras != null) ...[
                      _Resumo(obras: obras),
                      const SizedBox(height: Espaco.s4),
                      if (formato == Formato.celular)
                        for (final o in obras) ...[
                          _CartaoObra(obra: o),
                          const SizedBox(height: Espaco.s3),
                        ]
                      else
                        GradeCartoes(
                          colunas: formato == Formato.computador ? 3 : 2,
                          filhos: [for (final o in obras) _CartaoObra(obra: o)],
                        ),
                      const SizedBox(height: Espaco.s2),
                      Center(
                        child: TextButton(
                          onPressed: () => entrarComConvite(context),
                          child: const Text('Tenho um código de convite'),
                        ),
                      ),
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
}

class _MenuConta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Conta',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (v) async {
        if (v != 'sair') return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Sair da conta?'),
            content: const Text(
              'Suas obras continuam salvas na conta. Para ver de novo, é só entrar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Sair'),
              ),
            ],
          ),
        );
        if (ok == true) await AuthService.sair();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AuthService.primeiroNome ?? 'Sua conta',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.cores.texto,
                ),
              ),
              Text(
                AuthService.usuario?.email ?? '',
                style: TextStyle(fontSize: 12, color: context.cores.textoSuave),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'sair', child: Text('Sair')),
      ],
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.obras});
  final List<Obra> obras;

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
            if (obras.any((o) => o.funcao.veValores)) ...[
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
  const _CartaoObra({required this.obra});
  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Calculo.de(obra.parametros);
    final etapas = c.resultado?.etapas ?? const [];
    final pct = progresso(etapas, obra.statusEtapas);
    final atual = etapaAtual(etapas, obra.statusEtapas);
    final situacoes = obra.statusEtapas.values;
    final selo = situacoes.contains(StatusEtapa.bloqueada)
        ? const Selo('Com bloqueio', tom: TomSelo.erro)
        : etapas.isNotEmpty && atual == null
        ? const Selo('Concluída', tom: TomSelo.sucesso)
        : situacoes.any(
            (s) => s == StatusEtapa.iniciada || s == StatusEtapa.concluida,
          )
        ? const Selo('Em obra', tom: TomSelo.info)
        : const Selo('Planejamento');
    final local = [
      obra.dados.cidade,
      obra.dados.uf,
    ].where((s) => s.isNotEmpty).join(' – ');

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
              if (obra.funcao.veValores)
                Text(
                  c.resultado == null
                      ? 'Revisar parâmetros'
                      : brl.format(c.resultado!.total),
                  style: t.titleLarge?.copyWith(fontFeatures: numerosTabulares),
                ),
              Text(
                '${obra.parametros.area} m², ${obra.parametros.padrao.rotulo.toLowerCase()}',
                style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
              ),
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
