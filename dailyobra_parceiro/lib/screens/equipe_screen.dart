import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/loja_service.dart';
import 'componentes.dart';

/// Equipe da loja (só o dono): convida por e-mail quem já tem conta e remove integrantes.
class EquipeScreen extends StatefulWidget {
  const EquipeScreen({super.key});

  @override
  State<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends State<EquipeScreen> {
  final _email = TextEditingController();
  PapelLoja _papel = PapelLoja.vendedor;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    LojaService.instance.carregarEquipe();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _convidar() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      avisar(context, 'Informe um e-mail válido.');
      return;
    }
    setState(() => _enviando = true);
    try {
      await LojaService.instance.convidar(email, _papel);
      _email.clear();
      if (mounted) {
        avisar(
          context,
          'Pronto: a pessoa já vê a loja ao entrar no DailyObra Parceiros.',
        );
      }
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servico = LojaService.instance;
    final eu = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Equipe')),
      body: ListenableBuilder(
        listenable: servico,
        builder: (context, _) {
          final t = Theme.of(context).textTheme;
          final c = context.cores;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s4,
              Espaco.s4,
              Espaco.s8,
            ),
            children: [
              Painel(
                titulo: 'Convidar',
                child: Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'A pessoa precisa ter conta no DailyObra (pode criar no próprio app Parceiros).',
                        style: t.bodySmall?.copyWith(color: c.textoSuave),
                      ),
                      const SizedBox(height: Espaco.s3),
                      CampoTexto(
                        rotulo: 'E-mail',
                        controller: _email,
                        teclado: TextInputType.emailAddress,
                        autofill: const [AutofillHints.email],
                      ),
                      const SizedBox(height: Espaco.s3),
                      Segmentado<PapelLoja>(
                        valor: _papel,
                        opcoes: const [
                          (PapelLoja.vendedor, 'Vendedor'),
                          (PapelLoja.gerente, 'Gerente'),
                        ],
                        onChanged: (p) => setState(() => _papel = p),
                      ),
                      const SizedBox(height: Espaco.s1),
                      Text(
                        _papel == PapelLoja.gerente
                            ? 'Gerente responde propostas, muda preços e os dados da loja.'
                            : 'Vendedor responde propostas e acompanha pedidos.',
                        style: t.bodySmall?.copyWith(color: c.textoSuave),
                      ),
                      const SizedBox(height: Espaco.s3),
                      FilledButton(
                        onPressed: _enviando ? null : _convidar,
                        child: Text(_enviando ? 'Convidando…' : 'Convidar'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Espaco.s3),
              Painel(
                titulo: 'Quem usa o app',
                child: Column(
                  children: [
                    for (final m in servico.equipe)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: c.acao.withValues(alpha: 0.12),
                          child: Text(
                            LogoLoja.iniciais(m.nome),
                            style: TextStyle(color: c.acao),
                          ),
                        ),
                        title: Text(
                          m.userId == eu ? '${m.nome} (você)' : m.nome,
                        ),
                        subtitle: Text(m.papel.rotulo),
                        trailing: m.papel == PapelLoja.dono || m.userId == eu
                            ? null
                            : IconButton(
                                tooltip: 'Tirar da equipe',
                                icon: Icon(
                                  Icons.person_remove_outlined,
                                  color: c.erro,
                                ),
                                onPressed: () async {
                                  if (await confirmar(
                                    context,
                                    titulo: 'Tirar ${m.nome} da equipe?',
                                    texto: 'A pessoa deixa de ver as propostas e os pedidos da loja.',
                                    acao: 'Tirar',
                                  )) {
                                    try {
                                      await servico.removerMembro(m.userId);
                                    } on FalhaComMensagem catch (e) {
                                      if (context.mounted) {
                                        avisar(context, e.mensagem);
                                      }
                                    }
                                  }
                                },
                              ),
                      ),
                    if (servico.equipe.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(Espaco.s4),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
