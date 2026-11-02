import 'package:flutter/material.dart';

import '../obras/obra.dart';
import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import '../tema/tema.dart';
import '../tema/cores.dart';
import 'ui.dart';

/// Campos do orçamento (área, padrão, estrutura, cobertura, adicionais).
/// Os campos de texto guardam o que foi digitado; [onChanged] recebe os parâmetros a cada alteração.
class ParametrosForm extends StatefulWidget {
  const ParametrosForm({super.key, required this.inicial, required this.onChanged, this.erroArea});
  final ParametrosObra inicial;
  final ValueChanged<ParametrosObra> onChanged;
  final String? erroArea;

  @override
  State<ParametrosForm> createState() => _ParametrosFormState();
}

class _ParametrosFormState extends State<ParametrosForm> {
  late ParametrosObra _p = widget.inicial;
  late final _area = TextEditingController(text: _p.area);
  late final _areaSuperior = TextEditingController(text: _p.areaSuperior);
  late final _muroFrente = TextEditingController(text: _p.muroFrente);
  late final _muroTerreno = TextEditingController(text: _p.muroTerreno);
  late final _piscinaComp = TextEditingController(text: _p.piscinaComprimento);
  late final _piscinaLarg = TextEditingController(text: _p.piscinaLargura);

  // Custo das etapas por m² de cada padrão, com a estrutura e a cobertura escolhidas (térrea, sem adicionais)
  Map<Padrao, double>? _custos;
  (bool, TipoCobertura, int)? _chaveCustos;

  Map<Padrao, double> _custosPorPadrao() {
    final chave = (_p.laje, _p.cobertura, _p.aguas);
    if (_custos == null || chave != _chaveCustos) {
      _chaveCustos = chave;
      _custos = {
        for (final padrao in Padrao.values)
          padrao: calcularOrcamento(EntradaOrcamento(areaConstruida: 100, padrao: padrao, laje: _p.laje, cobertura: _p.cobertura, aguas: _p.aguas))
                  .totalEtapas /
              100,
      };
    }
    return _custos!;
  }

  @override
  void dispose() {
    for (final c in [_area, _areaSuperior, _muroFrente, _muroTerreno, _piscinaComp, _piscinaLarg]) {
      c.dispose();
    }
    super.dispose();
  }

