import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/loja_service.dart';
import 'componentes.dart';

/// Quem é de uma loja que já está no DailyObra entra com o CNPJ e o código de acesso que recebeu, e vira o dono dela.
class AssumirLojaScreen extends StatefulWidget {
  const AssumirLojaScreen({super.key, this.assumir});

  /// Quem confere o código; o padrão é a função assumir_loja do servidor.
  final Future<void> Function(String cnpj, String codigo)? assumir;

  @override
  State<AssumirLojaScreen> createState() => _AssumirLojaScreenState();
}

class _AssumirLojaScreenState extends State<AssumirLojaScreen> {
  final _cnpj = TextEditingController();
  final _codigo = TextEditingController();
  String? _erroCnpj;
  String? _erroCodigo;
  String? _erroServidor;
  bool _enviando = false;

  @override
  void dispose() {
    _cnpj.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    final codigo = _codigo.text.trim();
    setState(() {
      _erroCnpj = cnpjValido(_cnpj.text)
          ? null
          : 'CNPJ inválido. Confira os números.';
      _erroCodigo = codigo.isEmpty ? 'Digite o código que você recebeu.' : null;
      _erroServidor = null;
    });
    if (_erroCnpj != null || _erroCodigo != null) return;
    setState(() => _enviando = true);
    try {
      await (widget.assumir ?? LojaService.instance.assumir)(
        _cnpj.text.replaceAll(RegExp(r'\D'), ''),
        codigo,
      );
      // Com a loja carregada, a tela de baixo vira o painel
      if (mounted) Navigator.of(context).popUntil((rota) => rota.isFirst);
    } on FalhaComMensagem catch (e) {
      if (mounted) setState(() => _erroServidor = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar na minha loja')),
      body: ColunaCentral(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s4,
            Espaco.s4,
            Espaco.s8,
          ),
          children: [
            Text('Sua loja já está no DailyObra', style: t.headlineSmall),
            const SizedBox(height: Espaco.s1),
            Text(
              'Digite o CNPJ e o código de acesso que o DailyObra mandou para a empresa. Esta conta vira a dona da loja, e depois você convida a equipe.',
              style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
            ),
            const SizedBox(height: Espaco.s5),
            CampoTexto(
              rotulo: 'CNPJ da loja',
              controller: _cnpj,
              obrigatorio: true,
              teclado: TextInputType.number,
              erro: _erroCnpj,
              acao: TextInputAction.next,
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Código de acesso',
              controller: _codigo,
              obrigatorio: true,
              dica: 'ABCD-1234-EF56',
              erro: _erroCodigo,
              acao: TextInputAction.done,
              onSubmitted: (_) => _entrar(),
            ),
            const SizedBox(height: Espaco.s5),
            if (_erroServidor != null) ...[
              Aviso(_erroServidor!),
              const SizedBox(height: Espaco.s3),
            ],
            FilledButton(
              onPressed: _enviando ? null : _entrar,
              child: Text(_enviando ? 'Entrando…' : 'Entrar na minha loja'),
            ),
          ],
        ),
      ),
    );
  }
}
