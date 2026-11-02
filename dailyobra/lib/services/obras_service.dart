import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';

/// Obras do usuário no Supabase. Quem vê e altera cada obra é decidido no banco pelas políticas
/// RLS (tabela obra_membros); aqui só há cache em memória, conversão e mensagens em português.
class ObrasService extends ChangeNotifier {
  ObrasService._();

  static final instance = ObrasService._();

  /// Chamado no main, depois do Supabase.initialize: carrega as obras ao entrar e limpa ao sair
  void iniciar() {
    _carregarFixada();
    _assinatura ??= Supabase.instance.client.auth.onAuthStateChange.listen((
      estado,
    ) {
      final usuario = estado.session?.user.id;
      if (usuario == null) {
        _limpar();
      } else if (usuario != _usuarioCarregado) {
        carregar();
      }
    });
  }

  /// Testes de tela: usa estas obras sem consultar o Supabase
  @visibleForTesting
  void definirParaTeste({List<Obra>? obras, String? erro}) {
    _obras = obras;
    _erro = erro;
    _fixada = null;
    notifyListeners();
  }

  StreamSubscription<AuthState>? _assinatura;
  SupabaseClient get _db => Supabase.instance.client;

  List<Obra>? _obras;
  String? _erro;
  String? _usuarioCarregado;
  int _pedido = 0;

  /// null enquanto carrega pela primeira vez
  List<Obra>? get obras => _obras;
  String? get erro => _erro;

  static const _chaveAtiva = 'dailyobra.obraAtiva';
  String? _fixada;

  /// Obra do cartão do Início: a escolhida no Perfil, se ainda existir; senão a última atualizada.
  Obra? get obraAtiva {
    final lista = _obras ?? const <Obra>[];
    if (lista.isEmpty) return null;
    final fixada = _fixada == null ? null : obra(_fixada!);
    if (fixada != null) return fixada;
    return lista.reduce(
      (a, b) => b.atualizadaEm.isAfter(a.atualizadaEm) ? b : a,
    );
  }

