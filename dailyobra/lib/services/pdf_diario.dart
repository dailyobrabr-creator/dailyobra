import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _laranja = PdfColor.fromInt(0xFFA43F05);
const _texto = PdfColor.fromInt(0xFF22262B);
const _suave = PdfColor.fromInt(0xFF5C6470);
const _borda = PdfColor.fromInt(0xFFDCDFE3);
const _fundo = PdfColor.fromInt(0xFFF5F2EE);

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

String nomeDoPdf(DiaObra dia) => 'diario-de-obra-${dataIso(dia.data)}.pdf';

/// A Helvetica do PDF só escreve os acentos do português e o básico: o que o celular digita a
/// mais (travessão, aspas curvas) vira o equivalente, e emoji sai, para o documento não quebrar.
String _limpo(String texto) {
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

String _quantidade(double? q) {
  if (q == null) return '';
  return q == q.roundToDouble()
      ? q.toStringAsFixed(0)
      : q.toString().replaceAll('.', ',');
}

pw.Widget _titulo(String texto) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
  child: pw.Text(
    _limpo(texto),
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: _laranja,
    ),
  ),
);

pw.Widget _tabela({
  required List<String> cabecalho,
  required List<List<String>> linhas,
  required Map<int, pw.TableColumnWidth> larguras,
}) => pw.TableHelper.fromTextArray(
  headers: [for (final c in cabecalho) _limpo(c)],
  data: [
    for (final l in linhas) [for (final c in l) _limpo(c)],
  ],
  columnWidths: larguras,
  headerStyle: pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: _texto,
  ),
  headerDecoration: const pw.BoxDecoration(color: _fundo),
  headerAlignment: pw.Alignment.centerLeft,
  cellStyle: const pw.TextStyle(fontSize: 9.5, color: _texto),
  cellAlignment: pw.Alignment.topLeft,
  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  border: const pw.TableBorder(
    bottom: pw.BorderSide(color: _borda, width: 0.5),
    horizontalInside: pw.BorderSide(color: _borda, width: 0.5),
  ),
);

/// Título e conteúdo na mesma página, para o título não ficar sozinho no pé. Conteúdo longo vai
/// solto, porque só assim consegue continuar na página seguinte.
List<pw.Widget> _parte(String titulo, pw.Widget corpo, {required int letras}) =>
    letras <= 1800
    ? [
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [_titulo(titulo), corpo],
          ),
        ),
      ]
    : [_titulo(titulo), corpo];

List<pw.Widget> _parteComTabela(
  String titulo, {
  required List<String> cabecalho,
  required List<List<String>> linhas,
  required Map<int, pw.TableColumnWidth> larguras,
}) => _parte(
  titulo,
  _tabela(cabecalho: cabecalho, linhas: linhas, larguras: larguras),
  letras: linhas.fold(
    0,
    (soma, l) => soma + 40 + l.fold(0, (s, c) => s + c.length),
  ),
);

pw.Widget _foto(pw.MemoryImage imagem, String legenda) => pw.SizedBox(
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
            _limpo(legenda),
            style: const pw.TextStyle(fontSize: 8.5, color: _suave),
          ),
        ),
    ],
  ),
);

pw.Widget _assinatura(String rotulo, String nome) => pw.Expanded(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 34),
      pw.Container(height: 0.6, color: _texto),
      pw.SizedBox(height: 4),
      pw.Text(
        nome.isEmpty ? rotulo : _limpo(nome),
        style: const pw.TextStyle(fontSize: 9, color: _texto),
      ),
      if (nome.isNotEmpty)
        pw.Text(rotulo, style: const pw.TextStyle(fontSize: 8, color: _suave)),
    ],
  ),
);

