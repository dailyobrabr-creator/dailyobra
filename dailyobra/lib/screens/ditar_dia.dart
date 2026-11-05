import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/ditado.dart';
import '../services/ia_service.dart';
import '../services/obras_service.dart';

const tamanhoDoDitado = 6000;

/// Abre a janela do ditado e devolve o dia organizado, ou nulo se a pessoa desistir.
Future<SugestaoDoDia?> ditarODia(BuildContext context, String obraId) {
  return showDialog<SugestaoDoDia>(
    context: context,
    // Um toque fora da janela não pode jogar fora o que foi ditado
    barrierDismissible: false,
    builder: (_) => JanelaDoDitado(obraId: obraId),
  );
}

/// A pessoa fala ou escreve como foi o dia. Se a IA falhar, a janela continua aberta com o texto.
class JanelaDoDitado extends StatefulWidget {
  const JanelaDoDitado({super.key, required this.obraId});
  final String obraId;

  @override
  State<JanelaDoDitado> createState() => _JanelaDoDitadoState();
}

class _JanelaDoDitadoState extends State<JanelaDoDitado> {
  final _texto = TextEditingController();
  var _antes = '';
  var _ouvindo = false;
  var _organizando = false;
  String? _erro;

  @override
  void dispose() {
    if (_ouvindo) Ditado.instancia.parar();
    _texto.dispose();
    super.dispose();
  }

  void _ouviu(String fala) {
    if (!mounted) return;
    final texto = [_antes, fala.trim()].where((t) => t.isNotEmpty).join(' ');
    _texto.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  Future<void> _microfone() async {
    if (_ouvindo) {
      await Ditado.instancia.parar();
      if (mounted) setState(() => _ouvindo = false);
      return;
    }
    setState(() => _erro = null);
    if (!await Ditado.instancia.preparar()) {
      if (mounted) {
        setState(() {
          _erro = 'Não deu para usar o microfone aqui. Confira a permissão ou use o microfone do teclado.';
        });
      }
      return;
    }
    if (!mounted) return;
    _antes = _texto.text.trim();
    setState(() => _ouvindo = true);
    await Ditado.instancia.ouvir(
      aoOuvir: _ouviu,
      aoParar: () {
        if (mounted) setState(() => _ouvindo = false);
      },
    );
  }

  Future<void> _organizar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty) {
      setState(() => _erro = 'Fale ou escreva como foi o dia.');
      return;
    }
    if (_ouvindo) await Ditado.instancia.parar();
    if (!mounted) return;
    setState(() {
      _ouvindo = false;
      _organizando = true;
      _erro = null;
    });
    try {
      final dia = await IaService.instance.organizarDia(widget.obraId, texto);
      if (mounted) Navigator.pop(context, dia);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _organizando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Ditar o dia'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Conte como foi o dia: quem veio, o que foi feito, o que chegou e o que aconteceu.',
            ),
            const SizedBox(height: Espaco.s3),
            TextField(
              key: const Key('texto-do-ditado'),
              controller: _texto,
              enabled: !_organizando,
              minLines: 5,
              maxLines: 10,
              maxLength: tamanhoDoDitado,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ex.: vieram 3 pedreiros e 2 serventes, rebocamos a sala, chegaram 20 sacos de cimento e choveu à tarde.',
                hintMaxLines: 4,
                counterText: '',
              ),
            ),
            const SizedBox(height: Espaco.s2),
            OutlinedButton.icon(
              onPressed: _organizando ? null : _microfone,
              icon: Icon(
                _ouvindo ? Icons.stop_circle_outlined : Icons.mic_none,
                size: 18,
              ),
              label: Text(_ouvindo ? 'Parar de ouvir' : 'Falar'),
            ),
            if (_erro != null) ...[
              const SizedBox(height: Espaco.s3),
              Aviso(_erro!),
            ],
            const SizedBox(height: Espaco.s3),
            Text(
              'O texto vai para a IA só para organizar o dia. Você confere tudo antes de salvar.',
              style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _organizando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _organizando ? null : _organizar,
          child: Text(_organizando ? 'Organizando...' : 'Organizar'),
        ),
      ],
    );
  }
}
