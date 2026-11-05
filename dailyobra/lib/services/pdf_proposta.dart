import 'dart:typed_data';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_apoio.dart';

String nomeDaProposta(PropostaComercial p) => 'proposta-${p.numero}.pdf';

pw.Widget _linhaDoTotal(String rotulo, String valor, {bool forte = false}) {
  final estilo = pw.TextStyle(
    fontSize: forte ? 12 : 9.5,
    fontWeight: forte ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: pdfTexto,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(pdfLimpo(rotulo), style: estilo),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            pdfLimpo(valor),
            style: estilo,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _texto(String texto) => pw.Text(
  pdfLimpo(texto.trim()),
  style: const pw.TextStyle(fontSize: 9.5, color: pdfTexto),
);

/// A proposta como documento: pronta para o cliente assinar.
Future<Uint8List> pdfDaProposta({
  required PropostaComercial proposta,
  required DateTime hoje,
  MarcaEngenheiro? marca,
  Uint8List? logo,
}) {
  final p = proposta;
  final doc = pw.Document(
    title: pdfLimpo('Proposta ${p.numero} - ${p.titulo}'),
    author: marca?.nome.trim().isNotEmpty ?? false
        ? pdfLimpo(marca!.nome)
        : 'DailyObra',
    creator: 'DailyObra',
  );
  final lugar = [
    p.endereco.trim(),
    [p.cidade, p.uf].where((x) => x.trim().isNotEmpty).join(' - '),
  ].where((x) => x.isNotEmpty).join(' · ');
  final validade = p.validade;
  final prazo = p.prazoDias;
  final dados = [
    'Data: ${dataCurta(hoje)}/${hoje.year}',
    if (validade != null) 'Válida até ${dataCurta(validade)}/${validade.year}',
  ].join('   ·   ');
  final valores = p.valoresDasParcelas;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      maxPages: 20,
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            pdfLimpo('Proposta nº ${p.numero} · ${p.cliente}'),
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
          documento: 'PROPOSTA COMERCIAL Nº ${p.numero}',
          titulo: p.titulo,
          detalhe: lugar,
          marca: marca,
          logo: logo,
        ),
        pw.Text(
          pdfLimpo('Para: ${p.cliente}'),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: pdfTexto,
          ),
        ),
        if (p.contato.trim().isNotEmpty)
          pw.Text(
            pdfLimpo(p.contato),
            style: const pw.TextStyle(fontSize: 9.5, color: pdfSuave),
          ),
        pw.SizedBox(height: 3),
        pw.Text(
          pdfLimpo(dados),
          style: const pw.TextStyle(fontSize: 9.5, color: pdfSuave),
        ),
        if (p.inclui.trim().isNotEmpty)
          ...pdfParte(
            'O que está incluso',
            _texto(p.inclui),
            letras: p.inclui.length,
          ),
        if (p.naoInclui.trim().isNotEmpty)
          ...pdfParte(
            'O que não está incluso',
            _texto(p.naoInclui),
            letras: p.naoInclui.length,
          ),
        ...pdfParteComTabela(
          'Serviços',
          cabecalho: p.mostrarValores
              ? const ['Serviço', 'Valor']
              : const ['Serviço'],
          larguras: p.mostrarValores
              ? const {0: pw.FlexColumnWidth(), 1: pw.FixedColumnWidth(100)}
              : const {0: pw.FlexColumnWidth()},
          linhas: [
            for (final i in p.itens)
              [i.descricao, if (p.mostrarValores) brl.format(i.valor)],
          ],
        ),
        pw.SizedBox(height: 6),
        if (p.desconto > 0) ...[
          _linhaDoTotal('Subtotal', brl.format(p.subtotal)),
          _linhaDoTotal('Desconto', '- ${brl.format(p.desconto)}'),
        ],
        _linhaDoTotal('Total', brl.format(p.total), forte: true),
        if (p.parcelas.isNotEmpty)
          ...pdfParteComTabela(
            'Condições de pagamento',
            cabecalho: const ['Parcela', 'Quando', '%', 'Valor'],
            larguras: const {
              0: pw.FlexColumnWidth(),
              1: pw.FixedColumnWidth(100),
              2: pw.FixedColumnWidth(50),
              3: pw.FixedColumnWidth(90),
            },
            linhas: [
              for (final (i, x) in p.parcelas.indexed)
                [
                  x.descricao,
                  x.quando,
                  textoDePercentual(x.percentual),
                  brl.format(valores[i]),
                ],
            ],
          ),
        if (prazo != null)
          ...pdfParte(
            'Prazo',
            _texto(
              prazo == 1 ? '1 dia de execução.' : '$prazo dias de execução.',
            ),
            letras: 30,
          ),
        if (p.observacoes.trim().isNotEmpty)
          ...pdfParte(
            'Observações',
            _texto(p.observacoes),
            letras: p.observacoes.length,
          ),
        pw.SizedBox(height: 24),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pdfAssinatura('Responsável técnico', marca?.nome.trim() ?? ''),
            pw.SizedBox(width: 32),
            pdfAssinatura('De acordo, cliente', p.cliente),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
