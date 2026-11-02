// Motor de orçamento de obra nova residencial, extraído da planilha "Orçamento de Obra 09.2025.xlsm"
// (abas Res1/Res2). Mesma lógica de src/lib/orcamento/orcamento.ts do app web.

import 'tabelas.dart';

enum TipoCobertura { platibanda, telhadoAparente }

class Muro {
  const Muro({required this.frente, required this.areaTerreno, required this.acabamento});
  final double frente;
  final double areaTerreno;
  final AcabamentoMuro acabamento;
}

class Piscina {
  const Piscina({required this.comprimento, required this.largura, required this.tipo});
  final double comprimento;
  final double largura;
  final TipoPiscina tipo;
}

class EntradaOrcamento {
  const EntradaOrcamento({
    required this.areaConstruida,
    required this.padrao,
    required this.laje,
    this.areaPisosSuperiores = 0,
    this.cobertura = TipoCobertura.platibanda,
    this.aguas = 2,
    this.muro,
    this.piscina,
    this.gourmet,
    this.jardim,
  });

  /// Área total construída em m² (inclui varandas, garagens e pisos superiores)
  final double areaConstruida;
  final Padrao padrao;

  /// Laje de concreto na cobertura
  final bool laje;

  /// m² dos pisos superiores; 0 = térrea
  final double areaPisosSuperiores;
  final TipoCobertura cobertura;

  /// Águas do telhado aparente: 1, 2 ou 3 (3 = três ou mais)
  final int aguas;
  final Muro? muro;
  final Piscina? piscina;
  final TipoGourmet? gourmet;
  final TipoJardim? jardim;
}

class LinhaResultado {
  const LinhaResultado({
    required this.etapa,
    required this.nome,
    required this.descricao,
    required this.area,
    required this.custoM2,
    required this.maoDeObra,
    required this.material,
    required this.total,
  });
  final EtapaId etapa;
  final String nome;
  final String descricao;
  final double area;
  final double custoM2;
  final double maoDeObra;
  final double material;
  final double total;
}

enum ItemAdicional {
  muro('Muro'),
  piscina('Piscina'),
  gourmet('Área gourmet'),
  jardim('Jardim');

  const ItemAdicional(this.rotulo);
  final String rotulo;
}

class LinhaAdicional {
  const LinhaAdicional({required this.item, required this.quantidade, required this.unidade, required this.precoUnitario, required this.total});
  final ItemAdicional item;
  final double quantidade;
  final String unidade;
  final double precoUnitario;
  final double total;
}

class ResultadoOrcamento {
  const ResultadoOrcamento({required this.etapas, required this.adicionais, required this.totalEtapas, required this.totalAdicionais});
  final List<LinhaResultado> etapas;
  final List<LinhaAdicional> adicionais;
  final double totalEtapas;
  final double totalAdicionais;
  double get total => totalEtapas + totalAdicionais;
  double get maoDeObra => etapas.fold(0, (s, l) => s + l.maoDeObra);
  double get material => etapas.fold(0, (s, l) => s + l.material);
}

