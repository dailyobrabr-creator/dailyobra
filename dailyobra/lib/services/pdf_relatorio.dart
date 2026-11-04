import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_apoio.dart';

/// Quantas fotos o relatório leva, para continuar leve no WhatsApp.
const fotosNoRelatorio = 6;

String nomeDoRelatorio(SemanaObra semana) =>
    'relatorio-semanal-${dataIso(semana.inicio)}.pdf';

/// As últimas fotos da semana.
List<FotoDia> fotosDoRelatorio(ResumoDaSemana resumo) =>
    resumo.fotos.reversed.take(fotosNoRelatorio).toList().reversed.toList();

/// A semana da obra como documento para o cliente: sem valores, com a marca de quem assina.
Future<Uint8List> pdfDaSemana({
  required Obra obra,
  required RelatorioDaSemana relatorio,
  MarcaEngenheiro? marca,
  Uint8List? logo,
  Map<String, Uint8List> fotos = const {},
}) {
  final semana = relatorio.semana;
  final resumo = relatorio.resumo;
  final periodo =
      '${dataCurta(semana.inicio)} a ${dataCurta(semana.fim)}/${semana.fim.year}';
  final doc = pw.Document(
    title: pdfLimpo('Relatório semanal - ${obra.nome}'),
    author: marca?.nome.trim().isNotEmpty ?? false
        ? pdfLimpo(marca!.nome)
        : 'DailyObra',
    creator: 'DailyObra',
  );
  final imagens = <(pw.MemoryImage, String)>[];
  for (final f in fotosDoRelatorio(resumo)) {
    final imagem = pdfImagem(fotos[f.caminho]);
    if (imagem != null) imagens.add((imagem, f.legenda));
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
  final termino = relatorio.termino;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      maxPages: 30,
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            pdfLimpo('${obra.nome} · $periodo'),
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
          documento: 'RELATÓRIO SEMANAL',
          titulo: obra.nome,
          detalhe: pdfLugar(obra),
          marca: marca,
          logo: logo,
        ),
        pw.Text(
          pdfLimpo('Semana de $periodo'),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: pdfTexto,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pdfNumero('Andamento', '${relatorio.andamento}%'),
            pdfNumero('Dias registrados', '${resumo.dias.length}'),
            pdfNumero('Pessoas por dia', '${resumo.mediaDePessoas}'),
            pdfNumero(
              'Previsão de término',
              termino == null ? '-' : '${dataCurta(termino)}/${termino.year}',
            ),
          ],
        ),
        if (relatorio.etapaAtual != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              pdfLimpo('Etapa atual: ${relatorio.etapaAtual}'),
              style: const pw.TextStyle(fontSize: 10, color: pdfTexto),
            ),
          ),
        if (resumo.atividades.isNotEmpty)
          ...pdfParteComTabela(
            'O que foi feito',
            cabecalho: const ['Serviço', 'Local', 'Pronto'],
            larguras: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(2),
              2: pw.FixedColumnWidth(46),
            },
            linhas: [
              for (final a in resumo.atividades)
                [
                  a.descricao,
                  a.local,
                  if (a.percentual == null) '' else '${a.percentual}%',
                ],
            ],
          ),
        if (resumo.ocorrencias.isNotEmpty)
          ...pdfParteComTabela(
            'Ocorrências',
            cabecalho: const ['Tipo', 'Descrição'],
            larguras: const {
              0: pw.FixedColumnWidth(70),
              1: pw.FlexColumnWidth(),
            },
            linhas: [
              for (final o in resumo.ocorrencias) [o.tipo.rotulo, o.descricao],
            ],
          ),
        if (relatorio.mudancas.isNotEmpty)
          ...pdfParteComTabela(
            'Mudanças',
            cabecalho: const ['Mudança', 'Prazo', 'Situação'],
            larguras: const {
              0: pw.FlexColumnWidth(),
              1: pw.FixedColumnWidth(60),
              2: pw.FixedColumnWidth(110),
            },
            linhas: [
              for (final m in relatorio.mudancas)
                [m.titulo, m.impactoNoPrazo, m.situacao.rotulo],
            ],
          ),
        if (relatorio.proximas.isNotEmpty)
          ...pdfParteComTabela(
            'Próximos passos',
            cabecalho: const ['Etapa', 'Início', 'Fim'],
            larguras: const {
              0: pw.FlexColumnWidth(),
              1: pw.FixedColumnWidth(60),
              2: pw.FixedColumnWidth(60),
            },
            linhas: [
              for (final p in relatorio.proximas)
                [p.nome, dataCurta(p.inicio), dataCurta(p.fim)],
            ],
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
      ],
    ),
  );
  return doc.save();
}