  Future<void> fixarAtiva(String obraId) async {
    _fixada = obraId;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(
        _chaveAtiva,
        obraId,
      );
    } catch (_) {
      // Sem armazenamento local a escolha vale só até fechar o app
    }
  }

  Future<void> _carregarFixada() async {
    try {
      _fixada = (await SharedPreferences.getInstance()).getString(_chaveAtiva);
      notifyListeners();
    } catch (_) {}
  }

  Obra? obra(String id) {
    for (final o in _obras ?? const <Obra>[]) {
      if (o.id == id) return o;
    }
    return null;
  }

  static const _colunas =
      'id, nome, cidade, uf, endereco, responsavel, data_inicio, parametros, created_at, updated_at, obra_etapas(etapa, status), obra_membros(user_id, papel)';

  void _limpar() {
    _pedido++;
    _obras = null;
    _erro = null;
    _usuarioCarregado = null;
    notifyListeners();
  }

  Future<void> carregar() async {
    final usuario = _db.auth.currentUser?.id;
    if (usuario == null) return;
    final meu = ++_pedido;
    try {
      final linhas = await _db
          .from('obras')
          .select(_colunas)
          .order('updated_at', ascending: false);
      if (meu != _pedido) return; // chegou uma resposta mais nova
      _obras = [for (final l in linhas) _paraObra(l, usuario)];
      _erro = null;
      _usuarioCarregado = usuario;
    } catch (_) {
      if (meu != _pedido) return;
      _erro = 'Não foi possível carregar as obras. Verifique a conexão e puxe a tela para baixo para tentar de novo.';
    }
    notifyListeners();
  }

  Obra _paraObra(Map<String, dynamic> l, String usuario) {
    final status = <EtapaId, StatusEtapa>{};
    for (final e in (l['obra_etapas'] as List? ?? const [])) {
      final id = EtapaId.doCodigo(e['etapa'] as String);
      if (id != null) status[id] = StatusEtapa.doCodigo(e['status'] as String?);
    }
    String? papel;
    for (final m in (l['obra_membros'] as List? ?? const [])) {
      if (m['user_id'] == usuario) papel = m['papel'] as String?;
    }
    return Obra(
      id: l['id'] as String,
      papel: Papel.doCodigo(papel),
      dados: DadosObra(
        nome: l['nome'] as String? ?? '',
        cidade: l['cidade'] as String? ?? '',
        uf: l['uf'] as String? ?? '',
        endereco: l['endereco'] as String? ?? '',
        responsavel: l['responsavel'] as String? ?? '',
        inicioPrevisto: l['data_inicio'] as String? ?? '',
      ),
      parametros: ParametrosObra.fromJson(
        (l['parametros'] as Map?)?.cast<String, dynamic>(),
      ),
      statusEtapas: status,
      criadaEm: DateTime.parse(l['created_at'] as String),
      atualizadaEm: DateTime.parse(l['updated_at'] as String),
    );
  }

  Map<String, dynamic> _paraLinha(DadosObra d, ParametrosObra p) {
    String? ouNulo(String s) => s.trim().isEmpty ? null : s.trim();
    return {
      'nome': d.nome.trim(),
      'cidade': ouNulo(d.cidade),
      'uf': ouNulo(d.uf),
      'endereco': ouNulo(d.endereco),
      'responsavel': ouNulo(d.responsavel),
      'data_inicio': ouNulo(d.inicioPrevisto),
      'parametros': p.toJson(),
    };
  }

  Future<String> criar(DadosObra d, ParametrosObra p) async {
    try {
      final r = await _db
          .from('obras')
          .insert({..._paraLinha(d, p), 'status': 'planejada'})
          .select('id')
          .single();
      await carregar();
      return r['id'] as String;
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível cadastrar a obra. Verifique a conexão e tente de novo.',
      );
    }
  }

  Future<void> atualizar(String id, DadosObra d, ParametrosObra p) async {
    List<dynamic> r;
    try {
      r = await _db
          .from('obras')
          .update(_paraLinha(d, p))
          .eq('id', id)
          .select('id');
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível salvar as alterações. Verifique a conexão e tente de novo.',
      );
    }
    // RLS não devolve erro quando bloqueia: a linha simplesmente não é alterada
    if (r.isEmpty) {
      throw const FalhaAoSalvar(
        'Só o administrador da obra pode alterar os dados e o orçamento.',
      );
    }
    await carregar();
  }

  /// Atualiza na tela antes da resposta do servidor e desfaz se o servidor recusar
  Future<void> definirStatus(
    String id,
    EtapaId etapa,
    StatusEtapa status,
  ) async {
    final anterior = _obras;
    _obras = [
      for (final o in _obras ?? const <Obra>[])
        o.id == id ? o.comStatus(etapa, status) : o,
    ];
    notifyListeners();
    try {
      final r = await _db
          .from('obra_etapas')
          .upsert({
            'obra_id': id,
            'etapa': etapa.codigo,
            'status': status.codigo,
          }, onConflict: 'obra_id,etapa')
          .select('etapa');
      if (r.isEmpty) {
        throw const PostgrestException(message: 'sem linha', code: '42501');
      }
    } catch (e) {
      _obras = anterior;
      notifyListeners();
      throw FalhaAoSalvar(
        e is PostgrestException && e.code == '42501'
            ? 'Seu acesso a esta obra é só de acompanhamento.'
            : 'Não foi possível salvar a situação da etapa. Tente de novo.',
      );
    }
    unawaited(carregar());
  }

  Future<void> excluir(String id) async {
    List<dynamic> r;
    try {
      r = await _db.from('obras').delete().eq('id', id).select('id');
    } catch (_) {
      throw const FalhaAoSalvar(
        'Não foi possível excluir a obra. Verifique a conexão e tente de novo.',
      );
    }
    if (r.isEmpty) {
      throw const FalhaAoSalvar('Só o administrador da obra pode excluí-la.');
    }
    _obras = [
      for (final o in _obras ?? const <Obra>[])
        if (o.id != id) o,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    super.dispose();
  }
}

class FalhaAoSalvar implements Exception {
  const FalhaAoSalvar(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}
