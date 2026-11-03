import 'dart:async';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:dailyobra_parceiro/services/resultados_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final servico = ResultadosService.instance;
  final agora = DateTime(2026, 11, 3, 14, 30);

  test('lê o resultado do banco', () {
    final r = ResultadosPeriodo.fromJson({
      'faturamento': 3150,
      'pedidos': 9,
      'cashback': 46.5,
      'top': [
        {
          'construtor_id': 'c1',
          'nome': 'Ana Souza',
          'empresa': 'Souza Obras',
          'pedidos': 2,
          'total': 1500,
        },
      ],
    });
    expect(r.faturamento, 3150.0);
    expect(r.pedidos, 9);
    expect(r.cashback, 46.5);
    expect(r.ticket, 350.0);
    expect(r.top.single.exibicao, 'Ana Souza');
    expect(r.top.single.empresa, 'Souza Obras');
    expect(r.top.single.pedidos, 2);
    expect(r.top.single.total, 1500.0);
    expect(const ResultadosPeriodo().ticket, isNull);
  });

  test('construtor sem nome', () {
    final c = ConstrutorTop.fromJson({
      'construtor_id': 'c2',
      'nome': '',
      'empresa': '',
      'pedidos': 1,
      'total': 800,
    });
    expect(c.exibicao, 'Construtor');
  });

  test('carrega o mês e a comparação', () async {
    final pedidos = <(DateTime, DateTime)>[];
    servico.definirParaTeste(
      buscar: (de, ate) async {
        pedidos.add((de, ate));
        return ResultadosPeriodo(
          faturamento: de == DateTime(2026, 11) ? 1184 : 1000,
        );
      },
    );
    await servico.carregar(DateTime(2026, 11), agora: agora);
    expect(servico.mes, DateTime(2026, 11));
    expect(servico.atual!.faturamento, 1184);
    expect(servico.anterior!.faturamento, 1000);
    expect(servico.periodo!.ateAnterior, DateTime(2026, 10, 3, 14, 30));
    expect(pedidos, [
      (DateTime(2026, 11), DateTime(2026, 12)),
      (DateTime(2026, 10), DateTime(2026, 10, 3, 14, 30)),
    ]);
    expect(servico.carregando, isFalse);
    expect(servico.erro, isNull);
  });

  test('resposta atrasada de outro mês é ignorada', () async {
    final esperas = <(DateTime, DateTime), Completer<ResultadosPeriodo>>{};
    servico.definirParaTeste(
      buscar: (de, ate) => (esperas[(de, ate)] = Completer()).future,
    );
    final novembro = servico.carregar(DateTime(2026, 11), agora: agora);
    final outubro = servico.carregar(DateTime(2026, 10), agora: agora);
    expect(servico.mes, DateTime(2026, 10));
    esperas[(DateTime(2026, 10), DateTime(2026, 11))]!.complete(
      const ResultadosPeriodo(faturamento: 10),
    );
    esperas[(DateTime(2026, 9), DateTime(2026, 10))]!.complete(
      const ResultadosPeriodo(faturamento: 9),
    );
    await outubro;
    esperas[(DateTime(2026, 11), DateTime(2026, 12))]!.complete(
      const ResultadosPeriodo(faturamento: 11),
    );
    esperas[(DateTime(2026, 10), DateTime(2026, 10, 3, 14, 30))]!.complete(
      const ResultadosPeriodo(faturamento: 10.5),
    );
    await novembro;
    expect(servico.mes, DateTime(2026, 10));
    expect(servico.atual!.faturamento, 10);
    expect(servico.anterior!.faturamento, 9);
    expect(servico.carregando, isFalse);
  });

  test('erro vira mensagem', () async {
    servico.definirParaTeste(
      buscar: (de, ate) async => throw const FalhaComMensagem('Sem conexão.'),
    );
    await servico.carregar(DateTime(2026, 11), agora: agora);
    expect(servico.erro, 'Sem conexão.');
    expect(servico.carregando, isFalse);
  });

  test('recarregar busca o mesmo mês de novo', () async {
    var chamadas = 0;
    servico.definirParaTeste(
      buscar: (de, ate) async {
        chamadas++;
        return const ResultadosPeriodo();
      },
    );
    await servico.carregar(DateTime(2026, 10), agora: agora);
    await servico.recarregar();
    expect(chamadas, 4);
    expect(servico.mes, DateTime(2026, 10));
  });

  test('limpar apaga os resultados', () async {
    servico.definirParaTeste(
      buscar: (de, ate) async => const ResultadosPeriodo(faturamento: 1),
    );
    await servico.carregar(DateTime(2026, 11), agora: agora);
    servico.limpar();
    expect(servico.mes, isNull);
    expect(servico.atual, isNull);
    expect(servico.anterior, isNull);
  });
}
