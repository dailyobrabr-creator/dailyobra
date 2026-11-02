import 'dart:async';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/cadastro_loja_screen.dart';
import 'screens/navegacao_screen.dart';
import 'services/loja_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mesmo projeto Supabase do app do construtor; os links do e-mail voltam para este app
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  AuthService.definirLinkRetorno('dailyobraparceiros://login');
  final tema = await PreferenciaTema.carregar();
  runApp(ParceirosApp(tema: tema));
}

class ParceirosApp extends StatelessWidget {
  const ParceirosApp({super.key, required this.tema});
  final PreferenciaTema tema;

  @override
  Widget build(BuildContext context) {
    return AppComTema(
      titulo: 'DailyObra Parceiros',
      tema: tema,
      claro: AppTheme.claro(),
      escuro: AppTheme.escuro(),
      home: _Porta(tema: tema),
    );
  }
}

/// Primeira tela pela sessão: login, nova senha (link do e-mail), cadastro da loja ou painel.
class _Porta extends StatefulWidget {
  const _Porta({required this.tema});
  final PreferenciaTema tema;

  @override
  State<_Porta> createState() => _PortaState();
}

class _PortaState extends State<_Porta> {
  Session? _sessao = Supabase.instance.client.auth.currentSession;
  bool _recuperandoSenha = false;
  late final StreamSubscription<AuthState> _assinatura;

  @override
  void initState() {
    super.initState();
    if (_sessao != null) LojaService.instance.carregar();
    _assinatura = AuthService.mudancas.listen((estado) {
      final antes = _sessao?.user.id;
      setState(() {
        _sessao = estado.session;
        if (estado.event == AuthChangeEvent.passwordRecovery) {
          _recuperandoSenha = true;
        }
        if (estado.event == AuthChangeEvent.signedOut) {
          _recuperandoSenha = false;
        }
      });
      if (estado.session == null) {
        LojaService.instance.limpar();
      } else if (estado.session!.user.id != antes) {
        LojaService.instance.carregar();
      }
    });
  }

  @override
  void dispose() {
    _assinatura.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recuperandoSenha && _sessao != null) {
      return NovaSenhaScreen(
        onConcluir: () => setState(() => _recuperandoSenha = false),
      );
    }
    if (_sessao == null) {
      return const LoginScreen(
        selo: 'Parceiros',
        subtitulo: 'Receba orçamentos dos construtores da sua região, responda propostas e acompanhe os pedidos.',
      );
    }
    final loja = LojaService.instance;
    return ListenableBuilder(
      listenable: loja,
      builder: (context, _) {
        if (!loja.carregado) {
          return Scaffold(
            body: Center(
              child: loja.erro == null
                  ? const CircularProgressIndicator()
                  : EstadoVazio(
                      icone: Icons.wifi_off,
                      titulo: 'Não foi possível abrir a loja',
                      texto: loja.erro!,
                      acao: FilledButton(
                        onPressed: loja.carregar,
                        child: const Text('Tentar de novo'),
                      ),
                    ),
            ),
          );
        }
        if (loja.minhaLoja == null) return const CadastroLojaScreen();
        return NavegacaoScreen(
          key: ValueKey(loja.minhaLoja!.id),
          tema: widget.tema,
        );
      },
    );
  }
}
