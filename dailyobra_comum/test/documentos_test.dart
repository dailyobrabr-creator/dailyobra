import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter_test/flutter_test.dart';

Documento doc(String titulo, DateTime? validade) => Documento(titulo: titulo, validade: validade);

void main() {
  final hoje = DateTime(2026, 11, 5);
  DateTime em(int dias) => DateTime(2026, 11, 5 + dias);

  group('documentos', () {
    test('lê do banco', () {
      final d = Documento.fromJson(const {'id': 'd1', 'tipo': 'art', 'titulo': 'ART', 'numero': null, 'validade': '2026-12-10', 'caminho': 'o1/a.pdf', 'nome_arquivo': 'a.pdf', 'acesso': 'todos', 'posso_mexer': true});
      expect((d.tipo, d.titulo, d.numero, d.validade, d.nomeArquivo, d.acesso, d.possoMexer), (TipoDocumento.art, 'ART', '', DateTime(2026, 12, 10), 'a.pdf', AcessoDocumento.todos, true));
    });

    test('código desconhecido fica no mais fechado', () {
      expect(TipoDocumento.doCodigo('x'), TipoDocumento.outro);
      expect(AcessoDocumento.doCodigo('x'), AcessoDocumento.lideres);
    });

    test('monta o que vai para o banco', () {
      final m = Documento(titulo: 'Alvará', tipo: TipoDocumento.alvara, validade: DateTime(2027, 1, 2), acesso: AcessoDocumento.equipe).paraSalvar();
      expect((m['tipo'], m['validade'], m['acesso']), ('alvara', '2027-01-02', 'equipe'));
      expect(const Documento(titulo: 'x').paraSalvar()['validade'], isNull);
    });

    test('situação pelo vencimento', () {
      expect(doc('a', null).situacao(hoje), SituacaoValidade.semValidade);
      expect(doc('a', em(-1)).situacao(hoje), SituacaoValidade.vencido);
      expect(doc('a', hoje).situacao(hoje), SituacaoValidade.vencendo);
      expect(doc('a', em(30)).situacao(hoje), SituacaoValidade.vencendo);
      expect(doc('a', em(31)).situacao(hoje), SituacaoValidade.emDia);
    });

    test('texto da validade', () {
      expect(doc('a', null).textoDaValidade(hoje), 'Sem vencimento');
      expect(doc('a', em(-3)).textoDaValidade(hoje), 'Vencido há 3 dias');
      expect(doc('a', em(-1)).textoDaValidade(hoje), 'Vencido há 1 dia');
      expect(doc('a', hoje).textoDaValidade(hoje), 'Vence hoje');
      expect(doc('a', em(1)).textoDaValidade(hoje), 'Vence amanhã');
      expect(doc('a', em(12)).textoDaValidade(hoje), 'Vence em 12 dias');
      expect(doc('a', DateTime(2027, 3, 1)).textoDaValidade(hoje), 'Válido até 01/03/2027');
    });

    test('aviso começa pelo que está pior', () {
      expect(alertaDeDocumentos([doc('a', em(90)), doc('b', null)], hoje), isNull);
      expect(alertaDeDocumentos([doc('ART', em(12))], hoje), 'ART: vence em 12 dias.');
      expect(alertaDeDocumentos([doc('a', em(12)), doc('b', em(20))], hoje), '2 documentos vencem em até 30 dias.');
      expect(alertaDeDocumentos([doc('Alvará', em(-2)), doc('b', em(20))], hoje), 'Alvará está vencido.');
      expect(alertaDeDocumentos([doc('a', em(-2)), doc('b', em(-1))], hoje), '2 documentos vencidos.');
    });
  });

  group('checklists', () {
    Checklist lista(List<ResultadoItem?> r, {bool concluido = false}) => Checklist(
      modelo: 'x',
      tipo: TipoChecklist.seguranca,
      titulo: 'Segurança',
      data: hoje,
      concluido: concluido,
      itens: [
        for (final (i, x) in r.indexed) ItemChecklist(texto: 'Item $i', resultado: x),
      ],
    );

    test('lê do banco, na ordem dos itens', () {
      final c = Checklist.fromJson(const {
        'id': 'c1',
        'modelo': 'alvenaria',
        'tipo': 'qualidade',
        'titulo': 'Alvenaria',
        'etapa': 'alvenaria',
        'local': null,
        'data': '2026-11-03',
        'observacoes': null,
        'concluido': true,
        'concluido_nome': 'Seu Jorge',
        'concluido_em': '2026-11-03T12:00:00+00:00',
        'obra_checklist_itens': [
          {'ordem': 2, 'texto': 'B', 'resultado': 'nao', 'observacao': 'Torto', 'foto_path': 'o1/f.jpg'},
          {'ordem': 1, 'texto': 'A', 'resultado': null, 'observacao': null, 'foto_path': null},
        ],
      });
      expect((c.tipo, c.etapa, c.concluido, c.concluidoPor), (TipoChecklist.qualidade, EtapaId.alvenaria, true, 'Seu Jorge'));
      expect(c.itens.map((i) => i.texto), ['A', 'B']);
      expect(c.itens.first.resultado, isNull);
      expect((c.itens.last.resultado, c.itens.last.observacao, c.itens.last.fotoPath), (ResultadoItem.nao, 'Torto', 'o1/f.jpg'));
    });

    test('resposta desconhecida fica sem resposta', () {
      expect(ResultadoItem.doCodigo('talvez'), isNull);
      expect(ResultadoItem.doCodigo(null), isNull);
    });

    test('conta as respostas', () {
      final c = lista([ResultadoItem.ok, ResultadoItem.ok, ResultadoItem.ok, ResultadoItem.nao, ResultadoItem.na, null]);
      expect((c.conformes, c.naoConformes, c.naoSeAplica, c.faltam), (3, 1, 1, 1));
    });

    test('conformidade ignora o que não se aplica', () {
      expect(lista([ResultadoItem.ok, ResultadoItem.ok, ResultadoItem.ok, ResultadoItem.nao, ResultadoItem.na]).conformidade, 75);
      expect(lista([ResultadoItem.na]).conformidade, isNull);
      expect(lista([null]).conformidade, isNull);
    });

    test('resumo do rascunho e do concluído', () {
      expect(lista([ResultadoItem.ok, null]).resumo, '1 de 2 respondidos');
      expect(lista([ResultadoItem.ok, ResultadoItem.nao], concluido: true).resumo, '50% conforme');
      expect(lista([ResultadoItem.na], concluido: true).resumo, 'Concluído');
    });

    test('monta o que vai para o banco', () {
      final m = lista([ResultadoItem.nao]).paraSalvar();
      expect((m['tipo'], m['data']), ('seguranca', '2026-11-05'));
      expect(m['itens'], [
        {'texto': 'Item 0', 'resultado': 'nao', 'observacao': '', 'foto_path': null},
      ]);
    });

    test('modelos têm código único e itens curtos', () {
      final codigos = modelosDeChecklist.map((m) => m.codigo).toSet();
      expect(codigos, hasLength(modelosDeChecklist.length));
      for (final m in modelosDeChecklist) {
        expect(RegExp(r'^[a-z0-9_]{1,60}$').hasMatch(m.codigo), isTrue, reason: m.codigo);
        expect(m.titulo.length, lessThanOrEqualTo(160));
        for (final i in m.itens) {
          expect(i.length, lessThanOrEqualTo(300));
        }
      }
    });

    test('tem modelos dos dois tipos', () {
      expect(modelosDeChecklist.where((m) => m.tipo == TipoChecklist.seguranca), isNotEmpty);
      expect(modelosDeChecklist.where((m) => m.tipo == TipoChecklist.qualidade), isNotEmpty);
    });

    test('modelo vira checklist sem respostas', () {
      final m = modelosDeChecklist.firstWhere((x) => x.codigo == 'alvenaria');
      final c = m.novo(hoje);
      expect((c.modelo, c.etapa, c.concluido, c.faltam), ('alvenaria', EtapaId.alvenaria, false, m.itens.length));
    });

    test('quem preenche', () {
      expect(FuncaoObra.responsavel.inspeciona, isTrue);
      expect(FuncaoObra.mestre.inspeciona, isTrue);
      expect(FuncaoObra.estagiario.inspeciona, isTrue);
      expect(FuncaoObra.empreiteiro.inspeciona, isFalse);
      expect(FuncaoObra.cliente.inspeciona, isFalse);
    });
  });
}
