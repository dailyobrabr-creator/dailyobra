import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_apoio.dart';

String nomeDoChecklist(Checklist c) =>
    'checklist-${c.modelo}-${dataIso(c.data)}.pdf';

/// O checklist como documento: registra o que foi verificado, por quem e quando.
Future<Uint8List> pdfDoChecklist({
  required Obra obra,
  required Checklist checklist,
  MarcaEngenheiro? marca,
  Uint8List? logo,
  Map<String, Uint8List> fotos = const {},
}) {
  final c = checklist;
  final dia = '${dataCurta(c.data)}/${c.data.year}';
  final doc = pw.Document(
    title: pdfLimpo('Checklist - ${c.titulo}'),
    author: marca?.nome.trim().isNotEmpty ?? false
        ? pdfLimpo(marca!.nome)
        : 'DailyObra',
    creator: 'DailyObra',
  );
  final conformidade = c.conformidade;
  final detalhes = [
    dia,
    if (c.local.trim().isNotEmpty) c.local.trim(),
    if (c.concluido && c.concluidoPor.isNotEmpty)
      'Concluído por ${c.concluidoPor}',
  ].join('   ·   ');
  final imagens = <(pw.MemoryImage, String)>[];
  for (final i in c.itens) {
    final imagem = pdfImagem(fotos[i.fotoPath]);
    if (imagem != null) imagens.add((imagem, i.texto));
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
      maxPages: 30,
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            pdfLimpo('${obra.nome} · $dia'),
            style: const pw.TextStyle(fontSize: 8, color: pdfSuave),
          ),
          pw.Text(
            pdfLimpo(
              'Feito no DailyObra · página ${ctx.pageNumber} de ${ctx.pagesCount}',
            ),
            style: const pw.TextStyle(fontSize: 8, color: pdfSuave),
          ),
        ],
      ),
      build: (ctx) => [
        ...pdfCabecalho(
          documento: 'CHECKLIST DE ${c.tipo.rotulo.toUpperCase()}',
          titulo: c.titulo,
          detalhe: [
            obra.nome,
            pdfLugar(obra),
          ].where((p) => p.isNotEmpty).join(' · '),
          marca: marca,
          logo: logo,
          selo: c.concluido ? null : 'Rascunho',
        ),
        pw.Text(
          pdfLimpo(detalhes),
          style: const pw.TextStyle(fontSize: 9.5, color: pdfSuave),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pdfNumero('Conformes', '${c.conformes}'),
            pdfNumero('Não conformes', '${c.naoConformes}'),
            pdfNumero('Não se aplica', '${c.naoSeAplica}'),
            pdfNumero(
              'Conformidade',
              conformidade == null ? '-' : '$conformidade%',
            ),
          ],
        ),
        ...pdfParteComTabela(
          'Itens verificados',
          cabecalho: const ['Item', 'Resultado', 'Observação'],
          larguras: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FixedColumnWidth(72),
            2: pw.FlexColumnWidth(3),
          },
          linhas: [
            for (final i in c.itens)
              [i.texto, i.resultado?.rotulo ?? '-', i.observacao],
          ],
        ),
        if (c.observacoes.trim().isNotEmpty)
          ...pdfParte(
            'Observações',
            pw.Text(
              pdfLimpo(c.observacoes.trim()),
              style: const pw.TextStyle(fontSize: 9.5, color: pdfTexto),
            ),
            letras: c.observacoes.length,
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
            pdfAssinatura('Responsável pela obra', obra.dados.responsavel),
            pw.SizedBox(width: 32),
            pdfAssinatura('Verificado por', c.concluidoPor),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
