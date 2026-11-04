import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/compartilhar.dart';
import '../services/diario_service.dart';
import '../services/marca_service.dart';
import '../services/mudancas_service.dart';
import '../services/obras_service.dart';
import '../services/pdf_relatorio.dart';
import 'componentes.dart';
import 'dia_obra_screen.dart';
import 'marca_screen.dart';

/// A semana da obra num documento: vem do diário e do cronograma, sem digitar nada de novo.
class RelatorioScreen extends StatefulWidget {
  const RelatorioScreen({
    super.key,
    required this.obra,
    this.hoje,
    this.enviarPdf,
  });
  final Obra obra;

  /// Os testes fixam o dia.
  final DateTime? hoje;

  /// Os testes trocam o envio do PDF.
  final Future<void> Function(RelatorioDaSemana relatorio)? enviarPdf;

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  late final _hoje = widget.hoje ?? DateTime.now();

  late SemanaObra _semana = SemanaObra.doDia(_hoje);
  List<DiaObra>? _dias;
  List<Mudanca> _mudancas = const [];
  MarcaEngenheiro? _marca;
  String? _erro;
  bool _ocupado = false;

  List<LinhaResultado> get _etapas =>
      Calculo.de(widget.obra.parametros).resultado?.etapas ?? const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final id = widget.obra.id;
    try {
      final dias = await DiarioService.instance.listar(id);
      final marca = await MarcaService.instance.daObra(id);
      var mudancas = const <Mudanca>[];
      try {
        mudancas = await MudancasService.instance.listar(id);
      } on FalhaAoSalvar {
        // O relatório sai sem as mudanças
      }
      if (mounted) {
        setState(() {
          // Na segunda de manhã a semana ainda está vazia: abre na que acabou
          if (_dias == null && _relatorioDe(dias, mudancas).resumo.vazio) {
            _semana = _semana.anterior;
          }
          _dias = dias;
          _mudancas = mudancas;
          _marca = marca;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  RelatorioDaSemana _relatorioDe(List<DiaObra> dias, List<Mudanca> mudancas) =>
      montarRelatorio(
        obra: widget.obra,
        etapas: _etapas,
        dias: dias,
        mudancas: mudancas,
        semana: _semana,
      );

  bool get _temMarca {
    final m = _marca;
    return m != null && (m.logoPath != null || m.registro.trim().isNotEmpty);
  }

  Future<void> _gerar(RelatorioDaSemana r) async {
    setState(() => _ocupado = true);
    try {
      await (widget.enviarPdf ?? _enviarPdf)(r);
    } catch (_) {
      if (mounted) {
        avisar(context, 'Não foi possível gerar o PDF. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _enviarPdf(RelatorioDaSemana r) async {
    final marca = _marca;
    final bytes = await pdfDaSemana(
      obra: widget.obra,
      relatorio: r,
      marca: marca,
      logo: await MarcaService.instance.logoBytes(marca?.logoPath),
      fotos: await DiarioService.instance.bytesDe(fotosDoRelatorio(r.resumo)),
    );
    await compartilharPdf(
      bytes,
      nomeDoRelatorio(r.semana),
      titulo: 'Relatório semanal',
      texto: mensagemDoRelatorio(
        nomeDaObra: widget.obra.nome,
        semana: r.semana,
      ),
    );
  }

  Future<void> _abrirMarca() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MarcaScreen()),
    );
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    final relatorio = dias == null ? null : _relatorioDe(dias, _mudancas);
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório da semana')),
      body: _erro != null && dias == null
          ? Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Aviso(_erro!),
                  const SizedBox(height: Espaco.s3),
                  OutlinedButton(
                    onPressed: _carregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            )
          : relatorio == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : _conteudo(relatorio),
      bottomNavigationBar: relatorio == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s2,
                  Espaco.s4,
                  Espaco.s3,
                ),
                child: FilledButton.icon(
                  onPressed: _ocupado || relatorio.resumo.vazio
                      ? null
                      : () => _gerar(relatorio),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Gerar PDF'),
                ),
              ),
            ),
    );
  }

