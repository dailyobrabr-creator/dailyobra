import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/diario_service.dart';
import '../services/obras_service.dart';
import 'dia_obra_screen.dart';

/// Histórico: todos os dias registrados na obra, do mais novo para o mais antigo.
class DiarioScreen extends StatefulWidget {
  const DiarioScreen({super.key, required this.obra});
  final Obra obra;

  @override
  State<DiarioScreen> createState() => _DiarioScreenState();
}

class _DiarioScreenState extends State<DiarioScreen> {
  List<DiaObra>? _dias;
  String? _erro;

  bool get _registra => widget.obra.funcao.registra;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dias = await DiarioService.instance.listar(widget.obra.id);
      if (mounted) {
        setState(() {
          _dias = dias;
          _erro = null;
        });
      }
    } on FalhaAoSalvar catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _abrir(DateTime data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaObraScreen(obra: widget.obra, data: data),
      ),
    );
    await _carregar();
  }

  Future<void> _novoDia() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: hoje,
      firstDate: DateTime(hoje.year - 5),
      lastDate: hoje,
      helpText: 'Qual dia vai registrar?',
    );
    if (data != null) await _abrir(data);
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    return Scaffold(
      appBar: AppBar(title: const Text('Diário de obra')),
      floatingActionButton: _registra && dias != null
          ? FloatingActionButton.extended(
              onPressed: _novoDia,
              icon: const Icon(Icons.add),
              label: const Text('Novo dia'),
            )
          : null,
      body: _erro != null
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
          : dias == null
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : dias.isEmpty
          ? _vazio()
          : RefreshIndicator(
              color: context.cores.acao,
              onRefresh: _carregar,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s4,
                  Espaco.s4,
                  Espaco.s10 * 2,
                ),
                itemCount: dias.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: Espaco.s2),
                  child: _CartaoDoDia(
                    dia: dias[i],
                    aoTocar: () => _abrir(dias[i].data),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _vazio() {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nenhum dia registrado', style: t.titleMedium),
            const SizedBox(height: Espaco.s2),
            Text(
              _registra
                  ? 'Registre o clima, a equipe e o que foi feito. Vira o histórico da obra, pronto para virar PDF.'
                  : 'Quando a equipe registrar os dias, eles aparecem aqui.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoDoDia extends StatelessWidget {
  const _CartaoDoDia({required this.dia, required this.aoTocar});
  final DiaObra dia;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
                    Text(diaPorExtenso(dia.data), style: t.titleSmall),
                    const SizedBox(height: Espaco.s1),
                    Text(
                      dia.resumo,
                      style: t.bodyMedium?.copyWith(
                        color: context.cores.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espaco.s2),
              SeloDoDia(dia),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrada do diário na tela da obra: mostra como está o dia de hoje e leva para o histórico.
class EntradaDoDiario extends StatefulWidget {
  const EntradaDoDiario({super.key, required this.obra});
  final Obra obra;

  @override
  State<EntradaDoDiario> createState() => _EntradaDoDiarioState();
}

class _EntradaDoDiarioState extends State<EntradaDoDiario> {
  List<DiaObra>? _dias;
  bool _falhou = false;

  bool get _registra => widget.obra.funcao.registra;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dias = await DiarioService.instance.listar(widget.obra.id);
      if (mounted) {
        setState(() {
          _dias = dias;
          _falhou = false;
        });
      }
    } on FalhaAoSalvar {
      if (mounted) setState(() => _falhou = true);
    }
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    await _carregar();
  }

  String _situacaoDeHoje(DiaObra? hoje) {
    if (hoje == null) return 'Hoje ainda não foi preenchido.';
    return hoje.fechado ? 'Hoje já foi finalizado.' : 'Hoje está em rascunho.';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suave = t.bodyMedium?.copyWith(color: context.cores.textoSuave);
    final dias = _dias;
    final agora = DateTime.now();
    final hoje = dias?.where((d) => mesmoDia(d.data, agora)).firstOrNull;
    final ultimo = dias?.firstOrNull;
    return Painel(
      titulo: 'Diário de obra',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_falhou) ...[
              Text('Não foi possível carregar o diário.', style: suave),
              const SizedBox(height: Espaco.s2),
              OutlinedButton(
                onPressed: _carregar,
                child: const Text('Tentar de novo'),
              ),
            ] else if (dias == null)
              const Esqueleto(altura: 44)
            else ...[
              if (_registra)
                Text(_situacaoDeHoje(hoje), style: t.bodyLarge)
              else if (dias.isEmpty)
                Text('Nenhum dia registrado ainda.', style: suave),
              if (ultimo != null)
                Padding(
                  padding: const EdgeInsets.only(top: Espaco.s1),
                  child: Text(
                    'Último: ${dataCurta(ultimo.data)} · ${ultimo.resumo}',
                    style: suave,
                  ),
                ),
              if (_registra) ...[
                const SizedBox(height: Espaco.s3),
                FilledButton(
                  onPressed: () =>
                      _abrir(DiaObraScreen(obra: widget.obra, data: agora)),
                  child: Text(
                    hoje == null
                        ? 'Preencher hoje'
                        : hoje.fechado
                        ? 'Ver hoje'
                        : 'Continuar hoje',
                  ),
                ),
              ],
              if (dias.isNotEmpty) ...[
                const SizedBox(height: Espaco.s2),
                OutlinedButton(
                  onPressed: () => _abrir(DiarioScreen(obra: widget.obra)),
                  child: Text('Ver histórico (${dias.length})'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