  void _mudar(ParametrosObra p) {
    setState(() => _p = p);
    widget.onChanged(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final custos = _custosPorPadrao();
    const decimal = TextInputType.numberWithOptions(decimal: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoTexto(
          rotulo: 'Área construída (m²)',
          obrigatorio: true,
          controller: _area,
          teclado: decimal,
          dica: 'Ex.: 150',
          ajuda: 'Inclua varandas, garagem e pisos superiores.',
          erro: widget.erroArea,
          onChanged: (v) => _mudar(_p.copyWith(area: v)),
        ),
        const SizedBox(height: Espaco.s5),
        const Rotulo('Padrão de acabamento'),
        // Duas linhas de duas opções; a altura acompanha o texto (fonte do sistema aumentada não estoura)
        for (final par in [
          [Padrao.economico, Padrao.medio],
          [Padrao.mediaAlta, Padrao.alto],
        ]) ...[
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final padrao in par) ...[
                if (padrao != par.first) const SizedBox(width: Espaco.s2),
                Expanded(
                  child: _OpcaoPadrao(
                    padrao: padrao,
                    custoM2: custos[padrao]!,
                    escolhido: _p.padrao == padrao,
                    onTap: () => _mudar(_p.copyWith(padrao: padrao)),
                  ),
                ),
              ],
            ]),
          ),
          if (par.first == Padrao.economico) const SizedBox(height: Espaco.s2),
        ],
        const SizedBox(height: Espaco.s5),
        const Rotulo('Estrutura'),
        Segmentado<bool>(
          valor: _p.laje,
          opcoes: const [(true, 'Com laje'), (false, 'Sem laje')],
          onChanged: (v) => _mudar(_p.copyWith(laje: v)),
        ),
        const SizedBox(height: Espaco.s3),
        _Caixa(
          rotulo: 'Sobrado (tem piso superior)',
          marcado: _p.sobrado,
          onChanged: (v) => _mudar(_p.copyWith(sobrado: v)),
        ),
        if (_p.sobrado) ...[
          const SizedBox(height: Espaco.s2),
          CampoTexto(
            rotulo: 'Área dos pisos superiores (m²)',
            controller: _areaSuperior,
            teclado: decimal,
            onChanged: (v) => _mudar(_p.copyWith(areaSuperior: v)),
          ),
        ],
        const SizedBox(height: Espaco.s5),
        const Rotulo('Cobertura'),
        Segmentado<TipoCobertura>(
          valor: _p.cobertura,
          opcoes: const [(TipoCobertura.platibanda, 'Platibanda'), (TipoCobertura.telhadoAparente, 'Telhado aparente')],
          onChanged: (v) => _mudar(_p.copyWith(cobertura: v)),
        ),
        if (_p.cobertura == TipoCobertura.telhadoAparente) ...[
          const SizedBox(height: Espaco.s3),
          const Rotulo('Águas do telhado'),
          Segmentado<int>(
            valor: _p.aguas,
            opcoes: const [(1, '1 água'), (2, '2 águas'), (3, '3 ou mais')],
            onChanged: (v) => _mudar(_p.copyWith(aguas: v)),
          ),
        ],
        const SizedBox(height: Espaco.s5),
        const Divider(),
        const SizedBox(height: Espaco.s3),
        Text('Adicionais', style: t.titleSmall),
        const SizedBox(height: Espaco.s1),
        _Caixa(rotulo: 'Muro (2,5 m de altura)', marcado: _p.muroAtivo, onChanged: (v) => _mudar(_p.copyWith(muroAtivo: v))),
        if (_p.muroAtivo)
          _Recuo(children: [
            Row(children: [
              Expanded(child: CampoTexto(rotulo: 'Frente (m)', controller: _muroFrente, teclado: decimal, onChanged: (v) => _mudar(_p.copyWith(muroFrente: v)))),
              const SizedBox(width: Espaco.s3),
              Expanded(child: CampoTexto(rotulo: 'Terreno (m²)', controller: _muroTerreno, teclado: decimal, onChanged: (v) => _mudar(_p.copyWith(muroTerreno: v)))),
            ]),
            const SizedBox(height: Espaco.s3),
            _Escolha<AcabamentoMuro>(
              rotulo: 'Acabamento',
              valor: _p.muroAcabamento,
              opcoes: {for (final a in AcabamentoMuro.values) a: a.rotulo},
              onChanged: (v) => _mudar(_p.copyWith(muroAcabamento: v)),
            ),
          ]),
        _Caixa(rotulo: 'Piscina', marcado: _p.piscinaAtiva, onChanged: (v) => _mudar(_p.copyWith(piscinaAtiva: v))),
        if (_p.piscinaAtiva)
          _Recuo(children: [
            Row(children: [
              Expanded(child: CampoTexto(rotulo: 'Comprimento (m)', controller: _piscinaComp, teclado: decimal, onChanged: (v) => _mudar(_p.copyWith(piscinaComprimento: v)))),
              const SizedBox(width: Espaco.s3),
              Expanded(child: CampoTexto(rotulo: 'Largura (m)', controller: _piscinaLarg, teclado: decimal, onChanged: (v) => _mudar(_p.copyWith(piscinaLargura: v)))),
            ]),
            const SizedBox(height: Espaco.s3),
            _Escolha<TipoPiscina>(
              rotulo: 'Tipo',
              valor: _p.piscinaTipo,
              opcoes: {for (final a in TipoPiscina.values) a: a.rotulo},
              onChanged: (v) => _mudar(_p.copyWith(piscinaTipo: v)),
            ),
          ]),
        _Caixa(rotulo: 'Área gourmet', marcado: _p.gourmetAtivo, onChanged: (v) => _mudar(_p.copyWith(gourmetAtivo: v))),
        if (_p.gourmetAtivo)
          _Recuo(children: [
            _Escolha<TipoGourmet>(
              rotulo: 'Tipo de área gourmet',
              valor: _p.gourmetTipo,
              opcoes: {for (final a in TipoGourmet.values) a: a.rotulo},
              onChanged: (v) => _mudar(_p.copyWith(gourmetTipo: v)),
            ),
          ]),
        _Caixa(rotulo: 'Jardim', marcado: _p.jardimAtivo, onChanged: (v) => _mudar(_p.copyWith(jardimAtivo: v))),
        if (_p.jardimAtivo)
          _Recuo(children: [
            _Escolha<TipoJardim>(
              rotulo: 'Tipo de jardim',
              valor: _p.jardimTipo,
              opcoes: {for (final a in TipoJardim.values) a: a.rotulo},
              onChanged: (v) => _mudar(_p.copyWith(jardimTipo: v)),
            ),
          ]),
      ],
    );
  }
}

class _OpcaoPadrao extends StatelessWidget {
  const _OpcaoPadrao({required this.padrao, required this.custoM2, required this.escolhido, required this.onTap});
  final Padrao padrao;
  final double custoM2;
  final bool escolhido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      selected: escolhido,
      button: true,
      child: Material(
        color: escolhido ? context.cores.acao.withValues(alpha: 0.06) : context.cores.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Raio.sm),
          side: BorderSide(color: escolhido ? context.cores.acao : context.cores.borda, width: escolhido ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Raio.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espaco.s3, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(padrao.rotulo, style: t.labelLarge?.copyWith(color: escolhido ? context.cores.acao : context.cores.texto)),
                Text('${brlInteiro.format(custoM2)}/m²', style: t.bodySmall?.copyWith(fontFeatures: numerosTabulares)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Caixa extends StatelessWidget {
  const _Caixa({required this.rotulo, required this.marcado, required this.onChanged});
  final String rotulo;
  final bool marcado;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!marcado),
      borderRadius: BorderRadius.circular(Raio.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Checkbox(value: marcado, onChanged: (v) => onChanged(v ?? false)),
          Expanded(child: Text(rotulo, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500))),
        ]),
      ),
    );
  }
}

class _Recuo extends StatelessWidget {
  const _Recuo({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Espaco.s10, 0, 0, Espaco.s3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _Escolha<T> extends StatelessWidget {
  const _Escolha({required this.rotulo, required this.valor, required this.opcoes, required this.onChanged});
  final String rotulo;
  final T valor;
  final Map<T, String> opcoes;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Rotulo(rotulo),
      DropdownButtonFormField<T>(
        initialValue: valor,
        isExpanded: true,
        items: [for (final e in opcoes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ]);
  }
}
