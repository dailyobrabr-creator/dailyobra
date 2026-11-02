import 'package:flutter/material.dart';

/// Par de cores de uma categoria do catálogo: fundo suave e ícone da mesma família.
@immutable
class CorCategoria {
  const CorCategoria(this.fundo, this.icone);
  final Color fundo;
  final Color icone;
}

const _claro = {
  'basico': CorCategoria(Color(0xFFFDE3D2), Color(0xFF8A3504)),
  'estrutura': CorCategoria(Color(0xFFEDE7F6), Color(0xFF4C2F94)),
  'alvenaria': CorCategoria(Color(0xFFE6ECF4), Color(0xFF3B4A63)),
  'cobertura': CorCategoria(Color(0xFFE4EEF0), Color(0xFF2F4F5A)),
  'hidraulica': CorCategoria(Color(0xFFDCEBFB), Color(0xFF1D4ED8)),
  'eletrica': CorCategoria(Color(0xFFFDF1C7), Color(0xFF7A4F00)),
  'acabamento': CorCategoria(Color(0xFFF3E8DD), Color(0xFF6B4B2E)),
  'pintura': CorCategoria(Color(0xFFE3F5EA), Color(0xFF166534)),
  'loucas-metais': CorCategoria(Color(0xFFF6E3EC), Color(0xFF8E2453)),
  'ferramentas': CorCategoria(Color(0xFFE0F4F4), Color(0xFF0F5F5F)),
};

const _escuro = {
  'basico': CorCategoria(Color(0xFF3A2416), Color(0xFFFFB98F)),
  'estrutura': CorCategoria(Color(0xFF2A2340), Color(0xFFC4B2F2)),
  'alvenaria': CorCategoria(Color(0xFF232A36), Color(0xFFB4C3DA)),
  'cobertura': CorCategoria(Color(0xFF1D2C31), Color(0xFF9CC4CF)),
  'hidraulica': CorCategoria(Color(0xFF1C2A44), Color(0xFF8AB4FF)),
  'eletrica': CorCategoria(Color(0xFF3A3015), Color(0xFFF0C75E)),
  'acabamento': CorCategoria(Color(0xFF33281E), Color(0xFFD9B894)),
  'pintura': CorCategoria(Color(0xFF16301F), Color(0xFF7FD6A4)),
  'loucas-metais': CorCategoria(Color(0xFF3A1C2A), Color(0xFFF2A5C6)),
  'ferramentas': CorCategoria(Color(0xFF143233), Color(0xFF7FD3D3)),
};

/// Cores da categoria no tema; categoria desconhecida usa as de "basico".
CorCategoria coresDaCategoria(String categoriaId, Brightness brilho) {
  final tabela = brilho == Brightness.dark ? _escuro : _claro;
  return tabela[categoriaId] ?? tabela['basico']!;
}
