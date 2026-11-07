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

/// PIX do pedido. Automático é a cobrança do Asaas, que confirma o pedido sozinha; senão é a chave da loja, que confere à mão.
class PixDoPedido {
  const PixDoPedido(this.codigo, {this.automatico = false});
  final String codigo;
  final bool automatico;
}

/// Como o construtor paga. Cada loja diz quais recebe; o crediário depende de a loja aprovar o prazo.
enum FormaPagamento {
  pix('pix', 'PIX'),
  cartao('cartao', 'Cartão na loja'),
  boleto('boleto', 'Boleto'),
  dinheiro('dinheiro', 'Dinheiro'),
  crediario('crediario', 'Crediário da loja');

  const FormaPagamento(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static FormaPagamento? fromCodigo(String? c) => values.where((v) => v.codigo == c).firstOrNull;
}

/// O que a loja recebe enquanto não escolheu as formas dela.
const formasPadrao = [FormaPagamento.pix, FormaPagamento.cartao, FormaPagamento.crediario];

/// Resposta do dono ou gerente da loja ao pedido de prazo do crediário.
enum StatusPrazo {
  pendente,
  aprovado,
  recusado;

  static StatusPrazo? fromCodigo(String? c) => values.where((v) => v.name == c).firstOrNull;
}

/// Prazos do crediário que o construtor pode pedir, em dias.
const prazosCrediario = ['28', '28/35', '28/35/42'];

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

/// 000.000.000-00 ou 00.000.000/0000-00; outro tamanho volta como veio.
String formatarDocumento(String documento) {
  final d = somenteDigitos(documento);
  if (d.length == 14) return formatarCnpj(d);
  if (d.length != 11) return documento;
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}

/// CPF (11 dígitos) ou CNPJ (14), com ou sem pontuação.
bool documentoValido(String documento) {
  final d = somenteDigitos(documento);
  return switch (d.length) { 11 => cpfValido(d), 14 => cnpjValido(d), _ => false };
}

final _uuid = RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$');

/// Chave como o banco guarda: e-mail e chave aleatória em minúsculas; CPF, CNPJ e celular sem pontuação nem espaço.
String normalizarChavePix(String chave) {
  final c = chave.trim();
  if (c.contains('@') || _uuid.hasMatch(c)) return c.toLowerCase();
  final semPontuacao = c.replaceAll(RegExp(r'[\s.()/-]'), '');
  return RegExp(r'^\+?\d+$').hasMatch(semPontuacao) ? semPontuacao : c;
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
