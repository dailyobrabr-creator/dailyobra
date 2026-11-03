import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/loja_service.dart';
import '../services/ofertas_service.dart';
import 'componentes.dart';

/// Arquivo escolhido pela loja (nome com a extensão e o conteúdo).
class ArquivoPlanilha {
  const ArquivoPlanilha(this.nome, this.bytes);
  final String nome;
  final Uint8List bytes;
}

enum _Passo { arquivo, colunas, revisao, resumo }

/// Importa a planilha de preços: escolher o arquivo, apontar as colunas se o cabeçalho não disser,
/// conferir a ligação de cada produto ao catálogo e gravar tudo de uma vez.
class ImportarPlanilhaScreen extends StatefulWidget {
  const ImportarPlanilhaScreen({super.key, this.escolher, this.salvar});

  /// Testes: entrega o arquivo sem abrir o seletor do aparelho.
  final Future<ArquivoPlanilha?> Function()? escolher;

  /// Testes: recebe as ofertas sem gravar no servidor.
  final Future<void> Function(List<Oferta>)? salvar;

  @override
  State<ImportarPlanilhaScreen> createState() => _ImportarPlanilhaScreenState();
}

class _ImportarPlanilhaScreenState extends State<ImportarPlanilhaScreen> {
  _Passo _passo = _Passo.arquivo;
  String? _erro;
  bool _ocupado = false;
  List<List<String>> _linhas = const [];
  ColunasPlanilha _colunas = const ColunasPlanilha();
  int? _colunaNome;
  int? _colunaPreco;
  List<LinhaImportacao> _importacao = const [];
  DateTime _promoAte = DateTime.now().add(const Duration(days: 7));
  int _gravadas = 0;

