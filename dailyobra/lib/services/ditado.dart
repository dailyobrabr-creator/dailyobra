import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Fala vira texto no próprio aparelho, ou no navegador (Chrome e Edge). A escuta para sozinha depois de um silêncio, e o que já
/// foi ouvido continua no campo: se o aparelho não reconhecer voz, a pessoa escreve ou usa o microfone do teclado.
abstract class Ditado {
  /// Os testes trocam por um ditado de mentira.
  static Ditado instancia = _DitadoDoAparelho();

  /// Pede o microfone. Falso quando não há reconhecimento de voz ou a pessoa não deixou.
  Future<bool> preparar();

  /// [aoOuvir] recebe tudo o que foi reconhecido nesta escuta; [aoParar], quando ela termina.
  Future<void> ouvir({
    required ValueChanged<String> aoOuvir,
    required VoidCallback aoParar,
  });

  Future<void> parar();
}

class _DitadoDoAparelho implements Ditado {
  final _fala = SpeechToText();
  VoidCallback? _aoParar;

  void _parou() {
    final avisar = _aoParar;
    _aoParar = null;
    avisar?.call();
  }

  @override
  Future<bool> preparar() async {
    if (_fala.isAvailable) return true;
    try {
      return await _fala.initialize(
        onStatus: (s) {
          if (s == SpeechToText.doneStatus ||
              s == SpeechToText.notListeningStatus) {
            _parou();
          }
        },
        onError: (_) => _parou(),
        // Fone bluetooth exigiria mais uma permissão no Android
        options: [SpeechToText.androidNoBluetooth, SpeechToText.iosNoBluetooth],
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> ouvir({
    required ValueChanged<String> aoOuvir,
    required VoidCallback aoParar,
  }) async {
    _aoParar = aoParar;
    try {
      await _fala.listen(
        onResult: (r) => aoOuvir(r.recognizedWords),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 30),
          // O navegador só entende o idioma com hífen
          localeId: kIsWeb ? 'pt-BR' : 'pt_BR',
        ),
      );
    } catch (_) {
      _parou();
    }
  }

  @override
  Future<void> parar() => _fala.stop();
}
