import 'package:flutter/material.dart';

import '../supabase/auth_service.dart';
import '../tema/tema.dart';
import '../tema/cores.dart';
import '../ui/ui.dart';

/// Aberta pelo link de "Esqueci a senha" do e-mail (evento passwordRecovery do Supabase)
class NovaSenhaScreen extends StatefulWidget {
  const NovaSenhaScreen({super.key, required this.onConcluir});
  final VoidCallback onConcluir;

  @override
  State<NovaSenhaScreen> createState() => _NovaSenhaScreenState();
}

class _NovaSenhaScreenState extends State<NovaSenhaScreen> {
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_senha.text.length < 8) return setState(() => _erro = 'A senha precisa ter pelo menos 8 caracteres.');
    if (_senha.text != _confirmacao.text) return setState(() => _erro = 'As duas senhas não são iguais.');
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await AuthService.definirNovaSenha(_senha.text);
      widget.onConcluir();
    } on FalhaAuth catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: context.cores.superficie,
      appBar: AppBar(title: const Text('Nova senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Espaco.s5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Crie uma nova senha para a sua conta.', style: t.bodyLarge?.copyWith(color: context.cores.textoSuave)),
            const SizedBox(height: Espaco.s5),
            CampoTexto(rotulo: 'Nova senha', controller: _senha, senha: true, ajuda: 'Pelo menos 8 caracteres.', autofill: const [AutofillHints.newPassword]),
            const SizedBox(height: Espaco.s4),
            CampoTexto(rotulo: 'Repita a nova senha', controller: _confirmacao, senha: true, onSubmitted: (_) => _salvar()),
            if (_erro != null) ...[const SizedBox(height: Espaco.s4), Aviso(_erro!)],
            const SizedBox(height: Espaco.s5),
            FilledButton(onPressed: _enviando ? null : _salvar, child: Text(_enviando ? 'Salvando…' : 'Salvar nova senha')),
          ]),
        ),
      ),
    );
  }
}
