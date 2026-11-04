// Obra, parâmetros do orçamento e regras simples (validação, andamento).
// O JSON de [ParametrosObra] é o mesmo que o app web grava em obras.parametros,
// para uma obra cadastrada em um aparecer igual no outro.

import '../orcamento/orcamento.dart';
import '../orcamento/tabelas.dart';
import 'cronograma.dart';
import 'equipe.dart';

enum StatusEtapa {
  prevista('prevista', 'Prevista'),
  iniciada('iniciada', 'Em andamento'),
  concluida('concluida', 'Concluída'),
  bloqueada('bloqueada', 'Bloqueada');

  const StatusEtapa(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static StatusEtapa doCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => prevista);
}

/// Papel do usuário na obra (tabela obra_membros): cliente só acompanha
enum Papel {
  admin,
  membro,
  cliente;

  static Papel doCodigo(String? c) => values.firstWhere((v) => v.name == c, orElse: () => cliente);
}

/// Só milhares, sem vírgula: "10.000", "1.234.567". Não pega "0.500", que é decimal.
final _soMilhares = RegExp(r'^[1-9]\d{0,2}(\.\d{3})+$');

/// "1.153,5", "10.000" ou "153.5" → número; vazio ou inválido → NaN
double lerNumero(String v) {
  final t = v.trim();
  if (t.isEmpty) return double.nan;
  // Com vírgula, ponto é separador de milhar. Sem vírgula, também é, quando vem em grupos de três:
  // é assim que os valores aparecem nos campos ao editar. Fora isso, ponto é decimal.
  final normal = t.contains(',')
      ? t.replaceAll('.', '').replaceAll(',', '.')
      : _soMilhares.hasMatch(t)
      ? t.replaceAll('.', '')
      : t;
  return double.tryParse(normal) ?? double.nan;
}

/// Parâmetros como o usuário digita (texto), para o campo não perder "153," no meio da digitação.
class ParametrosObra {
  const ParametrosObra({
    this.area = '',
    this.padrao = Padrao.medio,
    this.laje = true,
    this.sobrado = false,
    this.areaSuperior = '',
    this.cobertura = TipoCobertura.platibanda,
    this.aguas = 2,
    this.muroAtivo = false,
    this.muroFrente = '',
    this.muroTerreno = '',
    this.muroAcabamento = AcabamentoMuro.economico,
    this.piscinaAtiva = false,
    this.piscinaComprimento = '',
    this.piscinaLargura = '',
    this.piscinaTipo = TipoPiscina.fibra,
    this.gourmetAtivo = false,
    this.gourmetTipo = TipoGourmet.churrasqueira,
    this.jardimAtivo = false,
    this.jardimTipo = TipoJardim.grama,
  });

  final String area;
  final Padrao padrao;
  final bool laje;
  final bool sobrado;
  final String areaSuperior;
  final TipoCobertura cobertura;
  final int aguas;
  final bool muroAtivo;
  final String muroFrente;
  final String muroTerreno;
  final AcabamentoMuro muroAcabamento;
  final bool piscinaAtiva;
  final String piscinaComprimento;
  final String piscinaLargura;
  final TipoPiscina piscinaTipo;
  final bool gourmetAtivo;
  final TipoGourmet gourmetTipo;
  final bool jardimAtivo;
  final TipoJardim jardimTipo;

  ParametrosObra copyWith({
    String? area,
    Padrao? padrao,
    bool? laje,
    bool? sobrado,
    String? areaSuperior,
    TipoCobertura? cobertura,
    int? aguas,
    bool? muroAtivo,
    String? muroFrente,
    String? muroTerreno,
    AcabamentoMuro? muroAcabamento,
    bool? piscinaAtiva,
    String? piscinaComprimento,
    String? piscinaLargura,
    TipoPiscina? piscinaTipo,
    bool? gourmetAtivo,
    TipoGourmet? gourmetTipo,
    bool? jardimAtivo,
    TipoJardim? jardimTipo,
  }) =>
      ParametrosObra(
        area: area ?? this.area,
        padrao: padrao ?? this.padrao,
        laje: laje ?? this.laje,
        sobrado: sobrado ?? this.sobrado,
        areaSuperior: areaSuperior ?? this.areaSuperior,
        cobertura: cobertura ?? this.cobertura,
        aguas: aguas ?? this.aguas,
        muroAtivo: muroAtivo ?? this.muroAtivo,
        muroFrente: muroFrente ?? this.muroFrente,
        muroTerreno: muroTerreno ?? this.muroTerreno,
        muroAcabamento: muroAcabamento ?? this.muroAcabamento,
        piscinaAtiva: piscinaAtiva ?? this.piscinaAtiva,
        piscinaComprimento: piscinaComprimento ?? this.piscinaComprimento,
        piscinaLargura: piscinaLargura ?? this.piscinaLargura,
        piscinaTipo: piscinaTipo ?? this.piscinaTipo,
        gourmetAtivo: gourmetAtivo ?? this.gourmetAtivo,
        gourmetTipo: gourmetTipo ?? this.gourmetTipo,
        jardimAtivo: jardimAtivo ?? this.jardimAtivo,
        jardimTipo: jardimTipo ?? this.jardimTipo,
      );

