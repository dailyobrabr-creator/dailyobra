import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

const base = PropostaComercial(
  cliente: 'Dona Lia',
  titulo: 'Casa',
  itens: [ItemComercial(descricao: 'Fundação', valor: 1000), ItemComercial(descricao: 'Alvenaria', valor: 2000)],
);

PropostaComercial com({List<ItemComercial>? itens, double desconto = 0, List<ParcelaComercial> parcelas = const [], String cliente = 'Dona Lia', String titulo = 'Casa'}) =>
    PropostaComercial(cliente: cliente, titulo: titulo, itens: itens ?? base.itens, desconto: desconto, parcelas: parcelas);

void main() {
  test('lê do banco', () {
    final p = PropostaComercial.fromJson(const {
      'id': 'p1',
      'numero': 12,
      'cliente': 'Dona Lia',
      'contato': null,
      'titulo': 'Casa',
      'endereco': 'Rua A',
      'cidade': 'Cuiabá',
      'uf': 'MT',
      'area': 120.5,
      'padrao': 'media_alta',
      'itens': [
        {'descricao': 'Fundação', 'valor': 1000},
      ],
      'desconto': 10,
      'mostrar_valores': false,
      'parcelas': [
        {'descricao': 'Entrada', 'percentual': 30, 'dias': 0},
      ],
      'inclui': 'Mão de obra',
      'nao_inclui': null,
      'prazo_dias': 180,
      'validade': '2027-01-10',
      'observacoes': null,
      'situacao': 'enviada',
      'obra_id': 'o1',
      'criado_em': '2026-11-05T12:00:00+00:00',
    });
    expect((p.numero, p.contato, p.area, p.padrao, p.desconto, p.mostrarValores, p.prazoDias, p.situacao, p.obraId), (12, '', 120.5, Padrao.mediaAlta, 10, false, 180, SituacaoComercial.enviada, 'o1'));
    expect(p.itens.single.valor, 1000);
    expect(p.parcelas.single.percentual, 30);
    expect(p.validade, DateTime(2027, 1, 10));
  });

  test('situação desconhecida vira rascunho', () {
    expect(SituacaoComercial.doCodigo('x'), SituacaoComercial.rascunho);
  });

  test('soma com desconto', () {
    final p = com(desconto: 500);
    expect((p.subtotal, p.total), (3000, 2500));
  });

  test('desconto maior que os itens não deixa negativo', () {
    expect(com(desconto: 9000).total, 0);
  });

  group('parcelas', () {
    test('sem parcelas não há o que conferir', () {
      expect(com().parcelasFecham, isTrue);
    });

    test('precisam fechar 100%', () {
      expect(com(parcelas: const [ParcelaComercial(descricao: 'a', percentual: 30)]).parcelasFecham, isFalse);
      expect(com(parcelas: const [ParcelaComercial(descricao: 'a', percentual: 33.33), ParcelaComercial(descricao: 'b', percentual: 33.33), ParcelaComercial(descricao: 'c', percentual: 33.34)]).parcelasFecham, isTrue);
    });

    test('a última fecha o total no centavo', () {
      final p = com(
        itens: const [ItemComercial(descricao: 'a', valor: 1000)],
        parcelas: const [ParcelaComercial(descricao: 'a', percentual: 33.33), ParcelaComercial(descricao: 'b', percentual: 33.33), ParcelaComercial(descricao: 'c', percentual: 33.34)],
      );
      expect(p.valoresDasParcelas.take(2), [333.3, 333.3]);
      expect(p.valoresDasParcelas.fold<double>(0, (s, v) => s + v), closeTo(1000, .001));
    });

    test('quando vence cada parcela', () {
      expect(const ParcelaComercial(descricao: 'a', percentual: 1).quando, 'No início');
      expect(const ParcelaComercial(descricao: 'a', percentual: 1, dias: 1).quando, '1 dia depois');
      expect(const ParcelaComercial(descricao: 'a', percentual: 1, dias: 30).quando, '30 dias depois');
    });
  });

  group('validade', () {
    final hoje = DateTime(2026, 11, 5);
    PropostaComercial na(DateTime? v, SituacaoComercial s) => PropostaComercial(cliente: 'a', titulo: 'b', validade: v, situacao: s);

    test('vence depois do último dia', () {
      expect(na(DateTime(2026, 11, 5), SituacaoComercial.enviada).vencida(hoje), isFalse);
      expect(na(DateTime(2026, 11, 4), SituacaoComercial.enviada).vencida(hoje), isTrue);
    });

    test('sem validade, aceita ou recusada não vence', () {
      expect(na(null, SituacaoComercial.enviada).vencida(hoje), isFalse);
      expect(na(DateTime(2026, 1, 1), SituacaoComercial.aceita).vencida(hoje), isFalse);
      expect(na(DateTime(2026, 1, 1), SituacaoComercial.recusada).vencida(hoje), isFalse);
    });
  });

  test('confere o que falta para gerar', () {
    expect(com(cliente: ' ').faltaParaGerar, 'Diga quem é o cliente.');
    expect(com(titulo: ' ').faltaParaGerar, 'Diga o nome da obra ou do serviço.');
    expect(com(itens: const []).faltaParaGerar, 'Adicione pelo menos um item.');
    expect(com(desconto: 9000).faltaParaGerar, 'A proposta precisa de um valor.');
    expect(com(parcelas: const [ParcelaComercial(descricao: 'a', percentual: 10)]).faltaParaGerar, 'As parcelas precisam somar 100%.');
    expect(com().faltaParaGerar, isNull);
  });

  test('passa os dados para a obra', () {
    const p = PropostaComercial(cliente: 'a', titulo: 'Casa', endereco: 'Rua A', cidade: 'Cuiabá', uf: 'MT', area: 120.5, padrao: Padrao.alto);
    expect((p.dadosDaObra.nome, p.dadosDaObra.endereco, p.dadosDaObra.cidade, p.dadosDaObra.uf), ('Casa', 'Rua A', 'Cuiabá', 'MT'));
    expect((p.parametrosDaObra.area, p.parametrosDaObra.padrao), ('120,5', Padrao.alto));
    expect(lerNumero(p.parametrosDaObra.area), 120.5);
    expect(const PropostaComercial(cliente: 'a', titulo: 'b').parametrosDaObra.area, '');
  });

  test('monta o que vai para o banco', () {
    final m = PropostaComercial(cliente: 'a', titulo: 'b', validade: DateTime(2027, 1, 2), itens: const [ItemComercial(descricao: 'x', valor: 1)]).paraSalvar();
    expect((m['validade'], m['padrao'], m['situacao']), ('2027-01-02', 'medio', 'rascunho'));
    expect(m['itens'], [
      {'descricao': 'x', 'valor': 1.0},
    ]);
  });

  group('estimativa', () {
    final r = Calculo.de(const ParametrosObra(area: '100')).resultado!;

    test('cada etapa vira um item', () {
      final itens = itensDaEstimativa(r);
      expect(itens.map((i) => i.descricao), r.etapas.map((e) => e.nome));
      expect(itens.first.valor, closeTo(r.etapas.first.total, .01));
    });

    test('acréscimo vai por cima', () {
      final itens = itensDaEstimativa(r, acrescimo: 20);
      expect(itens.first.valor, closeTo(r.etapas.first.total * 1.2, .01));
    });
  });

  test('mensagem do envio', () {
    expect(mensagemDaProposta(const PropostaComercial(numero: 12, cliente: 'a', titulo: 'Casa')), 'Proposta nº 12 para Casa.');
  });
}
