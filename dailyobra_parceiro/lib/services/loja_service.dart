import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Papel de quem usa o app na loja: dono e gerente gerem tudo; vendedor responde propostas.
enum PapelLoja {
  dono('dono', 'Dono'),
  gerente('gerente', 'Gerente'),
  vendedor('vendedor', 'Vendedor');

  const PapelLoja(this.codigo, this.rotulo);
  final String codigo;
  final String rotulo;

  bool get gere => this != vendedor;

  static PapelLoja fromCodigo(String? c) =>
      values.firstWhere((p) => p.codigo == c, orElse: () => vendedor);
}

/// Dados de cadastro que só a loja vê (o construtor vê o resumo em [Loja]).
class DadosLoja {
  const DadosLoja({
    this.cnpj = '',
    this.endereco = '',
    this.horario = '',
    this.status = 'ativa',
    this.chavePix,
  });
  final String cnpj;
  final String endereco;
  final String horario;
  final String status;

  /// Fica em loja_pix: a equipe da loja lê, dono e gerente gravam (o construtor só vê o PIX do pedido).
  final String? chavePix;
}

class MembroLoja {
  const MembroLoja({
    required this.userId,
    required this.nome,
    required this.papel,
  });
  final String userId;
  final String nome;
  final PapelLoja papel;
}

/// A loja de quem entrou no app e o papel dele nela.
class LojaService extends ChangeNotifier {
  LojaService._();

  static final instance = LojaService._();

  SupabaseClient get _db => Supabase.instance.client;

  Loja? _loja;
  DadosLoja _dados = const DadosLoja();
  PapelLoja _papel = PapelLoja.vendedor;
  List<MembroLoja> _equipe = const [];
  bool _carregado = false;
  String? _erro;
  bool _teste = false;

  /// O que [atualizar] mandaria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  final atualizacoesDeTeste = <Map<String, dynamic>>[];

  /// O que [salvarChavePix] mandaria ao banco, quando montado por [definirParaTeste].
  @visibleForTesting
  final chavesDeTeste = <String?>[];

  Loja? get minhaLoja => _loja;
  DadosLoja get dados => _dados;
  PapelLoja get meuPapel => _papel;
  List<MembroLoja> get equipe => _equipe;
  bool get carregado => _carregado;
  String? get erro => _erro;

  @visibleForTesting
  void definirParaTeste({
    Loja? loja,
    PapelLoja papel = PapelLoja.dono,
    DadosLoja dados = const DadosLoja(cnpj: '11222333000181'),
    List<MembroLoja> equipe = const [],
  }) {
    _loja = loja;
    _papel = papel;
    _dados = dados;
    _equipe = equipe;
    _carregado = true;
    _erro = null;
    _teste = true;
    atualizacoesDeTeste.clear();
    chavesDeTeste.clear();
    notifyListeners();
  }

  void limpar() {
    _loja = null;
    _papel = PapelLoja.vendedor;
    _equipe = const [];
    _carregado = false;
    _erro = null;
    notifyListeners();
  }

  static const _colunas =
      'id, nome, cnpj, descricao, logo_path, capa_path, whatsapp, endereco, cidade, uf, horario, '
      'frete_fixo, pedido_minimo, aberta, status, criada_em';

