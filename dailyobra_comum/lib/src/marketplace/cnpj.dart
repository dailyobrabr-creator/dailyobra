final _naoDigito = RegExp(r'\D');

String _digitos(String s) => s.replaceAll(_naoDigito, '');

/// Mesma conta do servidor (private.cnpj_valido): 14 dígitos, não todos iguais, dois verificadores.
bool cnpjValido(String cnpj) {
  final d = _digitos(cnpj);
  if (d.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(d)) return false;
  int verificador(int tamanho) {
    final pesos = tamanho == 12 ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2] : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    var soma = 0;
    for (var i = 0; i < tamanho; i++) {
      soma += int.parse(d[i]) * pesos[i];
    }
    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  return verificador(12) == int.parse(d[12]) && verificador(13) == int.parse(d[13]);
}

/// 00.000.000/0000-00, também com o número pela metade (para formatar enquanto digita).
String formatarCnpj(String cnpj) {
  final d = _digitos(cnpj);
  final b = StringBuffer();
  for (var i = 0; i < d.length && i < 14; i++) {
    if (i == 2 || i == 5) b.write('.');
    if (i == 8) b.write('/');
    if (i == 12) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}
