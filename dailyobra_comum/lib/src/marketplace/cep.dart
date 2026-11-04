import 'dart:convert';

import 'package:http/http.dart' as http;

import '../supabase/erros.dart';

/// Endereço que o ViaCEP devolve para um CEP.
class EnderecoCep {
  const EnderecoCep({required this.logradouro, required this.bairro, required this.cidade, required this.uf});
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
}

typedef BuscarCep = Future<EnderecoCep?> Function(String cep);
typedef BuscarCidades = Future<List<String>> Function(String uf);

const _falhaCep = FalhaComMensagem('Não deu para buscar o CEP agora. Preencha o endereço à mão.');
const _falhaCidades = FalhaComMensagem('Não deu para carregar as cidades.');

/// Consulta o ViaCEP direto do aparelho com os 8 números do [cep]; nulo quando o CEP não existe.
Future<EnderecoCep?> buscarCep(String cep, {http.Client? cliente}) async {
  final c = cliente ?? http.Client();
  try {
    final r = await c.get(Uri.parse('https://viacep.com.br/ws/$cep/json/')).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw _falhaCep;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map<String, dynamic>) throw _falhaCep;
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
    throw _falhaCep;
  } finally {
    if (cliente == null) c.close();
  }
}

/// Nomes dos municípios do estado, na lista oficial do IBGE, em ordem alfabética.
Future<List<String>> cidadesDoEstado(String uf, {http.Client? cliente}) async {
  final c = cliente ?? http.Client();
  try {
    final r = await c
        .get(Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/estados/$uf/municipios?orderBy=nome'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw _falhaCidades;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! List) throw _falhaCidades;
    return [for (final m in j) (m as Map<String, dynamic>)['nome'] as String];
  } on FalhaComMensagem {
    rethrow;
  } catch (_) {
    throw _falhaCidades;
  } finally {
    if (cliente == null) c.close();
  }
}
