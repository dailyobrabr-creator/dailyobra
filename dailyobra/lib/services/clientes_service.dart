import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente do construtor: quem paga a obra. O documento vai na nota quando o cliente paga.
class ClienteDoConstrutor {
  const ClienteDoConstrutor({
    required this.id,
    required this.nome,
    required this.whatsapp,
    required this.documento,
  });

  factory ClienteDoConstrutor.fromJson(Map<String, dynamic> j) =>
      ClienteDoConstrutor(
        id: j['id'] as String,
        nome: j['nome'] as String,
        whatsapp: j['whatsapp'] as String,
        documento: j['documento'] as String,
      );

  final String id;
  final String nome;
  final String whatsapp;
  final String documento;
}

/// Clientes cadastrados pelo construtor, para escolher quem paga sem digitar de novo.
class ClientesService extends ChangeNotifier {
  ClientesService._();

  static final instance = ClientesService._();

  SupabaseClient get _db => Supabase.instance.client;

  List<ClienteDoConstrutor> _lista = const [];
  bool _carregado = false;
  bool _teste = false;

  List<ClienteDoConstrutor> get lista => _lista;
  bool get carregado => _carregado;

  /// O que [adicionar] mandaria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  final adicionadosDeTeste = <(String, String, String)>[];

  @visibleForTesting
  void definirParaTeste({List<ClienteDoConstrutor> lista = const []}) {
    _lista = lista;
    _carregado = true;
    _teste = true;
    adicionadosDeTeste.clear();
    notifyListeners();
  }

  ClienteDoConstrutor? cliente(String? id) {
    for (final c in _lista) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> carregar() async {
    if (_teste || _db.auth.currentUser == null) return;
    try {
      final linhas = await _db
          .from('construtor_clientes')
          .select('id, nome, whatsapp, documento')
          .order('nome');
      _lista = [for (final j in linhas) ClienteDoConstrutor.fromJson(j)];
      _carregado = true;
      notifyListeners();
    } on Exception {
      // Sem a lista, o construtor ainda cadastra um cliente novo
    }
  }

  /// Cadastra o cliente, ou devolve o que já tem o mesmo documento.
  Future<ClienteDoConstrutor> adicionar({
    required String nome,
    required String whatsapp,
    required String documento,
  }) async {
    final doc = somenteDigitos(documento);
    for (final c in _lista) {
      if (c.documento == doc) return c;
    }
    final zap = somenteDigitos(whatsapp);
    if (_teste) {
      adicionadosDeTeste.add((nome.trim(), zap, doc));
      final novo = ClienteDoConstrutor(
        id: 'novo-${_lista.length + 1}',
        nome: nome.trim(),
        whatsapp: zap,
        documento: doc,
      );
      _lista = [..._lista, novo];
      notifyListeners();
      return novo;
    }
    final linha = await comMensagem(
      () => _db
          .from('construtor_clientes')
          .insert({'nome': nome.trim(), 'whatsapp': zap, 'documento': doc})
          .select('id, nome, whatsapp, documento')
          .single(),
    );
    final novo = ClienteDoConstrutor.fromJson(linha);
    _lista = [..._lista, novo]..sort((a, b) => a.nome.compareTo(b.nome));
    notifyListeners();
    return novo;
  }

  void limpar() {
    _lista = const [];
    _carregado = false;
    notifyListeners();
  }
}