/// O dia como documento: pronto para mandar ao cliente ou guardar na pasta da obra.
Future<Uint8List> pdfDoDia({
  required Obra obra,
  required DiaObra dia,
  Map<String, Uint8List> fotos = const {},
}) {
  final dataDoDia = '${dataCurta(dia.data)}/${dia.data.year}';
  final doc = pw.Document(
    title: _limpo('Diário de obra - $dataDoDia'),
    author: 'DailyObra',
    creator: 'DailyObra',
  );
  final lugar = [
    obra.dados.endereco.trim(),
    [
      obra.dados.cidade,
      obra.dados.uf,
    ].where((p) => p.trim().isNotEmpty).join(' - '),
  ].where((p) => p.isNotEmpty).join(' · ');
  final clima = [
    if (dia.climaManha != null) 'Manhã: ${dia.climaManha!.rotulo}',
    if (dia.climaTarde != null) 'Tarde: ${dia.climaTarde!.rotulo}',
  ].join('   ·   ');
  final imagens = <(pw.MemoryImage, String)>[];
  for (final f in dia.fotos) {
    final bytes = fotos[f.caminho];
    if (bytes == null) continue;
    try {
      imagens.add((pw.MemoryImage(bytes), f.legenda));
    } catch (_) {
      // Arquivo que não abre como imagem não derruba o documento
    }
  }

  final paresDeFotos = [
    for (var i = 0; i < imagens.length; i += 2)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _foto(imagens[i].$1, imagens[i].$2),
            if (i + 1 < imagens.length) ...[
              pw.SizedBox(width: 8),
              _foto(imagens[i + 1].$1, imagens[i + 1].$2),
            ],
          ],
        ),
      ),
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      maxPages: 60,
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _limpo('${obra.nome} · $dataDoDia'),
            style: const pw.TextStyle(fontSize: 8, color: _suave),
          ),
          pw.Text(
            _limpo(
              'Feito no DailyObra · página ${c.pageNumber} de ${c.pagesCount}',
            ),
            style: const pw.TextStyle(fontSize: 8, color: _suave),
          ),
        ],
      ),
      build: (c) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _limpo('DIÁRIO DE OBRA'),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _laranja,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _limpo(obra.nome),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto,
                    ),
                  ),
                  if (lugar.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        _limpo(lugar),
                        style: const pw.TextStyle(fontSize: 9.5, color: _suave),
                      ),
                    ),
                ],
              ),
            ),
            if (!dia.fechado)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _suave, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  'Rascunho',
                  style: const pw.TextStyle(fontSize: 8.5, color: _suave),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 1.5, color: _laranja),
        pw.SizedBox(height: 10),
        pw.Text(
          _limpo(diaPorExtenso(dia.data)),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _texto,
          ),
        ),
        if (clima.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              _limpo(clima),
              style: const pw.TextStyle(fontSize: 9.5, color: _suave),
            ),
          ),
        if (dia.equipe.isNotEmpty)
          ..._parteComTabela(
            'Equipe (${dia.pessoas} ${dia.pessoas == 1 ? 'pessoa' : 'pessoas'})',
            cabecalho: const ['Função', 'Qtd.', 'Empresa'],
            larguras: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FixedColumnWidth(42),
              2: pw.FlexColumnWidth(3),
            },
            linhas: [
              for (final e in dia.equipe)
                [e.funcao, '${e.quantidade}', e.empresa],
            ],
          ),
        if (dia.atividades.isNotEmpty)
          ..._parteComTabela(
            'O que foi feito',
            cabecalho: const ['Serviço', 'Local', 'Pronto'],
            larguras: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(2),
              2: pw.FixedColumnWidth(46),
            },
            linhas: [
              for (final a in dia.atividades)
                [
                  a.descricao,
                  a.local,
                  if (a.percentual == null) '' else '${a.percentual}%',
                ],
            ],
          ),
        if (dia.ocorrencias.isNotEmpty)
          ..._parteComTabela(
            'Ocorrências',
            cabecalho: const ['Tipo', 'Descrição'],
            larguras: const {
              0: pw.FixedColumnWidth(70),
              1: pw.FlexColumnWidth(),
            },
            linhas: [
              for (final o in dia.ocorrencias) [o.tipo.rotulo, o.descricao],
            ],
          ),
        if (dia.materiais.isNotEmpty)
          ..._parteComTabela(
            'Materiais usados',
            cabecalho: const ['Material', 'Qtd.', 'Fornecedor'],
            larguras: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FixedColumnWidth(66),
              2: pw.FlexColumnWidth(2),
            },
            linhas: [
              for (final m in dia.materiais)
                [
                  m.material,
                  '${_quantidade(m.quantidade)} ${m.unidade}'.trim(),
                  m.fornecedor,
                ],
            ],
          ),
        if (dia.equipamentos.isNotEmpty)
          ..._parteComTabela(
            'Equipamentos',
            cabecalho: const ['Equipamento', 'Qtd.'],
            larguras: const {
              0: pw.FlexColumnWidth(),
              1: pw.FixedColumnWidth(42),
            },
            linhas: [
              for (final e in dia.equipamentos)
                [e.equipamento, '${e.quantidade}'],
            ],
          ),
        if (dia.observacoes.trim().isNotEmpty)
          ..._parte(
            'Observações',
            pw.Text(
              _limpo(dia.observacoes.trim()),
              style: const pw.TextStyle(fontSize: 9.5, color: _texto),
            ),
            letras: dia.observacoes.length,
          ),
        if (paresDeFotos.isNotEmpty) ...[
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [_titulo('Fotos'), paresDeFotos.first],
            ),
          ),
          ...paresDeFotos.skip(1),
        ],
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _assinatura('Responsável pela obra', obra.dados.responsavel),
            pw.SizedBox(width: 32),
            _assinatura('Cliente ou fiscalização', ''),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
