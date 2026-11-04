import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';

import '../services/obras_service.dart';

/// Cadastro (sem [obra]) ou edição (com [obra]) de obra. Ao cadastrar, devolve o id da obra criada.
class ObraFormScreen extends StatefulWidget {
  const ObraFormScreen({
    super.key,
    this.obra,
    this.parametrosIniciais,
    this.consultarCep = buscarCep,
  });
  final Obra? obra;

  /// Parâmetros trazidos do simulador
  final ParametrosObra? parametrosIniciais;

  /// Busca do CEP; o padrão é o ViaCEP.
  final BuscarCep consultarCep;

  @override
  State<ObraFormScreen> createState() => _ObraFormScreenState();
}

class _ObraFormScreenState extends State<ObraFormScreen> {
  late DadosObra _dados = widget.obra?.dados ?? const DadosObra();
  late ParametrosObra _parametros =
      widget.obra?.parametros ??
      widget.parametrosIniciais ??
      const ParametrosObra();
  late final _nome = TextEditingController(text: _dados.nome);
  late final _endereco = TextEditingController(text: _dados.endereco);
  late final _responsavel = TextEditingController(text: _dados.responsavel);
  bool _tentou = false;
  bool _salvando = false;
  String? _falha;
  final _rolagem = ScrollController();

  bool get _edicao => widget.obra != null;

  @override
  void dispose() {
    for (final c in [_nome, _endereco, _responsavel]) {
      c.dispose();
    }
    _rolagem.dispose();
    super.dispose();
  }

  /// Rua e bairro do CEP entram no endereço só se ele ainda estiver vazio.
  void _preencherEndereco(EnderecoCep e) {
    final rua = [e.logradouro, e.bairro].where((p) => p.isNotEmpty).join(' – ');
    if (rua.isEmpty || _endereco.text.trim().isNotEmpty) return;
    _endereco.text = rua;
    setState(() => _dados = _dados.copyWith(endereco: rua));
  }

  Future<void> _escolherData() async {
    final atual = DateTime.tryParse(_dados.inicioPrevisto);
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: atual ?? hoje,
      firstDate: DateTime(hoje.year - 5),
      lastDate: DateTime(hoje.year + 10),
      helpText: 'Início previsto',
    );
    if (d != null) {
      setState(
        () => _dados = _dados.copyWith(
          inicioPrevisto: DateFormat('yyyy-MM-dd').format(d),
        ),
      );
    }
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    final erros = validarDados(_dados);
    final calculo = Calculo.de(_parametros);
    setState(() {
      _tentou = true;
      _falha = null;
    });
    if (erros.isNotEmpty || calculo.erro != null) {
      // Os dados da obra ficam no topo e a área logo abaixo: subir mostra o primeiro problema
      _rolagem.animateTo(
        erros.isNotEmpty ? 0 : 420,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      if (_edicao) {
        await ObrasService.instance.atualizar(
          widget.obra!.id,
          _dados,
          _parametros,
        );
        if (mounted) Navigator.pop(context);
      } else {
        final id = await ObrasService.instance.criar(_dados, _parametros);
        if (mounted) Navigator.pop(context, id);
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _falha = e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final erros = _tentou ? validarDados(_dados) : const <String, String>{};
    final calculo = Calculo.de(_parametros);
    final data = DateTime.tryParse(_dados.inicioPrevisto);

    return Scaffold(
      appBar: AppBar(title: Text(_edicao ? 'Editar obra' : 'Nova obra')),
      body: ListView(
        controller: _rolagem,
        padding: const EdgeInsets.all(Espaco.s4),
        children: [
          Painel(
            titulo: 'Dados da obra',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CampoTexto(
                    rotulo: 'Nome da obra',
                    obrigatorio: true,
                    controller: _nome,
                    dica: 'Ex.: Residência Silva',
                    maxLength: 120,
                    erro: erros['nome'],
                    acao: TextInputAction.next,
                    onChanged: (v) =>
                        setState(() => _dados = _dados.copyWith(nome: v)),
                  ),
                  const SizedBox(height: Espaco.s4),
                  CampoRegiao(
                    obrigatorio: true,
                    cidade: _dados.cidade,
                    uf: _dados.uf,
                    erro: erros['cidade'] ?? erros['uf'],
                    consultarCep: widget.consultarCep,
                    onEscolher: (cidade, uf) => setState(
                      () => _dados = _dados.copyWith(cidade: cidade, uf: uf),
                    ),
                    onCep: _preencherEndereco,
                  ),
                  const SizedBox(height: Espaco.s4),
                  CampoTexto(
                    rotulo: 'Endereço',
                    controller: _endereco,
                    dica: 'Rua, número, bairro',
                    autofill: const [AutofillHints.fullStreetAddress],
                    onChanged: (v) =>
                        setState(() => _dados = _dados.copyWith(endereco: v)),
                  ),
                  const SizedBox(height: Espaco.s4),
                  CampoTexto(
                    rotulo: 'Responsável técnico',
                    controller: _responsavel,
                    onChanged: (v) => setState(
                      () => _dados = _dados.copyWith(responsavel: v),
                    ),
                  ),
                  const SizedBox(height: Espaco.s4),
                  const Rotulo('Início previsto'),
                  OutlinedButton(
                    onPressed: _escolherData,
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Espaco.s3,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data == null
                                ? 'Escolher data'
                                : DateFormat(
                                    "d 'de' MMMM 'de' y",
                                    'pt_BR',
                                  ).format(data),
                            style: t.bodyLarge?.copyWith(
                              color: data == null
                                  ? context.cores.textoSuave
                                  : context.cores.texto,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: context.cores.textoSuave,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Espaco.s4),
          Painel(
            titulo: 'Parâmetros do orçamento',
            child: Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: ParametrosForm(
                inicial: _parametros,
                erroArea: _tentou && calculo.erro != null ? calculo.erro : null,
                onChanged: (p) => setState(() => _parametros = p),
              ),
            ),
          ),
          const SizedBox(height: Espaco.s6),
        ],
      ),
      bottomNavigationBar: _RodapeSalvar(
        calculo: calculo,
        tentou: _tentou,
        falha: _falha,
        salvando: _salvando,
        rotulo: _edicao ? 'Salvar' : 'Cadastrar',
        onSalvar: _salvar,
      ),
    );
  }
}

class _RodapeSalvar extends StatelessWidget {
  const _RodapeSalvar({
    required this.calculo,
    required this.tentou,
    required this.falha,
    required this.salvando,
    required this.rotulo,
    required this.onSalvar,
  });
  final Calculo calculo;
  final bool tentou;
  final String? falha;
  final bool salvando;
  final String rotulo;
  final VoidCallback onSalvar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: context.cores.superficie,
        border: Border(top: BorderSide(color: context.cores.borda)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s3,
            Espaco.s4,
            Espaco.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (falha != null) ...[
                Aviso(falha!),
                const SizedBox(height: Espaco.s3),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Estimativa', style: t.labelMedium),
                        calculo.resultado != null
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  brl.format(calculo.resultado!.total),
                                  style: t.titleLarge?.copyWith(
                                    fontFeatures: numerosTabulares,
                                  ),
                                ),
                              )
                            : Text(
                                calculo.erro ?? '',
                                style: t.bodySmall?.copyWith(
                                  color: tentou
                                      ? context.cores.erro
                                      : context.cores.textoSuave,
                                ),
                                maxLines: 2,
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Espaco.s3),
                  FilledButton(
                    onPressed: salvando ? null : onSalvar,
                    child: salvando
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.cores.textoSobreAcao,
                            ),
                          )
                        : Text(rotulo),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