  EntradaOrcamento paraEntrada() => EntradaOrcamento(
        areaConstruida: lerNumero(area),
        padrao: padrao,
        laje: laje,
        areaPisosSuperiores: sobrado ? _ouZero(lerNumero(areaSuperior)) : 0,
        cobertura: cobertura,
        aguas: aguas,
        muro: muroAtivo
            ? Muro(frente: lerNumero(muroFrente), areaTerreno: lerNumero(muroTerreno), acabamento: muroAcabamento)
            : null,
        piscina: piscinaAtiva
            ? Piscina(comprimento: lerNumero(piscinaComprimento), largura: lerNumero(piscinaLargura), tipo: piscinaTipo)
            : null,
        gourmet: gourmetAtivo ? gourmetTipo : null,
        jardim: jardimAtivo ? jardimTipo : null,
      );

  static double _ouZero(double n) => n.isNaN ? 0 : n;

  Map<String, dynamic> toJson() => {
        'area': area,
        'padrao': padrao.codigo,
        'laje': laje,
        'sobrado': sobrado,
        'areaSuperior': areaSuperior,
        'cobertura': cobertura == TipoCobertura.platibanda ? 'platibanda' : 'telhado_aparente',
        'aguas': aguas,
        'muro': {'ativo': muroAtivo, 'frente': muroFrente, 'terreno': muroTerreno, 'acabamento': muroAcabamento.codigo},
        'piscina': {'ativo': piscinaAtiva, 'comprimento': piscinaComprimento, 'largura': piscinaLargura, 'tipo': piscinaTipo.codigo},
        'gourmet': {'ativo': gourmetAtivo, 'tipo': gourmetTipo.codigo},
        'jardim': {'ativo': jardimAtivo, 'tipo': jardimTipo.codigo},
      };

  /// Aceita JSON incompleto (obras antigas): o que faltar fica com o padrão
  factory ParametrosObra.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    Map<String, dynamic> sub(String k) => (j![k] is Map) ? (j[k] as Map).cast<String, dynamic>() : const {};
    String txt(Object? v) => v == null ? '' : '$v';
    final muro = sub('muro'), piscina = sub('piscina'), gourmet = sub('gourmet'), jardim = sub('jardim');
    final aguas = (j['aguas'] is num) ? (j['aguas'] as num).toInt() : 2;
    return ParametrosObra(
      area: txt(j['area']),
      padrao: Padrao.doCodigo(j['padrao'] as String?),
      laje: j['laje'] != false,
      sobrado: j['sobrado'] == true,
      areaSuperior: txt(j['areaSuperior']),
      cobertura: j['cobertura'] == 'telhado_aparente' ? TipoCobertura.telhadoAparente : TipoCobertura.platibanda,
      aguas: aguas.clamp(1, 3),
      muroAtivo: muro['ativo'] == true,
      muroFrente: txt(muro['frente']),
      muroTerreno: txt(muro['terreno']),
      muroAcabamento: AcabamentoMuro.doCodigo(muro['acabamento'] as String?),
      piscinaAtiva: piscina['ativo'] == true,
      piscinaComprimento: txt(piscina['comprimento']),
      piscinaLargura: txt(piscina['largura']),
      piscinaTipo: TipoPiscina.doCodigo(piscina['tipo'] as String?),
      gourmetAtivo: gourmet['ativo'] == true,
      gourmetTipo: TipoGourmet.doCodigo(gourmet['tipo'] as String?),
      jardimAtivo: jardim['ativo'] == true,
      jardimTipo: TipoJardim.doCodigo(jardim['tipo'] as String?),
    );
  }
}

/// Resultado do orçamento ou a mensagem do que falta preencher
class Calculo {
  const Calculo._(this.resultado, this.erro);
  final ResultadoOrcamento? resultado;
  final String? erro;

  factory Calculo.de(ParametrosObra p) {
    try {
      return Calculo._(calcularOrcamento(p.paraEntrada()), null);
    } on EntradaInvalida catch (e) {
      return Calculo._(null, e.mensagem);
    }
  }
}

class DadosObra {
  const DadosObra({this.nome = '', this.cidade = '', this.uf = '', this.endereco = '', this.cep = '', this.logradouro = '', this.numero = '', this.complemento = '', this.bairro = '', this.responsavel = '', this.inicioPrevisto = ''});
  final String nome;
  final String cidade;
  final String uf;

  /// Texto mostrado nas telas, montado das partes abaixo. Obra antiga só tem este texto.
  final String endereco;
  final String cep;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String responsavel;

