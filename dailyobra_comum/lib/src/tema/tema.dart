import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cores.dart';

/// Cores do tema claro como constantes (ícone do app, geração de imagens). Nas telas, use
/// `context.cores`, que acompanha o tema claro ou escuro.
class AppColors {
  AppColors._();

  static const brandOrange = Color(0xFFF36E21);
  static const brandGraphite = Color(0xFF565966);
  static const action = Color(0xFFA43F05);
  static const ink = Color(0xFF252832);
  static const inkSoft = Color(0xFF535965);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF6F7F9);
  static const border = Color(0xFFD5D8DD);
}

/// Espaçamentos em múltiplos de 4 (space.1 a space.16 do manual)
class Espaco {
  Espaco._();
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0, s8 = 32.0, s10 = 40.0;
}

class Raio {
  Raio._();
  static const sm = 6.0, md = 10.0, lg = 16.0;
}

/// Valores em R$ com algarismos de largura fixa, para colunas de números alinharem
const numerosTabulares = [FontFeature.tabularFigures()];

class AppTheme {
  AppTheme._();

  /// [base] só nos testes de tela, para usar a fonte padrão sem baixar a Inter
  static ThemeData claro([TextTheme? base]) => _construir(CoresDailyObra.claro, Brightness.light, base);
  static ThemeData escuro([TextTheme? base]) => _construir(CoresDailyObra.escuro, Brightness.dark, base);

  static SystemUiOverlayStyle barraDoSistema(CoresDailyObra c, Brightness brilho) => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brilho == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brilho,
        systemNavigationBarColor: c.superficie,
        systemNavigationBarIconBrightness: brilho == Brightness.dark ? Brightness.light : Brightness.dark,
      );

  static ThemeData _construir(CoresDailyObra c, Brightness brilho, TextTheme? baseRecebida) {
    final base = baseRecebida ??
        GoogleFonts.interTextTheme(brilho == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme);
    // Escala tipográfica do manual, versão mobile (H1 28, H2 22, H3 18, corpo 16, pequeno 14, legenda 12).
    // letterSpacing 0: o Material 3 põe 0,1 a 0,5 px, que deixa a Inter espaçada demais; o manual não pede espaçamento.
    final texto = base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 28, height: 1.2, letterSpacing: 0, fontWeight: FontWeight.w700, color: c.texto),
      titleLarge: base.titleLarge?.copyWith(fontSize: 22, height: 1.25, letterSpacing: 0, fontWeight: FontWeight.w700, color: c.texto),
      titleMedium: base.titleMedium?.copyWith(fontSize: 18, height: 1.3, letterSpacing: 0, fontWeight: FontWeight.w600, color: c.texto),
      titleSmall: base.titleSmall?.copyWith(fontSize: 16, height: 1.3, letterSpacing: 0, fontWeight: FontWeight.w600, color: c.texto),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5, letterSpacing: 0, color: c.texto),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.45, letterSpacing: 0, color: c.texto),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, height: 1.4, letterSpacing: 0, color: c.textoSuave),
      labelLarge: base.labelLarge?.copyWith(fontSize: 14, height: 1.3, letterSpacing: 0, fontWeight: FontWeight.w600, color: c.texto),
      labelMedium: base.labelMedium?.copyWith(fontSize: 12, height: 1.3, letterSpacing: 0, fontWeight: FontWeight.w600, color: c.textoSuave),
    );

    final esquema = ColorScheme(
      brightness: brilho,
      primary: c.acao,
      onPrimary: c.textoSobreAcao,
      secondary: c.acento,
      onSecondary: c.textoSobreAcao,
      error: c.erro,
      onError: brilho == Brightness.dark ? const Color(0xFF1A0F07) : Colors.white,
      surface: c.superficie,
      onSurface: c.texto,
      onSurfaceVariant: c.textoSuave,
      outline: c.borda,
      outlineVariant: c.borda,
      surfaceContainerLowest: c.superficie,
      surfaceContainerLow: c.superficieSutil,
      surfaceContainer: c.superficieSutil,
      surfaceContainerHigh: c.superficie,
      surfaceContainerHighest: c.superficieSutil,
      surfaceTint: Colors.transparent,
    );

    final cantos = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.sm));
    OutlineInputBorder borda(Color cor, [double largura = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(Raio.sm), borderSide: BorderSide(color: cor, width: largura));

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: esquema,
      extensions: [c],
      scaffoldBackgroundColor: c.fundo,
      canvasColor: c.superficie,
      textTheme: texto,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.superficie,
        foregroundColor: c.texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: barraDoSistema(c, brilho),
        titleTextStyle: texto.titleMedium,
        shape: Border(bottom: BorderSide(color: c.borda)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.acao,
          foregroundColor: c.textoSobreAcao,
          disabledBackgroundColor: c.acao.withValues(alpha: 0.4),
          disabledForegroundColor: c.textoSobreAcao.withValues(alpha: 0.8),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: Espaco.s5),
          shape: cantos,
          textStyle: texto.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.texto,
          backgroundColor: c.superficie,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: Espaco.s4),
          side: BorderSide(color: c.borda),
          shape: cantos,
          textStyle: texto.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brilho == Brightness.dark ? c.acento : c.acao,
          minimumSize: const Size(44, 44),
          shape: cantos,
          textStyle: texto.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.superficie,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: Espaco.s3, vertical: 14),
        border: borda(c.borda),
        enabledBorder: borda(c.borda),
        focusedBorder: borda(c.acao, 2),
        errorBorder: borda(c.erro),
        focusedErrorBorder: borda(c.erro, 2),
        hintStyle: texto.bodyLarge?.copyWith(color: c.textoSuave.withValues(alpha: 0.75)),
        helperStyle: texto.bodySmall,
        errorStyle: texto.bodySmall?.copyWith(color: c.erro, fontWeight: FontWeight.w500),
        errorMaxLines: 3,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: c.textoSuave, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.acao : Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.textoSobreAcao),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.textoSobreAcao : c.textoSuave),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.acao : c.superficieSutil),
        trackOutlineColor: WidgetStatePropertyAll(c.borda),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.superficie,
        indicatorColor: c.acento.withValues(alpha: brilho == Brightness.dark ? 0.22 : 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => texto.labelMedium?.copyWith(
              color: s.contains(WidgetState.selected) ? c.texto : c.textoSuave,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? (brilho == Brightness.dark ? c.acento : c.acao) : c.textoSuave,
              size: 22,
            )),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.superficie,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borda,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Raio.lg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg)),
        titleTextStyle: texto.titleMedium,
        contentTextStyle: texto.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(color: c.superficie, surfaceTintColor: Colors.transparent, textStyle: texto.bodyMedium),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brilho == Brightness.dark ? c.superficieSutil : c.texto,
        contentTextStyle: texto.bodyMedium?.copyWith(color: brilho == Brightness.dark ? c.texto : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.sm)),
      ),
      dividerTheme: DividerThemeData(color: c.borda, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.acao),
      iconTheme: IconThemeData(color: c.textoSuave),
    );
  }
}
