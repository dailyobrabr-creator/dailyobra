// Lista de materiais estimada por etapa, a partir das casas de referência da planilha "Projetos Calculos".
// Mesma lógica de src/lib/orcamento/materiais.ts do app web.

import 'orcamento.dart';
import 'tabelas.dart';

part 'materiais_dados.dart';

/// Seções das planilhas "Projetos Calculos". O telhado aparente tem uma seção por número de águas.
enum SecaoMaterial {
  preparacao,
  fundacao,
  fundacaoLaje,
  estrutura,
  estruturaLaje,
  alvenaria,
  coberturaPlatibanda,
  telhado1Agua,
  telhado2Aguas,
  telhado3Aguas,
  eletrica,
  hidraulica,
  forro,
  revestimentos,
  pintura,
  acabamentos,
}

class ItemReferencia {
  const ItemReferencia({required this.item, required this.unidade, this.porM2, this.fixo, required this.precoRef});
  final String item;
  final String unidade;

  /// Quantidade por m² da etapa
  final double? porM2;

  /// Quantidade fixa por obra (ex.: relógio de água)
  final double? fixo;

  /// Preço da planilha, só referência até haver cotação
  final double precoRef;
}

class ItemMaterial {
  const ItemMaterial({required this.item, required this.unidade, required this.quantidadeExata, required this.quantidade, required this.precoRef});
  final String item;
  final String unidade;

  /// Quantidade calculada, sem arredondar
  final double quantidadeExata;

  /// Quantidade para compra: unidades inteiras, demais arredondadas para cima em 2 casas
  final double quantidade;
  final double precoRef;
  double get totalRef => quantidade * precoRef;
}

class EtapaMateriais {
  const EtapaMateriais({required this.etapa, required this.nome, required this.itens});
  final EtapaId etapa;
  final String nome;
  final List<ItemMaterial> itens;
  double get totalRef => itens.fold(0, (s, i) => s + i.totalRef);
}

sealed class ResultadoMateriais {
  const ResultadoMateriais();
}

class MateriaisDisponiveis extends ResultadoMateriais {
  const MateriaisDisponiveis({required this.etapas, required this.consolidado, required this.etapasSemLista});
  final List<EtapaMateriais> etapas;

  /// Mesma lista somada por item, para cotação
  final List<ItemMaterial> consolidado;

  /// Etapas do orçamento que ainda não têm lista de materiais na planilha
  final List<String> etapasSemLista;
  double get totalRef => consolidado.fold(0, (s, i) => s + i.totalRef);
}

class MateriaisIndisponiveis extends ResultadoMateriais {
  const MateriaisIndisponiveis(this.motivo);
  final String motivo;
}

// und, barra, balde, caixa, galão, lata: compra por unidade inteira
const _unidadesInteiras = {'und', 'br', 'bd', 'cx', 'gl', 'lt'};

double _arredondarCompra(double q, String unidade) {
  if (_unidadesInteiras.contains(unidade)) return (q - 1e-9).ceilToDouble();
  return (q * 100 - 1e-9).ceilToDouble() / 100;
}

SecaoMaterial? _secaoDaEtapa(EtapaId etapa, EntradaOrcamento e) {
  switch (etapa) {
    case EtapaId.aluguelEquipamentos:
    case EtapaId.calhasPlatibanda:
    case EtapaId.calhasTelhado:
    case EtapaId.esquadrias:
    case EtapaId.limpeza:
      return null;
    case EtapaId.telhadoAparente:
      return e.cobertura == TipoCobertura.telhadoAparente && e.aguas == 1 ? SecaoMaterial.telhado1Agua : SecaoMaterial.telhado2Aguas;
    case EtapaId.preparacao:
      return SecaoMaterial.preparacao;
    case EtapaId.fundacao:
      return SecaoMaterial.fundacao;
    case EtapaId.fundacaoLaje:
      return SecaoMaterial.fundacaoLaje;
    case EtapaId.estrutura:
      return SecaoMaterial.estrutura;
    case EtapaId.estruturaLaje:
      return SecaoMaterial.estruturaLaje;
    case EtapaId.alvenaria:
      return SecaoMaterial.alvenaria;
    case EtapaId.coberturaPlatibanda:
      return SecaoMaterial.coberturaPlatibanda;
    case EtapaId.telhado3Aguas:
      return SecaoMaterial.telhado3Aguas;
    case EtapaId.eletrica:
      return SecaoMaterial.eletrica;
    case EtapaId.hidraulica:
      return SecaoMaterial.hidraulica;
    case EtapaId.forro:
      return SecaoMaterial.forro;
    case EtapaId.revestimentos:
      return SecaoMaterial.revestimentos;
    case EtapaId.pintura:
      return SecaoMaterial.pintura;
    case EtapaId.acabamentos:
      return SecaoMaterial.acabamentos;
  }
}

ItemMaterial _item(ItemReferencia ref, double area) {
  final exata = ref.fixo ?? (ref.porM2 ?? 0) * area;
  return ItemMaterial(
    item: ref.item,
    unidade: ref.unidade,
    quantidadeExata: exata,
    quantidade: _arredondarCompra(exata, ref.unidade),
    precoRef: ref.precoRef,
  );
}

/// Ordem alfabética sem distinguir acentos e maiúsculas (equivalente simples ao localeCompare pt-BR)
String _chaveOrdem(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString().toLowerCase();
}

ResultadoMateriais listarMateriais(EntradaOrcamento e) {
  if (e.padrao == Padrao.medio) {
    return const MateriaisIndisponiveis(
      'A lista do padrão médio aguarda correção na planilha Projetos Calculos (casa de referência com medidas inconsistentes).',
    );
  }
  final orc = calcularOrcamento(e);
  final tabela = materiaisPorPadrao[e.padrao]!;
  final etapas = <EtapaMateriais>[];
  final semLista = <String>[];

  for (final linha in orc.etapas) {
    final secao = _secaoDaEtapa(linha.etapa, e);
    if (secao == null) {
      semLista.add(linha.nome);
      continue;
    }
    final itens = tabela[secao]!.map((ref) => _item(ref, linha.area)).toList();
    etapas.add(EtapaMateriais(etapa: linha.etapa, nome: linha.nome, itens: itens));
  }

  // Soma as quantidades exatas por item e só então arredonda, para não acumular arredondamentos
  final soma = <String, ItemMaterial>{};
  for (final it in etapas.expand((x) => x.itens)) {
    final chave = '${it.item}|${it.unidade}';
    final atual = soma[chave];
    soma[chave] = atual == null
        ? it
        : ItemMaterial(item: it.item, unidade: it.unidade, quantidadeExata: atual.quantidadeExata + it.quantidadeExata, quantidade: 0, precoRef: it.precoRef);
  }
  final consolidado = soma.values
      .map((it) => ItemMaterial(
            item: it.item,
            unidade: it.unidade,
            quantidadeExata: it.quantidadeExata,
            quantidade: _arredondarCompra(it.quantidadeExata, it.unidade),
            precoRef: it.precoRef,
          ))
      .toList()
    ..sort((a, b) => _chaveOrdem(a.item).compareTo(_chaveOrdem(b.item)));

  return MateriaisDisponiveis(etapas: etapas, consolidado: consolidado, etapasSemLista: semLista);
}
