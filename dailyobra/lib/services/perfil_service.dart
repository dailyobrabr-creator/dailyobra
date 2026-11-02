import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalogo_service.dart';

/// Dados do construtor na tabela profiles (cada um só lê e altera o próprio, pela RLS).
class PerfilService extends ChangeNotifier {
  PerfilService._();

  static final instance = PerfilService._();

  SupabaseClient get _db => Supabase.instance.client;

  String _nome = '';
  String _empresa = '';
  String? _cidade;
  String? _uf;
  String? _telefone;
  String? _emailTeste;
  String? _documento;

  String get nome => _nome;
  String get empresa => _empresa;
  String? get cidade => _cidade;
  String? get uf => _uf;
  String? get telefone => _telefone;

  /// CPF ou CNPJ só com dígitos; vai na nota quando o construtor mesmo paga o pedido.
  String? get documento => _documento;
  String get email => _emailTeste ?? _db.auth.currentUser?.email ?? '';

  String get primeiroNome {
    final p = _nome.trim().split(RegExp(r'\s+')).first;
    return p.isEmpty ? '' : p;
  }

  @visibleForTesting
  void definirParaTeste({
    String nome = '',
    String empresa = '',
    String? cidade,
    String? uf,
    String? email,
    String? documento,
  }) {
    _nome = nome;
    _empresa = empresa;
    _cidade = cidade;
    _uf = uf;
    _documento = documento;
    _emailTeste = email ?? 'ana@exemplo.com';
    CatalogoService.instance.definirCidade(cidade);
    notifyListeners();
  }

  void limpar() {
    _nome = _empresa = '';
    _cidade = _uf = _telefone = _documento = null;
    notifyListeners();
  }

  Future<void> carregar() async {
    final id = _db.auth.currentUser?.id;
    if (id == null) return;
    try {
      final j = await _db
          .from('profiles')
          .select('nome, empresa, cidade, uf, telefone')
          .eq('id', id)
          .maybeSingle();
      // Fora de profiles: as lojas que recebem proposta leem o perfil, o documento só o próprio construtor
      final doc = await _db
          .from('construtor_documentos')
          .select('documento')
          .eq('user_id', id)
          .maybeSingle();
      final meta = _db.auth.currentUser?.userMetadata ?? const {};
      _nome = (j?['nome'] as String?) ?? (meta['nome'] as String?) ?? '';
      _empresa = (j?['empresa'] as String?) ?? '';
      _cidade = j?['cidade'] as String?;
      _uf = (j?['uf'] as String?)?.trim();
      _telefone = j?['telefone'] as String?;
      _documento = doc?['documento'] as String?;
      CatalogoService.instance.definirCidade(_cidade);
      notifyListeners();
    } catch (_) {
      // Sem perfil carregado o app funciona igual; só perde a saudação e a ordem por cidade
    }
  }

  /// Lança [Exception] com a mensagem pronta para a tela.
  Future<void> salvar({
    required String nome,
    required String empresa,
    String? cidade,
    String? uf,
    String? documento,
  }) async {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw Exception('Entre de novo para salvar o perfil.');
    final doc = somenteDigitos(documento ?? '');
    final dados = {
      'nome': nome.trim(),
      'empresa': empresa.trim(),
      'cidade': (cidade?.trim().isEmpty ?? true) ? null : cidade!.trim(),
      'uf': (uf?.trim().isEmpty ?? true) ? null : uf!.trim().toUpperCase(),
    };
    try {
      await _db.from('profiles').upsert({'id': id, ...dados});
      final documentos = _db.from('construtor_documentos');
      if (doc.isEmpty) {
        await documentos.delete().eq('user_id', id);
      } else {
        await documentos.upsert({'user_id': id, 'documento': doc});
      }
    } catch (e) {
      throw Exception(mensagemDoServidor(e));
    }
    _nome = dados['nome']!;
    _empresa = dados['empresa']!;
    _cidade = dados['cidade'];
    _uf = dados['uf'];
    _documento = doc.isEmpty ? null : doc;
    CatalogoService.instance.definirCidade(_cidade);
    notifyListeners();
  }
}
