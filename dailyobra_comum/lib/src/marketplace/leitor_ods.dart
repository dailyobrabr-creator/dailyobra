import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml_events.dart';

/// Repetição máxima de uma célula ou linha preenchida (as vazias repetidas nem viram células).
const _maxRepeticao = 1024;

String? _atributo(XmlStartElementEvent e, String nome) {
  for (final a in e.attributes) {
    if (a.name == nome) return a.value;
  }
  return null;
}

int _repeticao(XmlStartElementEvent e, String nome) => int.tryParse(_atributo(e, nome) ?? '') ?? 1;

/// Linhas da primeira tabela de um .ods, lidas em fluxo: o content.xml de um relatório do ERP passa de 30 MB e não cabe
/// numa árvore XML. Célula de número vem do office:value; de texto, dos parágrafos dela. Células vazias no fim da linha e
/// linhas vazias (repetidas ou não) saem. A cada 500 linhas devolve o controle à tela.
Future<List<List<String>>> lerOds(Uint8List bytes) async {
  final arquivo = ZipDecoder().decodeBytes(bytes).findFile('content.xml');
  if (arquivo == null) throw const FormatException('content.xml não encontrado no arquivo');
  final xml = utf8.decode(arquivo.content, allowMalformed: true);

  final linhas = <List<String>>[];
  var naTabela = false;
  List<String>? linha;
  var repeticaoLinha = 1;
  var vaziasPendentes = 0;
  StringBuffer? texto;
  String? numero;
  var repeticaoCelula = 1;
  var paragrafos = 0;
  var noParagrafo = false;
  var lidas = 0;

  void fecharCelula() {
    final t = texto;
    final atual = linha;
    if (t == null || atual == null) return;
    final valor = (numero ?? t.toString()).trim();
    texto = null;
    numero = null;
    if (valor.isEmpty) {
      vaziasPendentes += repeticaoCelula;
      return;
    }
    for (var i = 0; i < vaziasPendentes; i++) {
      atual.add('');
    }
    vaziasPendentes = 0;
    for (var i = 0; i < math.min(repeticaoCelula, _maxRepeticao); i++) {
      atual.add(valor);
    }
  }

  void fecharLinha() {
    final atual = linha;
    linha = null;
    if (atual == null || atual.isEmpty) return;
    for (var i = 0; i < math.min(repeticaoLinha, _maxRepeticao); i++) {
      linhas.add(i == 0 ? atual : List.of(atual));
    }
  }

  for (final e in parseEvents(xml)) {
    if (e is XmlStartElementEvent) {
      switch (e.name) {
        case 'table:table':
          naTabela = true;
        case 'table:table-row' when naTabela:
          linha = [];
          vaziasPendentes = 0;
          repeticaoLinha = _repeticao(e, 'table:number-rows-repeated');
          if (e.isSelfClosing) fecharLinha();
        case 'table:table-cell' || 'table:covered-table-cell' when linha != null:
          repeticaoCelula = _repeticao(e, 'table:number-columns-repeated');
          final tipo = _atributo(e, 'office:value-type');
          numero = tipo == 'float' || tipo == 'currency' || tipo == 'percentage' ? _atributo(e, 'office:value') : null;
          texto = StringBuffer();
          paragrafos = 0;
          if (e.isSelfClosing) fecharCelula();
        case 'text:p' when texto != null:
          if (paragrafos++ > 0) texto!.write(' ');
          noParagrafo = !e.isSelfClosing;
        case 'text:s' when noParagrafo:
          texto?.write(' ' * _repeticao(e, 'text:c'));
        case 'text:tab' || 'text:line-break' when noParagrafo:
          texto?.write(' ');
      }
    } else if (e is XmlEndElementEvent) {
      switch (e.name) {
        case 'text:p':
          noParagrafo = false;
        case 'table:table-cell' || 'table:covered-table-cell':
          fecharCelula();
        case 'table:table-row' when naTabela:
          fecharLinha();
          if (++lidas % 500 == 0) await Future<void>.delayed(Duration.zero);
        case 'table:table' when naTabela:
          return linhas;
      }
    } else if (e is XmlTextEvent && noParagrafo) {
      texto?.write(e.value);
    }
  }
  return linhas;
}
