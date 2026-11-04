/// Equipe da obra: quem entra, por qual convite e com qual função.
library;

/// O que cada pessoa faz na obra. As regras daqui repetem as do banco, que é quem de fato decide;
/// aqui elas servem para a tela não oferecer o que o banco vai recusar.
enum FuncaoObra {
  responsavel('Responsável', 'Cuida da obra, da equipe e de tudo o que é registrado.'),
  mestre('Mestre de obras', 'Preenche e finaliza o diário e atualiza as etapas.'),
  estagiario('Estagiário', 'Preenche o diário como rascunho. Quem finaliza é o mestre ou o responsável.'),
  empreiteiro('Empreiteiro', 'Registra no diário e acompanha o andamento, sem ver valores.'),
  cliente('Cliente', 'Acompanha o orçamento, o andamento e o diário, sem alterar nada.');

  const FuncaoObra(this.rotulo, this.descricao);
  final String rotulo;
  final String descricao;

  /// Mexe nos dados da obra e na equipe.
  bool get administra => this == responsavel;

  /// Finaliza o dia e muda a situação das etapas.
  bool get lidera => this == responsavel || this == mestre;

  /// Preenche o diário.
  bool get registra => this != cliente;

  /// Vê a lista de materiais e registra o que chegou na obra.
  bool get cuidaDasCompras => this == responsavel || this == mestre || this == estagiario;

  /// Empreiteiro é de fora e não vê o orçamento.
  bool get veValores => this != empreiteiro;

  static const convidaveis = [mestre, estagiario, empreiteiro, cliente];

  /// Código desconhecido fica com o menor acesso.
  static FuncaoObra doCodigo(String? c) => values.asNameMap()[c] ?? cliente;
}

class MembroObra {
  const MembroObra({required this.id, required this.nome, required this.funcao, this.eu = false});
  factory MembroObra.fromJson(Map<String, dynamic> j) => MembroObra(id: j['user_id'] as String, nome: j['nome'] as String, funcao: FuncaoObra.doCodigo(j['funcao'] as String?), eu: j['eu'] as bool? ?? false);
  final String id;
  final String nome;
  final FuncaoObra funcao;

  /// É quem está usando o app.
  final bool eu;
}

class ConviteObra {
  const ConviteObra({required this.id, required this.codigo, required this.funcao, required this.expiraEm});
  factory ConviteObra.fromJson(Map<String, dynamic> j) => ConviteObra(id: j['id'] as String, codigo: j['codigo'] as String, funcao: FuncaoObra.doCodigo(j['funcao'] as String?), expiraEm: DateTime.parse(j['expira_em'] as String));
  final String id;
  final String codigo;
  final FuncaoObra funcao;
  final DateTime expiraEm;

  bool vencidoEm(DateTime agora) => !expiraEm.isAfter(agora);
}

/// O que aparece antes de a pessoa aceitar.
class PreviaConvite {
  const PreviaConvite({required this.obra, required this.funcao, required this.convidadoPor, required this.jaParticipa});
  factory PreviaConvite.fromJson(Map<String, dynamic> j) => PreviaConvite(obra: j['obra_nome'] as String, funcao: FuncaoObra.doCodigo(j['funcao'] as String?), convidadoPor: j['convidado_por'] as String, jaParticipa: j['ja_participa'] as bool? ?? false);
  final String obra;
  final FuncaoObra funcao;
  final String convidadoPor;
  final bool jaParticipa;
}

const _site = 'https://dailyobrabr-creator.github.io/dailyobra/';

String linkDoConvite(String codigo) => '$_site?convite=$codigo';

/// Texto pronto para o WhatsApp. O código vai junto porque quem já tem o app digita em vez de abrir o link.
String mensagemDoConvite({required String nomeDaObra, required FuncaoObra funcao, required String codigo}) =>
    'Você foi convidado para a obra $nomeDaObra no DailyObra, como ${funcao.rotulo}.\n\n'
    'Abra o link para entrar: ${linkDoConvite(codigo)}\n\n'
    'Se já tem o app, use o código $codigo em Obras. O convite vale por 7 dias.';