  Widget _conteudo(RelatorioDaSemana r) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodyMedium?.copyWith(color: context.cores.textoSuave);
    final semanaAtual = _semana.contem(_hoje);
    final termino = r.termino;
    final resumo = r.resumo;
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Painel(
          child: Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                onPressed: () => setState(() => _semana = _semana.anterior),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _semana.texto,
                  textAlign: TextAlign.center,
                  style: t.titleSmall?.copyWith(fontFeatures: numerosTabulares),
                ),
              ),
              IconButton(
                tooltip: 'Próxima semana',
                onPressed: semanaAtual
                    ? null
                    : () => setState(() => _semana = _semana.proxima),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espaco.s4),
        if (widget.obra.funcao.administra && !_temMarca) ...[
          Painel(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Coloque a sua marca'),
              subtitle: const Text('Logo e registro no topo do relatório'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _abrirMarca,
            ),
          ),
          const SizedBox(height: Espaco.s4),
        ],
        if (r.diasEmRascunho > 0) ...[
          Aviso(
            r.diasEmRascunho == 1
                ? '1 dia em rascunho ficou de fora. Finalize no diário para ele entrar.'
                : '${r.diasEmRascunho} dias em rascunho ficaram de fora. Finalize no diário para eles entrarem.',
            tom: TomSelo.aviso,
          ),
          const SizedBox(height: Espaco.s4),
        ],
        if (resumo.vazio)
          Padding(
            padding: const EdgeInsets.all(Espaco.s6),
            child: Column(
              children: [
                Text('Nenhum dia finalizado', style: t.titleMedium),
                const SizedBox(height: Espaco.s2),
                Text(
                  'O relatório sai do diário. Finalize os dias da semana para gerar o PDF.',
                  textAlign: TextAlign.center,
                  style: suave,
                ),
              ],
            ),
          )
        else ...[
          Painel(
            titulo: 'Resumo',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinhaValor('Andamento da obra', '${r.andamento}%'),
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('Dias registrados', '${resumo.dias.length}'),
                  const SizedBox(height: Espaco.s2),
                  LinhaValor('Pessoas por dia', '${resumo.mediaDePessoas}'),
                  if (r.etapaAtual != null) ...[
                    const SizedBox(height: Espaco.s2),
                    LinhaValor('Etapa atual', r.etapaAtual!),
                  ],
                  if (termino != null) ...[
                    const SizedBox(height: Espaco.s2),
                    LinhaValor(
                      'Previsão de término',
                      '${dataCurta(termino)}/${termino.year}',
                    ),
                  ],
                  if (resumo.fotos.isNotEmpty) ...[
                    const SizedBox(height: Espaco.s2),
                    LinhaValor(
                      'Fotos no PDF',
                      '${fotosDoRelatorio(resumo).length}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (resumo.atividades.isNotEmpty) ...[
            const SizedBox(height: Espaco.s4),
            _Lista(
              titulo: 'O que foi feito',
              itens: [
                for (final a in resumo.atividades)
                  [
                    a.descricao,
                    if (a.local.isNotEmpty) a.local,
                    if (a.percentual != null) '${a.percentual}%',
                  ].join(' · '),
              ],
            ),
          ],
          if (resumo.ocorrencias.isNotEmpty) ...[
            const SizedBox(height: Espaco.s4),
            _Lista(
              titulo: 'Ocorrências',
              itens: [
                for (final o in resumo.ocorrencias)
                  '${o.tipo.rotulo}: ${o.descricao}',
              ],
            ),
          ],
          if (r.mudancas.isNotEmpty) ...[
            const SizedBox(height: Espaco.s4),
            _Lista(
              titulo: 'Mudanças',
              itens: [
                for (final m in r.mudancas)
                  '${m.titulo} · ${m.situacao.rotulo}',
              ],
            ),
          ],
          if (r.proximas.isNotEmpty) ...[
            const SizedBox(height: Espaco.s4),
            _Lista(
              titulo: 'Próximos passos',
              itens: [
                for (final p in r.proximas)
                  '${p.nome} · ${dataCurta(p.inicio)} a ${dataCurta(p.fim)}',
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.titulo, required this.itens});
  final String titulo;
  final List<String> itens;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Painel(
      titulo: titulo,
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, item) in itens.indexed) ...[
              if (i > 0) const SizedBox(height: Espaco.s2),
              Text(item, style: t.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Entrada na tela da obra.
class EntradaDoRelatorio extends StatelessWidget {
  const EntradaDoRelatorio({super.key, required this.obra});
  final Obra obra;

  @override
  Widget build(BuildContext context) => EntradaDaObra(
    icone: Icons.summarize_outlined,
    titulo: 'Relatório da semana',
    detalhe: obra.funcao == FuncaoObra.cliente
        ? 'O resumo da obra, semana a semana'
        : 'PDF pronto para mandar ao cliente',
    aoTocar: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RelatorioScreen(obra: obra)),
    ),
  );
}

/// As fotos mais novas do diário, para o cliente ver a obra sem abrir dia por dia.
class UltimasFotos extends StatefulWidget {
  const UltimasFotos({super.key, required this.obra});
  final Obra obra;

  static const quantas = 8;

  @override
  State<UltimasFotos> createState() => _UltimasFotosState();
}

class _UltimasFotosState extends State<UltimasFotos> {
  List<FotoDia> _fotos = const [];
  Map<String, String> _links = const {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final servico = DiarioService.instance;
    try {
      final dias = await servico.listar(widget.obra.id);
      final fotos = [
        for (final d in dias)
          if (d.fechado) ...d.fotos.reversed,
      ].take(UltimasFotos.quantas).toList();
      final links = await servico.linksDasFotos([
        for (final f in fotos) f.caminho,
      ]);
      if (mounted) {
        setState(() {
          _fotos = fotos;
          _links = links;
        });
      }
    } on FalhaAoSalvar {
      // As fotos são um extra: sem elas a tela da obra segue igual
    }
  }

  Widget _imagem(FotoDia foto, {BoxFit fit = BoxFit.cover}) {
    final link = _links[foto.caminho];
    Widget vazio(BuildContext c) =>
        Center(child: Icon(Icons.image_outlined, color: c.cores.textoSuave));
    if (link == null) return vazio(context);
    return Image.network(link, fit: fit, errorBuilder: (c, _, _) => vazio(c));
  }

  void _ampliar(FotoDia foto) {
    showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: _imagem(foto, fit: BoxFit.contain)),
            if (foto.legenda.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s3,
                  Espaco.s4,
                  0,
                ),
                child: Text(foto.legenda),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fotos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaco.s4),
      child: Painel(
        titulo: 'Últimas fotos',
        child: SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(Espaco.s3),
            itemCount: _fotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: Espaco.s2),
            itemBuilder: (_, i) => MiniaturaFoto(
              imagem: _imagem(_fotos[i]),
              aoTocar: () => _ampliar(_fotos[i]),
            ),
          ),
        ),
      ),
    );
  }
}
