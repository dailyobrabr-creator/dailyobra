import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

LinhaResultado linha(EtapaId etapa, double total) =>
    LinhaResultado(etapa: etapa, nome: etapa.codigo, descricao: '', area: 100, custoM2: 1, maoDeObra: 0, material: 0, total: total);

LancamentoObra gasto(double valor, {EtapaId? etapa}) => LancamentoObra(descricao: 'x', valor: valor, data: DateTime(2026, 11, 3), etapa: etapa);

final etapas = [linha(EtapaId.fundacao, 1000), linha(EtapaId.alvenaria, 2000)];

void main() {
  test('lê gasto do banco', () {
    final l = LancamentoObra.fromJson(const {
      'id': 'g1',
      'origem': 'gasto',
      'etapa': 'alvenaria',
      'tipo': 'mao_de_obra',
      'descricao': 'Diária',
      'fornecedor': 'João',
      'valor': 150.5,
      'data': '2026-11-03',
      'nota_path': 'o1/a.jpg',
      'autor': 'Marina',
      'posso_mexer': true,
    });
    expect(l.doPedido, isFalse);
    expect(l.etapa, EtapaId.alvenaria);
    expect(l.tipo, TipoGasto.maoDeObra);
    expect(l.valor, 150.5);
    expect(l.data, DateTime(2026, 11, 3));
    expect(l.notaPath, 'o1/a.jpg');
    expect(l.possoMexer, isTrue);
  });

  test('lê pedido do banco', () {
    final l = LancamentoObra.fromJson(const {'id': 'p1', 'origem': 'pedido', 'etapa': null, 'tipo': 'material', 'descricao': 'Pedido na Operário', 'valor': 1000, 'data': '2026-11-03'});
    expect(l.doPedido, isTrue);
    expect(l.etapa, isNull);
    expect(l.valor, 1000.0);
    expect(l.possoMexer, isFalse);
  });

  test('prepara o gasto para salvar', () {
    final l = LancamentoObra(descricao: 'Areia', valor: 150.5, data: DateTime(2026, 11, 3), etapa: EtapaId.alvenaria, tipo: TipoGasto.maoDeObra, fornecedor: 'Depósito', notaPath: 'o1/a.jpg');
    expect(l.paraSalvar(), {'descricao': 'Areia', 'valor': 150.5, 'data': '2026-11-03', 'etapa': 'alvenaria', 'tipo': 'mao_de_obra', 'fornecedor': 'Depósito', 'nota_path': 'o1/a.jpg'});
  });

  test('soma o realizado por etapa', () {
    final r = resumirDinheiro(etapas: etapas, lancamentos: [gasto(100, etapa: EtapaId.fundacao), gasto(50, etapa: EtapaId.fundacao), gasto(300, etapa: EtapaId.alvenaria)]);
    expect(r.linhas[0].realizado, 150);
    expect(r.linhas[1].realizado, 300);
    expect(r.realizado, 450);
    expect(r.orcado, 3000);
    expect(r.saldo, 2550);
    expect(r.semEtapa, 0);
    expect(r.alerta, isNull);
  });

  test('o que não tem etapa entra no total', () {
    final r = resumirDinheiro(etapas: etapas, lancamentos: [gasto(100), gasto(40, etapa: EtapaId.fundacao)]);
    expect(r.semEtapa, 100);
    expect(r.realizado, 140);
  });

  test('etapa que saiu do orçamento não some da conta', () {
    final r = resumirDinheiro(etapas: etapas, lancamentos: [gasto(70, etapa: EtapaId.pintura)]);
    expect(r.semEtapa, 70);
    expect(r.realizado, 70);
  });

  test('orçado próprio troca a estimativa', () {
    final r = resumirDinheiro(etapas: etapas, orcado: const {EtapaId.fundacao: 500}, lancamentos: const []);
    expect(r.linhas[0].orcado, 500);
    expect(r.linhas[0].estimado, 1000);
    expect(r.linhas[0].proprio, isTrue);
    expect(r.linhas[1].proprio, isFalse);
    expect(r.orcado, 2500);
  });

  test('adicionais entram no orçado do total', () {
    expect(resumirDinheiro(etapas: etapas, adicionais: 700, lancamentos: const []).orcado, 3700);
  });

  group('estouro', () {
    test('etapa no limite não estourou', () {
      final l = resumirDinheiro(etapas: etapas, lancamentos: [gasto(1000, etapa: EtapaId.fundacao)]).linhas[0];
      expect(l.estourou, isFalse);
      expect(l.perto, isTrue);
      expect(l.fracao, 1);
    });

    test('perto do limite a partir de 90%', () {
      LinhaDinheiro com(double v) => resumirDinheiro(etapas: etapas, lancamentos: [gasto(v, etapa: EtapaId.fundacao)]).linhas[0];
      expect(com(899).perto, isFalse);
      expect(com(900).perto, isTrue);
    });

    test('etapa estourada', () {
      final r = resumirDinheiro(etapas: etapas, lancamentos: [gasto(1250, etapa: EtapaId.fundacao)]);
      expect(r.linhas[0].estourou, isTrue);
      expect(r.linhas[0].excedente, 250);
      expect(r.linhas[0].perto, isFalse);
      expect(r.etapasEstouradas, 1);
      expect(r.estourou, isFalse);
      expect(r.alerta, '1 etapa passou do orçado.');
    });

    test('duas etapas estouradas', () {
      final r = resumirDinheiro(etapas: etapas, orcado: const {EtapaId.fundacao: 10, EtapaId.alvenaria: 10}, adicionais: 500, lancamentos: [gasto(20, etapa: EtapaId.fundacao), gasto(20, etapa: EtapaId.alvenaria)]);
      expect(r.alerta, '2 etapas passaram do orçado.');
    });

    test('obra inteira estourada', () {
      final r = resumirDinheiro(etapas: etapas, lancamentos: [gasto(3500)]);
      expect(r.estourou, isTrue);
      expect(r.alerta, contains('A obra passou do orçado em'));
      expect(r.alerta, contains(brl.format(500)));
    });

    test('etapa com orçado zero e gasto conta como estourada', () {
      final r = resumirDinheiro(etapas: etapas, orcado: const {EtapaId.fundacao: 0}, lancamentos: [gasto(10, etapa: EtapaId.fundacao)]);
      expect(r.linhas[0].estourou, isTrue);
      expect(r.linhas[0].fracao, 1);
      expect(resumirDinheiro(etapas: etapas, orcado: const {EtapaId.fundacao: 0}, lancamentos: const []).linhas[0].fracao, 0);
    });
  });

  test('texto do resumo', () {
    final r = resumirDinheiro(etapas: etapas, lancamentos: [gasto(1200)]);
    expect(r.texto, '${brlInteiro.format(1200)} de ${brlInteiro.format(3000)}');
  });
}
