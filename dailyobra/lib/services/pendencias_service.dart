import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// Pendências da obra. Tudo passa por funções do banco, que trazem o nome do responsável e
/// conferem quem pode mexer.
class PendenciasService {
  PendenciasService._();

  static final instance = PendenciasService._();

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<Pendencia> _pendencias = const [];

  @visibleForTesting
  final salvasDeTeste = <Pendencia>[];
  @visibleForTesting
  final resolvidasDeTeste = <(String, bool)>[];
  @visibleForTesting
  final excluidasDeTeste = <String>[];

  @visibleForTesting
  void definirParaTeste({List<Pendencia> pendencias = const [], String? erro}) {
    _teste = true;
    _erro = erro;
    _pendencias = [...pendencias];
    salvasDeTeste.clear();
    resolvidasDeTeste.clear();
    excluidasDeTeste.clear();
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

  /// A obra guarda quantas estão abertas: os avisos dela dependem disso.
  Future<void> _atualizarObras() async {
    if (!_teste) await ObrasService.instance.carregar();
  }

  Future<List<Pendencia>> listar(String obraId) => _executar(
    () async {
      final r = await _db.rpc<List<dynamic>>(
        'pendencias_da_obra',
        params: {'p_obra': obraId},
      );
      return [
        for (final p in r)
          Pendencia.fromJson(Map<String, dynamic>.from(p as Map)),
      ];
    },
    () => [..._pendencias],
    'Não foi possível carregar as pendências. Verifique a conexão e tente de novo.',
  );

  Future<void> salvar(String obraId, Pendencia p) async {
    await _executar(
      () => _db.rpc<String>(
        'salvar_pendencia',
        params: {'p_obra': obraId, 'p_id': p.id, 'p_dados': p.paraSalvar()},
      ),
      () {
        salvasDeTeste.add(p);
        final id = p.id ?? 'nova-${salvasDeTeste.length}';
        _pendencias = [
          for (final o in _pendencias)
            if (o.id != id) o,
          Pendencia(
            id: id,
            descricao: p.descricao,
            etapa: p.etapa,
            responsavelId: p.responsavelId,
            responsavelNome: p.responsavelNome,
            prazo: p.prazo,
            fotoPath: p.fotoPath,
            resolvida: p.resolvida,
          ),
        ];
        return id;
      },
      'Não foi possível salvar a pendência. Verifique a conexão e tente de novo.',
    );
    await _atualizarObras();
  }

  Future<void> resolver(String id, bool resolvida) async {
    await _executar(
      () => _db.rpc<void>(
        'resolver_pendencia',
        params: {'p_id': id, 'p_resolvida': resolvida},
      ),
      () {
        resolvidasDeTeste.add((id, resolvida));
        _pendencias = [
          for (final p in _pendencias)
            p.id == id
                ? Pendencia(
                    id: p.id,
                    descricao: p.descricao,
                    etapa: p.etapa,
                    responsavelId: p.responsavelId,
                    responsavelNome: p.responsavelNome,
                    prazo: p.prazo,
                    fotoPath: p.fotoPath,
                    resolvida: resolvida,
                    possoMexer: p.possoMexer,
                  )
                : p,
        ];
      },
      'Não foi possível atualizar a pendência. Tente de novo.',
    );
    await _atualizarObras();
  }

  /// Devolve o caminho da foto, quando tinha, para apagar o arquivo.
  Future<String?> excluir(String id) async {
    final foto = await _executar(
      () => _db.rpc<String?>('excluir_pendencia', params: {'p_id': id}),
      () {
        excluidasDeTeste.add(id);
        _pendencias = [
          for (final p in _pendencias)
            if (p.id != id) p,
        ];
        return null;
      },
      'Não foi possível excluir a pendência. Tente de novo.',
    );
    await _atualizarObras();
    return foto;
  }
}
