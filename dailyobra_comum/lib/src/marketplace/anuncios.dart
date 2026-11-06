import 'modelos.dart';

enum TipoAnuncio {
  banner('banner', 'Banner principal'),
  destaque('destaque', 'Destaque na busca');

  const TipoAnuncio(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static TipoAnuncio fromCodigo(String? c) => values.firstWhere((t) => t.codigo == c, orElse: () => banner);
}

enum SituacaoAnuncio {
  agendado('Agendado'),
  ativo('Ativo'),
  pausado('Pausado'),
  encerrado('Encerrado');

  const SituacaoAnuncio(this.rotulo);
  final String rotulo;
}

/// Anúncio de uma loja: banner no carrossel do Início ou produto em destaque na busca.
class Anuncio {
  const Anuncio({
    required this.id,
    required this.lojaId,
    required this.tipo,
    required this.titulo,
    required this.inicio,
    required this.fim,
    this.imagemCaminho,
    this.itemId,
    this.pausado = false,
  });

  factory Anuncio.fromJson(Map<String, dynamic> j) => Anuncio(
        id: j['id'] as String,
        lojaId: j['loja_id'] as String,
        tipo: TipoAnuncio.fromCodigo(j['tipo'] as String?),
        titulo: j['titulo'] as String,
        inicio: DateTime.parse(j['inicio'] as String),
        fim: DateTime.parse(j['fim'] as String),
        imagemCaminho: j['imagem_path'] as String?,
        itemId: j['item_id'] as String?,
        pausado: (j['pausado'] as bool?) ?? false,
      );

  final String id;
  final String lojaId;
  final TipoAnuncio tipo;
  final String titulo;

  /// Primeiro e último dia no ar.
  final DateTime inicio;
  final DateTime fim;

  /// Caminho no bucket `lojas`; só no banner.
  final String? imagemCaminho;

  /// Produto do catálogo; só no destaque.
  final String? itemId;
  final bool pausado;

  String? get imagemUrl => urlPublica(imagemCaminho);

  SituacaoAnuncio situacao(DateTime hoje) {
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    if (DateTime(fim.year, fim.month, fim.day).isBefore(dia)) return SituacaoAnuncio.encerrado;
    if (pausado) return SituacaoAnuncio.pausado;
    return DateTime(inicio.year, inicio.month, inicio.day).isAfter(dia) ? SituacaoAnuncio.agendado : SituacaoAnuncio.ativo;
  }

  bool noAr(DateTime hoje) => situacao(hoje) == SituacaoAnuncio.ativo;
}
