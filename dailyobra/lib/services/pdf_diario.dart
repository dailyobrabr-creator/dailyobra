import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_apoio.dart';

String nomeDoPdf(DiaObra dia) => 'diario-de-obra-${dataIso(dia.data)}.pdf';

String _quantidade(double? q) {
  if (q == null) return '';
  return q == q.roundToDouble()
      ? q.toStringAsFixed(0)
      : q.toString().replaceAll('.', ',');
}

pw.Widget _assinatura(String rotulo, String nome) => pw.Expanded(
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

/// O dia como documento: pronto para mandar ao cliente ou guardar na pasta da obra.
Future<Uint8List> pdfDoDia({
  required Obra obra,
  required DiaObra dia,
  Map<String, Uint8List> fotos = const {},
  MarcaEngenheiro? marca,
  Uint8List? logo,
}) {
  final dataDoDia = '${dataCurta(dia.data)}/${dia.data.year}';
  final doc = pw.Document(
    title: pdfLimpo('Diário de obra - $dataDoDia'),
    author: 'DailyObra',
    creator: 'DailyObra',
  );
  final lugar = pdfLugar(obra);
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
            pdfFoto(imagens[i].$1, imagens[i].$2),
            if (i + 1 < imagens.length) ...[
              pw.SizedBox(width: 8),
              pdfFoto(imagens[i + 1].$1, imagens[i + 1].$2),
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
            pdfLimpo('${obra.nome} · $dataDoDia'),
            style: const pw.TextStyle(fontSize: 8, color: pdfSuave),
          ),
          pw.Text(
            pdfLimpo(
              'Feito no DailyObra · página ${c.pageNumber} de ${c.pagesCount}',
            ),
            style: const pw.TextStyle(fontSize: 8, color: pdfSuave),
          ),
        ],
      ),
      build: (c) => [
        ...pdfCabecalho(
          documento: 'DIÁRIO DE OBRA',
          titulo: obra.nome,
          detalhe: lugar,
          marca: marca,
          logo: logo,
          selo: dia.fechado ? null : 'Rascunho',
        ),
        pw.Text(
          pdfLimpo(diaPorExtenso(dia.data)),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: pdfTexto,
          ),
        ),
        if (clima.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              pdfLimpo(clima),
              style: const pw.TextStyle(fontSize: 9.5, color: pdfSuave),
            ),
          ),
        if (dia.equipe.isNotEmpty)
          ...pdfParteComTabela(
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
          ...pdfParteComTabela(
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
          ...pdfParteComTabela(
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
          ...pdfParteComTabela(
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
          ...pdfParteComTabela(
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
          ...pdfParte(
            'Observações',
            pw.Text(
              pdfLimpo(dia.observacoes.trim()),
              style: const pw.TextStyle(fontSize: 9.5, color: pdfTexto),
            ),
            letras: dia.observacoes.length,
          ),
        if (paresDeFotos.isNotEmpty) ...[
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [pdfTitulo('Fotos'), paresDeFotos.first],
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
