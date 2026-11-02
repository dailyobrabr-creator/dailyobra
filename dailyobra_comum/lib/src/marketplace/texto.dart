const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', '³': '3', '²': '2',
};

final _hifenEntreLetraENumero = RegExp(r'(?<=[a-z])-(?=\d)|(?<=\d)-(?=[a-z])');
final _foraDoAlfabeto = RegExp(r'[^a-z0-9/,. ]');
final _espacos = RegExp(r'\s+');

/// Forma de comparar textos digitados com o catálogo: minúsculas, sem acento, só letras,
/// números e os sinais de medida (`5/16`, `2,5mm`, `1.000`), com um espaço entre palavras.
/// "CA-50" vira "ca50"; os demais hífens e símbolos viram espaço.
String normalizar(String texto) {
  final b = StringBuffer();
  for (final r in texto.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    b.write(_acentos[c] ?? c);
  }
  return b
      .toString()
      .replaceAll(_hifenEntreLetraENumero, '')
      .replaceAll(_foraDoAlfabeto, ' ')
      .replaceAll(_espacos, ' ')
      .trim();
}
