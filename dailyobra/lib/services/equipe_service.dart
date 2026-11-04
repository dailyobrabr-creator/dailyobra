import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// Equipe e convites da obra. Tudo o que muda a equipe passa por funções do banco, que conferem
/// quem pode e mantêm a função e o papel iguais.
class EquipeService {
  EquipeService._();

  static final instance = EquipeService._();

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  List<MembroObra> _membros = const [];
  List<ConviteObra> _convites = const [];
  PreviaConvite? _previa;
  String? _erro;

  @visibleForTesting
  final convidadosDeTeste = <FuncaoObra>[];
  @visibleForTesting
  final canceladosDeTeste = <String>[];
  @visibleForTesting
  final mudancasDeTeste = <(String, FuncaoObra)>[];
  @visibleForTesting
  final removidosDeTeste = <String>[];
  @visibleForTesting
  final aceitosDeTeste = <String>[];

  @visibleForTesting
  void definirParaTeste({
    List<MembroObra> membros = const [],
    List<ConviteObra> convites = const [],
    PreviaConvite? previa,
    String? erro,
  }) {
    _teste = true;
    _membros = [...membros];
    _convites = [...convites];
    _previa = previa;
    _erro = erro;
    convidadosDeTeste.clear();
    canceladosDeTeste.clear();
    mudancasDeTeste.clear();
    removidosDeTeste.clear();
    aceitosDeTeste.clear();
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
      return await noBanco();
    } on PostgrestException catch (e) {
      throw FalhaAoSalvar(e.code == 'P0001' ? e.message : falha);
    } catch (_) {
      throw FalhaAoSalvar(falha);
    }
  }

  Future<List<MembroObra>> equipe(String obraId) => _executar(
    () async {
      final r = await _db.rpc<List<dynamic>>(
        'equipe_da_obra',
        params: {'p_obra': obraId},
      );
      return [
        for (final m in r)
          MembroObra.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
    },
    () => [..._membros],
    'Não foi possível carregar a equipe. Verifique a conexão e tente de novo.',
  );

  /// Só os que ainda podem ser usados.
  Future<List<ConviteObra>> convites(String obraId) => _executar(
    () async {
      final r = await _db
          .from('obra_convites')
          .select('id, codigo, funcao, expira_em')
          .eq('obra_id', obraId)
          .isFilter('usado_em', null)
          .gt('expira_em', DateTime.now().toUtc().toIso8601String())
          .order('criado_em', ascending: false);
      return [for (final c in r) ConviteObra.fromJson(c)];
    },
    () => [..._convites],
    'Não foi possível carregar os convites. Verifique a conexão e tente de novo.',
  );

  Future<ConviteObra> convidar(String obraId, FuncaoObra funcao) => _executar(
    () async {
      final r = await _db.rpc<dynamic>(
        'criar_convite',
        params: {'p_obra': obraId, 'p_funcao': funcao.name},
      );
      return ConviteObra.fromJson(Map<String, dynamic>.from(r as Map));
    },
    () {
      convidadosDeTeste.add(funcao);
      final codigo = convidadosDeTeste.length.toString().padLeft(5, '0');
      final novo = ConviteObra(
        id: 'novo-$codigo',
        codigo: 'TESTE-$codigo',
        funcao: funcao,
        expiraEm: DateTime(2099),
      );
      _convites = [novo, ..._convites];
      return novo;
    },
    'Não foi possível criar o convite. Verifique a conexão e tente de novo.',
  );

  Future<void> cancelarConvite(String id) => _executar(
    () => _db.rpc<void>('cancelar_convite', params: {'p_convite': id}),
    () {
      canceladosDeTeste.add(id);
      _convites = [
        for (final c in _convites)
          if (c.id != id) c,
      ];
    },
    'Não foi possível cancelar o convite. Tente de novo.',
  );

  Future<void> mudarFuncao(String obraId, String usuario, FuncaoObra funcao) =>
      _executar(
        () => _db.rpc<void>(
          'mudar_funcao_membro',
          params: {
            'p_obra': obraId,
            'p_usuario': usuario,
            'p_funcao': funcao.name,
          },
        ),
        () {
          mudancasDeTeste.add((usuario, funcao));
          _membros = [
            for (final m in _membros)
              m.id == usuario
                  ? MembroObra(id: m.id, nome: m.nome, funcao: funcao, eu: m.eu)
                  : m,
          ];
        },
        'Não foi possível mudar a função. Tente de novo.',
      );

  /// Tira alguém da obra, ou a própria pessoa quando ela sai.
  Future<void> remover(String obraId, String usuario) async {
    await _executar(
      () => _db.rpc<void>(
        'remover_membro',
        params: {'p_obra': obraId, 'p_usuario': usuario},
      ),
      () {
        removidosDeTeste.add(usuario);
        _membros = [
          for (final m in _membros)
            if (m.id != usuario) m,
        ];
      },
      'Não foi possível tirar esta pessoa da obra. Tente de novo.',
    );
    if (!_teste) await ObrasService.instance.carregar();
  }

  Future<PreviaConvite> verConvite(String codigo) => _executar(
    () async {
      final r = await _db.rpc<List<dynamic>>(
        'ver_convite',
        params: {'p_codigo': codigo},
      );
      return PreviaConvite.fromJson(Map<String, dynamic>.from(r.first as Map));
    },
    () => _previa!,
    'Não foi possível abrir o convite. Verifique a conexão e tente de novo.',
  );

  /// Coloca a pessoa na obra e devolve o id dela.
  Future<String> aceitar(String codigo) async {
    final id = await _executar(
      () => _db.rpc<String>('aceitar_convite', params: {'p_codigo': codigo}),
      () {
        aceitosDeTeste.add(codigo);
        return 'o1';
      },
      'Não foi possível aceitar o convite. Verifique a conexão e tente de novo.',
    );
    if (!_teste) await ObrasService.instance.carregar();
    return id;
  }
}
