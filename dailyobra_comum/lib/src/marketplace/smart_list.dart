import 'modelos.dart';
import 'texto.dart';

/// Lista de materiais digitada ou colada pelo construtor ("100 sacos de cimento", "ferro 5/16 20 barras")
/// transformada em produtos do catálogo com quantidade.
enum TipoLinha { reconhecido, escolher, naoReconhecido }

class LinhaSmartList {
  const LinhaSmartList({
    required this.original,
    required this.quantidade,
    this.unidadeFalada,
    required this.tipo,
    this.item,
    this.candidatos = const [],
  });
  final String original;
  final double quantidade;

  /// Unidade que o construtor escreveu ("saco", "barra", "m3"), na forma canônica.
  final String? unidadeFalada;
  final TipoLinha tipo;
  final ItemCatalogo? item;

  /// Produtos parecidos para o construtor escolher quando o texto não basta (até 3).
  final List<ItemCatalogo> candidatos;

  LinhaSmartList escolher(ItemCatalogo escolhido) => LinhaSmartList(
        original: original,
        quantidade: quantidade,
        unidadeFalada: unidadeFalada,
        tipo: TipoLinha.reconhecido,
        item: escolhido,
      );

  LinhaSmartList comQuantidade(double nova) => LinhaSmartList(
        original: original,
        quantidade: nova,
        unidadeFalada: unidadeFalada,
        tipo: tipo,
        item: item,
        candidatos: candidatos,
      );
}

/// Unidades de compra como o construtor escreve, na forma canônica usada para comparar com o catálogo.
const _unidades = {
  'saco': 'saco', 'sacos': 'saco', 'sc': 'saco', 'scs': 'saco',
  'barra': 'barra', 'barras': 'barra', 'br': 'barra', 'vara': 'barra', 'varas': 'barra',
  'rolo': 'rolo', 'rolos': 'rolo',
  'un': 'un', 'und': 'un', 'unid': 'un', 'unidade': 'un', 'unidades': 'un',
  'pc': 'un', 'pcs': 'un', 'peca': 'un', 'pecas': 'un',
  'm3': 'm3', 'm2': 'm2', 'm': 'm', 'mt': 'm', 'mts': 'm', 'metro': 'm', 'metros': 'm',
  'milheiro': 'milheiro', 'milheiros': 'milheiro',
  'lata': 'lata', 'latas': 'lata', 'galao': 'galao', 'galoes': 'galao', 'gl': 'galao',
  'kg': 'kg', 'kgs': 'kg', 'quilo': 'kg', 'quilos': 'kg',
  'caixa': 'caixa', 'caixas': 'caixa', 'cx': 'caixa', 'cxs': 'caixa',
  'pacote': 'pacote', 'pacotes': 'pacote', 'pct': 'pacote',
  'l': 'l', 'lt': 'l', 'lts': 'l', 'litro': 'l', 'litros': 'l',
  'balde': 'balde', 'baldes': 'balde', 'folha': 'folha', 'folhas': 'folha',
  'painel': 'painel', 'paineis': 'painel', 'kit': 'kit', 'kits': 'kit',
  'par': 'par', 'pares': 'par', 'jogo': 'jogo', 'jogos': 'jogo',
};

/// No meio da linha, "50 kg" ou "100 m" costuma ser o tamanho do produto, não a quantidade.
const _soNoComeco = {'kg', 'm', 'l'};

/// Logo depois do número do começo, estas palavras indicam medida ("2,5 mm"), não quantidade.
const _medidas = {'mm', 'cm', 'pol', 'polegada', 'polegadas', 'w', 'v'};
const _medidasColadas = {'kg', 'g'};

const _semPeso = {'de', 'da', 'do', 'das', 'dos', 'e', 'com', 'para', 'p', 'em', 'a', 'o', 'os', 'as', 'um', 'uma', 'tipo', 'marca'};

