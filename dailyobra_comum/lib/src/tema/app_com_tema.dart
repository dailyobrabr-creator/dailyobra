import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'preferencia_tema.dart';

/// MaterialApp em português que segue a escolha de tema do usuário (Sistema, Claro, Escuro).
class AppComTema extends StatelessWidget {
  const AppComTema({
    super.key,
    required this.titulo,
    required this.tema,
    required this.claro,
    required this.escuro,
    required this.home,
  });
  final String titulo;
  final PreferenciaTema tema;
  final ThemeData claro;
  final ThemeData escuro;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: tema,
      builder: (context, modo, _) => MaterialApp(
        title: titulo,
        debugShowCheckedModeBanner: false,
        theme: claro,
        darkTheme: escuro,
        themeMode: modo,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );
  }
}
