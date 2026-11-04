import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';

import '../services/carrinho_service.dart';
import '../services/catalogo_service.dart';
import '../services/obras_service.dart';
import 'caixa_screen.dart';
import 'compras_screen.dart';
import 'componentes.dart';
import 'contratos_screen.dart';
import 'cronograma_screen.dart';
import 'diario_screen.dart';
import 'dinheiro_screen.dart';
import 'equipe_screen.dart';
import 'mao_de_obra_screen.dart';
import 'mudancas_screen.dart';
import 'obra_form_screen.dart';
import 'pendencias_screen.dart';
import 'relatorio_screen.dart';

class ObraScreen extends StatefulWidget {
  const ObraScreen({super.key, required this.id});
  final String id;

  @override
  State<ObraScreen> createState() => _ObraScreenState();
}

class _ObraScreenState extends State<ObraScreen> {
  final _chaves = {for (final e in EtapaId.values) e: GlobalKey()};

  void _mostrar(String mensagem) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensagem)));

  Future<void> _mudarSituacao(EtapaId etapa, StatusEtapa s) async {
    try {
      await ObrasService.instance.definirStatus(widget.id, etapa, s);
    } on FalhaAoSalvar catch (e) {
      if (mounted) _mostrar(e.mensagem);
    }
  }

  Future<void> _excluir(Obra obra) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Excluir “${obra.nome}”?'),
        content: const Text(
          'A obra, o andamento e o histórico serão apagados para todos que têm acesso. Não dá para desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.cores.erro),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir obra'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ObrasService.instance.excluir(obra.id);
      if (mounted) Navigator.pop(context);
    } on FalhaAoSalvar catch (e) {
      if (mounted) _mostrar(e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ObrasService.instance,
      builder: (context, _) {
        final servico = ObrasService.instance;
        final obra = servico.obra(widget.id);
        if (obra == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: servico.obras == null && servico.erro == null
                  ? const Esqueleto(altura: 320)
                  : Aviso(
                      servico.erro ?? 'Obra não encontrada. Ela pode ter sido excluída, ou sua conta não tem acesso a ela.',
                    ),
            ),
          );
        }
        return _conteudo(obra);
      },
    );
  }

  Widget _conteudo(Obra obra) {
    final t = Theme.of(context).textTheme;
    final calculo = Calculo.de(obra.parametros);
    final funcao = obra.funcao;
    final admin = funcao.administra;
    final cliente = funcao == FuncaoObra.cliente;
    final agora = DateTime.now();
    final resumo = resumirCronograma(
      etapas: [
        for (final e in calculo.resultado?.etapas ?? const <LinhaResultado>[])
          e.etapa,
      ],
      datas: obra.cronograma,
      status: obra.statusEtapas,
      hoje: agora,
    );
    final alerta = alertaDaObra(resumo, obra.pendenciasVencidas(agora));
    final endereco = [
      obra.dados.endereco,
      [obra.dados.cidade, obra.dados.uf].where((s) => s.isNotEmpty).join(' – '),
    ].where((s) => s.isNotEmpty).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(obra.nome, overflow: TextOverflow.ellipsis),
        actions: [
          if (admin)
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (v) {
                if (v == 'editar') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ObraFormScreen(obra: obra),
                    ),
                  );
                } else if (v == 'excluir') {
                  _excluir(obra);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'editar', child: Text('Editar obra')),
                PopupMenuItem(
                  value: 'excluir',
                  child: Text(
                    'Excluir obra',
                    style: TextStyle(color: context.cores.erro),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: context.cores.acao,
        onRefresh: ObrasService.instance.carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s5,
            Espaco.s4,
            Espaco.s10,
          ),
          children: [
            Text(obra.nome, style: t.headlineMedium),
            if (endereco.isNotEmpty) ...[
              const SizedBox(height: Espaco.s1),
              Text(
                endereco,
                style: t.bodyLarge?.copyWith(color: context.cores.textoSuave),
              ),
            ],
            const SizedBox(height: Espaco.s4),
            if (!funcao.veValores) ...[
              const Aviso(
                'Seu acesso mostra o andamento e o diário da obra, sem valores.',
                tom: TomSelo.info,
              ),
              const SizedBox(height: Espaco.s4),
            ],
            if (!funcao.registra) ...[
              const Aviso(
                'Seu acesso a esta obra é de acompanhamento: você vê o orçamento e o andamento, sem alterar.',
                tom: TomSelo.info,
              ),
              const SizedBox(height: Espaco.s4),
            ],
            if (alerta != null) ...[
              Aviso(alerta, tom: TomSelo.aviso),
              const SizedBox(height: Espaco.s4),
            ],
            if (cliente) ...[
              EntradaDasMudancas(obra: obra),
              const SizedBox(height: Espaco.s4),
              UltimasFotos(obra: obra),
            ],
            EntradaDoDiario(obra: obra),
            const SizedBox(height: Espaco.s4),
            EntradaDoCronograma(obra: obra, resumo: resumo),
            const SizedBox(height: Espaco.s2),
            if (funcao.registra) ...[
              EntradaDasPendencias(obra: obra),
              const SizedBox(height: Espaco.s2),
            ],
            if (funcao.cuidaDasCompras) ...[
              EntradaDasCompras(obra: obra),
              const SizedBox(height: Espaco.s2),
            ],
            if (funcao.lidera) ...[
              EntradaDoDinheiro(obra: obra),
              const SizedBox(height: Espaco.s2),
              EntradaDaMaoDeObra(obra: obra),
              const SizedBox(height: Espaco.s2),
            ],
            if (admin) ...[
              EntradaDoCaixa(obra: obra),
              const SizedBox(height: Espaco.s2),
            ],
            if (funcao == FuncaoObra.empreiteiro) ...[
              EntradaDoContrato(obra: obra),
              const SizedBox(height: Espaco.s2),
            ],
            if (funcao.veMudancas && !cliente) ...[
              EntradaDasMudancas(obra: obra),
              const SizedBox(height: Espaco.s2),
            ],
            if (funcao.veMudancas) ...[
              EntradaDoRelatorio(obra: obra),
              const SizedBox(height: Espaco.s2),
            ],
            EntradaDaEquipe(obra: obra),
            const SizedBox(height: Espaco.s4),
            if (calculo.resultado == null)
              Painel(
                child: Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Aviso(calculo.erro!),
                      if (admin) ...[
                        const SizedBox(height: Espaco.s3),
                        FilledButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ObraFormScreen(obra: obra),
                            ),
                          ),
                          child: const Text('Corrigir parâmetros'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else if (funcao.veValores)
              ..._resultado(obra, calculo.resultado!, funcao.lidera)
            else
              Painel(
                child: _Andamento(
                  obra: obra,
                  etapas: calculo.resultado!.etapas,
                  comValores: false,
                  onEscolher: (_) {},
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultado(Obra obra, ResultadoOrcamento r, bool lidera) {
    return [
      Painel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: BlocoTotal(r: r),
            ),
            const Divider(),
            _Ficha(obra: obra),
            const Divider(),
            _Andamento(
              obra: obra,
              etapas: r.etapas,
              onEscolher: (etapa) {
                final alvo = _chaves[etapa]?.currentContext;
                if (alvo != null) {
                  Scrollable.ensureVisible(
                    alvo,
                    duration: const Duration(milliseconds: 300),
                    alignment: 0.1,
                  );
                }
              },
            ),
            const NotaEstimativa(),
          ],
        ),
      ),
      const SizedBox(height: Espaco.s4),
      ListaEtapas(
        r: r,
        chaves: _chaves,
        situacao: (l) => Align(
          alignment: Alignment.centerLeft,
          child: BotaoSituacao(
            nome: l.nome,
            valor: obra.statusDe(l.etapa),
            onChanged: lidera ? (s) => _mudarSituacao(l.etapa, s) : null,
          ),
        ),
      ),
      const SizedBox(height: Espaco.s4),
      _CotarMateriais(
        obraId: obra.id,
        materiais: listarMateriais(obra.parametros.paraEntrada()),
      ),
      const SizedBox(height: Espaco.s4),
      ListaMateriais(m: listarMateriais(obra.parametros.paraEntrada())),
    ];
  }
}

