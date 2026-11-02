import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema escolhido no Perfil (Sistema, Claro, Escuro), guardado no aparelho
class PreferenciaTema extends ValueNotifier<ThemeMode> {
  PreferenciaTema._(super.value, this._prefs);

  static const _chave = 'dailyobra.tema';
  final SharedPreferences _prefs;

  static Future<PreferenciaTema> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final modo = switch (prefs.getString(_chave)) {
      'claro' => ThemeMode.light,
      'escuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return PreferenciaTema._(modo, prefs);
  }

  Future<void> definir(ThemeMode modo) async {
    value = modo;
    await _prefs.setString(_chave, switch (modo) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'escuro',
      ThemeMode.system => 'sistema',
    });
  }
}
