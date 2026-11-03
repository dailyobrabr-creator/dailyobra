import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

/// "dia:início-fim" em minutos, em ordem, para comparar faixas de uma vez.
String faixas(List<FaixaHorario>? lista) {
  if (lista == null) return 'nada';
  final textos = [for (final f in lista) '${f.dia}:${f.inicio}-${f.fim}']
    ..sort();
  return textos.join(' ');
}

String semana(int inicio, int fim, {List<int> dias = const [1, 2, 3, 4, 5]}) =>
    [for (final d in dias) '$d:$inicio-$fim'].join(' ');

void main() {
  group('lerHorario', () {
    test('seg a sex e sábado, com meia hora', () {
      expect(
        faixas(lerHorario('Seg a sex 7h às 17h30; sáb 7h às 12h30')),
        '${semana(420, 1050)} 6:420-750',
      );
    });

    test('por extenso, com dois pontos, "17:30h" e ponto final', () {
      expect(
        faixas(lerHorario('Segunda à Sexta: 7h às 17:30h. Sábado: 7h às 12h.')),
        '${semana(420, 1050)} 6:420-720',
      );
    });

    test('formato 07:00-18:00 com hífen entre os dias', () {
      expect(
        faixas(lerHorario('seg-sex 07:00-18:00, sab 07:00-12:00')),
        '${semana(420, 1080)} 6:420-720',
      );
    });

    test('dois turnos no mesmo dia', () {
      final lido = faixas(lerHorario('Seg a sex 8h às 12h e 13h às 18h'));
      expect(lido, contains('1:480-720'));
      expect(lido, contains('1:780-1080'));
      expect(lido, contains('5:780-1080'));
      expect(lido, isNot(contains('6:')));
    });

    test('todos os dias e lista de dias', () {
      expect(
        faixas(lerHorario('Todos os dias das 8h às 20h')),
        semana(480, 1200, dias: [1, 2, 3, 4, 5, 6, 7]),
      );
      expect(
        faixas(lerHorario('Seg, qua e sex 9h às 17h')),
        semana(540, 1020, dias: [1, 3, 5]),
      );
    });

    test('segunda com horário diferente dos outros dias', () {
      expect(
        faixas(
          lerHorario(
            'Seg 7h30 às 17h30; ter a sex 7h às 17h30; sáb 7h às 12h30',
          ),
        ),
        '1:450-1050 ${semana(420, 1050, dias: [2, 3, 4, 5])} 6:420-750',
      );
    });

    test('sem dia ou sem hora não chuta', () {
      expect(lerHorario(''), isNull);
      expect(lerHorario('Ligue para saber o horário'), isNull);
      expect(lerHorario('8h às 18h'), isNull, reason: 'sem os dias');
      expect(lerHorario('Televendas (66) 3411-6500'), isNull);
    });
  });

  group('situacaoDaLoja', () {
    const comapa = Loja(
      id: 'c',
      nome: 'Comapa',
      cidade: 'Rondonópolis',
      uf: 'MT',
      horario: 'Seg a sex 7h às 17h30; sáb 7h às 12h30',
    );

    // Domingo, 01/11/2026, 23h52 em Brasília = 22h52 em Rondonópolis (MT, uma hora a menos)
    test('domingo à noite: fechada, abre amanhã às 7h', () {
      final s = situacaoDaLoja(comapa, DateTime.utc(2026, 11, 2, 2, 52));
      expect(s.estado, EstadoLoja.fechada);
      expect(s.selo, 'fechada');
      expect(s.detalhe, 'abre amanhã às 7h');
    });

    test('segunda às 10h: aberta até 17h30', () {
      final s = situacaoDaLoja(comapa, DateTime.utc(2026, 11, 2, 14));
      expect(s.estado, EstadoLoja.aberta);
      expect(s.selo, 'aberta');
      expect(s.detalhe, 'fecha às 17h30');
    });

    test('segunda às 6h: abre às 7h', () {
      expect(
        situacaoDaLoja(comapa, DateTime.utc(2026, 11, 2, 10)).detalhe,
        'abre às 7h',
      );
    });

    test('sábado às 13h: abre seg às 7h', () {
      final s = situacaoDaLoja(comapa, DateTime.utc(2026, 11, 7, 17));
      expect(s.estado, EstadoLoja.fechada);
      expect(s.detalhe, 'abre seg às 7h');
    });

    test('usa o fuso da loja: 7h em Brasília ainda é 6h em Mato Grosso', () {
      final agora = DateTime.utc(2026, 11, 2, 10);
      expect(situacaoDaLoja(comapa, agora).estado, EstadoLoja.fechada);
      const noParana = Loja(
        id: 'p',
        nome: 'No Paraná',
        cidade: 'Maringá',
        uf: 'PR',
        horario: 'Seg a sex 7h às 17h30',
      );
      expect(situacaoDaLoja(noParana, agora).estado, EstadoLoja.aberta);
    });

    test('pedidos pausados pela loja vêm antes do horário', () {
      const pausada = Loja(
        id: 'z',
        nome: 'Pausada',
        cidade: 'Rondonópolis',
        uf: 'MT',
        aberta: false,
        horario: 'Seg a sex 7h às 17h30',
      );
      final s = situacaoDaLoja(pausada, DateTime.utc(2026, 11, 2, 14));
      expect(s.estado, EstadoLoja.pausada);
      expect(s.selo, 'pedidos pausados');
    });

    test('sem horário: nenhum selo', () {
      const semHorario = Loja(
        id: 'o',
        nome: 'Operário',
        cidade: 'Rondonópolis',
        uf: 'MT',
      );
      final s = situacaoDaLoja(semHorario, DateTime.utc(2026, 11, 2, 14));
      expect(s.estado, EstadoLoja.semHorario);
      expect(s.selo, '');
    });
  });

  group('escreverHorario', () {
    FaixaHorario f(int dia, int inicio, int fim) => FaixaHorario(dia, inicio, fim);
    List<FaixaHorario> dias(List<int> ds, int inicio, int fim) => [for (final d in ds) f(d, inicio, fim)];
    const uteis = [1, 2, 3, 4, 5];
    final casos = <String, List<FaixaHorario>>{
      'Seg a sex 7h às 18h; sáb 7h às 12h': [...dias(uteis, 420, 1080), f(6, 420, 720)],
      'Seg a sex 7h às 11h e 13h às 18h': [...dias(uteis, 780, 1080), ...dias(uteis, 420, 660)],
      'Seg 7h30 às 17h30; ter a sex 7h às 17h30; sáb 7h às 12h30': [f(1, 450, 1050), ...dias([2, 3, 4, 5], 420, 1050), f(6, 420, 750)],
      'Sáb e dom 8h às 12h': dias([6, 7], 480, 720),
      'Seg a qua 8h às 18h; sex 8h às 18h': [...dias([1, 2, 3], 480, 1080), f(5, 480, 1080)],
    };
    final nomes = ['escreve dias úteis iguais e sábado', 'escreve intervalo', 'meia hora', 'dois dias seguidos usam e', 'dias separados'];
    for (final (i, MapEntry(key: texto, value: lista)) in casos.entries.indexed) {
      test(nomes[i], () => expect(escreverHorario(lista), texto));
    }

    test('tudo fechado', () => expect(escreverHorario(const []), ''));

    test('ida e volta', () {
      for (final texto in casos.keys) {
        expect(escreverHorario(lerHorario(texto)!), texto);
      }
    });
  });
}
