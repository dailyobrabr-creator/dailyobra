import 'loja_service.dart';

/// Sistemas de gestão mais usados nas lojas de material de construção, na ordem das Configurações.
const sistemasDeGestao = [
  'Santri',
  'Bling',
  'Tiny',
  'Omie',
  'TOTVS',
  'Sankhya',
  'Linx',
  'Conta Azul',
];

/// Até onde vai o nome do sistema (a mesma regra do banco).
const tamanhoDoSistema = 40;

/// O que o Faturamento diz, com o nome do sistema da loja. Sem sistema, a loja só registra o número da venda.
class TextosDoSistema {
  const TextosDoSistema(this.sistema);

  /// Os textos da loja aberta no app.
  factory TextosDoSistema.daLoja() =>
      TextosDoSistema(LojaService.instance.dados.sistemaGestao);

  final String? sistema;

  String get botaoLancar => switch (sistema) {
    final s? => 'Lançar no $s',
    null => 'Registrar venda',
  };

  String get vazioParaLancar => switch (sistema) {
    final s? =>
      'Os pedidos pagos ou com prazo aprovado aparecem aqui para entrar no $s.',
    null => 'Os pedidos pagos ou com prazo aprovado aparecem aqui para você registrar a venda.',
  };

  String get vazioLancados => switch (sistema) {
    final s? => 'Os pedidos lançados no $s ficam aqui, com o número da venda.',
    null => 'As vendas registradas ficam aqui, com o número de cada uma.',
  };

  String get canceladoLancado => switch (sistema) {
    final s? => 'Cancelado: estornar no $s',
    null => 'Cancelado: desfazer a venda',
  };

  String get avisoDesfazer => switch (sistema) {
    final s? =>
      'O pedido volta para a fila. Se a venda já entrou no $s, estorne por lá.',
    null => 'O pedido volta para a fila. Se a venda já foi registrada em outro lugar, desfaça por lá.',
  };

  String explicacaoDoLancamento(String valor) => switch (sistema) {
    final s? =>
      'Lance a venda de $valor no $s e informe o número que ele gerou.',
    null =>
      'Registre a venda de $valor e informe o número dela (nota, recibo ou pedido).',
  };

  String get rotuloDoNumero => switch (sistema) {
    final s? => 'Número da venda no $s',
    null => 'Número da venda',
  };

  String get dadoDoPedido => switch (sistema) {
    final s? => 'Venda no $s',
    null => 'Venda registrada',
  };

  String pedidosParaLancar(int n) {
    final onde = switch (sistema) {
      final s? => ' no $s',
      null => '',
    };
    return switch (n) {
      0 => 'Nenhum pedido para lançar',
      1 => '1 pedido para lançar$onde',
      _ => '$n pedidos para lançar$onde',
    };
  }
}