/// "1.000", "1.000,5", "2,5", "10.5" ou "100"; a fração ("1/2") só vale no começo da linha.
const _numero = r'\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d{1,7}(?:[.,]\d+)?';
final _numeroInicial = RegExp('^(\\d{1,7}/\\d{1,4}|$_numero)(?![\\d/])( ?)([a-z][a-z0-9]*)?');
final _numeroComUnidade = RegExp('(?<![\\da-z/.,])($_numero)(?![\\d/]) ?([a-z][a-z0-9]*)');
final _decimalComPonto = RegExp(r'(\d)\.(\d{1,2})(?!\d)');
final _medidaSeparada = RegExp(r'(\d) (mm|cm|kg|m|g|l|w|v|pol)\b');
final _pontaDeSinal = RegExp(r'^[.,/]+|[.,/]+$');
final _temDigito = RegExp(r'\d');
final _temTexto = RegExp(r'[a-z0-9]');

double? _lerNumero(String s) {
  if (s.contains('/')) {
    final p = s.split('/');
    final a = double.tryParse(p[0]), b = double.tryParse(p[1]);
    return (a == null || b == null || b == 0) ? null : a / b;
  }
  if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(s)) {
    return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
  }
  return double.tryParse(s.replaceAll(',', '.'));
}

String _singular(String t) {
  if (t.length <= 3 || _temDigito.hasMatch(t)) return t;
  if (t.endsWith('oes')) return '${t.substring(0, t.length - 3)}ao';
  if (t.endsWith('s')) return t.substring(0, t.length - 1);
  return t;
}

/// Termos de comparação: medidas juntas ("2,5 mm" → "2,5mm"), sem palavras vazias, no singular.
List<String> _termos(String normalizado) {
  final t = normalizado
      .replaceAllMapped(_decimalComPonto, (m) => '${m[1]},${m[2]}')
      .replaceAllMapped(_medidaSeparada, (m) => '${m[1]}${m[2]}');
  return [
    for (final p in t.split(' '))
      if (p.replaceAll(_pontaDeSinal, '') case final limpo when limpo.isNotEmpty && !_semPeso.contains(limpo)) _singular(limpo),
  ];
}

class _Indice {
  _Indice(this.item) {
    unidade = _canonica(normalizar(item.unidade));
    for (final t in _termos(normalizar(item.nome))) {
      if (_temDigito.hasMatch(t)) {
        medidas.add(t);
      } else if (!_ehUnidade(t)) {
        nome.add(t);
      }
    }
    for (final s in item.sinonimos) {
      for (final t in _termos(normalizar(s))) {
        if (_temDigito.hasMatch(t)) {
          medidas.add(t);
        } else if (!_ehUnidade(t)) {
          sinonimos.add(t);
        }
      }
    }
  }
  final ItemCatalogo item;
  late final String unidade;
  final medidas = <String>{};
  final sinonimos = <String>{};
  final nome = <String>{};

  /// Medida em comum vale 3, sinônimo 2, palavra do nome 1, unidade igual 1. Sem nenhuma
  /// palavra em comum não pontua: "joelho 25mm" não deve virar qualquer produto de 25 mm.
  int pontuar(Set<String> termos, String? unidadeFalada) {
    var p = 0;
    var palavra = false;
    for (final t in termos) {
      if (medidas.contains(t)) {
        p += 3;
      } else if (sinonimos.contains(t)) {
        p += 2;
        palavra = true;
      } else if (nome.contains(t)) {
        p += 1;
        palavra = true;
      }
    }
    if (!palavra) return 0;
    if (unidadeFalada != null && unidadeFalada == unidade) p += 1;
    return p;
  }
}

String _canonica(String u) => _unidades[_singular(u)] ?? _unidades[u] ?? u;
bool _ehUnidade(String t) => _unidades.containsKey(t);

/// Unidade num jeito só ("m²" e "M2", "unidade" e "UN", "Saco" e "SC"), para comparar a da planilha com a do catálogo.
String unidadeCanonica(String unidade) => _canonica(normalizar(unidade));

/// Liga nomes de produto (de uma planilha, por exemplo) ao catálogo com a mesma pontuação da lista inteligente,
/// sem ler quantidade no começo do nome. Monta os índices uma vez para muitos nomes.
class ReconhecedorDeProdutos {
  ReconhecedorDeProdutos(List<ItemCatalogo> catalogo) : _indices = [for (final i in catalogo) _Indice(i)];
  final List<_Indice> _indices;

  LinhaSmartList reconhecer(String nome) => _decidir(nome.trim(), null, null, normalizar(nome), _indices);
}