/// Leva a lista de materiais da obra para o orçamento do marketplace, já convertida em produtos.
class _CotarMateriais extends StatelessWidget {
  const _CotarMateriais({required this.obraId, required this.materiais});
  final String obraId;
  final ResultadoMateriais materiais;

  Future<void> _cotar(BuildContext context) async {
    final catalogo = CatalogoService.instance;
    final carrinho = CarrinhoService.instance;
    final quantidades = materiaisDaObraNoCatalogo(
      materiais,
      catalogo.planilhaParaItem,
      catalogo: catalogo.itemPorId,
    );
    if (quantidades.isEmpty) {
      avisar(
        context,
        'Os materiais desta obra ainda não estão no catálogo das lojas.',
      );
      return;
    }
    if (!carrinho.vazio) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Trocar o orçamento atual?'),
          content: const Text(
            'O orçamento em montagem será trocado pelos materiais desta obra.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Trocar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    carrinho.substituirPor(quantidades, obraId: obraId);
    if (!context.mounted) return;
    irParaAba(context, Aba.orcamentos);
    avisar(
      context,
      '${quantidades.length} produtos da obra no orçamento. Confira as quantidades.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (materiais is! MateriaisDisponiveis) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Painel(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Preço real dos materiais', style: t.titleSmall),
            const SizedBox(height: Espaco.s1),
            Text(
              'Mande a lista desta obra para as lojas do DailyObra e compare os preços de verdade.',
              style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
            ),
            const SizedBox(height: Espaco.s3),
            FilledButton.icon(
              onPressed: () => _cotar(context),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Cotar materiais desta obra'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.obra});
  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = obra.parametros;
    final inicio = DateTime.tryParse(obra.dados.inicioPrevisto);
    final linhas = <(String, String)>[
      (
        'Área construída',
        '${p.area} m²${p.sobrado && p.areaSuperior.isNotEmpty ? ', ${p.areaSuperior} m² no superior' : ''}',
      ),
      ('Padrão', p.padrao.rotulo),
      ('Estrutura', p.laje ? 'Com laje' : 'Sem laje'),
      (
        'Cobertura',
        p.cobertura == TipoCobertura.platibanda
            ? 'Platibanda'
            : 'Telhado, ${p.aguas == 3
                  ? '3 ou mais águas'
                  : p.aguas == 1
                  ? '1 água'
                  : '2 águas'}',
      ),
      if (obra.dados.responsavel.isNotEmpty)
        ('Responsável', obra.dados.responsavel),
      if (inicio != null)
        (
          'Início previsto',
          DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(inicio),
        ),
    ];
    return Column(
      children: [
        for (var i = 0; i < linhas.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Espaco.s4,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(top: BorderSide(color: context.cores.borda)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    linhas[i].$1,
                    style: t.bodyMedium?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    linhas[i].$2,
                    textAlign: TextAlign.right,
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Andamento extends StatelessWidget {
  const _Andamento({
    required this.obra,
    required this.etapas,
    required this.onEscolher,
    this.comValores = true,
  });
  final Obra obra;
  final List<LinhaResultado> etapas;
  final ValueChanged<EtapaId> onEscolher;
  final bool comValores;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pct = progresso(etapas, obra.statusEtapas);
    final atual = etapaAtual(etapas, obra.statusEtapas);
    final situacao = atual == null ? null : obra.statusDe(atual.etapa);
    final prefixo = switch (situacao) {
      StatusEtapa.bloqueada => 'Bloqueada: ',
      StatusEtapa.iniciada => 'Em andamento: ',
      _ => 'Próxima etapa: ',
    };
    return Padding(
      padding: const EdgeInsets.all(Espaco.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Andamento da obra', style: t.titleSmall)),
              Text(
                '$pct%',
                style: t.titleLarge?.copyWith(fontFeatures: numerosTabulares),
              ),
              const SizedBox(width: Espaco.s1),
              Text('concluído', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: Espaco.s3),
          FaixaObra(
            etapas: etapas,
            status: obra.statusEtapas,
            legenda: true,
            comValores: comValores,
            onEscolher: onEscolher,
            padrao: atual == null
                ? Text(
                    'Todas as etapas concluídas',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.cores.sucesso,
                    ),
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: prefixo,
                          style: TextStyle(color: context.cores.textoSuave),
                        ),
                        TextSpan(
                          text: atual.nome,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
