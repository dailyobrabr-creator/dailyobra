import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/compartilhar.dart';
import '../services/marca_service.dart';
import '../services/obras_service.dart';
import '../services/pdf_proposta.dart';
import '../services/perfil_service.dart';
import '../services/propostas_comerciais_service.dart';
import 'componentes.dart';
import 'obra_form_screen.dart';
import 'obra_screen.dart';

/// Quantos dias a proposta vale, quando o engenheiro não muda.
const _diasDeValidade = 15;

/// Propostas para os clientes, da mais nova para a mais antiga.
class PropostasComerciaisScreen extends StatefulWidget {
  const PropostasComerciaisScreen({
    super.key,
    this.hoje,
    this.enviarPdf,
    this.criarObra,
  });

  /// Os testes fixam o dia.
  final DateTime? hoje;

  /// Os testes trocam o envio do PDF.
  final Future<void> Function(PropostaComercial proposta)? enviarPdf;

  /// Os testes trocam o cadastro da obra. Devolve o id dela.
  final Future<String?> Function(PropostaComercial proposta)? criarObra;

  @override
  State<PropostasComerciaisScreen> createState() =>
      _PropostasComerciaisScreenState();
}

class _PropostasComerciaisScreenState extends State<PropostasComerciaisScreen> {
  List<PropostaComercial>? _propostas;
  String? _erro;

  DateTime get _hoje => widget.hoje ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final p = await PropostasComerciaisService.instance.listar();
      if (mounted) {
        setState(() {
          _propostas = p;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _abrir([PropostaComercial? p]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropostaComercialScreen(
          proposta: p,
          hoje: widget.hoje,
          enviarPdf: widget.enviarPdf,
          criarObra: widget.criarObra,
        ),
      ),
    );
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final propostas = _propostas;
    return Scaffold(
      appBar: AppBar(title: const Text('Propostas comerciais')),
      floatingActionButton: propostas == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _abrir,
              icon: const Icon(Icons.add),
              label: const Text('Nova proposta'),
            ),
      body: _erro != null && propostas == null
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
          : propostas == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : _lista(propostas),
    );
  }

  Widget _lista(List<PropostaComercial> propostas) {
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      color: context.cores.acao,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Espaco.s4,
          Espaco.s4,
          Espaco.s4,
          Espaco.s10 * 2,
        ),
        children: [
          if (propostas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Espaco.s6),
              child: Column(
                children: [
                  Text('Nenhuma proposta', style: t.titleMedium),
                  const SizedBox(height: Espaco.s2),
                  Text(
                    'Monte a proposta com a sua marca e mande em PDF. Quando o cliente aceitar, ela vira obra.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          for (final p in propostas) ...[
            _CartaoDaProposta(
              proposta: p,
              hoje: _hoje,
              aoTocar: () => _abrir(p),
            ),
            const SizedBox(height: Espaco.s2),
          ],
        ],
      ),
    );
  }
}

class _CartaoDaProposta extends StatelessWidget {
  const _CartaoDaProposta({
    required this.proposta,
    required this.hoje,
    required this.aoTocar,
  });