  static Future<ArquivoPlanilha?> _escolherNoAparelho() async {
    final arquivo = await FilePicker.pickFile(
      dialogTitle: 'Planilha de preços',
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'ods'],
    );
    if (arquivo == null) return null;
    return ArquivoPlanilha(arquivo.name, await arquivo.readAsBytes());
  }

  Future<void> _escolherArquivo() async {
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      final arquivo = await (widget.escolher ?? _escolherNoAparelho)();
      if (arquivo == null || !mounted) return;
      final linhas = await lerPlanilha(arquivo.nome, arquivo.bytes);
      final colunas = detectarColunas(linhas);
      _linhas = linhas;
      if (colunas.completas) {
        _montar(colunas);
      } else {
        setState(() {
          _colunas = colunas;
          _colunaNome = colunas.nome;
          _colunaPreco = colunas.preco;
          _passo = _Passo.colunas;
        });
      }
    } on PlanilhaInvalida catch (e) {
      setState(() => _erro = e.mensagem);
    } catch (_) {
      setState(() => _erro = 'Não deu para abrir o arquivo. Tente de novo.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _montar(ColunasPlanilha colunas) {
    setState(() {
      _colunas = colunas;
      _importacao = montarImportacao(
        _linhas,
        colunas,
        OfertasService.instance.catalogo,
      );
      _passo = _Passo.revisao;
    });
  }

  List<Oferta> _ofertas() => ofertasDaImportacao(
    _importacao,
    lojaId: LojaService.instance.minhaLoja?.id ?? '',
    promoAte: _colunas.promocao == null ? null : _promoAte,
  );

  Future<void> _gravar() async {
    final ofertas = _ofertas();
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await (widget.salvar ?? OfertasService.instance.salvarVarias)(ofertas);
      if (!mounted) return;
      setState(() {
        _gravadas = ofertas.length;
        _passo = _Passo.resumo;
      });
    } on FalhaComMensagem catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _trocar(LinhaImportacao antiga, LinhaImportacao nova) {
    setState(() {
      _importacao = [
        for (final l in _importacao) identical(l, antiga) ? nova : l,
      ];
    });
  }

  Future<void> _escolherValidade() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _promoAte,
      firstDate: hoje,
      lastDate: hoje.add(const Duration(days: 365)),
    );
    if (data != null) setState(() => _promoAte = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar planilha')),
      body: ColunaCentral(
        child: switch (_passo) {
          _Passo.arquivo => _passoArquivo(context),
          _Passo.colunas => _passoColunas(context),
          _Passo.revisao => _passoRevisao(context),
          _Passo.resumo => _passoResumo(context),
        },
      ),
    );
  }

  Widget _passoArquivo(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Text('Preços de uma vez', style: t.titleLarge),
        const SizedBox(height: Espaco.s2),
        Text(
          'Use o CSV ou o Excel exportado do seu sistema, com uma coluna de produto e uma de preço. Você confere tudo antes de gravar.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: Espaco.s2),
        Text(
          'Até 3.000 produtos. Unidade, código e preço promocional são opcionais. Os preços dos produtos que não estão na planilha não mudam.',
          style: t.bodySmall?.copyWith(color: c.textoSuave),
        ),
        if (_erro != null) ...[
          const SizedBox(height: Espaco.s3),
          Aviso(_erro!),
        ],
        const SizedBox(height: Espaco.s4),
        FilledButton.icon(
          onPressed: _ocupado ? null : _escolherArquivo,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Escolher arquivo'),
        ),
      ],
    );
  }

  Widget _passoColunas(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cabecalho = _linhas[_colunas.linhaCabecalho];
    final opcoes = [
      for (var i = 0; i < cabecalho.length; i++)
        DropdownMenuItem(
          value: i,
          child: Text(
            cabecalho[i].trim().isEmpty ? 'Coluna ${i + 1}' : cabecalho[i],
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    final nome = _colunaNome;
    final preco = _colunaPreco;
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Text(
          'Não achamos as colunas sozinhos. Diga qual é o produto e qual é o preço.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: Espaco.s4),
        DropdownButtonFormField<int>(
          key: const ValueKey('coluna-nome'),
          initialValue: nome,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Coluna do produto'),
          items: opcoes,
          onChanged: (v) => setState(() => _colunaNome = v),
        ),
        const SizedBox(height: Espaco.s3),
        DropdownButtonFormField<int>(
          key: const ValueKey('coluna-preco'),
          initialValue: preco,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Coluna do preço'),
          items: opcoes,
          onChanged: (v) => setState(() => _colunaPreco = v),
        ),
        const SizedBox(height: Espaco.s4),
        FilledButton(
          onPressed: nome == null || preco == null || nome == preco
              ? null
              : () => _montar(_colunas.copyWith(nome: nome, preco: preco)),
          child: const Text('Continuar'),
        ),
      ],
    );
  }

  Widget _passoRevisao(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    int conta(GrupoImportacao g) =>
        _importacao.where((l) => l.grupo == g).length;
    final ligados = conta(GrupoImportacao.ligado);
    final escolher = conta(GrupoImportacao.escolher);
    final fora = conta(GrupoImportacao.fora);
    final n = _ofertas().length;
    final visiveis = [
      for (final l in _importacao)
        if (l.grupo != GrupoImportacao.fora) l,
    ];
    final dia = _promoAte.day.toString().padLeft(2, '0');
    final mes = _promoAte.month.toString().padLeft(2, '0');
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
              Text(
                '$ligados ${ligados == 1 ? 'ligado' : 'ligados'} · $escolher para escolher · $fora fora do catálogo',
                style: t.titleSmall,
              ),
              const SizedBox(height: Espaco.s1),
              Text(
                'Confira o item do catálogo e o preço de cada linha. Só as marcadas são gravadas.',
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
              if (_colunas.promocao != null) ...[
                const SizedBox(height: Espaco.s3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Promoções valem até $dia/$mes',
                        style: t.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _escolherValidade,
                      child: const Text('Mudar'),
                    ),
                  ],
                ),
              ],
              if (_erro != null) ...[
                const SizedBox(height: Espaco.s3),
                Aviso(_erro!),
              ],
              const SizedBox(height: Espaco.s3),
              for (final l in visiveis) ...[
                _LinhaRevisao(linha: l, onChanged: (nova) => _trocar(l, nova)),
                const SizedBox(height: Espaco.s2),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s2,
              Espaco.s4,
              Espaco.s3,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: n == 0 || _ocupado ? null : _gravar,
                child: Text('Gravar $n ${n == 1 ? 'preço' : 'preços'}'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passoResumo(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final fora = [
      for (final l in _importacao)
        if (l.grupo == GrupoImportacao.fora) l.nome,
    ];
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Icon(Icons.check_circle_outline, size: 48, color: c.sucesso),
        const SizedBox(height: Espaco.s3),
        Text(
          '$_gravadas ${_gravadas == 1 ? 'preço gravado' : 'preços gravados'} · ${fora.length} fora do catálogo',
          textAlign: TextAlign.center,
          style: t.titleMedium,
        ),
        if (fora.isNotEmpty) ...[
          const SizedBox(height: Espaco.s4),
          Text(
            'Fora do catálogo (mande para o suporte incluir):',
            style: t.bodyMedium,
          ),
          const SizedBox(height: Espaco.s2),
          for (final nome in fora)
            Padding(
              padding: const EdgeInsets.only(bottom: Espaco.s1),
              child: Text(
                nome,
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
            ),
        ],
        const SizedBox(height: Espaco.s4),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar para produtos'),
        ),
      ],
    );
  }
}

class _LinhaRevisao extends StatelessWidget {
  const _LinhaRevisao({required this.linha, required this.onChanged});
  final LinhaImportacao linha;
  final ValueChanged<LinhaImportacao> onChanged;

  /// Marcada só quando dá para gravar: item escolhido, preço válido e a mesma unidade.
  static bool _podeGravar(LinhaImportacao l) =>
      l.item != null &&
      !l.avisos.contains(AvisoImportacao.precoInvalido) &&
      !l.avisos.contains(AvisoImportacao.unidadeDiferente);

  String _textoDoAviso(AvisoImportacao a) => switch (a) {
    AvisoImportacao.unidadeDiferente =>
      'Unidade da planilha: ${linha.unidadePlanilha}; o catálogo vende por ${linha.item?.unidade ?? '—'}. Confira o preço.',
    AvisoImportacao.repetido => 'Repetido: ficou marcado o mais barato.',
    AvisoImportacao.precoInvalido => 'Preço inválido.',
    AvisoImportacao.promocaoIgnorada => 'Promoção maior que o preço, ignorada.',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final l = linha;
    final preco = l.preco;
    return Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.md),
        side: BorderSide(color: c.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaco.s1,
          Espaco.s2,
          Espaco.s3,
          Espaco.s2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: l.marcada,
              onChanged: l.item == null || preco == null || preco <= 0
                  ? null
                  : (v) => onChanged(l.copyWith(marcada: v ?? false)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (l.grupo == GrupoImportacao.escolher)
                    DropdownButton<ItemCatalogo>(
                      isExpanded: true,
                      value: l.item,
                      hint: const Text('Qual destes?'),
                      items: [
                        for (final i in l.candidatos)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              i.nome,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (i) {
                        if (i == null) return;
                        final nova = l.copyWith(item: i);
                        onChanged(nova.copyWith(marcada: _podeGravar(nova)));
                      },
                    )
                  else if (l.item != null)
                    Text(
                      l.item!.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: c.textoSuave),
                    ),
                  if (l.item != null)
                    Text(
                      'Preço por ${l.item!.unidade}',
                      style: t.bodySmall?.copyWith(color: c.textoSuave),
                    ),
                  for (final a in l.avisos)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _textoDoAviso(a),
                        style: t.bodySmall?.copyWith(color: c.aviso),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Espaco.s2),
            SizedBox(
              width: 104,
              child: TextFormField(
                key: ValueKey('preco-${l.numero}'),
                initialValue: preco == null
                    ? ''
                    : preco.toStringAsFixed(2).replaceAll('.', ','),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  prefixText: r'R$ ',
                  isDense: true,
                ),
                onChanged: (texto) {
                  final nova = l.copyWith(preco: lerPreco(texto) ?? 0);
                  onChanged(
                    nova.marcada && !_podeGravar(nova)
                        ? nova.copyWith(marcada: false)
                        : nova,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
