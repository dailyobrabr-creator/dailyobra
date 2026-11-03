import 'dart:math' as math;

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

const _curtos = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _nomes = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

/// Horários que a loja escolhe: de 15 em 15 minutos, de 00:00 a 23:45.
const _passo = 15;
final _horarios = [for (var m = 0; m < 24 * 60; m += _passo) m];

String _hhmm(int minutos) =>
    '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}';

/// Um dia do horário: fechado, ou aberto de [abre] a [fecha], com o intervalo de [saida] a [volta] quando há.
class HorarioDia {
  const HorarioDia({
    this.aberto = false,
    this.abre = 8 * 60,
    this.fecha = 18 * 60,
    this.intervalo = false,
    this.saida = 12 * 60,
    this.volta = 13 * 60,
  });
  final bool aberto;
  final int abre;
  final int fecha;
  final bool intervalo;
  final int saida;
  final int volta;

  HorarioDia copyWith({
    bool? aberto,
    int? abre,
    int? fecha,
    bool? intervalo,
    int? saida,
    int? volta,
  }) => HorarioDia(
    aberto: aberto ?? this.aberto,
    abre: abre ?? this.abre,
    fecha: fecha ?? this.fecha,
    intervalo: intervalo ?? this.intervalo,
    saida: saida ?? this.saida,
    volta: volta ?? this.volta,
  );

  List<FaixaHorario> faixas(int dia) => [
    if (aberto && !intervalo) FaixaHorario(dia, abre, fecha),
    if (aberto && intervalo) ...[
      FaixaHorario(dia, abre, saida),
      FaixaHorario(dia, volta, fecha),
    ],
  ];

  bool get valido =>
      !aberto ||
      (intervalo
          ? abre < saida && saida < volta && volta < fecha
          : abre < fecha);
}

/// O horário da semana no editor; vira o texto que o app do construtor lê ([escreverHorario]).
class ControleHorario extends ChangeNotifier {
  ControleHorario._(this._dias, this.naoLido);

  /// Lê o horário salvo. O que não der para ler (ou dia com mais de 2 faixas, ou hora fora da lista de 15 em 15)
  /// começa com todos os dias fechados e fica em [naoLido].
  factory ControleHorario.doTexto(String texto) {
    final fechados = List.filled(7, const HorarioDia());
    if (texto.trim().isEmpty) return ControleHorario._(fechados, null);
    final faixas = lerHorario(texto);
    if (faixas == null) return ControleHorario._(fechados, texto);
    final porDia = {for (var d = 1; d <= 7; d++) d: <FaixaHorario>[]};
    for (final f in faixas) {
      porDia[f.dia]!.add(f);
    }
    final dias = <HorarioDia>[];
    for (var d = 1; d <= 7; d++) {
      final l = porDia[d]!..sort((a, b) => a.inicio.compareTo(b.inicio));
      final naLista = l.every(
        (f) => f.inicio % _passo == 0 && f.fim % _passo == 0 && f.fim < 24 * 60,
      );
      if (l.length > 2 || !naLista) return ControleHorario._(fechados, texto);
      dias.add(switch (l) {
        [final f] => HorarioDia(aberto: true, abre: f.inicio, fecha: f.fim),
        [final a, final b] => HorarioDia(
          aberto: true,
          intervalo: true,
          abre: a.inicio,
          saida: a.fim,
          volta: b.inicio,
          fecha: b.fim,
        ),
        _ => const HorarioDia(),
      });
    }
    return ControleHorario._(dias, null);
  }

  final List<HorarioDia> _dias;

  /// O texto salvo que não deu para ler.
  final String? naoLido;
  bool _alterado = false;

  /// A loja mexeu no editor (sem isso, o horário salvo fica como estava).
  bool get alterado => _alterado;

  /// 1 = segunda … 7 = domingo.
  HorarioDia dia(int d) => _dias[d - 1];

  void abrirDia(int d, bool aberto) =>
      _mudar(d, dia(d).copyWith(aberto: aberto));

  void definir(
    int d, {
    int? abre,
    int? fecha,
    bool? intervalo,
    int? saida,
    int? volta,
  }) => _mudar(
    d,
    dia(d).copyWith(
      abre: abre,
      fecha: fecha,
      intervalo: intervalo,
      saida: saida,
      volta: volta,
    ),
  );

