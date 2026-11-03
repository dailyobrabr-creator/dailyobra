import 'dart:convert';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:http/http.dart' as http;

/// Endereço que o ViaCEP devolve para um CEP (a loja confere e completa número e complemento).
class EnderecoCep {
  const EnderecoCep({
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
}

typedef BuscarCep = Future<EnderecoCep?> Function(String cep);

const _falha = FalhaComMensagem(
  'Não deu para buscar o CEP agora. Preencha o endereço à mão.',
);

/// Consulta o ViaCEP direto do aparelho com os 8 números do [cep]; nulo quando o CEP não existe.
Future<EnderecoCep?> buscarCep(String cep, {http.Client? cliente}) async {
  final c = cliente ?? http.Client();
  try {
    final r = await c
        .get(Uri.parse('https://viacep.com.br/ws/$cep/json/'))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw _falha;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map<String, dynamic>) throw _falha;
    // O ViaCEP responde {"erro": true} (ou "true") para CEP que não existe
    final erro = j['erro'];
    if (erro == true || erro == 'true') return null;
    return EnderecoCep(
      logradouro: (j['logradouro'] as String?) ?? '',
      bairro: (j['bairro'] as String?) ?? '',
      cidade: (j['localidade'] as String?) ?? '',
      uf: (j['uf'] as String?) ?? '',
    );
  } on FalhaComMensagem {
    rethrow;
  } catch (_) {
    throw _falha;
  } finally {
    if (cliente == null) c.close();
  }
}
