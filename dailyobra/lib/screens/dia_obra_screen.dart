import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/compartilhar.dart';
import '../services/diario_service.dart';
import '../services/marca_service.dart';
import '../services/obras_service.dart';
import '../services/pdf_diario.dart';
import 'componentes.dart';
import 'ditar_dia.dart';

const _funcoes = [
  'Pedreiro',
  'Servente',
  'Mestre de obras',
  'Encarregado',
  'Carpinteiro',
  'Armador',
  'Eletricista',
  'Encanador',
  'Pintor',
];

String? _inteiro(String v) {
  if (v.trim().isEmpty) return null;
  return int.tryParse(v.trim()) == null ? 'Digite um número inteiro.' : null;
}

String? _percentual(String v) {
  if (v.trim().isEmpty) return null;
  final n = int.tryParse(v.trim());
  return n == null || n < 0 || n > 100 ? 'Digite de 0 a 100.' : null;
}

double? _decimal(String v) {
  final n = lerNumero(v);
  return n.isNaN ? null : n;
}

String? _numero(String v) {
  if (v.trim().isEmpty) return null;
  return _decimal(v) == null ? 'Digite um número.' : null;
}

/// Um dia do diário: quem preenche monta tudo aqui, e quem só acompanha vê o que foi registrado.
class DiaObraScreen extends StatefulWidget {
  const DiaObraScreen({
    super.key,
    required this.obra,
    required this.data,
    this.escolherFoto,
    this.enviarPdf,
    this.ditarAoAbrir = false,
  });

  final Obra obra;
  final DateTime data;

  /// O atalho do Início abre direto a janela do ditado, se o dia ainda puder mudar.
  final bool ditarAoAbrir;

  /// Câmera ([true]) ou galeria; os testes trocam por fotos prontas.
  final Future<List<XFile>> Function(bool camera)? escolherFoto;

  /// Os testes trocam a geração e o envio do documento.
  final Future<void> Function(DiaObra dia)? enviarPdf;

  @override
  State<DiaObraScreen> createState() => _DiaObraScreenState();
}

class _DiaObraScreenState extends State<DiaObraScreen> {
  late DiaObra _dia = DiaObra(obraId: widget.obra.id, data: widget.data);
  DiaObra? _anterior;
  final _observacoes = TextEditingController();

  /// Fotos enviadas agora, mostradas sem baixar de novo.
  final _bytes = <String, Uint8List>{};
  final _removidas = <String>[];
  Map<String, String> _links = const {};

  bool _carregando = true;
  String? _erro;
  bool _alterado = false;
  bool _ocupado = false;
  bool _enviandoFoto = false;
  bool _jaDitou = false;

