import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';

/// No app instalado a leitura ainda não roda no aparelho; no navegador ela roda (leitura_no_aparelho_web.dart).
Future<String> lerNoAparelho(Uint8List bytes, String tipo) async =>
    throw const FalhaComMensagem(
      'No app instalado a leitura de foto e PDF ainda não funciona. Abra o DailyObra pelo navegador ou cole o texto da lista.',
    );
