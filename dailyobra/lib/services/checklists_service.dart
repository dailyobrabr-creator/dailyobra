import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'diario_service.dart';
import 'obras_service.dart';

/// Checklists da obra. As fotos ficam no mesmo bucket das fotos do diário, porque viram foto de
/// pendência quando o item não está conforme.
class ChecklistsService {
  ChecklistsService._();

  static final instance = ChecklistsService._();

  SupabaseClient get _db => Supabase.instance.client;

  var _teste = false;
  String? _erro;
  List<Checklist> _checklists = const [];

  @visibleForTesting
  final salvosDeTeste = <(Checklist, bool)>[];
  @visibleForTesting
  final excluidosDeTeste = <String>[];

  @visibleForTesting
  void definirParaTeste({List<Checklist> checklists = const [], String? erro}) {
    _teste = true;
    _erro = erro;
    _checklists = [...checklists];
    salvosDeTeste.clear();
    excluidosDeTeste.clear();
  }

  Future<List<Checklist>> listar(String obraId) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      return [..._checklists]..sort((a, b) => b.data.compareTo(a.data));
    }
    try {
      final r = await _db
          .from('obra_checklists')
          .select('*, obra_checklist_itens(*)')
          .eq('obra_id', obraId)
          .order('data', ascending: false);
      return [for (final j in r) Checklist.fromJson(j)];
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível carregar os checklists. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// Ao concluir, o banco abre as pendências e a obra precisa recontar as dela.
  Future<void> salvar(
    String obraId,
    Checklist c, {
    bool concluir = false,
  }) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      salvosDeTeste.add((c, concluir));
      final id = c.id ?? 'novo-${salvosDeTeste.length}';
      _checklists = [
        for (final x in _checklists)
          if (x.id != id) x,
        Checklist(
          id: id,
          modelo: c.modelo,
          tipo: c.tipo,
          titulo: c.titulo,
          etapa: c.etapa,
          local: c.local,
          data: c.data,
          observacoes: c.observacoes,
          concluido: concluir,
          itens: c.itens,
        ),
      ];
      return;
    }
    const falha =
        'Não foi possível salvar o checklist. Verifique a conexão e tente de novo.';
    try {
      await _db.rpc<String>(
        'salvar_checklist',
        params: {
          'p_obra': obraId,
          'p_id': c.id,
          'p_dados': c.paraSalvar(),
          'p_concluir': concluir,
        },
      );
    } on PostgrestException catch (e) {
      throw FalhaAoSalvar(e.code == 'P0001' ? e.message : falha);
    } catch (_) {
      throw const FalhaAoSalvar(falha);
    }
    if (concluir) await ObrasService.instance.carregar();
  }

  Future<void> excluir(String id) async {
    if (_teste) {
      if (_erro != null) throw FalhaAoSalvar(_erro!);
      excluidosDeTeste.add(id);
      _checklists = [
        for (final x in _checklists)
          if (x.id != id) x,
      ];
      return;
    }
    const falha = 'Não foi possível excluir o checklist. Tente de novo.';
    final List<dynamic> fotos;
    try {
      fotos = await _db.rpc<List<dynamic>>(
        'excluir_checklist',
        params: {'p_id': id},
      );
    } on PostgrestException catch (e) {
      throw FalhaAoSalvar(e.code == 'P0001' ? e.message : falha);
    } catch (_) {
      throw const FalhaAoSalvar(falha);
    }
    await DiarioService.instance.apagarFotos([
      for (final f in fotos) f as String,
    ]);
  }
}