/// Entrada que não dá para calcular; [mensagem] é mostrada ao usuário como está.
class EntradaInvalida implements Exception {
  const EntradaInvalida(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

void _validar(EntradaOrcamento e) {
  // `!(x > 0)` também recusa NaN, que é o que um campo vazio vira
  if (!(e.areaConstruida > 0)) throw const EntradaInvalida('Informe a área construída em m².');
  final sup = e.areaPisosSuperiores;
  if (sup < 0 || sup >= e.areaConstruida) {
    throw const EntradaInvalida('A área dos pisos superiores deve ser menor que a área construída.');
  }
  final m = e.muro;
  if (m != null && !(m.frente > 0 && m.areaTerreno > 0)) {
    throw const EntradaInvalida('Informe a frente e a área do terreno para calcular o muro.');
  }
  final p = e.piscina;
  if (p != null && !(p.comprimento > 0 && p.largura > 0)) {
    throw const EntradaInvalida('Informe comprimento e largura da piscina.');
  }
}

/// Sequência de etapas da aba Res1 (platibanda) e Res2 (telhado aparente).
List<EtapaId> _etapasSelecionadas(EntradaOrcamento e) {
  final platibanda = e.cobertura == TipoCobertura.platibanda;
  final cobertura = platibanda
      ? EtapaId.coberturaPlatibanda
      : e.aguas == 3
          ? EtapaId.telhado3Aguas
          : EtapaId.telhadoAparente;
  return [
    EtapaId.preparacao,
    EtapaId.aluguelEquipamentos,
    e.laje ? EtapaId.fundacaoLaje : EtapaId.fundacao,
    e.laje ? EtapaId.estruturaLaje : EtapaId.estrutura,
    EtapaId.alvenaria,
    platibanda ? EtapaId.calhasPlatibanda : EtapaId.calhasTelhado,
    cobertura,
    EtapaId.eletrica,
    EtapaId.hidraulica,
    EtapaId.forro,
    EtapaId.revestimentos,
    EtapaId.pintura,
    EtapaId.esquadrias,
    EtapaId.acabamentos,
    EtapaId.limpeza,
  ];
}

const _coberturas = {EtapaId.coberturaPlatibanda, EtapaId.telhado3Aguas, EtapaId.telhadoAparente};

ResultadoOrcamento calcularOrcamento(EntradaOrcamento e) {
  _validar(e);
  final sup = e.areaPisosSuperiores;

  final etapas = _etapasSelecionadas(e).map((id) {
    final linha = construcaoNovaResidencial[id]!;
    // Cobertura só incide sobre a projeção do último piso (Res1!I46)
    final area = _coberturas.contains(id) ? e.areaConstruida - sup : e.areaConstruida;
    final custoM2 = linha.custoM2[e.padrao]!;
    final total = area * custoM2;
    final fracaoMO = linha.maoDeObra[e.padrao]!;
    return LinhaResultado(
      etapa: id,
      nome: linha.nome,
      descricao: linha.descricao,
      area: area,
      custoM2: custoM2,
      maoDeObra: total * fracaoMO,
      material: total * (1 - fracaoMO),
      total: total,
    );
  }).toList();

  final adicionais = <LinhaAdicional>[];
  final muro = e.muro;
  if (muro != null) {
    // Res1!U40:W40: lateral = área do terreno / frente; perímetro completo
    final lateral = muro.areaTerreno / muro.frente;
    final metros = 2 * muro.frente + 2 * lateral;
    final preco = muroPorMetro[muro.acabamento]!;
    adicionais.add(LinhaAdicional(item: ItemAdicional.muro, quantidade: metros, unidade: 'm', precoUnitario: preco, total: metros * preco));
  }
  final piscina = e.piscina;
  if (piscina != null) {
    // Res1!W42: perímetro da piscina × preço por tipo
    final perimetro = 2 * piscina.comprimento + 2 * piscina.largura;
    final preco = piscinaPorMetroPerimetro[piscina.tipo]!;
    adicionais.add(LinhaAdicional(item: ItemAdicional.piscina, quantidade: perimetro, unidade: 'm', precoUnitario: preco, total: perimetro * preco));
  }
  final gourmet = e.gourmet;
  if (gourmet != null) {
    final area = e.areaConstruida * gourmetFracaoArea[gourmet]!;
    final preco = gourmetM2[gourmet]![e.padrao]!;
    adicionais.add(LinhaAdicional(item: ItemAdicional.gourmet, quantidade: area, unidade: 'm²', precoUnitario: preco, total: area * preco));
  }
  final jardim = e.jardim;
  if (jardim != null) {
    final area = e.areaConstruida * jardimFracaoArea[jardim]!;
    final preco = jardimM2[jardim]![e.padrao]!;
    adicionais.add(LinhaAdicional(item: ItemAdicional.jardim, quantidade: area, unidade: 'm²', precoUnitario: preco, total: area * preco));
  }

  return ResultadoOrcamento(
    etapas: etapas,
    adicionais: adicionais,
    totalEtapas: etapas.fold(0, (s, l) => s + l.total),
    totalAdicionais: adicionais.fold(0, (s, l) => s + l.total),
  );
}
