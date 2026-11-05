import 'dart:async';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obras_service.dart';

/// As ajudas da IA na obra, pela função ia-obra do Supabase. A resposta só preenche o formulário: quem usa confere antes de salvar.
class IaService {
  IaService._();

  static final instance = IaService._();

  static const _espera = Duration(seconds: 90);
  static const _falhou = 'Não deu para usar a IA agora. Tente de novo.';

  var _teste = false;
  SugestaoDoDia _diaDeTeste = const SugestaoDoDia();
  SugestaoDaNota _notaDeTeste = const SugestaoDaNota();
  String? _erro;
  Future<void>? _segurar;

  @visibleForTesting
  final pedidosDeTeste = <String>[];

  /// Com [segurar], a resposta só chega quando esse Future terminar: os testes conferem a tela durante a espera.
  @visibleForTesting
  void definirParaTeste({
    SugestaoDoDia dia = const SugestaoDoDia(),
    SugestaoDaNota nota = const SugestaoDaNota(),
    String? erro,
    Future<void>? segurar,
  }) {
    _teste = true;
    _diaDeTeste = dia;
    _notaDeTeste = nota;
    _erro = erro;
    _segurar = segurar;
    pedidosDeTeste.clear();
  }

  Future<SugestaoDoDia> organizarDia(String obraId, String texto) async {
    if (_teste) {
      await _respostaDeTeste(texto);
      return _diaDeTeste;
    }
    final r = await _chamar({'acao': 'diario', 'obra': obraId, 'texto': texto});
    return SugestaoDoDia.fromJson(Map<String, dynamic>.from(r['dia'] as Map));
  }

  Future<SugestaoDaNota> lerNota(String obraId, String caminho) async {
    if (_teste) {
      await _respostaDeTeste(caminho);
      return _notaDeTeste;
    }
    final r = await _chamar({
      'acao': 'nota',
      'obra': obraId,
      'caminho': caminho,
    });
    return SugestaoDaNota.fromJson(Map<String, dynamic>.from(r['nota'] as Map));
  }

  Future<void> _respostaDeTeste(String pedido) async {
    pedidosDeTeste.add(pedido);
    await _segurar;
    final erro = _erro;
    if (erro != null) throw FalhaAoSalvar(erro);
  }

  Future<Map<String, dynamic>> _chamar(Map<String, Object?> corpo) async {
    try {
      final resposta = await Supabase.instance.client.functions
          .invoke('ia-obra', body: corpo)
          .timeout(_espera);
      return Map<String, dynamic>.from(resposta.data as Map);
    } on FunctionException catch (e) {
      final detalhes = e.details;
      final erro = detalhes is Map ? detalhes['erro'] : null;
      throw FalhaAoSalvar(erro is String ? erro : _falhou);
    } catch (_) {
      throw const FalhaAoSalvar(_falhou);
    }
  }
}
