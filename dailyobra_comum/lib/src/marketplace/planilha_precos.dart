import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'modelos.dart';
import 'smart_list.dart';
import 'texto.dart';

/// Planilha que não dá para importar, com o motivo pronto para a tela.
class PlanilhaInvalida implements Exception {
  const PlanilhaInvalida(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

const maxLinhasImportacao = 3000;

/// Separador da primeira linha (entre as 10 primeiras com texto) que tem ";", "," ou tabulação fora de aspas.
String _separador(String texto) {
  final linhas = texto.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).take(10);
  for (final linha in linhas) {
    final contagem = {';': 0, ',': 0, '\t': 0};
    var aspas = false;
    var campoVazio = true;
    for (final ch in linha.split('')) {
      if (ch == '"' && (aspas || campoVazio)) {
        aspas = !aspas;
        campoVazio = false;
      } else if (!aspas && contagem.containsKey(ch)) {
        contagem[ch] = contagem[ch]! + 1;
        campoVazio = true;
      } else if (ch.trim().isNotEmpty) {
        campoVazio = false;
      }
    }
    final maior = contagem.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (maior.value > 0) return maior.key;
  }
  return ';';
}

/// Linhas e células de um CSV: separador ";", "," ou tabulação, aspas no começo da célula (com "" dentro), BOM do Excel
/// e quebra de linha do Windows. Aspa no meio do texto é texto ("TUBO 3/4""). Células sem espaço nas pontas.
List<List<String>> lerCsv(String texto) {
  if (texto.startsWith('﻿')) texto = texto.substring(1);
  final sep = _separador(texto);
  final linhas = <List<String>>[];
  var linha = <String>[];
  final celula = StringBuffer();
  var aspas = false;
  void fecharCelula() {
    linha.add(celula.toString().trim());
    celula.clear();
  }

  for (var i = 0; i < texto.length; i++) {
    final ch = texto[i];
    if (aspas) {
      if (ch != '"') {
        celula.write(ch);
      } else if (i + 1 < texto.length && texto[i + 1] == '"') {
        celula.write('"');
        i++;
      } else {
        aspas = false;
      }
    } else if (ch == '"' && celula.toString().trim().isEmpty) {
      // Aspa abre citação só no começo da célula; no meio é texto (polegada: TUBO 3/4")
      aspas = true;
    } else if (ch == sep) {
      fecharCelula();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < texto.length && texto[i + 1] == '\n') i++;
      fecharCelula();
      linhas.add(linha);
      linha = <String>[];
    } else {
      celula.write(ch);
    }
  }
  if (celula.isNotEmpty || linha.isNotEmpty) {
    fecharCelula();
    linhas.add(linha);
  }
  return linhas;
}

/// Índice da coluna pela referência da célula ("A1" → 0, "B3" → 1, "AA7" → 26).
int _coluna(String referencia) {
  var n = 0;
  for (final u in referencia.toUpperCase().codeUnits) {
    if (u < 65 || u > 90) break;
    n = n * 26 + (u - 64);
  }
  return n - 1;
}

String _valorDaCelula(XmlElement c, List<String> compartilhados) {
  final v = c.findElements('v', namespaceUri: '*').firstOrNull?.innerText ?? '';
  switch (c.getAttribute('t')) {
    case 's':
      final i = int.tryParse(v);
      return i != null && i >= 0 && i < compartilhados.length ? compartilhados[i] : '';
    case 'inlineStr':
      return c.findAllElements('t', namespaceUri: '*').map((t) => t.innerText).join().trim();
    case 'str' || 'b' || 'e':
      return v.trim();
  }
  final n = double.tryParse(v);
  if (n == null) return v.trim();
  if (n == n.truncateToDouble() && n.abs() < 1e15) return n.toInt().toString();
  return n.toString().replaceAll('.', ',');
}

/// Caminho da primeira planilha do .xlsx, pela ordem do workbook.
String _primeiraPlanilha(String? Function(String) ler) {
  const padrao = 'xl/worksheets/sheet1.xml';
  final workbook = ler('xl/workbook.xml');
  final relacoes = ler('xl/_rels/workbook.xml.rels');
  if (workbook == null || relacoes == null) return padrao;
  final planilha = XmlDocument.parse(workbook).findAllElements('sheet', namespaceUri: '*').firstOrNull;
  final id = planilha?.attributes.where((a) => a.name.local == 'id').firstOrNull?.value;
  if (id == null) return padrao;
  final alvo = XmlDocument.parse(relacoes)
      .findAllElements('Relationship', namespaceUri: '*')
      .where((r) => r.getAttribute('Id') == id)
      .firstOrNull
      ?.getAttribute('Target');
  if (alvo == null) return padrao;
  return alvo.startsWith('/') ? alvo.substring(1) : 'xl/$alvo';
}

