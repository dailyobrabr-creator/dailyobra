import 'dart:io';

import 'package:http/http.dart' as http;

/// Celular e computador: além do erro do cliente HTTP, o sistema avisa falta de rede por exceções de E/S.
bool ehFalhaDeConexao(Object erro) =>
    erro is SocketException ||
    erro is HandshakeException ||
    erro is http.ClientException;
