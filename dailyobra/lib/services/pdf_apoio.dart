import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const pdfLaranja = PdfColor.fromInt(0xFFA43F05);
const pdfTexto = PdfColor.fromInt(0xFF22262B);
const pdfSuave = PdfColor.fromInt(0xFF5C6470);
const pdfBorda = PdfColor.fromInt(0xFFDCDFE3);
const pdfFundo = PdfColor.fromInt(0xFFF5F2EE);

const _trocas = {
  '–': '-',
  '—': '-',
  '“': '"',
  '”': '"',
  '‘': "'",
  '’': "'",
  '…': '...',
  '•': '-',
};

/// A Helvetica do PDF só escreve os acentos do português e o básico: o que o celular digita a
/// mais (travessão, aspas curvas) vira o equivalente, e emoji sai, para o documento não quebrar.
String pdfLimpo(String texto) {
  final s = StringBuffer();
  for (final r in texto.runes) {
    final c = String.fromCharCode(r);
    final troca = _trocas[c];
    if (troca != null) {
      s.write(troca);
    } else if (r == 10 || (r >= 32 && r < 127) || (r >= 160 && r < 256)) {
      s.write(c);
    }
  }
  return s.toString();
}

pw.Widget pdfTitulo(String texto) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
  child: pw.Text(
    pdfLimpo(texto),
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: pdfLaranja,
    ),
  ),
);

pw.Widget pdfTabela({
  required List<String> cabecalho,
  required List<List<String>> linhas,
  required Map<int, pw.TableColumnWidth> larguras,
}) => pw.TableHelper.fromTextArray(
  headers: [for (final c in cabecalho) pdfLimpo(c)],
  data: [
    for (final l in linhas) [for (final c in l) pdfLimpo(c)],
  ],
  columnWidths: larguras,
  headerStyle: pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: pdfTexto,
  ),
  headerDecoration: const pw.BoxDecoration(color: pdfFundo),
  headerAlignment: pw.Alignment.centerLeft,
  cellStyle: const pw.TextStyle(fontSize: 9.5, color: pdfTexto),
  cellAlignment: pw.Alignment.topLeft,
  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  border: const pw.TableBorder(
    bottom: pw.BorderSide(color: pdfBorda, width: 0.5),
    horizontalInside: pw.BorderSide(color: pdfBorda, width: 0.5),
  ),
);

/// Título e conteúdo na mesma página, para o título não ficar sozinho no pé. Conteúdo longo vai
/// solto, porque só assim consegue continuar na página seguinte.
List<pw.Widget> pdfParte(
  String titulo,
  pw.Widget corpo, {
  required int letras,
}) => letras <= 1800
    ? [
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [pdfTitulo(titulo), corpo],
          ),
        ),
      ]
    : [pdfTitulo(titulo), corpo];

List<pw.Widget> pdfParteComTabela(
  String titulo, {
  required List<String> cabecalho,
  required List<List<String>> linhas,
  required Map<int, pw.TableColumnWidth> larguras,
}) => pdfParte(
  titulo,
  pdfTabela(cabecalho: cabecalho, linhas: linhas, larguras: larguras),
  letras: linhas.fold(
    0,
    (soma, l) => soma + 40 + l.fold(0, (s, c) => s + c.length),
  ),
);

pw.Widget pdfFoto(pw.MemoryImage imagem, String legenda) => pw.SizedBox(
  width: 253,
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 253,
        height: 180,
        child: pw.Image(imagem, fit: pw.BoxFit.cover),
      ),
      if (legenda.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(
            pdfLimpo(legenda),
            style: const pw.TextStyle(fontSize: 8.5, color: pdfSuave),
          ),
        ),
    ],
  ),
);

pw.Widget pdfAssinatura(String rotulo, String nome) => pw.Expanded(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 34),
      pw.Container(height: 0.6, color: pdfTexto),
      pw.SizedBox(height: 4),
      pw.Text(
        nome.isEmpty ? rotulo : pdfLimpo(nome),
        style: const pw.TextStyle(fontSize: 9, color: pdfTexto),
      ),
      if (nome.isNotEmpty)
        pw.Text(
          rotulo,
          style: const pw.TextStyle(fontSize: 8, color: pdfSuave),
        ),
    ],
  ),
);

pw.Widget pdfNumero(String rotulo, String valor) => pw.Expanded(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        pdfLimpo(rotulo),
        style: const pw.TextStyle(fontSize: 8.5, color: pdfSuave),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        pdfLimpo(valor),
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: pdfTexto,
        ),
      ),
    ],
  ),
);

String pdfLugar(Obra obra) => [
  obra.dados.endereco.trim(),
  [
    obra.dados.cidade,
    obra.dados.uf,
  ].where((p) => p.trim().isNotEmpty).join(' - '),
].where((p) => p.isNotEmpty).join(' · ');

/// Abre o arquivo como imagem. O que não abrir fica de fora, sem derrubar o documento.
pw.MemoryImage? pdfImagem(Uint8List? bytes) {
  if (bytes == null) return null;
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

/// Topo dos documentos: quem assina, o que é o documento e a linha que separa do conteúdo.
List<pw.Widget> pdfCabecalho({
  required String documento,
  required String titulo,
  String detalhe = '',
  MarcaEngenheiro? marca,
  Uint8List? logo,
  String? selo,
}) {
  final imagem = pdfImagem(logo);
  final nome = marca?.nome.trim() ?? '';
  final contato = marca?.contato ?? '';
  return [
    if (imagem != null || nome.isNotEmpty) ...[
      pw.Row(
        children: [
          if (imagem != null) ...[
            pw.SizedBox(
              width: 96,
              height: 44,
              child: pw.Image(
                imagem,
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.centerLeft,
              ),
            ),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (nome.isNotEmpty)
                  pw.Text(
                    pdfLimpo(nome),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfTexto,
                    ),
                  ),
                if (contato.isNotEmpty)
                  pw.Text(
                    pdfLimpo(contato),
                    style: const pw.TextStyle(fontSize: 8.5, color: pdfSuave),
                  ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
    ],
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                pdfLimpo(documento),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfLaranja,
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                pdfLimpo(titulo),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfTexto,
                ),
              ),
              if (detalhe.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    pdfLimpo(detalhe),
                    style: const pw.TextStyle(fontSize: 9.5, color: pdfSuave),
                  ),
                ),
            ],
          ),
        ),
        if (selo != null)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: pdfSuave, width: 0.6),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              pdfLimpo(selo),
              style: const pw.TextStyle(fontSize: 8.5, color: pdfSuave),
            ),
          ),
      ],
    ),
    pw.SizedBox(height: 10),
    pw.Container(height: 1.5, color: pdfLaranja),
    pw.SizedBox(height: 10),
  ];
}
