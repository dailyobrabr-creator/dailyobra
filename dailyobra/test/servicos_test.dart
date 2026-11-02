import 'package:dailyobra/services/novidades_service.dart';
import 'package:dailyobra/services/obras_service.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Obra obra(String id, DateTime atualizada) => Obra(
  id: id,
  papel: Papel.admin,
  dados: DadosObra(
    nome: 'Obra $id',
    cidade: 'Maringá',
    uf: 'PR',
    endereco: '',
    responsavel: '',
    inicioPrevisto: '',
  ),
  parametros: const ParametrosObra(area: '100'),
  statusEtapas: const {},
  criadaEm: DateTime(2026, 10, 1),
  atualizadaEm: atualizada,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ObrasService.instance.definirParaTeste());

  group('obra ativa', () {
    test('sem escolha, é a última atualizada', () {
      ObrasService.instance.definirParaTeste(
        obras: [
          obra('a', DateTime(2026, 10, 10)),
          obra('b', DateTime(2026, 10, 20)),
        ],
      );
      expect(ObrasService.instance.obraAtiva?.id, 'b');
    });

    test(
      'a escolhida vale e fica guardada; se sumir, volta para a última',
      () async {
        ObrasService.instance.definirParaTeste(
          obras: [
            obra('a', DateTime(2026, 10, 10)),
            obra('b', DateTime(2026, 10, 20)),
          ],
        );
        await ObrasService.instance.fixarAtiva('a');
        expect(ObrasService.instance.obraAtiva?.id, 'a');
        expect(
          (await SharedPreferences.getInstance()).getString(
            'dailyobra.obraAtiva',
          ),
          'a',
        );
        ObrasService.instance.definirParaTeste(
          obras: [obra('b', DateTime(2026, 10, 20))],
        );
        expect(ObrasService.instance.obraAtiva?.id, 'b');
      },
    );

    test('sem obras não há obra ativa', () {
      ObrasService.instance.definirParaTeste(obras: const []);
      expect(ObrasService.instance.obraAtiva, isNull);
    });
  });

  group('novidades', () {
    final itens = [
      Novidade(
        tipo: TipoNovidade.saiuEntrega,
        quando: DateTime(2026, 11, 1, 15),
        pedidoId: 'd1',
        lojaNome: 'A',
      ),
      Novidade(
        tipo: TipoNovidade.contraproposta,
        quando: DateTime(2026, 11, 1, 12),
        propostaId: 'p1',
        lojaNome: 'A',
      ),
      Novidade(
        tipo: TipoNovidade.aceita,
        quando: DateTime(2026, 10, 30),
        propostaId: 'p2',
        lojaNome: 'B',
      ),
    ];

    test('conta as não vistas e zera ao abrir', () async {
      NovidadesService.instance.definirParaTeste(
        itens: itens,
        vistoAte: DateTime(2026, 10, 1),
      );
      expect(NovidadesService.instance.naoVistas, 3);
      await NovidadesService.instance.marcarVistas();
      expect(NovidadesService.instance.naoVistas, 0);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'dailyobra.novidades.vistoAte',
        ),
        isNotNull,
      );
    });
  });
}
