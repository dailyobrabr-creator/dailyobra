import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mudancas_service.dart';
import 'obras_service.dart';

/// O que o banco devolve para esta pessoa: tudo para o responsável; para o mestre, só o que ele lançou.
class DadosDinheiro {
  const DadosDinheiro({
    required this.lancamentos,
    required this.orcado,
    this.mudancas = 0,
  });
  final List<LancamentoObra> lancamentos;
  final Map<EtapaId, double> orcado;

  /// Soma do que o cliente aprovou.
  final double mudancas;
}

/// Gastos, pedidos da obra e valores orçados. As notas ficam em um bucket só delas: a equipe
/// inteira lê as fotos do diário, e nota é assunto do responsável e de quem lançou.
class DinheiroService {
  DinheiroService._();

  static final instance = DinheiroService._();

  static const tamanhoMaximo = 5 * 1024 * 1024;
  static const _balde = 'obra-notas';

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<LancamentoObra> _lancamentos = const [];
  Map<EtapaId, double> _orcado = const {};
  double _mudancas = 0;
  var _notasDeTeste = 0;

  @visibleForTesting
  final salvosDeTeste = <LancamentoObra>[];
  @visibleForTesting
  final excluidosDeTeste = <String>[];
  @visibleForTesting
  final orcadosDeTeste = <(EtapaId, double?)>[];
  @visibleForTesting
  final classificadosDeTeste = <(String, EtapaId?)>[];

  @visibleForTesting
  void definirParaTeste({
    List<LancamentoObra> lancamentos = const [],
    Map<EtapaId, double> orcado = const {},
    double mudancas = 0,
    String? erro,
  }) {
    _teste = true;
    _erro = erro;
    _mudancas = mudancas;
    _lancamentos = [...lancamentos];
    _orcado = {...orcado};
    _notasDeTeste = 0;
    salvosDeTeste.clear();
    excluidosDeTeste.clear();
    orcadosDeTeste.clear();
    classificadosDeTeste.clear();
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

  Future<DadosDinheiro> carregar(String obraId) => _executar(
    () async {
      final (linhas, orcados, mudancas) = await (
        _db.rpc<List<dynamic>>(
          'lancamentos_da_obra',
          params: {'p_obra': obraId},
        ),
        _db.from('obra_orcado').select('etapa, valor').eq('obra_id', obraId),
        MudancasService.instance.valorAprovado(obraId),
      ).wait;
      return DadosDinheiro(
        lancamentos: [
          for (final l in linhas)
            LancamentoObra.fromJson(Map<String, dynamic>.from(l as Map)),
        ],
        orcado: {
          for (final o in orcados)
            ?EtapaId.doCodigo(o['etapa'] as String): (o['valor'] as num)
                .toDouble(),
        },
        mudancas: mudancas,
      );
    },
    () => DadosDinheiro(
      lancamentos: [..._lancamentos]..sort((a, b) => b.data.compareTo(a.data)),
      orcado: {..._orcado},
      mudancas: _mudancas,
    ),
    'Não foi possível carregar os valores. Verifique a conexão e tente de novo.',
  );

  Future<String> salvarGasto(String obraId, LancamentoObra g) => _executar(
    () => _db.rpc<String>(
      'salvar_gasto',
      params: {'p_obra': obraId, 'p_id': g.id, 'p_dados': g.paraSalvar()},
    ),
    () {
      salvosDeTeste.add(g);
      final id = g.id ?? 'novo-${salvosDeTeste.length}';
      _lancamentos = [
        for (final l in _lancamentos)
          if (l.id != id) l,
        LancamentoObra(
          id: id,
          descricao: g.descricao,
          valor: g.valor,
          data: g.data,
          etapa: g.etapa,
          tipo: g.tipo,
          fornecedor: g.fornecedor,
          notaPath: g.notaPath,
        ),
      ];
      return id;
    },
    'Não foi possível salvar o gasto. Verifique a conexão e tente de novo.',
  );

  /// Tira o gasto e, se tinha nota, o arquivo dela.
  Future<void> excluirGasto(String id) async {
    final nota = await _executar(
      () => _db.rpc<String?>('excluir_gasto', params: {'p_id': id}),
      () {
        excluidosDeTeste.add(id);
        _lancamentos = [
          for (final l in _lancamentos)
            if (l.id != id) l,
        ];
        return null;
      },
      'Não foi possível excluir o gasto. Tente de novo.',
    );
    if (nota != null) await apagarNotas([nota]);
  }

  /// Valor nulo volta para a estimativa do app.
  Future<void> definirOrcado(String obraId, EtapaId etapa, double? valor) =>
      _executar(
        () => _db.rpc<void>(
          'definir_orcado',
          params: {'p_obra': obraId, 'p_etapa': etapa.codigo, 'p_valor': valor},
        ),
        () {
          orcadosDeTeste.add((etapa, valor));
          if (valor == null) {
            _orcado.remove(etapa);
          } else {
            _orcado[etapa] = valor;
          }
        },
        'Não foi possível salvar o valor. Tente de novo.',
      );

  Future<void> classificarPedido(String pedidoId, EtapaId? etapa) => _executar(
    () => _db.rpc<void>(
      'classificar_pedido',
      params: {'p_pedido': pedidoId, 'p_etapa': etapa?.codigo},
    ),
    () {
      classificadosDeTeste.add((pedidoId, etapa));
      _lancamentos = [
        for (final l in _lancamentos)
          l.id == pedidoId
              ? LancamentoObra(
                  id: l.id,
                  doPedido: true,
                  descricao: l.descricao,
                  valor: l.valor,
                  data: l.data,
                  etapa: etapa,
                  fornecedor: l.fornecedor,
                  autor: l.autor,
                )
              : l,
      ];
    },
    'Não foi possível mudar a etapa do pedido. Tente de novo.',
  );

  /// Sobe a foto da nota e devolve o caminho. A primeira parte do caminho é a obra: é por ela
  /// que o banco confere quem pode enviar.
  Future<String> enviarNota({
    required String obraId,
    required Uint8List bytes,
    required String nome,
  }) async {
    final minusculo = nome.toLowerCase();
    final (extensao, tipo) = minusculo.endsWith('.png')
        ? ('png', 'image/png')
        : minusculo.endsWith('.webp')
        ? ('webp', 'image/webp')
        : ('jpg', 'image/jpeg');
    if (_teste) return '$obraId/nota-${_notasDeTeste++}.$extensao';
    final arquivo = '${DateTime.now().microsecondsSinceEpoch}.$extensao';
    try {
      await _db.storage
          .from(_balde)
          .uploadBinary(
            '$obraId/$arquivo',
            bytes,
            fileOptions: FileOptions(contentType: tipo),
          );
      return '$obraId/$arquivo';
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível enviar a foto. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// Nota trocada ou tirada. Falhar aqui só deixa um arquivo sobrando.
  Future<void> apagarNotas(List<String> caminhos) async {
    if (_teste || caminhos.isEmpty) return;
    try {
      await _db.storage.from(_balde).remove(caminhos);
    } catch (_) {}
  }

  /// Links de 1 hora para ver as notas: o bucket é privado.
  Future<Map<String, String>> linksDasNotas(List<String> caminhos) async {
    if (_teste || caminhos.isEmpty) return const {};
    try {
      final r = await _db.storage
          .from(_balde)
          .createSignedUrlsResult(caminhos, 3600);
      return {
        for (final l in r)
          if (l is SignedUrlSuccess) l.path: l.signedUrl,
      };
    } catch (_) {
      return const {};
    }
  }
}
