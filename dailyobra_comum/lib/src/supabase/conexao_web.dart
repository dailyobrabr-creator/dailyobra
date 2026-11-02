import 'package:http/http.dart' as http;

/// Navegador: a falta de rede chega como erro do cliente HTTP (não existe dart:io aqui).
bool ehFalhaDeConexao(Object erro) => erro is http.ClientException;