  bool get _registra => widget.obra.funcao.registra;
  bool get _admin => widget.obra.funcao.administra;
  bool get _lidera => widget.obra.funcao.lidera;
  bool get _edita => _registra && !_dia.fechado;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final servico = DiarioService.instance;
    try {
      final dia = await servico.doDia(widget.obra.id, widget.data);
      final anterior = await servico.ultimoComEquipe(
        widget.obra.id,
        antesDe: widget.data,
      );
      final links = await servico.linksDasFotos([
        for (final f in dia?.fotos ?? const <FotoDia>[]) f.caminho,
      ]);
      if (!mounted) return;
      setState(() {
        if (dia != null) _dia = dia;
        _observacoes.text = _dia.observacoes;
        _anterior = anterior;
        _links = links;
        _carregando = false;
      });
      if (widget.ditarAoAbrir && !_jaDitou && _edita) {
        _jaDitou = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ditar();
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _carregando = false;
        });
      }
    }
  }

  void _mudar(DiaObra novo) => setState(() {
    _dia = novo;
    _alterado = true;
  });

  /// A sugestão só preenche a tela: nada vai para o banco até a pessoa conferir e salvar.
  Future<void> _ditar() async {
    final sugestao = await ditarODia(context, widget.obra.id);
    if (sugestao == null || !mounted) return;
    final antes = _dia;
    final alteradoAntes = _alterado;
    void mostrar(DiaObra dia, bool alterado) => setState(() {
      _dia = dia;
      _observacoes.text = dia.observacoes;
      _alterado = alterado;
    });
    mostrar(sugestao.aplicar(_dia), true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Dia preenchido. Confira antes de salvar.'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              if (mounted) mostrar(antes, alteradoAntes);
            },
          ),
        ),
      );
  }

  Future<void> _salvar({bool finalizar = false}) async {
    setState(() => _ocupado = true);
    try {
      final salvo = await DiarioService.instance.salvar(
        _dia,
        finalizar: finalizar,
      );
      await DiarioService.instance.apagarFotos(_removidas);
      _removidas.clear();
      if (!mounted) return;
      setState(() {
        _dia = salvo;
        _alterado = false;
      });
      avisar(context, finalizar ? 'Dia finalizado.' : 'Dia salvo.');
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _finalizar() async {
    if (_dia.vazio) {
      avisar(context, 'Preencha alguma coisa antes de finalizar o dia.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Finalizar este dia?'),
        content: const Text(
          'Depois de finalizado, o dia não pode mais ser alterado. Só o administrador da obra consegue reabrir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok == true) await _salvar(finalizar: true);
  }

  Future<void> _reabrir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reabrir este dia?'),
        content: const Text(
          'O dia volta a ser rascunho, e quem toca a obra pode alterar de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      await DiarioService.instance.reabrir(_dia.id!);
      if (!mounted) return;
      setState(() => _dia = _dia.copyWith(situacao: SituacaoDia.rascunho));
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _gerarPdf() async {
    if (_alterado) {
      avisar(context, 'Salve o dia antes de gerar o PDF.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      await (widget.enviarPdf ?? _enviarPdf)(_dia);
    } catch (_) {
      if (mounted) {
        avisar(context, 'Não foi possível gerar o PDF. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _enviarPdf(DiaObra dia) async {
    final marca = await MarcaService.instance.daObra(widget.obra.id);
    final bytes = await pdfDoDia(
      obra: widget.obra,
      dia: dia,
      fotos: await DiarioService.instance.bytesDasFotos(dia),
      marca: marca,
      logo: await MarcaService.instance.logoBytes(marca?.logoPath),
    );
    await compartilharPdf(bytes, nomeDoPdf(dia), titulo: 'Diário de obra');
  }

  Future<List<XFile>> _abrirSeletor(bool camera) async {
    final seletor = ImagePicker();
    if (camera) {
      final foto = await seletor.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 80,
      );
      return [?foto];
    }
    final vagas = DiarioService.fotosPorDia - _dia.fotos.length;
    final fotos = await seletor.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 80,
      limit: vagas > 1 ? vagas : null,
    );
    return fotos.take(vagas).toList();
  }

  Future<void> _pegarFotos(bool camera) async {
    final List<XFile> fotos;
    try {
      fotos = await (widget.escolherFoto ?? _abrirSeletor)(camera);
    } catch (_) {
      if (mounted) {
        avisar(
          context,
          camera
              ? 'Não foi possível abrir a câmera. Confira a permissão do app.'
              : 'Não foi possível abrir a galeria.',
        );
      }
      return;
    }
    if (fotos.isEmpty || !mounted) return;
    setState(() => _enviandoFoto = true);
    try {
      for (final foto in fotos) {
        final bytes = await foto.readAsBytes();
        if (bytes.length > DiarioService.tamanhoMaximo) {
          if (mounted) {
            avisar(context, 'Esta foto passou de 5 MB. Escolha outra.');
          }
          continue;
        }
        final caminho = await DiarioService.instance.enviarFoto(
          obraId: widget.obra.id,
          data: widget.data,
          bytes: bytes,
          nome: foto.name,
        );
        if (!mounted) return;
        _bytes[caminho] = bytes;
        _mudar(
          _dia.copyWith(
            fotos: [
              ..._dia.fotos,
              FotoDia(caminho: caminho),
            ],
          ),
        );
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  void _removerFoto(int i) {
    _removidas.add(_dia.fotos[i].caminho);
    _mudar(_dia.copyWith(fotos: _semItem(_dia.fotos, i)));
  }

  Widget _imagemDaFoto(FotoDia foto, {BoxFit fit = BoxFit.cover}) {
    final bytes = _bytes[foto.caminho];
    final link = _links[foto.caminho];
    Widget falhou(BuildContext c, Object e, StackTrace? s) =>
        Center(child: Icon(Icons.image_outlined, color: c.cores.textoSuave));
    if (bytes != null) {
      return Image.memory(bytes, fit: fit, errorBuilder: falhou);
    }
    if (link != null) {
      return Image.network(link, fit: fit, errorBuilder: falhou);
    }
    return Center(
      child: Icon(Icons.image_outlined, color: context.cores.textoSuave),
    );
  }

  Future<void> _abrirFoto(int i) async {
    final foto = _dia.fotos[i];
    final legenda = TextEditingController(text: foto.legenda);
    final nova = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Raio.sm),
              child: SizedBox(
                height: 240,
                child: _imagemDaFoto(foto, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: Espaco.s3),
            if (_edita)
              CampoTexto(
                rotulo: 'Legenda',
                controller: legenda,
                maxLength: 120,
                dica: 'O que aparece na foto',
              )
            else if (foto.legenda.isNotEmpty)
              Text(foto.legenda),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(_edita ? 'Cancelar' : 'Fechar'),
          ),
          if (_edita)
            FilledButton(
              onPressed: () => Navigator.pop(c, legenda.text.trim()),
              child: const Text('Salvar item'),
            ),
        ],
      ),
    );
    legenda.dispose();
    if (nova == null) return;
    final fotos = [..._dia.fotos];
    fotos[i] = FotoDia(caminho: foto.caminho, legenda: nova);
    _mudar(_dia.copyWith(fotos: fotos));
  }

  Future<(List<String>, T?)?> _janela<T>({
    required String titulo,
    required bool novo,
    required List<_Campo> campos,
    List<String> atalhos = const [],
    List<(T, String)> opcoes = const [],
    T? opcao,
  }) => showDialog<(List<String>, T?)>(
    context: context,
    builder: (_) => _JanelaItem<T>(
      titulo: titulo,
      novo: novo,
      campos: campos,
      atalhos: atalhos,
      opcoes: opcoes,
      opcao: opcao,
    ),
  );

  Future<void> _editarEquipe([int? i]) async {
    final e = i == null ? null : _dia.equipe[i];
    final r = await _janela<void>(
      titulo: 'Equipe',
      novo: e == null,
      atalhos: _funcoes,
      campos: [
        _Campo('Função', valor: e?.funcao ?? '', obrigatorio: true),
        _Campo(
          'Quantidade',
          valor: '${e?.quantidade ?? 1}',
          teclado: TextInputType.number,
          validar: _inteiro,
        ),
        _Campo('Empresa ou empreiteiro', valor: e?.empresa ?? ''),
      ],
    );
    if (r == null) return;
    final item = ItemEquipe(
      funcao: r.$1[0],
      quantidade: int.tryParse(r.$1[1]) ?? 1,
      empresa: r.$1[2],
    );
    _mudar(_dia.copyWith(equipe: _comItem(_dia.equipe, i, item)));
  }

  Future<void> _editarAtividade([int? i]) async {
    final a = i == null ? null : _dia.atividades[i];
    final r = await _janela<void>(
      titulo: 'O que foi feito',
      novo: a == null,
      campos: [
        _Campo(
          'Serviço',
          valor: a?.descricao ?? '',
          obrigatorio: true,
          maxLength: 500,
          dica: 'Ex.: reboco da sala',
        ),
        _Campo('Local', valor: a?.local ?? '', dica: 'Ex.: térreo'),
        _Campo(
          'Quanto ficou pronto (%)',
          valor: a?.percentual?.toString() ?? '',
          teclado: TextInputType.number,
          validar: _percentual,
        ),
      ],
    );
    if (r == null) return;
    final item = Atividade(
      descricao: r.$1[0],
      local: r.$1[1],
      percentual: int.tryParse(r.$1[2]),
    );
    _mudar(_dia.copyWith(atividades: _comItem(_dia.atividades, i, item)));
  }

  Future<void> _editarOcorrencia([int? i]) async {
    final o = i == null ? null : _dia.ocorrencias[i];
    final r = await _janela<TipoOcorrencia>(
      titulo: 'Ocorrência',
      novo: o == null,
      opcoes: [for (final t in TipoOcorrencia.values) (t, t.rotulo)],
      opcao: o?.tipo ?? TipoOcorrencia.geral,
      campos: [
        _Campo(
          'O que aconteceu',
          valor: o?.descricao ?? '',
          obrigatorio: true,
          maxLength: 500,
        ),
      ],
    );
    if (r == null) return;
    final item = Ocorrencia(
      tipo: r.$2 ?? TipoOcorrencia.geral,
      descricao: r.$1[0],
    );
    _mudar(_dia.copyWith(ocorrencias: _comItem(_dia.ocorrencias, i, item)));
  }

  Future<void> _editarMaterial([int? i]) async {
    final m = i == null ? null : _dia.materiais[i];
    final q = m?.quantidade;
    final r = await _janela<void>(
      titulo: 'Material usado',
      novo: m == null,
      campos: [
        _Campo('Material', valor: m?.material ?? '', obrigatorio: true),
        _Campo(
          'Quantidade',
          valor: q == null ? '' : formatarQuantidade(q),
          teclado: const TextInputType.numberWithOptions(decimal: true),
          validar: _numero,
        ),
        _Campo('Unidade', valor: m?.unidade ?? '', dica: 'Ex.: saco, m²'),
        _Campo('Fornecedor', valor: m?.fornecedor ?? ''),
      ],
    );
    if (r == null) return;
    final item = MaterialDia(
      material: r.$1[0],
      quantidade: _decimal(r.$1[1]),
      unidade: r.$1[2],
      fornecedor: r.$1[3],
    );
    _mudar(_dia.copyWith(materiais: _comItem(_dia.materiais, i, item)));
  }

  Future<void> _editarEquipamento([int? i]) async {
    final e = i == null ? null : _dia.equipamentos[i];
    final r = await _janela<void>(
      titulo: 'Equipamento',
      novo: e == null,
      campos: [
        _Campo(
          'Equipamento',
          valor: e?.equipamento ?? '',
          obrigatorio: true,
          dica: 'Ex.: betoneira',
        ),
        _Campo(
          'Quantidade',
          valor: '${e?.quantidade ?? 1}',
          teclado: TextInputType.number,
          validar: _inteiro,
        ),
      ],
    );
    if (r == null) return;
    final item = EquipamentoDia(
      equipamento: r.$1[0],
      quantidade: int.tryParse(r.$1[1]) ?? 1,
    );
    _mudar(_dia.copyWith(equipamentos: _comItem(_dia.equipamentos, i, item)));
  }

  Future<void> _sair() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text(
          'O que você preencheu neste dia ainda não foi salvo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sair'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Continuar aqui'),
          ),
        ],
      ),
    );
    if (sair == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_alterado,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _sair();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diário de obra'),
          actions: [
            if (_dia.id != null)
              IconButton(
                tooltip: 'Gerar PDF',
                onPressed: _ocupado ? null : _gerarPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
          ],
        ),
        body: _corpo(),
        bottomNavigationBar: _rodape(),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return Center(
        child: CircularProgressIndicator(color: context.cores.acao),
      );
    }
    if (_erro != null) {
      return Padding(
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
      );
    }
    final t = Theme.of(context).textTheme;
    final partes = [
      _clima(),
      _equipe(),
      _lista(
        titulo: 'O que foi feito',
        adicionar: 'Adicionar atividade',
        aoAdicionar: _editarAtividade,
        linhas: [
          for (final (i, a) in _dia.atividades.indexed)
            _Linha(
              titulo: a.descricao,
              detalhe: [
                a.local,
                if (a.percentual != null) '${a.percentual}%',
              ].where((p) => p.isNotEmpty).join(' · '),
              aoTocar: _edita ? () => _editarAtividade(i) : null,
              aoRemover: _edita
                  ? () => _mudar(
                      _dia.copyWith(atividades: _semItem(_dia.atividades, i)),
                    )
                  : null,
            ),
        ],
      ),
      _lista(
        titulo: 'Ocorrências',
        adicionar: 'Adicionar ocorrência',
        aoAdicionar: _editarOcorrencia,
        linhas: [
          for (final (i, o) in _dia.ocorrencias.indexed)
            _Linha(
              titulo: o.descricao,
              detalhe: o.tipo.rotulo,
              aoTocar: _edita ? () => _editarOcorrencia(i) : null,
              aoRemover: _edita
                  ? () => _mudar(
                      _dia.copyWith(ocorrencias: _semItem(_dia.ocorrencias, i)),
                    )
                  : null,
            ),
        ],
      ),
      _lista(
        titulo: 'Materiais',
        adicionar: 'Adicionar material',
        aoAdicionar: _editarMaterial,
        linhas: [
          for (final (i, m) in _dia.materiais.indexed)
            _Linha(
              titulo: m.material,
              detalhe: [
                if (m.quantidade != null)
                  '${formatarQuantidade(m.quantidade!)} ${m.unidade}'.trim(),
                m.fornecedor,
              ].where((p) => p.isNotEmpty).join(' · '),
              aoTocar: _edita ? () => _editarMaterial(i) : null,
              aoRemover: _edita
                  ? () => _mudar(
                      _dia.copyWith(materiais: _semItem(_dia.materiais, i)),
                    )
                  : null,
            ),
        ],
      ),
      _lista(
        titulo: 'Equipamentos',
        adicionar: 'Adicionar equipamento',
        aoAdicionar: _editarEquipamento,
        linhas: [
          for (final (i, e) in _dia.equipamentos.indexed)
            _Linha(
              titulo: '${e.quantidade} · ${e.equipamento}',
              aoTocar: _edita ? () => _editarEquipamento(i) : null,
              aoRemover: _edita
                  ? () => _mudar(
                      _dia.copyWith(
                        equipamentos: _semItem(_dia.equipamentos, i),
                      ),
                    )
                  : null,
            ),
        ],
      ),
      _fotos(),
      _anotacoes(),
    ].nonNulls.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.s4,
        Espaco.s5,
        Espaco.s4,
        Espaco.s6,
      ),
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
                    Text(diaPorExtenso(widget.data), style: t.titleLarge),
                    const SizedBox(height: Espaco.s1),
                    Text(
                      widget.obra.nome,
                      style: t.bodyMedium?.copyWith(
                        color: context.cores.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              if (_dia.id != null) ...[
                const SizedBox(width: Espaco.s2),
                SeloDoDia(_dia),
              ],
            ],
          ),
          if (!_registra && _dia.id == null) ...[
            const SizedBox(height: Espaco.s4),
            const Aviso(
              'Este dia ainda não foi registrado.',
              tom: TomSelo.info,
            ),
          ],
          if (_edita) ...[
            const SizedBox(height: Espaco.s4),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _ditar,
              icon: const Icon(Icons.mic_none, size: 18),
              label: const Text('Ditar o dia'),
            ),
          ],
          for (final parte in partes) ...[
            const SizedBox(height: Espaco.s4),
            parte,
          ],
        ],
      ),
    );
  }

  Widget? _clima() {
    if (!_edita) {
      final texto = [
        if (_dia.climaManha != null) 'Manhã: ${_dia.climaManha!.rotulo}',
        if (_dia.climaTarde != null) 'Tarde: ${_dia.climaTarde!.rotulo}',
      ].join(' · ');
      if (texto.isEmpty) return null;
      return _Secao(titulo: 'Clima', child: Text(texto));
    }
    return _Secao(
      titulo: 'Clima',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _escolhaClima(
            'Manhã',
            'manha',
            _dia.climaManha,
            (c) => _mudar(_dia.comClima(c, _dia.climaTarde)),
          ),
          const SizedBox(height: Espaco.s3),
          _escolhaClima(
            'Tarde',
            'tarde',
            _dia.climaTarde,
            (c) => _mudar(_dia.comClima(_dia.climaManha, c)),
          ),
        ],
      ),
    );
  }

  Widget _escolhaClima(
    String rotulo,
    String chave,
    Clima? valor,
    ValueChanged<Clima?> mudar,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Rotulo(rotulo),
      Wrap(
        spacing: Espaco.s2,
        runSpacing: Espaco.s1,
        children: [
          for (final c in Clima.values)
            _Escolha(
              key: Key('clima-$chave-${c.name}'),
              rotulo: c.rotulo,
              marcada: c == valor,
              aoMudar: (marcado) => mudar(marcado ? c : null),
            ),
        ],
      ),
    ],
  );

  Widget? _equipe() {
    final anterior = _anterior;
    final pessoas = _dia.pessoas;
    return _lista(
      titulo: 'Equipe',
      contagem: pessoas == 0
          ? null
          : '$pessoas ${pessoas == 1 ? 'pessoa' : 'pessoas'}',
      adicionar: 'Adicionar função',
      chave: const Key('adicionar-equipe'),
      aoAdicionar: _editarEquipe,
      topo: _edita && _dia.equipe.isEmpty && anterior != null
          ? OutlinedButton.icon(
              onPressed: () => _mudar(_dia.copyWith(equipe: anterior.equipe)),
              icon: const Icon(Icons.history, size: 18),
              label: Text('Repetir equipe de ${dataCurta(anterior.data)}'),
            )
          : null,
      linhas: [
        for (final (i, e) in _dia.equipe.indexed)
          _Linha(
            titulo: '${e.quantidade} · ${e.funcao}',
            detalhe: e.empresa,
            aoTocar: _edita ? () => _editarEquipe(i) : null,
            aoRemover: _edita
                ? () => _mudar(_dia.copyWith(equipe: _semItem(_dia.equipe, i)))
                : null,
          ),
      ],
    );
  }

  /// Parte que é uma lista. Quem só lê não vê as partes que ficaram sem nada.
  Widget? _lista({
    required String titulo,
    required String adicionar,
    required VoidCallback aoAdicionar,
    required List<Widget> linhas,
    String? contagem,
    Key? chave,
    Widget? topo,
  }) {
    if (!_edita && linhas.isEmpty) return null;
    return _Secao(
      titulo: titulo,
      acao: contagem == null
          ? null
          : Text(contagem, style: Theme.of(context).textTheme.labelMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topo != null) ...[topo, const SizedBox(height: Espaco.s2)],
          ...linhas,
          if (_edita)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: chave,
                onPressed: aoAdicionar,
                icon: const Icon(Icons.add, size: 18),
                label: Text(adicionar),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _fotos() {
    final fotos = _dia.fotos;
    if (!_edita && fotos.isEmpty) return null;
    final cabe = fotos.length < DiarioService.fotosPorDia;
    return _Secao(
      titulo: 'Fotos',
      acao: Text(
        '${fotos.length} de ${DiarioService.fotosPorDia}',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fotos.isNotEmpty) ...[
            Wrap(
              spacing: Espaco.s2,
              runSpacing: Espaco.s2,
              children: [
                for (final (i, f) in fotos.indexed)
                  MiniaturaFoto(
                    imagem: _imagemDaFoto(f),
                    aoTocar: () => _abrirFoto(i),
                    aoRemover: _edita ? () => _removerFoto(i) : null,
                  ),
              ],
            ),
            const SizedBox(height: Espaco.s3),
          ],
          if (_enviandoFoto)
            LinearProgressIndicator(color: context.cores.acao)
          else if (_edita && cabe)
            Wrap(
              spacing: Espaco.s2,
              runSpacing: Espaco.s2,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pegarFotos(true),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Tirar foto'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pegarFotos(false),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Da galeria'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget? _anotacoes() {
    if (!_edita) {
      if (_dia.observacoes.trim().isEmpty) return null;
      return _Secao(titulo: 'Observações', child: Text(_dia.observacoes));
    }
    return _Secao(
      titulo: 'Observações',
      child: KeyedSubtree(
        key: const Key('observacoes'),
        child: TextField(
          controller: _observacoes,
          minLines: 3,
          maxLines: 8,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => _mudar(_dia.copyWith(observacoes: v)),
          decoration: const InputDecoration(
            hintText: 'Algo mais que precise ficar registrado',
            counterText: '',
          ),
        ),
      ),
    );
  }

  Widget? _rodape() {
    if (_carregando || _erro != null) return null;
    final Widget conteudo;
    if (_edita) {
      conteudo = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _ocupado ? null : _salvar,
              child: const Text('Salvar rascunho'),
            ),
          ),
          if (_lidera) ...[
            const SizedBox(width: Espaco.s2),
            Expanded(
              child: FilledButton(
                onPressed: _ocupado ? null : _finalizar,
                child: const Text('Finalizar o dia'),
              ),
            ),
          ],
        ],
      );
    } else if (_admin && _dia.fechado) {
      conteudo = OutlinedButton(
        onPressed: _ocupado ? null : _reabrir,
        child: const Text('Reabrir o dia'),
      );
    } else {
      return null;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaco.s4,
          Espaco.s2,
          Espaco.s4,
          Espaco.s3,
        ),
        child: conteudo,
      ),
    );
  }
}

