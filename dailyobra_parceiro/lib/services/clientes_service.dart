import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loja_service.dart';

/// Quem mandou proposta para a loja: com pedido é cliente; sem pedido, lead.
class ClienteLoja {
  const ClienteLoja({
    required this.construtorId,
    this.nome = '',
    this.empresa = '',
    this.telefone = '',
    this.cidade = '',
    this.uf = '',
    required this.propostas,
    required this.pedidos,
    required this.total,
    required this.ultimoContato,
  });

  factory ClienteLoja.fromJson(Map<String, dynamic> j) => ClienteLoja(
    construtorId: j['construtor_id'] as String,
    nome: (j['nome'] as String?) ?? '',
    empresa: (j['empresa'] as String?) ?? '',
    telefone: (j['telefone'] as String?) ?? '',
    cidade: (j['cidade'] as String?) ?? '',
    uf: (j['uf'] as String?) ?? '',
    propostas: (j['propostas'] as num).toInt(),
    pedidos: (j['pedidos'] as num).toInt(),
    total: (j['total'] as num).toDouble(),
    ultimoContato: DateTime.parse(j['ultimo_contato'] as String).toLocal(),
  );

  final String construtorId;
  final String nome;
  final String empresa;
  final String telefone;
  final String cidade;
  final String uf;
  final int propostas;

  /// Pedidos que não foram cancelados.
  final int pedidos;

  /// Soma desses pedidos.
  final double total;
  final DateTime ultimoContato;

  bool get comprou => pedidos > 0;

  String get exibicao => nome.isNotEmpty
      ? nome
      : empresa.isNotEmpty
      ? empresa
      : 'Construtor';

  /// "Souza Obras · Rondonópolis · MT"
  String get linha => [
    if (nome.isNotEmpty) empresa,
    cidade,
    uf,
  ].where((p) => p.isNotEmpty).join(' · ');

  String get resumo => comprou
      ? 'Comprou ${brl.format(total)} em $pedidos ${pedidos == 1 ? 'pedido' : 'pedidos'}'
      : '$propostas ${propostas == 1 ? 'proposta' : 'propostas'}, nenhum pedido';
}

enum FiltroCliente {
  todos('Todos'),
  clientes('Clientes'),
  leads('Leads');

  const FiltroCliente(this.rotulo);
  final String rotulo;
}

/// [lista] na mesma ordem, só com quem é do [filtro] e combina com a [busca] (nome, empresa, cidade ou telefone).
List<ClienteLoja> filtrarClientes(
  List<ClienteLoja> lista,
  FiltroCliente filtro,
  String busca,
) {
  final termo = normalizar(busca);
  final digitos = somenteDigitos(busca);
  return [
    for (final c in lista)
      if (switch (filtro) {
            FiltroCliente.todos => true,
            FiltroCliente.clientes => c.comprou,
            FiltroCliente.leads => !c.comprou,
          } &&
          (termo.isEmpty ||
              normalizar('${c.nome} ${c.empresa} ${c.cidade}')
                  .contains(termo) ||
              (digitos.isNotEmpty &&
                  somenteDigitos(c.telefone).contains(digitos))))
        c,
  ];
}

/// Clientes e leads da loja. A equipe inteira vê: o vendedor é quem liga para o cliente.
class ClientesService extends ChangeNotifier {
  ClientesService._();

  static final instance = ClientesService._();

  SupabaseClient get _db => Supabase.instance.client;

  List<ClienteLoja> _lista = const [];
  bool _carregado = false;
  String? _erro;
  int _pedido = 0;
  Future<List<ClienteLoja>> Function()? _buscarDeTeste;

  List<ClienteLoja> get lista => _lista;
  bool get carregado => _carregado;
  String? get erro => _erro;

  @visibleForTesting
  void definirParaTeste({
    required Future<List<ClienteLoja>> Function() buscar,
  }) {
    limpar();
    _buscarDeTeste = buscar;
  }

  void limpar() {
    _pedido++;
    _lista = const [];
    _carregado = false;
    _erro = null;
    notifyListeners();
  }

  /// Traz a lista de novo. A que já estava fica na tela até a resposta chegar, e a resposta de um
  /// carregar mais antigo é descartada.
  Future<void> carregar() async {
    final meu = ++_pedido;
    try {
      final lista = await _buscar();
      if (meu != _pedido) return;
      _lista = lista;
      _carregado = true;
      _erro = null;
    } on FalhaComMensagem catch (e) {
      if (meu != _pedido) return;
      _erro = e.mensagem;
    }
    notifyListeners();
  }

  Future<List<ClienteLoja>> _buscar() async {
    final buscar = _buscarDeTeste;
    if (buscar != null) return buscar();
    final loja = LojaService.instance.minhaLoja;
    if (loja == null) {
      throw const FalhaComMensagem('Cadastre a loja antes de ver os clientes.');
    }
    final linhas = await comMensagem(
      () => _db.rpc('clientes_loja', params: {'p_loja': loja.id}),
    );
    return [
      for (final j in linhas as List)
        ClienteLoja.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  }
}
