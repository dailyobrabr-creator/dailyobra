import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

class DadosCompras {
  const DadosCompras({
    required this.materiais,
    required this.pedidos,
    required this.recebimentos,
  });

  final List<MaterialObra> materiais;
  final List<ItemDePedido> pedidos;
  final List<Recebimento> recebimentos;
}

/// Lista de materiais da obra, o que foi pedido para ela e o que chegou.
class ComprasService {
  ComprasService._();

  static final instance = ComprasService._();

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<MaterialObra> _materiais = const [];
  List<ItemDePedido> _pedidos = const [];
  List<Recebimento> _recebimentos = const [];

  /// Listas inteiras que [salvarLista] mandaria ao banco.
  @visibleForTesting
  final listasDeTeste = <List<MaterialObra>>[];
  @visibleForTesting
  final materiaisDeTeste = <MaterialObra>[];
  @visibleForTesting
  final excluidosDeTeste = <String>[];
  @visibleForTesting
  final recebimentosDeTeste =
      <(String?, List<Recebimento>, DateTime, String, String?)>[];
  @visibleForTesting
  final recebimentosExcluidosDeTeste = <String>[];

  @visibleForTesting
  void definirParaTeste({
    List<MaterialObra> materiais = const [],
    List<ItemDePedido> pedidos = const [],
    List<Recebimento> recebimentos = const [],
    String? erro,
  }) {
    _teste = true;
    _erro = erro;
    _materiais = [...materiais];
    _pedidos = [...pedidos];
    _recebimentos = [...recebimentos];
    listasDeTeste.clear();
    materiaisDeTeste.clear();
    excluidosDeTeste.clear();
    recebimentosDeTeste.clear();
    recebimentosExcluidosDeTeste.clear();
  }

  /// Em teste não há banco: [emTeste] faz o papel dele, e o erro combinado vale para tudo.
  Future<T> _executar<T>(
    Future<T> Function() noBanco,
    T Function() emTeste,
    String falha,
  ) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      return emTeste();
    }
    try {
      final r = await noBanco();
      return r;
    } on PostgrestException catch (e) {
      throw FalhaAoSalvar(e.code == 'P0001' ? e.message : falha);
    } catch (_) {
      throw FalhaAoSalvar(falha);
    }
  }

  Future<DadosCompras> carregar(String obraId) => _executar(
    () async {
      final (materiais, pedidos, recebimentos) = await (
        _db
            .from('obra_materiais')
            .select('id, etapa, item_id, nome, unidade, quantidade, preco_base')
            .eq('obra_id', obraId)
            .order('criado_em'),
        _db.rpc<List<dynamic>>('itens_dos_pedidos', params: {'p_obra': obraId}),
        _db
            .from('obra_recebimentos')
            .select(
              'id, pedido_id, item_id, nome, unidade, quantidade, data, observacao, foto_path',
            )
            .eq('obra_id', obraId)
            .order('data', ascending: false),
      ).wait;
      return DadosCompras(
        materiais: [for (final m in materiais) MaterialObra.fromJson(m)],
        pedidos: [
          for (final p in pedidos)
            ItemDePedido.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
        recebimentos: [for (final r in recebimentos) Recebimento.fromJson(r)],
      );
    },
    () => DadosCompras(
      materiais: [..._materiais],
      pedidos: [..._pedidos],
      recebimentos: [..._recebimentos],
    ),
    'Não foi possível carregar as compras. Verifique a conexão e tente de novo.',
  );

  /// Troca a lista inteira da obra.
  Future<void> salvarLista(String obraId, List<MaterialObra> lista) =>
      _executar(
        () => _db.rpc<void>(
          'salvar_materiais',
          params: {
            'p_obra': obraId,
            'p_itens': [for (final m in lista) m.paraSalvar()],
          },
        ),
        () {
          listasDeTeste.add(lista);
          _materiais = [...lista];
        },
        'Não foi possível salvar a lista. Verifique a conexão e tente de novo.',
      );

  Future<String> salvarMaterial(String obraId, MaterialObra m) => _executar(
    () => _db.rpc<String>(
      'salvar_material',
      params: {'p_obra': obraId, 'p_id': m.id, 'p_dados': m.paraSalvar()},
    ),
    () {
      materiaisDeTeste.add(m);
      final id = m.id ?? 'novo-${materiaisDeTeste.length}';
      _materiais = [
        for (final o in _materiais)
          if (o.id != id) o,
        MaterialObra(
          id: id,
          etapa: m.etapa,
          itemId: m.itemId,
          nome: m.nome,
          unidade: m.unidade,
          quantidade: m.quantidade,
          precoBase: m.precoBase,
        ),
      ];
      return id;
    },
    'Não foi possível salvar o material. Tente de novo.',
  );

  Future<void> excluirMaterial(String id) => _executar(
    () => _db.rpc<void>('excluir_material', params: {'p_id': id}),
    () {
      excluidosDeTeste.add(id);
      _materiais = [
        for (final m in _materiais)
          if (m.id != id) m,
      ];
    },
    'Não foi possível excluir o material. Tente de novo.',
  );

  /// Sem [pedidoId], é material comprado fora do app.
  Future<void> registrarRecebimento(
    String obraId, {
    String? pedidoId,
    required List<Recebimento> itens,
    required DateTime data,
    String observacao = '',
    String? foto,
  }) => _executar(
    () => _db.rpc<void>(
      'registrar_recebimento',
      params: {
        'p_obra': obraId,
        'p_pedido': pedidoId,
        'p_itens': [for (final i in itens) i.paraSalvar()],
        'p_data': dataIso(data),
        'p_observacao': observacao,
        'p_foto': foto,
      },
    ),
    () {
      recebimentosDeTeste.add((pedidoId, itens, data, observacao, foto));
      _recebimentos = [
        for (final i in itens)
          Recebimento(
            id: 'novo-${recebimentosDeTeste.length}',
            pedidoId: pedidoId,
            itemId: i.itemId,
            nome: i.nome,
            unidade: i.unidade,
            quantidade: i.quantidade,
            data: data,
            observacao: observacao,
            fotoPath: foto,
          ),
        ..._recebimentos,
      ];
    },
    'Não foi possível registrar o recebimento. Verifique a conexão e tente de novo.',
  );

  /// Devolve o caminho da foto quando ela não é mais usada, para apagar o arquivo.
  Future<String?> excluirRecebimento(String id) => _executar(
    () => _db.rpc<String?>('excluir_recebimento', params: {'p_id': id}),
    () {
      recebimentosExcluidosDeTeste.add(id);
      _recebimentos = [
        for (final r in _recebimentos)
          if (r.id != id) r,
      ];
      return null;
    },
    'Não foi possível excluir o recebimento. Tente de novo.',
  );
}