List<T> _comItem<T>(List<T> lista, int? i, T item) {
  if (i == null) return [...lista, item];
  return [...lista]..[i] = item;
}

List<T> _semItem<T>(List<T> lista, int i) => [...lista]..removeAt(i);

/// "Rascunho" ou "Finalizado", na mesma aparência em todas as telas do diário.
class SeloDoDia extends StatelessWidget {
  const SeloDoDia(this.dia, {super.key});
  final DiaObra dia;

  @override
  Widget build(BuildContext context) => Selo(
    dia.situacao.rotulo,
    tom: dia.fechado ? TomSelo.sucesso : TomSelo.aviso,
  );
}

class MiniaturaFoto extends StatelessWidget {
  const MiniaturaFoto({
    super.key,
    required this.imagem,
    required this.aoTocar,
    this.aoRemover,
  });

  final Widget imagem;
  final VoidCallback aoTocar;
  final VoidCallback? aoRemover;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: context.cores.superficieSutil,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(Raio.sm),
            child: InkWell(onTap: aoTocar, child: imagem),
          ),
          if (aoRemover != null)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: aoRemover,
                  child: const Tooltip(
                    message: 'Remover foto',
                    child: Padding(
                      padding: EdgeInsets.all(Espaco.s1),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// O laranja da marca com texto branco não dá contraste: a opção marcada usa a cor de ação.
class _Escolha extends StatelessWidget {
  const _Escolha({
    super.key,
    required this.rotulo,
    required this.marcada,
    required this.aoMudar,
  });

  final String rotulo;
  final bool marcada;
  final ValueChanged<bool> aoMudar;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return ChoiceChip(
      label: Text(rotulo),
      selected: marcada,
      onSelected: aoMudar,
      selectedColor: cores.acao,
      checkmarkColor: cores.textoSobreAcao,
      labelStyle: marcada ? TextStyle(color: cores.textoSobreAcao) : null,
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, this.acao, required this.child});
  final String titulo;
  final Widget? acao;
  final Widget child;

  @override
  Widget build(BuildContext context) => Painel(
    titulo: titulo,
    acao: acao,
    child: Padding(padding: const EdgeInsets.all(Espaco.s4), child: child),
  );
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.titulo,
    this.detalhe = '',
    this.aoTocar,
    this.aoRemover,
  });

  final String titulo;
  final String detalhe;
  final VoidCallback? aoTocar;
  final VoidCallback? aoRemover;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espaco.s2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: t.bodyLarge),
                  if (detalhe.isNotEmpty)
                    Text(
                      detalhe,
                      style: t.bodySmall?.copyWith(
                        color: context.cores.textoSuave,
                      ),
                    ),
                ],
              ),
            ),
            if (aoRemover != null)
              IconButton(
                tooltip: 'Remover',
                visualDensity: VisualDensity.compact,
                onPressed: aoRemover,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _Campo {
  const _Campo(
    this.rotulo, {
    this.valor = '',
    this.obrigatorio = false,
    this.teclado,
    this.dica,
    this.maxLength = 120,
    this.validar,
  });

  final String rotulo;
  final String valor;
  final bool obrigatorio;
  final TextInputType? teclado;
  final String? dica;
  final int maxLength;
  final String? Function(String)? validar;
}

/// Janela de um item do dia. Devolve o que foi digitado, na ordem de [campos], e a opção marcada.
class _JanelaItem<T> extends StatefulWidget {
  const _JanelaItem({
    required this.titulo,
    required this.novo,
    required this.campos,
    required this.atalhos,
    required this.opcoes,
    required this.opcao,
  });

  final String titulo;
  final bool novo;
  final List<_Campo> campos;

  /// Preenchem o primeiro campo com um toque.
  final List<String> atalhos;
  final List<(T, String)> opcoes;
  final T? opcao;

  @override
  State<_JanelaItem<T>> createState() => _JanelaItemState<T>();
}

class _JanelaItemState<T> extends State<_JanelaItem<T>> {
  late final _textos = [
    for (final c in widget.campos) TextEditingController(text: c.valor),
  ];
  late final _erros = List<String?>.filled(widget.campos.length, null);
  late T? _opcao = widget.opcao;

  @override
  void dispose() {
    for (final c in _textos) {
      c.dispose();
    }
    super.dispose();
  }

  void _concluir() {
    setState(() {
      for (final (i, c) in widget.campos.indexed) {
        final v = _textos[i].text;
        _erros[i] = c.obrigatorio && v.trim().isEmpty
            ? 'Preencha este campo.'
            : c.validar?.call(v);
      }
    });
    if (_erros.any((e) => e != null)) return;
    Navigator.pop(context, ([for (final c in _textos) c.text.trim()], _opcao));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.opcoes.isNotEmpty) ...[
              const Rotulo('Tipo'),
              Wrap(
                spacing: Espaco.s2,
                runSpacing: Espaco.s1,
                children: [
                  for (final (valor, rotulo) in widget.opcoes)
                    _Escolha(
                      rotulo: rotulo,
                      marcada: valor == _opcao,
                      aoMudar: (_) => setState(() => _opcao = valor),
                    ),
                ],
              ),
              const SizedBox(height: Espaco.s3),
            ],
            for (final (i, c) in widget.campos.indexed) ...[
              if (i > 0) const SizedBox(height: Espaco.s3),
              CampoTexto(
                rotulo: c.rotulo,
                controller: _textos[i],
                obrigatorio: c.obrigatorio,
                teclado: c.teclado,
                dica: c.dica,
                maxLength: c.maxLength,
                erro: _erros[i],
              ),
              if (i == 0 && widget.atalhos.isNotEmpty) ...[
                const SizedBox(height: Espaco.s2),
                Wrap(
                  spacing: Espaco.s2,
                  children: [
                    for (final a in widget.atalhos)
                      ActionChip(
                        label: Text(a),
                        onPressed: () => setState(() => _textos[0].text = a),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _concluir,
          child: Text(widget.novo ? 'Adicionar' : 'Salvar item'),
        ),
      ],
    );
  }
}
