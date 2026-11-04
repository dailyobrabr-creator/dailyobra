/// Documentos da obra: ART, projetos, alvará, contratos e o vencimento de cada um.
library;

import 'cronograma.dart';
import 'diario.dart';

enum TipoDocumento {
  art('art', 'ART ou RRT'),
  projeto('projeto', 'Projeto'),
  alvara('alvara', 'Alvará'),
  contrato('contrato', 'Contrato'),
  licenca('licenca', 'Licença'),
  outro('outro', 'Outro');

  const TipoDocumento(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static TipoDocumento doCodigo(String? c) => values.firstWhere((t) => t.codigo == c, orElse: () => outro);
}

enum AcessoDocumento {
  lideres('lideres', 'Só o responsável e o mestre'),
  equipe('equipe', 'Toda a equipe'),
  todos('todos', 'A equipe e o cliente');

  const AcessoDocumento(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  /// Código desconhecido fica com o menor acesso.
  static AcessoDocumento doCodigo(String? c) => values.firstWhere((a) => a.codigo == c, orElse: () => lideres);
}

enum SituacaoValidade { semValidade, emDia, vencendo, vencido }

/// A partir de quantos dias antes do vencimento o documento pede atenção.
const diasDeAvisoDoDocumento = 30;

class Documento {
  const Documento({this.id, this.tipo = TipoDocumento.outro, required this.titulo, this.numero = '', this.validade, this.caminho, this.nomeArquivo = '', this.acesso = AcessoDocumento.lideres, this.possoMexer = true});
  factory Documento.fromJson(Map<String, dynamic> j) => Documento(
    id: j['id'] as String?,
    tipo: TipoDocumento.doCodigo(j['tipo'] as String?),
    titulo: j['titulo'] as String,
    numero: j['numero'] as String? ?? '',
    validade: j['validade'] == null ? null : DateTime.parse(j['validade'] as String),
    caminho: j['caminho'] as String?,
    nomeArquivo: j['nome_arquivo'] as String? ?? '',
    acesso: AcessoDocumento.doCodigo(j['acesso'] as String?),
    possoMexer: j['posso_mexer'] as bool? ?? false,
  );

  final String? id;
  final TipoDocumento tipo;
  final String titulo;

  /// Número da ART, do alvará ou do contrato.
  final String numero;
  final DateTime? validade;
  final String? caminho;
  final String nomeArquivo;
  final AcessoDocumento acesso;
  final bool possoMexer;

  /// Negativo quando já venceu.
  int? diasParaVencer(DateTime hoje) {
    final v = validade;
    return v == null ? null : diasEntre(hoje, v);
  }

  SituacaoValidade situacao(DateTime hoje) {
    final dias = diasParaVencer(hoje);
    if (dias == null) return SituacaoValidade.semValidade;
    if (dias < 0) return SituacaoValidade.vencido;
    return dias <= diasDeAvisoDoDocumento ? SituacaoValidade.vencendo : SituacaoValidade.emDia;
  }

  /// "Vencido há 3 dias", "Vence hoje", "Vence em 12 dias", "Válido até 10/12/2026"
  String textoDaValidade(DateTime hoje) {
    final v = validade;
    final dias = diasParaVencer(hoje);
    if (v == null || dias == null) return 'Sem vencimento';
    if (dias < -1) return 'Vencido há ${-dias} dias';
    if (dias == -1) return 'Vencido há 1 dia';
    if (dias == 0) return 'Vence hoje';
    if (dias == 1) return 'Vence amanhã';
    if (dias <= diasDeAvisoDoDocumento) return 'Vence em $dias dias';
    return 'Válido até ${dataCurta(v)}/${v.year}';
  }

  Map<String, Object?> paraSalvar() => {'tipo': tipo.codigo, 'titulo': titulo, 'numero': numero, 'validade': validade == null ? null : dataIso(validade!), 'caminho': caminho, 'nome_arquivo': nomeArquivo, 'acesso': acesso.codigo};
}

/// Frase do aviso, a partir do que está pior. Nula quando está tudo em dia.
String? alertaDeDocumentos(List<Documento> documentos, DateTime hoje) {
  final vencidos = documentos.where((d) => d.situacao(hoje) == SituacaoValidade.vencido).toList();
  if (vencidos.length == 1) return '${vencidos.single.titulo} está vencido.';
  if (vencidos.isNotEmpty) return '${vencidos.length} documentos vencidos.';
  final vencendo = documentos.where((d) => d.situacao(hoje) == SituacaoValidade.vencendo).toList()..sort((a, b) => a.validade!.compareTo(b.validade!));
  if (vencendo.length == 1) return '${vencendo.single.titulo}: ${vencendo.single.textoDaValidade(hoje).toLowerCase()}.';
  if (vencendo.isNotEmpty) return '${vencendo.length} documentos vencem em até $diasDeAvisoDoDocumento dias.';
  return null;
}
