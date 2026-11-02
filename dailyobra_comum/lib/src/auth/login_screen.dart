import 'package:flutter/material.dart';

import '../supabase/auth_service.dart';
import '../tema/tema.dart';
import '../tema/cores.dart';
import '../ui/ui.dart';
import '../ui/vitrine.dart';

enum _Modo { entrar, criar, recuperar }

// Link alinhado à esquerda com os campos (sem o recuo padrão do TextButton), mantendo 44 px de altura para o toque
final _linkAlinhado = TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 44), tapTargetSize: MaterialTapTargetSize.padded);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSimular, this.selo, this.subtitulo});

  /// Abre o simulador sem precisar de conta
  final VoidCallback? onSimular;

  /// Nome do app ao lado da logo ("Parceiros" no app das lojas)
  final String? selo;

  /// Frase sob o título; o padrão fala das obras do construtor
  final String? subtitulo;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _Modo _modo = _Modo.entrar;
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _enviando = false;
  String? _erro;
  String? _aviso;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _trocar(_Modo m) => setState(() {
        _modo = m;
        _erro = null;
        _aviso = null;
      });

  Future<void> _enviar() async {
    final email = _email.text.trim().toLowerCase();
    String? erro;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      erro = 'Informe um e-mail válido.';
    } else if (_modo == _Modo.criar && _nome.text.trim().length < 2) {
      erro = 'Informe seu nome.';
    } else if (_modo == _Modo.criar && _senha.text.length < 8) {
      erro = 'A senha precisa ter pelo menos 8 caracteres.';
    } else if (_modo == _Modo.entrar && _senha.text.isEmpty) {
      erro = 'Informe sua senha.';
    }
    if (erro != null) {
      setState(() {
        _erro = erro;
        _aviso = null;
      });
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
      _aviso = null;
    });
    try {
      switch (_modo) {
        case _Modo.entrar:
          // Ao entrar, o AuthGate troca para o início sozinho
          await AuthService.entrar(email, _senha.text);
        case _Modo.criar:
          final logado = await AuthService.criarConta(_nome.text.trim(), email, _senha.text);
          if (!logado && mounted) {
            setState(() => _aviso = 'Enviamos um link de confirmação para $email. Abra o e-mail neste celular e toque no link para ativar a conta.');
          }
        case _Modo.recuperar:
          await AuthService.recuperarSenha(email);
          if (mounted) setState(() => _aviso = 'Se houver uma conta com $email, enviamos um link para criar uma nova senha.');
      }
    } on FalhaAuth catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final titulo = switch (_modo) { _Modo.entrar => 'Entrar', _Modo.criar => 'Criar conta', _Modo.recuperar => 'Recuperar senha' };
    final acao = switch (_modo) { _Modo.entrar => 'Entrar', _Modo.criar => 'Criar conta', _Modo.recuperar => 'Enviar link' };

    return Scaffold(
      backgroundColor: context.cores.superficie,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Espaco.s5, Espaco.s8, Espaco.s5, Espaco.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Flexible(child: MarcaDailyObra(soSimbolo: false, altura: 34)),
                        if (widget.selo != null) ...[const SizedBox(width: Espaco.s3), Selo(widget.selo!, tom: TomSelo.info)],
                      ],
                    ),
                    const SizedBox(height: Espaco.s10),
                    Text(titulo, style: t.headlineMedium),
                    const SizedBox(height: Espaco.s2),
                    Text(
                      _modo == _Modo.recuperar
                          ? 'Informe o e-mail da conta para receber o link de nova senha.'
                          : widget.subtitulo ?? 'Orçamento, materiais e andamento das suas obras, no celular e no computador.',
                      style: t.bodyLarge?.copyWith(color: context.cores.textoSuave),
                    ),
                    const SizedBox(height: Espaco.s6),
                    if (_modo != _Modo.recuperar) ...[
                      Segmentado<_Modo>(
                        valor: _modo,
                        opcoes: const [(_Modo.entrar, 'Já tenho conta'), (_Modo.criar, 'Sou novo aqui')],
                        onChanged: _trocar,
                      ),
                      const SizedBox(height: Espaco.s5),
                    ],
                    if (_modo == _Modo.criar) ...[
                      CampoTexto(rotulo: 'Seu nome', controller: _nome, acao: TextInputAction.next, autofill: const [AutofillHints.name]),
                      const SizedBox(height: Espaco.s4),
                    ],
                    CampoTexto(
                      rotulo: 'E-mail',
                      controller: _email,
                      teclado: TextInputType.emailAddress,
                      acao: _modo == _Modo.recuperar ? TextInputAction.done : TextInputAction.next,
                      autofill: const [AutofillHints.email],
                      onSubmitted: _modo == _Modo.recuperar ? (_) => _enviar() : null,
                    ),
                    if (_modo != _Modo.recuperar) ...[
                      const SizedBox(height: Espaco.s4),
                      CampoTexto(
                        rotulo: 'Senha',
                        controller: _senha,
                        senha: true,
                        acao: TextInputAction.done,
                        ajuda: _modo == _Modo.criar ? 'Pelo menos 8 caracteres.' : null,
                        autofill: [_modo == _Modo.criar ? AutofillHints.newPassword : AutofillHints.password],
                        onSubmitted: (_) => _enviar(),
                      ),
                    ],
                    if (_erro != null) ...[const SizedBox(height: Espaco.s4), Aviso(_erro!)],
                    if (_aviso != null) ...[const SizedBox(height: Espaco.s4), Aviso(_aviso!, tom: TomSelo.sucesso)],
                    const SizedBox(height: Espaco.s5),
                    FilledButton(
                      onPressed: _enviando ? null : _enviar,
                      child: _enviando
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.cores.textoSobreAcao))
                          : Text(acao),
                    ),
                    const SizedBox(height: Espaco.s2),
                    if (_modo == _Modo.entrar)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(style: _linkAlinhado, onPressed: () => _trocar(_Modo.recuperar), child: const Text('Esqueci a senha')),
                      ),
                    if (_modo == _Modo.recuperar)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(style: _linkAlinhado, onPressed: () => _trocar(_Modo.entrar), child: const Text('Voltar para entrar')),
                      ),
                    if (widget.onSimular != null) ...[
                      const SizedBox(height: Espaco.s6),
                      const Divider(),
                      const SizedBox(height: Espaco.s4),
                      Text('Quer só estimar um valor?', style: t.bodyMedium?.copyWith(color: context.cores.textoSuave), textAlign: TextAlign.center),
                      TextButton(onPressed: widget.onSimular, child: const Text('Usar o simulador sem cadastro')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