  void copiarSegunda() {
    for (var d = 2; d <= 5; d++) {
      _dias[d - 1] = dia(1);
    }
    _alterado = true;
    notifyListeners();
  }

  void _mudar(int d, HorarioDia novo) {
    _dias[d - 1] = novo;
    _alterado = true;
    notifyListeners();
  }

  String texto() =>
      escreverHorario([for (var d = 1; d <= 7; d++) ...dia(d).faixas(d)]);

  /// Primeiro dia com horário trocado (fecha antes de abrir, intervalo fora do horário).
  String? validar() {
    for (var d = 1; d <= 7; d++) {
      if (!dia(d).valido) return 'Confira o horário de ${_nomes[d - 1]}.';
    }
    return null;
  }
}

/// Horário de atendimento escolhido dia a dia, sem digitar.
class EditorHorario extends StatelessWidget {
  const EditorHorario({super.key, required this.controle});
  final ControleHorario controle;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controle,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controle.naoLido != null) ...[
          Aviso(
            'Não deu para ler o horário anterior (${controle.naoLido}). Escolha de novo.',
            tom: TomSelo.aviso,
          ),
          const SizedBox(height: Espaco.s2),
        ],
        for (var d = 1; d <= 7; d++) _LinhaDia(controle: controle, dia: d),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controle.copiarSegunda,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copiar segunda para terça a sexta'),
          ),
        ),
      ],
    ),
  );
}

class _LinhaDia extends StatelessWidget {
  const _LinhaDia({required this.controle, required this.dia});
  final ControleHorario controle;
  final int dia;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final h = controle.dia(dia);
    Widget hora(
      String nome,
      String rotulo,
      int valor,
      ValueChanged<int> mudar,
    ) => _Hora(
      chave: Key('horario-$dia-$nome'),
      rotulo: rotulo,
      valor: valor,
      onChanged: mudar,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaco.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(_curtos[dia - 1], style: t.titleSmall),
            ),
          ),
          Switch(
            key: Key('horario-$dia'),
            value: h.aberto,
            onChanged: (v) => controle.abrirDia(dia, v),
          ),
          const SizedBox(width: Espaco.s2),
          Expanded(
            child: !h.aberto
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      'Fechado',
                      style: t.bodyMedium?.copyWith(color: c.textoSuave),
                    ),
                  )
                : Wrap(
                    spacing: Espaco.s3,
                    runSpacing: Espaco.s2,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      hora(
                        'abre',
                        'Abre',
                        h.abre,
                        (m) => controle.definir(dia, abre: m),
                      ),
                      if (h.intervalo) ...[
                        hora(
                          'saida',
                          'Saída',
                          h.saida,
                          (m) => controle.definir(dia, saida: m),
                        ),
                        hora(
                          'volta',
                          'Volta',
                          h.volta,
                          (m) => controle.definir(dia, volta: m),
                        ),
                      ],
                      hora(
                        'fecha',
                        'Fecha',
                        h.fecha,
                        (m) => controle.definir(dia, fecha: m),
                      ),
                      FilterChip(
                        key: Key('horario-$dia-intervalo'),
                        label: const Text('Intervalo'),
                        selected: h.intervalo,
                        onSelected: (v) => controle.definir(dia, intervalo: v),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Uma hora do dia: mostra a escolhida e abre a lista de 15 em 15 minutos.
class _Hora extends StatelessWidget {
  const _Hora({
    required this.chave,
    required this.rotulo,
    required this.valor,
    required this.onChanged,
  });
  final Key chave;
  final String rotulo;
  final int valor;
  final ValueChanged<int> onChanged;

  Future<void> _escolher(BuildContext context) async {
    const altura = 48.0;
    final indice = _horarios.indexOf(valor);
    final escolhido = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 360,
          child: ListView.builder(
            // Abre com a hora escolhida no meio da lista
            controller: ScrollController(
              initialScrollOffset: math.max(0, indice * altura - 144),
            ),
            itemExtent: altura,
            itemCount: _horarios.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(_hhmm(_horarios[i])),
              selected: _horarios[i] == valor,
              onTap: () => Navigator.pop(context, _horarios[i]),
            ),
          ),
        ),
      ),
    );
    if (escolhido != null) onChanged(escolhido);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rotulo,
          style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
        ),
        OutlinedButton(
          key: chave,
          onPressed: () => _escolher(context),
          child: Text(_hhmm(valor)),
        ),
      ],
    );
  }
}