  final PropostaComercial proposta;
  final DateTime hoje;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = proposta;
    final vencida = p.vencida(hoje);
    return Painel(
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nº ${p.numero} · ${p.titulo}', style: t.titleSmall),
                    Text(
                      p.cliente,
                      style: t.bodySmall?.copyWith(
                        color: context.cores.textoSuave,
                      ),
                    ),
                    const SizedBox(height: Espaco.s1),
                    Text(
                      brl.format(p.total),
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: numerosTabulares,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espaco.s2),
              Selo(
                vencida ? 'Vencida' : p.situacao.rotulo,
                tom: vencida
                    ? TomSelo.erro
                    : switch (p.situacao) {
                        SituacaoComercial.rascunho => TomSelo.neutro,
                        SituacaoComercial.enviada => TomSelo.info,
                        SituacaoComercial.aceita => TomSelo.sucesso,
                        SituacaoComercial.recusada => TomSelo.aviso,
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaItem {
  _LinhaItem([ItemComercial? i])
    : descricao = TextEditingController(text: i?.descricao),
      valor = TextEditingController(
        text: i == null ? '' : formatarQuantidade(i.valor),
      );

  final TextEditingController descricao;
  final TextEditingController valor;

  void dispose() {
    descricao.dispose();
    valor.dispose();
  }
}

class _LinhaParcela {
  _LinhaParcela([ParcelaComercial? p])
    : descricao = TextEditingController(text: p?.descricao),
      percentual = TextEditingController(
        text: p == null ? '' : formatarQuantidade(p.percentual),
      ),
      dias = TextEditingController(text: p == null ? '' : '${p.dias}');

  final TextEditingController descricao;
  final TextEditingController percentual;
  final TextEditingController dias;

  void dispose() {
    descricao.dispose();
    percentual.dispose();
    dias.dispose();
  }
}

/// Monta, gera e acompanha uma proposta. Depois de virar obra, ela só pode ser consultada.
class PropostaComercialScreen extends StatefulWidget {
  const PropostaComercialScreen({
    super.key,
    this.proposta,
    this.hoje,
    this.enviarPdf,
    this.criarObra,
  });
  final PropostaComercial? proposta;
  final DateTime? hoje;
  final Future<void> Function(PropostaComercial proposta)? enviarPdf;
  final Future<String?> Function(PropostaComercial proposta)? criarObra;

  @override
  State<PropostaComercialScreen> createState() =>
      _PropostaComercialScreenState();
}

class _PropostaComercialScreenState extends State<PropostaComercialScreen> {
  late PropostaComercial? _base = widget.proposta;
  late final DateTime _hoje = widget.hoje ?? DateTime.now();
  late final _cliente = TextEditingController(text: _base?.cliente);
  late final _contato = TextEditingController(text: _base?.contato);
  late final _titulo = TextEditingController(text: _base?.titulo);
  late final _endereco = TextEditingController(text: _base?.endereco);
  late final _cidade = TextEditingController(text: _base?.cidade);
  late final _area = TextEditingController(
    text: _base?.area == null ? '' : formatarQuantidade(_base!.area!),
  );
  late final _desconto = TextEditingController(
    text: (_base?.desconto ?? 0) == 0
        ? ''
        : formatarQuantidade(_base!.desconto),
  );
  late final _prazo = TextEditingController(
    text: _base?.prazoDias == null ? '' : '${_base!.prazoDias}',
  );
  late final _inclui = TextEditingController(text: _base?.inclui);
  late final _naoInclui = TextEditingController(text: _base?.naoInclui);
  late final _observacoes = TextEditingController(text: _base?.observacoes);
  late String? _uf = ufs.contains(_base?.uf) ? _base!.uf : null;
  late Padrao _padrao = _base?.padrao ?? Padrao.medio;
  late bool _mostrarValores = _base?.mostrarValores ?? true;
  late SituacaoComercial _situacao =
      _base?.situacao ?? SituacaoComercial.rascunho;
  late DateTime? _validade = widget.proposta == null
      ? DateTime(_hoje.year, _hoje.month, _hoje.day + _diasDeValidade)
      : _base?.validade;
  late final List<_LinhaItem> _itens = [
    for (final i in _base?.itens ?? const <ItemComercial>[]) _LinhaItem(i),
  ];
  late final List<_LinhaParcela> _parcelas = [
    for (final p in _base?.parcelas ?? const <ParcelaComercial>[])
      _LinhaParcela(p),
  ];
  String? _erroCliente;
  String? _erroTitulo;
  bool _ocupado = false;

  bool get _travada => _base?.obraId != null;

  @override
  void dispose() {
    for (final c in [
      _cliente,
      _contato,
      _titulo,
      _endereco,
      _cidade,
      _area,
      _desconto,
      _prazo,
      _inclui,
      _naoInclui,
      _observacoes,
    ]) {
      c.dispose();
    }
    for (final i in _itens) {
      i.dispose();
    }
    for (final p in _parcelas) {
      p.dispose();
    }
    super.dispose();
  }

  double? _numero(String texto) {
    final n = lerNumero(texto);
    return n.isNaN || n < 0 ? null : n;
  }

  /// Valores que não dão para ler viram zero aqui; quem salva confere com [_confereValores].
  PropostaComercial _montar() => PropostaComercial(
    id: _base?.id,
    numero: _base?.numero,
    cliente: _cliente.text.trim(),
    contato: _contato.text.trim(),
    titulo: _titulo.text.trim(),
    endereco: _endereco.text.trim(),
    cidade: _cidade.text.trim(),
    uf: _uf ?? '',
    area: _numero(_area.text),
    padrao: _padrao,
    itens: [
      for (final i in _itens)
        if (i.descricao.text.trim().isNotEmpty)
          ItemComercial(
            descricao: i.descricao.text.trim(),
            valor: _numero(i.valor.text) ?? 0,
          ),
    ],
    desconto: _numero(_desconto.text) ?? 0,
    mostrarValores: _mostrarValores,
    parcelas: [
      for (final p in _parcelas)
        if (p.descricao.text.trim().isNotEmpty)
          ParcelaComercial(
            descricao: p.descricao.text.trim(),
            percentual: _numero(p.percentual.text) ?? 0,
            dias: int.tryParse(p.dias.text.trim()) ?? 0,
          ),
    ],
    inclui: _inclui.text.trim(),
    naoInclui: _naoInclui.text.trim(),
    prazoDias: int.tryParse(_prazo.text.trim()),
    validade: _validade,
    observacoes: _observacoes.text.trim(),
    situacao: _situacao,
    obraId: _base?.obraId,
  );

  /// Valor digitado errado não pode virar zero sem aviso: é preço para o cliente.
  bool _confereValores() {
    bool ruim(String t) => t.trim().isNotEmpty && _numero(t) == null;
    final erro =
        ruim(_area.text) ||
        ruim(_desconto.text) ||
        _itens.any((i) => ruim(i.valor.text)) ||
        _parcelas.any((p) => ruim(p.percentual.text));
    if (erro) {
      avisar(context, 'Confira os valores digitados.');
      return false;
    }
    final semNome =
        _itens.any(
          (i) =>
              i.descricao.text.trim().isEmpty && i.valor.text.trim().isNotEmpty,
        ) ||
        _parcelas.any(
          (p) =>
              p.descricao.text.trim().isEmpty &&
              p.percentual.text.trim().isNotEmpty,
        );
    if (semNome) avisar(context, 'Dê um nome a cada item.');
    return !semNome;
  }

  Future<PropostaComercial?> _gravar() async {
    final p = _montar();
    setState(() {
      _erroCliente = p.cliente.isEmpty ? 'Diga quem é o cliente.' : null;
      _erroTitulo = p.titulo.isEmpty
          ? 'Diga o nome da obra ou do serviço.'
          : null;
    });
    if (p.cliente.isEmpty || p.titulo.isEmpty || !_confereValores()) {
      return null;
    }
    setState(() => _ocupado = true);
    try {
      final salva = await PropostasComerciaisService.instance.salvar(p);
      if (mounted) setState(() => _base = salva);
      return salva;
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
      return null;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _salvar() async {
    final salva = await _gravar();
    if (salva != null && mounted) Navigator.pop(context);
  }

  Future<void> _gerarPdf() async {
    final atual = _montar();
    final falta = atual.faltaParaGerar;
    if (falta != null) {
      avisar(context, falta);
      return;
    }
    final salva = _travada ? _base : await _gravar();
    if (salva == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await (widget.enviarPdf ?? _enviarPdf)(salva);
    } catch (_) {
      if (mounted) {
        avisar(context, 'Não foi possível gerar o PDF. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _enviarPdf(PropostaComercial p) async {
    final marcas = MarcaService.instance;
    var marca = const MarcaEngenheiro();
    try {
      marca = await marcas.minha();
    } on FalhaAoSalvar {
      // O PDF sai com o nome do perfil
    }
    if (marca.nome.trim().isEmpty) {
      final perfil = PerfilService.instance;
      final empresa = perfil.empresa.trim();
      marca = MarcaEngenheiro(
        nome: empresa.isNotEmpty ? empresa : perfil.nome,
        registro: marca.registro,
        telefone: marca.telefone,
        email: marca.email,
        logoPath: marca.logoPath,
      );
    }
    final bytes = await pdfDaProposta(
      proposta: p,
      hoje: _hoje,
      marca: marca,
      logo: await marcas.logoBytes(marca.logoPath),
    );
    await compartilharPdf(
      bytes,
      nomeDaProposta(p),
      titulo: 'Proposta comercial',
      texto: mensagemDaProposta(p),
    );
  }

  Future<void> _usarEstimativa() async {
    final calculo = Calculo.de(
      ParametrosObra(area: _area.text.trim(), padrao: _padrao),
    );
    final resultado = calculo.resultado;
    if (resultado == null) {
      avisar(context, calculo.erro ?? 'Digite a área da obra.');
      return;
    }
    final acrescimo = await showDialog<double>(
      context: context,
      builder: (_) => _JanelaEstimativa(trocaItens: _itens.isNotEmpty),
    );
    if (acrescimo == null || !mounted) return;
    setState(() {
      for (final i in _itens) {
        i.dispose();
      }
      _itens
        ..clear()
        ..addAll([
          for (final i in itensDaEstimativa(resultado, acrescimo: acrescimo))
            _LinhaItem(i),
        ]);
    });
  }

  Future<String?> _cadastrarObra(PropostaComercial p) => Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => ObraFormScreen(
        dadosIniciais: p.dadosDaObra,
        parametrosIniciais: p.parametrosDaObra,
      ),
    ),
  );

  Future<void> _criarObra() async {
    final salva = await _gravar();
    if (salva == null || !mounted) return;
    final obraId = await (widget.criarObra ?? _cadastrarObra)(salva);
    if (obraId == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await PropostasComerciaisService.instance.virarObra(
        salva.id!,
        obraId,
        _hoje,
      );
      if (!mounted) return;
      setState(() {
        _base = PropostaComercial(
          id: salva.id,
          numero: salva.numero,
          cliente: salva.cliente,
          contato: salva.contato,
          titulo: salva.titulo,
          endereco: salva.endereco,
          cidade: salva.cidade,
          uf: salva.uf,
          area: salva.area,
          padrao: salva.padrao,
          itens: salva.itens,
          desconto: salva.desconto,
          mostrarValores: salva.mostrarValores,
          parcelas: salva.parcelas,
          inclui: salva.inclui,
          naoInclui: salva.naoInclui,
          prazoDias: salva.prazoDias,
          validade: salva.validade,
          observacoes: salva.observacoes,
          situacao: salva.situacao,
          obraId: obraId,
        );
      });
      avisar(
        context,
        salva.parcelas.isEmpty
            ? 'Obra criada.'
            : 'Obra criada. As parcelas estão no caixa da obra.',
      );
    } on FalhaAoSalvar catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir esta proposta?'),
        content: const Text('Não dá para desfazer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.cores.erro),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await PropostasComerciaisService.instance.excluir(_base!.id!);
      if (mounted) Navigator.pop(context);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final numero = _base?.numero;
    return Scaffold(
      appBar: AppBar(
        title: Text(numero == null ? 'Nova proposta' : 'Proposta nº $numero'),
        actions: [
          if (_base?.id != null)
            IconButton(
              tooltip: 'Excluir proposta',
              onPressed: _ocupado ? null : _excluir,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_travada) ...[
              const Aviso(
                'Esta proposta virou obra e não muda mais.',
                tom: TomSelo.info,
              ),
              const SizedBox(height: Espaco.s2),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ObraScreen(id: _base!.obraId!),
                  ),
                ),
                child: const Text('Abrir a obra'),
              ),
              const SizedBox(height: Espaco.s4),
            ],
            if (_situacao == SituacaoComercial.aceita && !_travada) ...[
              FilledButton.icon(
                onPressed: _ocupado ? null : _criarObra,
                icon: const Icon(Icons.home_work_outlined),
                label: const Text('Criar a obra'),
              ),
              const SizedBox(height: Espaco.s4),
            ],
            IgnorePointer(ignoring: _travada, child: _formulario()),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s2,
            Espaco.s4,
            Espaco.s3,
          ),
          child: Row(
            children: [
              if (!_travada) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _ocupado ? null : _salvar,
                    child: const Text('Salvar'),
                  ),
                ),
                const SizedBox(width: Espaco.s2),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: _ocupado ? null : _gerarPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Gerar PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulario() {
    final t = Theme.of(context).textTheme;
    final atual = _montar();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_base?.id != null) ...[
          const Rotulo('Situação'),
          DropdownButtonFormField<SituacaoComercial>(
            initialValue: _situacao,
            isExpanded: true,
            style: t.bodyLarge,
            items: [
              for (final s in SituacaoComercial.values)
                DropdownMenuItem(value: s, child: Text(s.rotulo)),
            ],
            onChanged: (v) => setState(() => _situacao = v ?? _situacao),
          ),
          const SizedBox(height: Espaco.s4),
        ],
        Painel(
          titulo: 'Cliente',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoTexto(
                  rotulo: 'Nome do cliente',
                  controller: _cliente,
                  obrigatorio: true,
                  erro: _erroCliente,
                  maxLength: 160,
                ),
                const SizedBox(height: Espaco.s3),
                CampoTexto(
                  rotulo: 'Telefone ou e-mail',
                  controller: _contato,
                  maxLength: 120,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.s4),
        Painel(
          titulo: 'Obra',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoTexto(
                  rotulo: 'Nome da obra ou do serviço',
                  controller: _titulo,
                  obrigatorio: true,
                  dica: 'Ex.: Residência Silva',
                  erro: _erroTitulo,
                  maxLength: 160,
                ),
                const SizedBox(height: Espaco.s3),
                CampoTexto(
                  rotulo: 'Endereço',
                  controller: _endereco,
                  maxLength: 300,
                ),
                const SizedBox(height: Espaco.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: CampoTexto(
                        rotulo: 'Cidade',
                        controller: _cidade,
                        maxLength: 120,
                      ),
                    ),
                    const SizedBox(width: Espaco.s2),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Rotulo('UF'),
                          DropdownButtonFormField<String?>(
                            initialValue: _uf,
                            isExpanded: true,
                            style: t.bodyLarge,
                            items: [
                              const DropdownMenuItem(child: Text('-')),
                              for (final u in ufs)
                                DropdownMenuItem(value: u, child: Text(u)),
                            ],
                            onChanged: (v) => setState(() => _uf = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espaco.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CampoTexto(
                        rotulo: 'Área (m²)',
                        controller: _area,
                        teclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        maxLength: 10,
                      ),
                    ),
                    const SizedBox(width: Espaco.s2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Rotulo('Padrão'),
                          DropdownButtonFormField<Padrao>(
                            initialValue: _padrao,
                            isExpanded: true,
                            style: t.bodyLarge,
                            items: [
                              for (final p in Padrao.values)
                                DropdownMenuItem(
                                  value: p,
                                  child: Text(p.rotulo),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _padrao = v ?? _padrao),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.s4),
        Painel(
          titulo: 'Serviços e valores',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : _usarEstimativa,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Usar a estimativa do app'),
                ),
                const SizedBox(height: Espaco.s3),
                for (final (i, item) in _itens.indexed) ...[
                  CampoTexto(
                    rotulo: 'Item ${i + 1}',
                    controller: item.descricao,
                    maxLength: 200,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Espaco.s2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoTexto(
                          rotulo: 'Valor ${i + 1}',
                          controller: item.valor,
                          teclado: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          maxLength: 16,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tirar o item ${i + 1}',
                        onPressed: () => setState(() {
                          _itens.removeAt(i).dispose();
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: Espaco.s3),
                ],
                TextButton.icon(
                  onPressed: () => setState(() => _itens.add(_LinhaItem())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar item'),
                ),
                const SizedBox(height: Espaco.s2),
                CampoTexto(
                  rotulo: 'Desconto (R\$)',
                  controller: _desconto,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 16,
                  onChanged: (_) => setState(() {}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar o valor de cada item'),
                  subtitle: const Text('Desligado, o PDF mostra só o total'),
                  value: _mostrarValores,
                  onChanged: (v) => setState(() => _mostrarValores = v),
                ),
                const SizedBox(height: Espaco.s2),
                LinhaValor('Total', brl.format(atual.total), destaque: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.s4),
        Painel(
          titulo: 'Pagamento',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, p) in _parcelas.indexed) ...[
                  CampoTexto(
                    rotulo: 'Parcela ${i + 1}',
                    controller: p.descricao,
                    dica: 'Ex.: Na assinatura',
                    maxLength: 120,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Espaco.s2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoTexto(
                          rotulo: '% da parcela ${i + 1}',
                          controller: p.percentual,
                          teclado: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          maxLength: 6,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: Espaco.s2),
                      Expanded(
                        child: CampoTexto(
                          rotulo: 'Dias após o início',
                          controller: p.dias,
                          teclado: TextInputType.number,
                          maxLength: 4,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tirar a parcela ${i + 1}',
                        onPressed: () => setState(() {
                          _parcelas.removeAt(i).dispose();
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: Espaco.s3),
                ],
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _parcelas.add(_LinhaParcela())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar parcela'),
                ),
                if (atual.parcelas.isNotEmpty) ...[
                  const SizedBox(height: Espaco.s2),
                  LinhaValor(
                    'Soma das parcelas',
                    '${formatarQuantidade(atual.somaDasParcelas)}%',
                    cor: atual.parcelasFecham ? null : context.cores.erro,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.s4),
        Painel(
          titulo: 'Condições',
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoTexto(
                  rotulo: 'Prazo de execução (dias)',
                  controller: _prazo,
                  teclado: TextInputType.number,
                  maxLength: 4,
                ),
                const SizedBox(height: Espaco.s3),
                CampoData(
                  rotulo: 'Válida até',
                  valor: _validade,
                  aoMudar: (d) => setState(() => _validade = d),
                ),
                const SizedBox(height: Espaco.s3),
                const Rotulo('O que está incluso'),
                TextField(
                  key: const Key('inclui'),
                  controller: _inclui,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Espaco.s3),
                const Rotulo('O que não está incluso'),
                TextField(
                  key: const Key('nao_inclui'),
                  controller: _naoInclui,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Espaco.s3),
                const Rotulo('Observações'),
                TextField(
                  key: const Key('observacoes'),
                  controller: _observacoes,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pergunta o acréscimo sobre a estimativa. Devolve o percentual.
class _JanelaEstimativa extends StatefulWidget {
  const _JanelaEstimativa({required this.trocaItens});
  final bool trocaItens;

  @override
  State<_JanelaEstimativa> createState() => _JanelaEstimativaState();
}

class _JanelaEstimativaState extends State<_JanelaEstimativa> {
  final _acrescimo = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _acrescimo.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _acrescimo.text.trim();
    final v = texto.isEmpty ? 0.0 : lerNumero(texto);
    if (v.isNaN || v < 0) {
      setState(() => _erro = 'Digite um percentual válido.');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Usar a estimativa'),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.trocaItens
                  ? 'As etapas do orçamento do app entram no lugar dos itens atuais. Confira os valores antes de enviar.'
                  : 'As etapas do orçamento do app viram os itens da proposta. Confira os valores antes de enviar.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Acréscimo sobre a estimativa (%)',
              controller: _acrescimo,
              ajuda: 'Sua margem e seus honorários',
              teclado: const TextInputType.numberWithOptions(decimal: true),
              erro: _erro,
              maxLength: 6,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: const Text('Usar')),
      ],
    );
  }
}

/// Entrada na lista de obras: a proposta vem antes da obra existir.
class EntradaDasPropostas extends StatelessWidget {
  const EntradaDasPropostas({super.key});

  @override
  Widget build(BuildContext context) => EntradaDaObra(
    icone: Icons.request_quote_outlined,
    titulo: 'Propostas comerciais',
    detalhe: 'Proposta em PDF com a sua marca',
    aoTocar: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PropostasComerciaisScreen()),
    ),
  );
}