List<LinhaSmartList> interpretarLista(String texto, List<ItemCatalogo> catalogo) {
  final indices = [for (final i in catalogo) _Indice(i)];
  final linhas = <LinhaSmartList>[];
  for (final bruta in texto.split(RegExp(r'\r?\n'))) {
    final original = bruta.trim();
    final n = normalizar(original);
    if (!_temTexto.hasMatch(n)) continue;
    linhas.add(_interpretarLinha(original, n, indices));
  }
  return linhas;
}

LinhaSmartList _interpretarLinha(String original, String n, List<_Indice> indices) {
  final ini = _numeroInicial.firstMatch(n);
  final palavraIni = ini?[3];
  final coladaIni = ini != null && ini[2]!.isEmpty && palavraIni != null;
  final iniEhMedida = palavraIni != null && (_medidas.contains(palavraIni) || (coladaIni && _medidasColadas.contains(palavraIni)));

  if (ini != null && !iniEhMedida && palavraIni != null && _ehUnidade(palavraIni)) {
    return _decidir(original, _lerNumero(ini[1]!), _unidades[palavraIni], n.substring(ini.end), indices);
  }

  RegExpMatch? noMeio, fraco;
  for (final m in _numeroComUnidade.allMatches(n)) {
    final u = _unidades[m[2]!];
    if (u == null) continue;
    if (_soNoComeco.contains(u)) {
      fraco = m;
    } else {
      noMeio = m;
    }
  }
  if (noMeio != null) {
    return _decidir(original, _lerNumero(noMeio[1]!), _unidades[noMeio[2]!], n.replaceRange(noMeio.start, noMeio.end, ' '), indices);
  }
  if (ini != null && !iniEhMedida) {
    return _decidir(original, _lerNumero(ini[1]!), null, n.substring(ini[1]!.length), indices);
  }
  if (fraco != null) {
    // "prego 2 kg" é quantidade; "cimento 50 kg" é o tamanho do saco. Só fica como quantidade
    // quando o produto reconhecido é vendido nessa unidade.
    final unidade = _unidades[fraco[2]!]!;
    final tentativa = _decidir(original, _lerNumero(fraco[1]!), unidade, n.replaceRange(fraco.start, fraco.end, ' '), indices);
    if (tentativa.tipo == TipoLinha.reconhecido && _canonica(normalizar(tentativa.item!.unidade)) == unidade) return tentativa;
  }
  return _decidir(original, 1, null, n, indices);
}

LinhaSmartList _decidir(String original, double? quantidade, String? unidade, String resto, List<_Indice> indices) {
  if (quantidade == null || !quantidade.isFinite || quantidade <= 0) quantidade = 1;

  final termos = <String>{};
  for (final t in _termos(resto)) {
    if (_ehUnidade(t)) {
      unidade ??= _unidades[t];
    } else {
      termos.add(t);
    }
  }

  final pontuados = [
    for (final i in indices)
      if (i.pontuar(termos, unidade) case final p when p > 0) (indice: i, pontos: p),
  ]..sort((a, b) => b.pontos.compareTo(a.pontos));

  final melhor = pontuados.isEmpty ? 0 : pontuados.first.pontos;
  final segundo = pontuados.length > 1 ? pontuados[1].pontos : 0;
  if (melhor >= 2 && melhor - segundo >= 2) {
    return LinhaSmartList(
      original: original, quantidade: quantidade, unidadeFalada: unidade,
      tipo: TipoLinha.reconhecido, item: pontuados.first.indice.item,
    );
  }
  if (melhor >= 2) {
    return LinhaSmartList(
      original: original, quantidade: quantidade, unidadeFalada: unidade, tipo: TipoLinha.escolher,
      candidatos: [
        for (final p in pontuados.where((p) => p.pontos >= 2 && melhor - p.pontos < 2).take(3)) p.indice.item,
      ],
    );
  }
  return LinhaSmartList(original: original, quantidade: quantidade, unidadeFalada: unidade, tipo: TipoLinha.naoReconhecido);
}

/// Soma as quantidades das linhas já ligadas a um produto, por id do catálogo.
Map<String, double> somarPorItem(List<LinhaSmartList> linhas) {
  final soma = <String, double>{};
  for (final l in linhas) {
    final item = l.item;
    if (item == null) continue;
    soma[item.id] = (soma[item.id] ?? 0) + l.quantidade;
  }
  return soma;
}