/// Linhas da primeira planilha de um .xlsx. Número vira texto no formato brasileiro ("45,9"); célula pulada vira "".
List<List<String>> lerXlsx(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  String? ler(String nome) {
    final arquivo = zip.findFile(nome);
    return arquivo == null ? null : utf8.decode(arquivo.content, allowMalformed: true);
  }

  final compartilhados = <String>[];
  final textos = ler('xl/sharedStrings.xml');
  if (textos != null) {
    for (final si in XmlDocument.parse(textos).findAllElements('si', namespaceUri: '*')) {
      compartilhados.add(si.findAllElements('t', namespaceUri: '*').map((t) => t.innerText).join().trim());
    }
  }
  final planilha = ler(_primeiraPlanilha(ler));
  if (planilha == null) throw const FormatException('Planilha não encontrada no arquivo');
  final linhas = <List<String>>[];
  for (final row in XmlDocument.parse(planilha).findAllElements('row', namespaceUri: '*')) {
    final numero = int.tryParse(row.getAttribute('r') ?? '') ?? linhas.length + 1;
    while (linhas.length < numero - 1) {
      linhas.add(<String>[]);
    }
    final celulas = <String>[];
    for (final c in row.findElements('c', namespaceUri: '*')) {
      final referencia = c.getAttribute('r');
      final coluna = referencia == null ? celulas.length : _coluna(referencia);
      while (celulas.length < coluna) {
        celulas.add('');
      }
      celulas.add(_valorDaCelula(c, compartilhados));
    }
    linhas.add(celulas);
  }
  return linhas;
}