  Future<void> carregar() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final vinculo = await _db
          .from('loja_membros')
          .select('papel, lojas($_colunas)')
          .eq('user_id', uid)
          .limit(1)
          .maybeSingle();
      final j = vinculo?['lojas'] as Map<String, dynamic>?;
      if (j == null) {
        _loja = null;
      } else {
        _loja = Loja.fromJson(j);
        _papel = PapelLoja.fromCodigo(vinculo!['papel'] as String?);
        final pix = await _db
            .from('loja_pix')
            .select('chave')
            .eq('loja_id', j['id'] as String)
            .maybeSingle();
        _dados = DadosLoja(
          cnpj: (j['cnpj'] as String?)?.trim() ?? '',
          endereco: (j['endereco'] as String?) ?? '',
          horario: (j['horario'] as String?) ?? '',
          status: (j['status'] as String?) ?? 'ativa',
          chavePix: pix?['chave'] as String?,
        );
      }
      _erro = null;
      _carregado = true;
    } catch (e) {
      _erro = mensagemDoServidor(e);
    }
    notifyListeners();
  }

  /// Cria a loja (função criar_loja: valida CNPJ, cidade e UF, e põe quem cadastra como dono).
  Future<String> criar(Map<String, dynamic> dados) async {
    final id = await comMensagem(
      () => _db.rpc('criar_loja', params: {'p': dados}),
    );
    await carregar();
    return id as String;
  }

  /// Altera campos da própria loja (nome, descrição, frete...). CNPJ e situação só o suporte muda.
  Future<void> atualizar(Map<String, dynamic> campos) async {
    final loja = _loja;
    if (loja == null) return;
    if (_teste) {
      atualizacoesDeTeste.add(campos);
      return;
    }
    await comMensagem(() => _db.from('lojas').update(campos).eq('id', loja.id));
    await carregar();
  }

  Future<void> abrirOuFechar(bool aberta) => atualizar({'aberta': aberta});

  /// Grava a chave PIX em loja_pix (nula apaga); o formato é conferido de novo pelo banco.
  Future<void> salvarChavePix(String? chave) async {
    final loja = _loja;
    if (loja == null) return;
    if (_teste) {
      chavesDeTeste.add(chave);
      return;
    }
    final tabela = _db.from('loja_pix');
    await comMensagem(() async {
      if (chave == null) {
        await tabela.delete().eq('loja_id', loja.id);
      } else {
        await tabela.upsert({'loja_id': loja.id, 'chave': chave});
      }
    });
    await carregar();
  }

  /// Logo ou capa já reduzida pelo seletor (JPEG). Guarda em `lojas/{id}/logo.jpg` ou `capa.jpg`
  /// e devolve o endereço público com `?v=` para o app não mostrar a imagem antiga do cache.
  Future<String> enviarImagem(XFile arquivo, {required bool capa}) async {
    final loja = _loja;
    if (loja == null) {
      throw const FalhaComMensagem('Cadastre a loja antes de enviar imagens.');
    }
    final bytes = await arquivo.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      throw const FalhaComMensagem(
        'A imagem passou de 2 MB. Escolha outra foto ou recorte antes.',
      );
    }
    final caminho = '${loja.id}/${capa ? 'capa' : 'logo'}.jpg';
    await comMensagem(
      () => _db.storage
          .from('lojas')
          .uploadBinary(
            caminho,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
              cacheControl: '60',
            ),
          ),
    );
    await atualizar({capa ? 'capa_path' : 'logo_path': caminho});
    return '${urlPublica(caminho)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> carregarEquipe() async {
    final loja = _loja;
    if (loja == null) return;
    try {
      final linhas = await _db
          .from('loja_membros')
          .select('user_id, papel')
          .eq('loja_id', loja.id);
      final ids = [for (final l in linhas) l['user_id'] as String];
      final perfis = ids.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _db.from('profiles').select('id, nome').inFilter('id', ids);
      final nomes = {
        for (final p in perfis) p['id'] as String: p['nome'] as String?,
      };
      _equipe = [
        for (final l in linhas)
          MembroLoja(
            userId: l['user_id'] as String,
            nome: nomes[l['user_id']] ?? 'Integrante da equipe',
            papel: PapelLoja.fromCodigo(l['papel'] as String?),
          ),
      ]..sort((a, b) => a.papel.index.compareTo(b.papel.index));
      notifyListeners();
    } catch (_) {
      // A tela da equipe mostra o que já tinha
    }
  }

  /// Convida quem já tem conta no DailyObra (função convidar_membro, só o dono).
  Future<void> convidar(String email, PapelLoja papel) async {
    final loja = _loja;
    if (loja == null) return;
    await comMensagem(
      () => _db.rpc(
        'convidar_membro',
        params: {
          'p_loja': loja.id,
          'p_email': email.trim().toLowerCase(),
          'p_papel': papel.codigo,
        },
      ),
    );
    await carregarEquipe();
  }

  Future<void> removerMembro(String userId) async {
    final loja = _loja;
    if (loja == null) return;
    await comMensagem(
      () => _db
          .from('loja_membros')
          .delete()
          .eq('loja_id', loja.id)
          .eq('user_id', userId),
    );
    await carregarEquipe();
  }
}
