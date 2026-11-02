import '../supabase/supabase_config.dart';

/// Dinheiro e quantidade chegam do PostgREST como número, mas aceitamos texto também.
double lerValor(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

double? _valorOuNulo(Object? v) => v == null ? null : lerValor(v);

DateTime? _data(Object? v) => v is String && v.isNotEmpty ? DateTime.parse(v) : null;

/// Endereço público de um arquivo do bucket `lojas` (logo, capa e fotos do catálogo).
/// Caminhos que já são endereços completos passam direto.
String? urlPublica(String? caminho) {
  if (caminho == null || caminho.isEmpty) return null;
  if (caminho.startsWith('http')) return caminho;
  return '${SupabaseConfig.url}/storage/v1/object/public/lojas/$caminho';
}

class Categoria {
  const Categoria({required this.id, required this.nome, required this.ordem});
  final String id;
  final String nome;
  final int ordem;

  factory Categoria.fromJson(Map<String, dynamic> j) =>
      Categoria(id: j['id'] as String, nome: j['nome'] as String, ordem: (j['ordem'] as num).toInt());
}

class ItemCatalogo {
  const ItemCatalogo({
    required this.id,
    required this.nome,
    required this.unidade,
    required this.categoriaId,
    required this.tier,
    this.sinonimos = const [],
    this.imagemUrl,
  });
  final String id;
  final String nome;
  final String unidade;
  final String categoriaId;
  final int tier;
  final List<String> sinonimos;
  final String? imagemUrl;

  factory ItemCatalogo.fromJson(Map<String, dynamic> j) => ItemCatalogo(
        id: j['id'] as String,
        nome: j['nome'] as String,
        unidade: j['unidade'] as String,
        categoriaId: j['categoria_id'] as String,
        tier: (j['tier_cashback'] as num).toInt(),
        sinonimos: [for (final s in (j['sinonimos'] as List? ?? const [])) s as String],
        imagemUrl: urlPublica(j['imagem_path'] as String?),
      );

  @override
  bool operator ==(Object other) => other is ItemCatalogo && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Loja {
  const Loja({
    required this.id,
    required this.nome,
    this.descricao = '',
    this.logoUrl,
    this.capaUrl,
    this.whatsapp = '',
    required this.cidade,
    required this.uf,
    this.freteFixo = 0,
    this.pedidoMinimo = 0,
    this.aberta = true,
    this.nova = false,
    this.horario = '',
  });
  final String id;
  final String nome;
  final String descricao;
  final String? logoUrl;
  final String? capaUrl;
  final String whatsapp;
  final String cidade;
  final String uf;
  final double freteFixo;
  final double pedidoMinimo;
  final bool aberta;

  /// Cadastrada nos últimos 30 dias: ganha o selo "Nova" na vitrine.
  final bool nova;

  /// Horário de atendimento como a loja escreveu ("Seg a sex 7h às 18h").
  final String horario;

  factory Loja.fromJson(Map<String, dynamic> j) {
    final criada = _data(j['criada_em']);
    return Loja(
      id: j['id'] as String,
      nome: j['nome'] as String,
      descricao: (j['descricao'] as String?) ?? '',
      logoUrl: urlPublica(j['logo_path'] as String?),
      capaUrl: urlPublica(j['capa_path'] as String?),
      whatsapp: (j['whatsapp'] as String?) ?? '',
      cidade: j['cidade'] as String,
      uf: j['uf'] as String,
      freteFixo: lerValor(j['frete_fixo']),
      pedidoMinimo: lerValor(j['pedido_minimo']),
      aberta: (j['aberta'] as bool?) ?? true,
      nova: criada != null && DateTime.now().difference(criada).inDays < 30,
      horario: (j['horario'] as String?) ?? '',
    );
  }
}

enum Disponibilidade {
  disponivel('disponivel', 'Disponível'),
  sobConsulta('sob_consulta', 'Sob consulta'),
  semEstoque('sem_estoque', 'Sem estoque');

  const Disponibilidade(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static Disponibilidade fromCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => disponivel);
}

class Oferta {
  const Oferta({
    required this.lojaId,
    required this.itemId,
    required this.preco,
    this.precoPromocional,
    this.promoAte,
    this.disponibilidade = Disponibilidade.disponivel,
    this.pausada = false,
  });
  final String lojaId;
  final String itemId;
  final double preco;
  final double? precoPromocional;
  final DateTime? promoAte;
  final Disponibilidade disponibilidade;
  final bool pausada;

  /// A promoção vale até o fim do dia de [promoAte], na mesma regra do servidor.
  bool emPromocao(DateTime hoje) {
    if (precoPromocional == null || promoAte == null) return false;
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    final fim = DateTime(promoAte!.year, promoAte!.month, promoAte!.day);
    return !fim.isBefore(dia);
  }

  /// Preço que vale hoje; nulo quando a loja pausou o produto ou está sem estoque.
  double? precoVigente(DateTime hoje) {
    if (pausada || disponibilidade == Disponibilidade.semEstoque) return null;
    return emPromocao(hoje) ? precoPromocional : preco;
  }

  factory Oferta.fromJson(Map<String, dynamic> j) => Oferta(
        lojaId: j['loja_id'] as String,
        itemId: j['item_id'] as String,
        preco: lerValor(j['preco']),
        precoPromocional: _valorOuNulo(j['preco_promocional']),
        promoAte: _data(j['promo_ate']),
        disponibilidade: Disponibilidade.fromCodigo(j['disponibilidade'] as String?),
        pausada: (j['pausada'] as bool?) ?? false,
      );
}

enum ModoProposta {
  negociacao('negociacao', 'Negociação'),
  pedido('pedido', 'Pedido direto');

  const ModoProposta(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  static ModoProposta fromCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => negociacao);
}

enum StatusProposta {
  enviada('enviada', 'Aguardando a loja'),
  contraproposta('contraproposta', 'Contraproposta'),
  aceita('aceita', 'Aceita'),
  recusada('recusada', 'Recusada'),
  cancelada('cancelada', 'Cancelada'),
  expirada('expirada', 'Expirada');

  const StatusProposta(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  bool get aberta => this == enviada || this == contraproposta;

  static StatusProposta fromCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => enviada);
}

enum StatusPedido {
  confirmado('confirmado', 'Confirmado'),
  emSeparacao('em_separacao', 'Em separação'),
  saiuEntrega('saiu_entrega', 'Saiu para entrega'),
  entregue('entregue', 'Entregue'),
  cancelado('cancelado', 'Cancelado');

  const StatusPedido(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  /// Próximo passo que a loja pode marcar; nulo quando o pedido já terminou.
  StatusPedido? get proximo => switch (this) {
        confirmado => emSeparacao,
        emSeparacao => saiuEntrega,
        saiuEntrega => entregue,
        entregue || cancelado => null,
      };

  static StatusPedido fromCodigo(String? c) => values.firstWhere((v) => v.codigo == c, orElse: () => confirmado);
}
