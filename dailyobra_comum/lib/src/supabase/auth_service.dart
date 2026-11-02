import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login por e-mail e senha no Supabase Auth. A sessão é guardada e renovada pelo próprio
/// supabase_flutter, então o app abre já logado.
class AuthService {
  AuthService._();

  /// Link que o e-mail de confirmação e de nova senha abre: cada app tem o seu esquema
  /// (dailyobra://login, dailyobraparceiros://login). Definido no main de cada app.
  static String _linkApp = 'dailyobra://login';

  /// Para onde voltam os links do e-mail (confirmação de conta e nova senha). No navegador é o
  /// próprio site; no celular, o esquema do app (o Parceiros troca por dailyobraparceiros://login).
  static String get linkRetorno =>
      kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : _linkApp;

  static void definirLinkRetorno(String link) => _linkApp = link;

  static GoTrueClient get _auth => Supabase.instance.client.auth;

  static User? get usuario => _auth.currentUser;
  static Stream<AuthState> get mudancas => _auth.onAuthStateChange;

  static String? get primeiroNome {
    final nome = (usuario?.userMetadata?['nome'] as String?)?.trim();
    return (nome == null || nome.isEmpty) ? null : nome.split(' ').first;
  }

  static Future<void> entrar(String email, String senha) async {
    try {
      await _auth.signInWithPassword(email: email, password: senha);
    } on AuthException catch (e) {
      throw FalhaAuth(mensagemErro(e));
    } catch (_) {
      throw FalhaAuth(mensagemErro(null));
    }
  }

  /// true = conta criada e já logada; false = precisa confirmar pelo e-mail
  static Future<bool> criarConta(
    String nome,
    String email,
    String senha,
  ) async {
    try {
      final r = await _auth.signUp(
        email: email,
        password: senha,
        data: {'nome': nome},
        emailRedirectTo: linkRetorno,
      );
      return r.session != null;
    } on AuthException catch (e) {
      throw FalhaAuth(mensagemErro(e));
    } catch (_) {
      throw FalhaAuth(mensagemErro(null));
    }
  }

  static Future<void> recuperarSenha(String email) async {
    try {
      await _auth.resetPasswordForEmail(email, redirectTo: linkRetorno);
    } on AuthException catch (e) {
      throw FalhaAuth(mensagemErro(e));
    } catch (_) {
      throw FalhaAuth(mensagemErro(null));
    }
  }

  static Future<void> definirNovaSenha(String senha) async {
    try {
      await _auth.updateUser(UserAttributes(password: senha));
    } on AuthException catch (e) {
      throw FalhaAuth(mensagemErro(e));
    } catch (_) {
      throw FalhaAuth(mensagemErro(null));
    }
  }

  static Future<void> sair() => _auth.signOut();

  /// Mensagens do Supabase Auth em português, pelo código do erro
  static String mensagemErro(AuthException? e) {
    switch (e?.code) {
      case 'invalid_credentials':
        return 'E-mail ou senha incorretos.';
      case 'email_not_confirmed':
        return 'Confirme seu e-mail pelo link que enviamos antes de entrar.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Já existe uma conta com este e-mail. Use Entrar.';
      case 'weak_password':
        return 'Senha fraca. Use pelo menos 8 caracteres, misturando letras e números.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.';
      case 'same_password':
        return 'A nova senha precisa ser diferente da atual.';
      case 'validation_failed':
        return 'Confira o e-mail informado.';
      default:
        return 'Não foi possível concluir agora. Verifique a conexão e tente de novo.';
    }
  }
}

class FalhaAuth implements Exception {
  const FalhaAuth(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}