  /// AAAA-MM-DD ou vazio
  final String inicioPrevisto;

  DadosObra copyWith({String? nome, String? cidade, String? uf, String? endereco, String? cep, String? logradouro, String? numero, String? complemento, String? bairro, String? responsavel, String? inicioPrevisto}) => DadosObra(
        nome: nome ?? this.nome,
        cidade: cidade ?? this.cidade,
        uf: uf ?? this.uf,
        endereco: endereco ?? this.endereco,
        cep: cep ?? this.cep,
        logradouro: logradouro ?? this.logradouro,
        numero: numero ?? this.numero,
        complemento: complemento ?? this.complemento,
        bairro: bairro ?? this.bairro,
        responsavel: responsavel ?? this.responsavel,
        inicioPrevisto: inicioPrevisto ?? this.inicioPrevisto,
      );
}

const ufs = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA',
  'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
];

/// Erros por campo ('nome', 'cidade', 'uf', 'inicioPrevisto'); vazio = válido
Map<String, String> validarDados(DadosObra d) {
  final erros = <String, String>{};
  final nome = d.nome.trim();
  if (nome.length < 3) {
    erros['nome'] = 'Dê um nome à obra com pelo menos 3 letras.';
  } else if (nome.length > 120) {
    erros['nome'] = 'Use no máximo 120 caracteres.';
  }
  if (d.cidade.trim().isEmpty) erros['cidade'] = 'Informe a cidade.';
  if (!ufs.contains(d.uf)) erros['uf'] = 'Escolha o estado.';
  if (d.inicioPrevisto.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d.inicioPrevisto)) {
    erros['inicioPrevisto'] = 'Data inválida.';
  }
  return erros;
}

class Obra {
  const Obra({
    required this.id,
    required this.papel,
    this._funcao,
    required this.dados,
    required this.parametros,
    required this.statusEtapas,
    required this.criadaEm,
    required this.atualizadaEm,
    this.pessoas = 1,
    this.cronograma = const {},
    this.prazosAbertos = const [],
  });

  final String id;
  final Papel papel;
  final FuncaoObra? _funcao;
  final DadosObra dados;
  final ParametrosObra parametros;
  final Map<EtapaId, StatusEtapa> statusEtapas;
  final DateTime criadaEm;
  final DateTime atualizadaEm;

  /// Quantas pessoas estão na equipe.
  final int pessoas;

  /// Datas de cada etapa; etapa sem linha aqui não tem datas.
  final Map<EtapaId, DatasEtapa> cronograma;

  /// Prazo de cada pendência aberta, nulo quando não tem prazo. O cliente não vê pendências.
  final List<DateTime?> prazosAbertos;

  int get pendenciasAbertas => prazosAbertos.length;
  int pendenciasVencidas(DateTime hoje) => prazosAbertos.where((p) => p != null && diasEntre(p, hoje) > 0).length;

  String get nome => dados.nome;

  /// O que a pessoa pode fazer nesta obra.
  FuncaoObra get funcao =>
      _funcao ??
      switch (papel) {
        Papel.admin => FuncaoObra.responsavel,
        Papel.membro => FuncaoObra.mestre,
        Papel.cliente => FuncaoObra.cliente,
      };

  StatusEtapa statusDe(EtapaId e) => statusEtapas[e] ?? StatusEtapa.prevista;

  Obra comStatus(EtapaId etapa, StatusEtapa s) => Obra(
        id: id,
        papel: papel,
        funcao: _funcao,
        dados: dados,
        parametros: parametros,
        statusEtapas: {...statusEtapas, etapa: s},
        criadaEm: criadaEm,
        atualizadaEm: atualizadaEm,
        pessoas: pessoas,
        cronograma: cronograma,
        prazosAbertos: prazosAbertos,
      );
}

/// Percentual concluído entre as etapas do orçamento, ponderado pelo custo de cada etapa
int progresso(List<LinhaResultado> etapas, Map<EtapaId, StatusEtapa> status) {
  final total = etapas.fold<double>(0, (s, e) => s + e.total);
  if (total == 0) return 0;
  final feito = etapas.fold<double>(0, (s, e) => s + (status[e.etapa] == StatusEtapa.concluida ? e.total : 0));
  return (feito / total * 100).round();
}

/// Etapa em foco: a primeira bloqueada ou em andamento; senão a primeira não concluída; null se tudo concluído
LinhaResultado? etapaAtual(List<LinhaResultado> etapas, Map<EtapaId, StatusEtapa> status) {
  for (final e in etapas) {
    final s = status[e.etapa];
    if (s == StatusEtapa.bloqueada || s == StatusEtapa.iniciada) return e;
  }
  for (final e in etapas) {
    if (status[e.etapa] != StatusEtapa.concluida) return e;
  }
  return null;
}
