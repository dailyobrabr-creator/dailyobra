import 'package:supabase_flutter/supabase_flutter.dart';

import 'conexao_io.dart' if (dart.library.js_interop) 'conexao_web.dart';

/// Texto para mostrar ao usuário quando uma chamada ao Supabase falha.
///
/// As funções do banco avisam regras de negócio com `errcode = 'P0001'` e uma mensagem em
/// português pronta para a tela ("O pedido mínimo da Loja A é R$ 100,00..."). Qualquer outro erro
/// vira uma frase genérica: detalhe técnico não ajuda quem está na obra.
String mensagemDoServidor(Object erro) {
  if (erro is PostgrestException && erro.code == 'P0001') return erro.message;
  if (ehFalhaDeConexao(erro)) {
    return 'Sem conexão. Verifique a internet e tente de novo.';
  }
  return 'Não foi possível concluir agora. Tente de novo.';
}

/// Falha com o texto pronto para a tela (já passou por [mensagemDoServidor]).
class FalhaComMensagem implements Exception {
  const FalhaComMensagem(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Roda a chamada ao Supabase e troca qualquer erro por [FalhaComMensagem].
Future<T> comMensagem<T>(Future<T> Function() acao) async {
  try {
    return await acao();
  } on FalhaComMensagem {
    rethrow;
  } catch (e) {
    throw FalhaComMensagem(mensagemDoServidor(e));
  }
}