/// Texto do CSV: UTF-8 e, se não for, Latin-1 (o "CSV separado por vírgulas" do Excel no Windows).
String _textoDoCsv(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Lê o arquivo pela extensão, descarta as linhas vazias e confere os limites da importação.
List<List<String>> lerPlanilha(String nomeArquivo, Uint8List bytes) {
  final nome = nomeArquivo.toLowerCase();
  List<List<String>> linhas;
  if (nome.endsWith('.csv')) {
    linhas = lerCsv(_textoDoCsv(bytes));
  } else if (nome.endsWith('.xlsx')) {
    try {
      linhas = lerXlsx(bytes);
    } catch (_) {
      throw const PlanilhaInvalida('Não deu para ler o arquivo. Abra no Excel, salve de novo como .xlsx ou .csv e tente outra vez.');
    }
  } else {
    throw const PlanilhaInvalida('Envie um arquivo .csv ou .xlsx.');
  }
  linhas = [for (final l in linhas) if (l.any((c) => c.trim().isNotEmpty)) l];
  if (linhas.isEmpty) throw const PlanilhaInvalida('A planilha está vazia.');
  if (linhas.length == 1) throw const PlanilhaInvalida('A planilha só tem o cabeçalho.');
  if (linhas.length - 1 > maxLinhasImportacao) throw const PlanilhaInvalida('A planilha passa de 3.000 produtos. Divida em partes.');
  return linhas;
}

/// Onde está cada informação na planilha: a linha do cabeçalho e o índice de cada coluna.
class ColunasPlanilha {
  const ColunasPlanilha({this.linhaCabecalho = 0, this.nome, this.preco, this.promocao, this.unidade, this.codigo});
  final int linhaCabecalho;
  final int? nome;
  final int? preco;
  final int? promocao;
  final int? unidade;
  final int? codigo;

  bool get completas => nome != null && preco != null;

  /// Colunas escolhidas pela loja quando o cabeçalho não diz.
  ColunasPlanilha copyWith({int? nome, int? preco}) => ColunasPlanilha(
    linhaCabecalho: linhaCabecalho, nome: nome ?? this.nome, preco: preco ?? this.preco, promocao: promocao, unidade: unidade, codigo: codigo,
  );
}

ColunasPlanilha _colunasDe(List<String> cabecalho, int linha) {
  final n = [for (final c in cabecalho) normalizar(c)];
  int? achar(bool Function(String) teste, [Set<int> fora = const {}]) {
    for (var i = 0; i < n.length; i++) {
      if (!fora.contains(i) && n[i].isNotEmpty && teste(n[i])) return i;
    }
    return null;
  }

  final promocao = achar((c) => c.contains('promo') || c == 'oferta' || c.startsWith('preco oferta'));
  final semPromocao = {?promocao};
  final preco = achar((c) => (c.contains('preco') || c.contains('valor')) && c.contains('venda'), semPromocao) ??
      achar((c) => const {'preco', 'valor', 'preco unitario', 'valor unitario', 'preco un', 'valor un', 'preco r', 'valor r'}.contains(c), semPromocao) ??
      achar((c) => (c.startsWith('preco') || c.startsWith('valor')) && !c.contains('custo') && !c.contains('total'), semPromocao);
  // "Item" costuma ser a numeração das linhas: vale como nome só sem coluna de produto, descrição ou nome
  final nome = achar((c) => const {'produto', 'descricao', 'nome'}.contains(c) || c.startsWith('descricao') || c.startsWith('produto') || c.startsWith('nome do produto')) ??
      achar((c) => c == 'item');
  final unidade = achar((c) => const {'unidade', 'un', 'und', 'unid', 'unidade de medida', 'unidade medida'}.contains(c));
  final codigo = achar((c) => const {'codigo', 'sku', 'ref', 'referencia', 'cod'}.contains(c) || c.startsWith('codigo'));
  return ColunasPlanilha(linhaCabecalho: linha, nome: nome, preco: preco, promocao: promocao, unidade: unidade, codigo: codigo);
}

/// Cabeçalho entre as 10 primeiras linhas: a primeira que tem coluna de nome e de preço. Sem nenhuma assim, devolve o
/// que der para achar na primeira linha (a loja escolhe o resto).
ColunasPlanilha detectarColunas(List<List<String>> linhas) {
  for (var i = 0; i < linhas.length && i < 10; i++) {
    final c = _colunasDe(linhas[i], i);
    if (c.completas) return c;
  }
  return linhas.isEmpty ? const ColunasPlanilha() : _colunasDe(linhas.first, 0);
}

final _numeroDoPreco = RegExp(r'\d[\d.,]*');
final _separadorNoFim = RegExp(r'[.,]+$');

/// Primeiro número do texto como preço: "R$ 1.234,56", "1234,56", "45.90", "1.234" e "45,90 / sc". Com ponto e vírgula, o
/// último é o decimal; só ponto é milhar quando todos os grupos depois do primeiro têm 3 dígitos e o primeiro não é zero
/// ("0.125" é decimal). Sem número, ou zero, é inválido (null).
double? lerPreco(String texto) {
  final achado = _numeroDoPreco.firstMatch(texto);
  if (achado == null) return null;
  var s = achado[0]!.replaceAll(_separadorNoFim, '');
  final ponto = s.lastIndexOf('.');
  final virgula = s.lastIndexOf(',');
  if (ponto >= 0 && virgula >= 0) {
    s = virgula > ponto ? s.replaceAll('.', '').replaceAll(',', '.') : s.replaceAll(',', '');
  } else if (virgula >= 0) {
    final partes = s.split(',');
    s = '${partes.sublist(0, partes.length - 1).join()}.${partes.last}';
  } else if (ponto >= 0) {
    final partes = s.split('.');
    final milhar = partes.first != '0' && partes.skip(1).every((p) => p.length == 3);
    s = milhar ? partes.join() : '${partes.sublist(0, partes.length - 1).join()}.${partes.last}';
  }
  final valor = double.tryParse(s);
  return valor == null || valor <= 0 ? null : valor;
}

enum GrupoImportacao { ligado, escolher, fora }

enum AvisoImportacao { unidadeDiferente, repetido, precoInvalido, promocaoIgnorada }

Set<AvisoImportacao> _avisosDe(ItemCatalogo? item, String? unidade, double? preco) => {
  if (preco == null || preco <= 0) AvisoImportacao.precoInvalido,
  if (item != null && unidade != null && unidadeCanonica(unidade) != unidadeCanonica(item.unidade)) AvisoImportacao.unidadeDiferente,
};

/// Um produto da planilha ligado (ou não) ao catálogo, como a loja vê na revisão.
class LinhaImportacao {
  const LinhaImportacao({
    required this.numero,
    required this.nome,
    this.codigo,
    this.unidadePlanilha,
    required this.grupo,
    this.item,
    this.candidatos = const [],
    this.preco,
    this.promocao,
    this.avisos = const {},
    this.marcada = false,
  });

  /// Posição entre as linhas da planilha que têm conteúdo (1 = primeira).
  final int numero;
  final String nome;
  final String? codigo;
  final String? unidadePlanilha;
  final GrupoImportacao grupo;
  final ItemCatalogo? item;
  final List<ItemCatalogo> candidatos;
  final double? preco;
  final double? promocao;
  final Set<AvisoImportacao> avisos;
  final bool marcada;

  /// Escolha do item entre os candidatos, preço corrigido ou marcação; unidade e preço são conferidos de novo.
  LinhaImportacao copyWith({ItemCatalogo? item, double? preco, bool? marcada}) {
    final novoItem = item ?? this.item;
    final novoPreco = preco ?? this.preco;
    return LinhaImportacao(
      numero: numero, nome: nome, codigo: codigo, unidadePlanilha: unidadePlanilha, grupo: grupo, item: novoItem, candidatos: candidatos,
      preco: novoPreco, promocao: promocao, marcada: marcada ?? this.marcada,
      avisos: {...avisos.difference({AvisoImportacao.unidadeDiferente, AvisoImportacao.precoInvalido}), ..._avisosDe(novoItem, unidadePlanilha, novoPreco)},
    );
  }

  LinhaImportacao _repetida() => LinhaImportacao(
    numero: numero, nome: nome, codigo: codigo, unidadePlanilha: unidadePlanilha, grupo: grupo, item: item, candidatos: candidatos,
    preco: preco, promocao: promocao, avisos: {...avisos, AvisoImportacao.repetido},
  );
}

/// Liga cada produto da planilha ao catálogo e decide o que já vem marcado: só o ligado, com preço válido e a mesma
/// unidade; entre marcados no mesmo item, só o mais barato. Promoção maior ou igual ao preço é ignorada.
List<LinhaImportacao> montarImportacao(List<List<String>> linhas, ColunasPlanilha colunas, List<ItemCatalogo> catalogo) {
  final reconhecedor = ReconhecedorDeProdutos(catalogo);
  String? celula(List<String> linha, int? i) {
    if (i == null || i >= linha.length) return null;
    final v = linha[i].trim();
    return v.isEmpty ? null : v;
  }

  final resultado = <LinhaImportacao>[];
  for (var i = colunas.linhaCabecalho + 1; i < linhas.length; i++) {
    final linha = linhas[i];
    final nome = celula(linha, colunas.nome);
    if (nome == null) continue;
    final preco = lerPreco(celula(linha, colunas.preco) ?? '');
    var promocao = colunas.promocao == null ? null : lerPreco(celula(linha, colunas.promocao) ?? '');
    final unidade = celula(linha, colunas.unidade);
    final r = reconhecedor.reconhecer(nome);
    final grupo = switch (r.tipo) {
      TipoLinha.reconhecido => GrupoImportacao.ligado,
      TipoLinha.escolher => GrupoImportacao.escolher,
      TipoLinha.naoReconhecido => GrupoImportacao.fora,
    };
    final avisos = _avisosDe(r.item, unidade, preco);
    if (promocao != null && preco != null && promocao >= preco) {
      promocao = null;
      avisos.add(AvisoImportacao.promocaoIgnorada);
    }
    resultado.add(LinhaImportacao(
      numero: i + 1, nome: nome, codigo: celula(linha, colunas.codigo), unidadePlanilha: unidade, grupo: grupo, item: r.item,
      candidatos: r.candidatos, preco: preco, promocao: promocao, avisos: avisos,
      marcada: grupo == GrupoImportacao.ligado && !avisos.contains(AvisoImportacao.unidadeDiferente) && !avisos.contains(AvisoImportacao.precoInvalido),
    ));
  }

  final porItem = <String, List<int>>{};
  for (var i = 0; i < resultado.length; i++) {
    final item = resultado[i].item;
    if (resultado[i].marcada && item != null) (porItem[item.id] ??= []).add(i);
  }
  for (final indices in porItem.values.where((x) => x.length > 1)) {
    indices.sort((a, b) {
      final c = resultado[a].preco!.compareTo(resultado[b].preco!);
      return c != 0 ? c : a.compareTo(b);
    });
    for (final i in indices.skip(1)) {
      resultado[i] = resultado[i]._repetida();
    }
  }
  return resultado;
}

/// Ofertas a gravar: só as linhas marcadas com item e preço; a promoção entra só com a validade. Se a loja marcar duas
/// linhas no mesmo item, vai a mais barata (o lote não pode ter o mesmo item duas vezes).
List<Oferta> ofertasDaImportacao(List<LinhaImportacao> linhas, {required String lojaId, DateTime? promoAte}) {
  final porItem = <String, Oferta>{};
  for (final l in linhas) {
    final item = l.item;
    final preco = l.preco;
    if (!l.marcada || item == null || preco == null || preco <= 0) continue;
    final promocao = l.promocao;
    final comPromocao = promoAte != null && promocao != null && promocao < preco;
    final oferta = Oferta(
      lojaId: lojaId, itemId: item.id, preco: preco,
      precoPromocional: comPromocao ? promocao : null, promoAte: comPromocao ? promoAte : null,
    );
    final atual = porItem[item.id];
    if (atual == null || preco < atual.preco) porItem[item.id] = oferta;
  }
  return porItem.values.toList();
}
