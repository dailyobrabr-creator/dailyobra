import '../ui/ui.dart' show brl;
import 'cnpj.dart';

/// Quem paga o pedido: o próprio construtor ("Eu pago") ou o cliente final, pelo link de pagamento.
enum Pagador {
  proprio('proprio'),
  cliente('cliente');

  const Pagador(this.codigo);
  final String codigo;

  static Pagador? fromCodigo(String? c) => values.where((v) => v.codigo == c).firstOrNull;
}

/// Em que pé está o pagamento de um pedido. Mesma precedência da função private.situacao_pagamento do banco.
enum SituacaoPagamento { semPagador, aguardandoDados, aguardandoPagamento, informado, pago, cancelado }

const _baseDoLink = 'https://dailyobrabr-creator.github.io/dailyobra/pagar/?c=';

/// Endereço da página que o cliente abre para pagar (dailyobra/web/pagar).
String linkDePagamento(String codigo) => '$_baseDoLink$codigo';

String mensagemDoLink({required String nome, required String loja, required double total, required String link}) =>
    'Olá, $nome! Preparei os materiais da sua obra na $loja: total ${brl.format(total)}. Para pagar direto à loja por PIX e receber a nota no seu nome, abra: $link';

/// wa.me com 55 + DDD + número (o 55 entra só quando falta) e a mensagem codificada.
Uri linkWhatsApp(String whatsapp, String mensagem) {
  var numero = somenteDigitos(whatsapp);
  if (numero.length == 10 || numero.length == 11) numero = '55$numero';
  return Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}');
}

final _naoDigito = RegExp(r'\D');

String somenteDigitos(String s) => s.replaceAll(_naoDigito, '');

/// Mesma conta do servidor (private.cpf_valido): 11 dígitos, não todos iguais, dois verificadores.
bool cpfValido(String cpf) {
  final d = somenteDigitos(cpf);
  if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
  int verificador(int tamanho) {
    var soma = 0;
    for (var i = 0; i < tamanho; i++) {
      soma += int.parse(d[i]) * (tamanho + 1 - i);
    }
    final dv = soma * 10 % 11;
    return dv == 10 ? 0 : dv;
  }

  return verificador(9) == int.parse(d[9]) && verificador(10) == int.parse(d[10]);
}

/// CPF (11 dígitos) ou CNPJ (14), com ou sem pontuação.
bool documentoValido(String documento) {
  final d = somenteDigitos(documento);
  return switch (d.length) { 11 => cpfValido(d), 14 => cnpjValido(d), _ => false };
}

const _chaveInvalida = 'Chave PIX inválida. Use CPF, CNPJ, e-mail, celular com +55 ou chave aleatória.';

/// Mesmas regras do banco (private.chave_pix_valida); nulo quando a chave serve.
String? chavePixInvalida(String chave) {
  final c = chave.trim();
  final serve = switch (c) {
    _ when RegExp(r'^\d{11}$').hasMatch(c) => cpfValido(c),
    _ when RegExp(r'^\d{14}$').hasMatch(c) => cnpjValido(c),
    _ when RegExp(r'^\+55\d{10,11}$').hasMatch(c) => true,
    _ when RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(c) => true,
    _ when RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(c) && c.length <= 77 => true,
    _ => false,
  };
  return serve ? null : _chaveInvalida;
}
