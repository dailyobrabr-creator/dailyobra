import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loja_service.dart';

const _tamanhoMaximoDaImagem = 2 * 1024 * 1024;

/// Anúncio com o resultado somado desde que entrou no ar.
class AnuncioDaLoja {
  const AnuncioDaLoja({
    required this.anuncio,
    this.itemNome,
    this.unidade,
    this.impressoes = 0,
    this.cliques = 0,
    this.vendidos,
  });

  factory AnuncioDaLoja.fromJson(Map<String, dynamic> j) => AnuncioDaLoja(
    anuncio: Anuncio.fromJson(j),
    itemNome: j['item_nome'] as String?,
    unidade: j['unidade'] as String?,
    impressoes: (j['impressoes'] as num).toInt(),
    cliques: (j['cliques'] as num).toInt(),
    vendidos: j['vendidos'] == null ? null : lerValor(j['vendidos']),
  );

  final Anuncio anuncio;
  final String? itemNome;
  final String? unidade;
  final int impressoes;
  final int cliques;

  /// Quantidade vendida do produto no período; só no destaque.
  final double? vendidos;

  /// Sem impressão não há taxa de cliques.
  double? get taxaDeCliques => impressoes == 0 ? null : cliques / impressoes;
}

/// Anúncios da loja no painel, para dono e gerente (o banco recusa o vendedor).
class AnunciosService extends ChangeNotifier {
  AnunciosService._();

  static final instance = AnunciosService._();

  SupabaseClient get _db => Supabase.instance.client;

  List<AnuncioDaLoja> _lista = const [];
  bool _carregado = false;
  String? _erro;
  bool _teste = false;

  List<AnuncioDaLoja> get lista => _lista;
  bool get carregado => _carregado;
  String? get erro => _erro;

  /// O que iria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  final chamadasDeTeste = <(String, Map<String, Object?>)>[];

  @visibleForTesting
  void definirParaTeste({List<AnuncioDaLoja> lista = const []}) {
    _lista = lista;
    _carregado = true;
    _erro = null;
    _teste = true;
    chamadasDeTeste.clear();
    notifyListeners();
  }

  void limpar() {
    _lista = const [];
    _carregado = false;
    _erro = null;
    notifyListeners();
  }

  Future<void> carregar() async {
    if (_teste) return;
    final loja = LojaService.instance.minhaLoja;
    if (loja == null) return;
    try {
      final r = await comMensagem(
        () => _db.rpc('anuncios_da_loja', params: {'p_loja': loja.id}),
      );
      _lista = [
        for (final j in r as List)
          AnuncioDaLoja.fromJson(j as Map<String, dynamic>),
      ];
      _erro = null;
      _carregado = true;
    } on FalhaComMensagem catch (e) {
      _erro = e.mensagem;
    }
    notifyListeners();
  }

  /// Sobe a imagem do banner e devolve o caminho no bucket. Lança [FalhaComMensagem].
  Future<String> enviarImagem(XFile arquivo) async {
    final loja = LojaService.instance.minhaLoja;
    if (loja == null) {
      throw const FalhaComMensagem('Cadastre a loja antes de enviar imagens.');
    }
    final bytes = await arquivo.readAsBytes();
    if (bytes.length > _tamanhoMaximoDaImagem) {
      throw const FalhaComMensagem(
        'A imagem passou de 2 MB. Escolha outra foto ou recorte antes.',
      );
    }
    final caminho =
        '${loja.id}/anuncio-${DateTime.now().millisecondsSinceEpoch}.jpg';
    if (_teste) return caminho;
    await comMensagem(
      () => _db.storage
          .from('lojas')
          .uploadBinary(
            caminho,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
          ),
    );
    return caminho;
  }

  Future<void> _chamar(String funcao, Map<String, Object?> params) async {
    if (_teste) {
      chamadasDeTeste.add((funcao, params));
      return;
    }
    await comMensagem(() => _db.rpc(funcao, params: params));
    await carregar();
  }

  /// Cria o anúncio, ou altera quando vem [id]. Lança [FalhaComMensagem].
  Future<void> salvar({
    String? id,
    required TipoAnuncio tipo,
    required String titulo,
    String? imagem,
    String? itemId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final loja = LojaService.instance.minhaLoja;
    if (loja == null) {
      throw const FalhaComMensagem('Cadastre a loja antes de anunciar.');
    }
    await _chamar('salvar_anuncio', {
      'p_loja': loja.id,
      'p_id': id,
      'p_tipo': tipo.codigo,
      'p_titulo': titulo,
      'p_imagem': imagem,
      'p_item': itemId,
      'p_inicio': _dia(inicio),
      'p_fim': _dia(fim),
    });
  }

  Future<void> pausar(String id, {required bool pausado}) =>
      _chamar('pausar_anuncio', {'p_anuncio': id, 'p_pausado': pausado});

  /// Apaga o anúncio e, se for banner, a imagem dele.
  Future<void> excluir(String id) async {
    if (_teste) {
      chamadasDeTeste.add(('excluir_anuncio', {'p_anuncio': id}));
      return;
    }
    final caminho = await comMensagem(
      () => _db.rpc('excluir_anuncio', params: {'p_anuncio': id}),
    );
    if (caminho is String && caminho.isNotEmpty) {
      try {
        await _db.storage.from('lojas').remove([caminho]);
      } on Exception {
        // O anúncio já saiu; a imagem órfã não aparece para ninguém
      }
    }
    await carregar();
  }

  static String _dia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
