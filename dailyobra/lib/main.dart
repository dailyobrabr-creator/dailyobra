import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';

import 'screens/convite_screen.dart';
import 'screens/navegacao_screen.dart';
import 'screens/simulador_screen.dart';
import 'services/obras_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Datas em português ("31 de out. de 2026") nos cartões e na ficha da obra
  await initializeDateFormatting('pt_BR');
  // Restaura a sessão guardada no aparelho e passa a tratar os links do e-mail (dailyobra://login)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  ObrasService.instance.iniciar();
  final tema = await PreferenciaTema.carregar();
  runApp(DailyObraApp(tema: tema));
}

class DailyObraApp extends StatelessWidget {
  const DailyObraApp({super.key, required this.tema});

  /// Escolha de tema do Perfil (Sistema, Claro, Escuro)
  final PreferenciaTema tema;

  @override
  Widget build(BuildContext context) {
    return AppComTema(
      titulo: 'DailyObra',
      tema: tema,
      claro: AppTheme.claro(),
      escuro: AppTheme.escuro(),
      home: _Porta(tema: tema),
    );
  }
}

/// Decide a primeira tela pela sessão: login, início ou nova senha (link de recuperação do e-mail)
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

  /// Código do link do convite, que só o site recebe: no app a pessoa digita.
  final _convite = Uri.base.queryParameters['convite'];

  @override
  void initState() {
    super.initState();
    _assinatura = AuthService.mudancas.listen((estado) {
      setState(() {
        _sessao = estado.session;
        if (estado.event == AuthChangeEvent.passwordRecovery) {
          _recuperandoSenha = true;
        }
        if (estado.event == AuthChangeEvent.signedOut) {
          _recuperandoSenha = false;
        }
      });
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
      return LoginScreen(
        subtitulo: _convite != null
            ? 'Entre ou crie sua conta para aceitar o convite para a obra.'
            : 'Compare o preço das lojas, monte o orçamento da obra e negocie direto com quem vende.',
        onSimular: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SimuladorScreen(podeSalvar: false),
          ),
        ),
      );
    }
    return AbreConvite(
      codigo: _convite,
      child: NavegacaoScreen(tema: widget.tema),
    );
  }
}
