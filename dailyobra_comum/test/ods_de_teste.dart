import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const _ns = 'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"';

/// .ods mínimo: as linhas dadas (XML de table:table-row) na primeira tabela e uma segunda tabela, que não deve ser lida.
Uint8List odsDeTeste(String linhas) {
  final arquivo = Archive();
  void adicionar(String nome, String conteudo) => arquivo.addFile(ArchiveFile.bytes(nome, utf8.encode(conteudo)));
  adicionar('mimetype', 'application/vnd.oasis.opendocument.spreadsheet');
  adicionar('content.xml', '<?xml version="1.0" encoding="UTF-8"?><office:document-content $_ns><office:body><office:spreadsheet>'
      '<table:table table:name="Planilha1">$linhas</table:table>'
      '<table:table table:name="Outra"><table:table-row>${celulaOds('não lê')}</table:table-row></table:table>'
      '</office:spreadsheet></office:body></office:document-content>');
  return ZipEncoder().encodeBytes(arquivo);
}

/// Célula de texto, repetida [repetir] vezes.
String celulaOds(String texto, {int repetir = 1}) =>
    '<table:table-cell${repetir > 1 ? ' table:number-columns-repeated="$repetir"' : ''} office:value-type="string"><text:p>$texto</text:p></table:table-cell>';

String linhaOds(String celulas) => '<table:table-row>$celulas</table:table-row>';
