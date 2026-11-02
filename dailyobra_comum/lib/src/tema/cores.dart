import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cores do Design System DailyObra nos temas claro e escuro. Os widgets leem daqui
/// (`context.cores`) em vez de cores fixas, para funcionar nos dois temas.
/// No claro o botão é o laranja escuro (#A43F05, texto branco); no escuro, o laranja da marca
/// (#F36E21) com texto quase preto: nos dois o contraste passa de 4,5:1.
@immutable
class CoresDailyObra extends ThemeExtension<CoresDailyObra> {
  const CoresDailyObra({
    required this.fundo,
    required this.superficie,
    required this.superficieSutil,
    required this.borda,
    required this.texto,
    required this.textoSuave,
    required this.acao,
    required this.acaoPressionada,
    required this.textoSobreAcao,
    required this.acento,
    required this.sucesso,
    required this.aviso,
    required this.erro,
    required this.info,
    required this.segPrevista,
    required this.segNeutra,
    required this.hachuraLaranja,
    required this.hachuraVermelha,
    required this.topo,
    required this.textoSobreTopo,
    required this.destaqueSuave,
    required this.cartaoEscuro,
    required this.textoCartaoEscuro,
    required this.textoCartaoEscuroSuave,
  });

  /// Fundo das telas
  final Color fundo;

  /// Cartões e painéis
  final Color superficie;

  /// Faixas dentro de cartões (rodapés de total, notas)
  final Color superficieSutil;
  final Color borda;
  final Color texto;
  final Color textoSuave;

  /// Botão principal
  final Color acao;
  final Color acaoPressionada;
  final Color textoSobreAcao;

  /// Laranja da marca: faixa da obra, destaques, seleção
  final Color acento;
  final Color sucesso;
  final Color aviso;
  final Color erro;
  final Color info;
  final Color segPrevista;
  final Color segNeutra;
  final Color hachuraLaranja;
  final Color hachuraVermelha;

  /// Barra laranja da vitrine (mesma nos dois temas); texto em grafite, porque branco sobre esse
  /// laranja não passa de 4,5:1
  final Color topo;
  final Color textoSobreTopo;

  /// Fundo suave laranja: item ativo do menu, prazo, ícone da lista inteligente
  final Color destaqueSuave;

  /// Cartões grafite de destaque (Clube, pedido a caminho)
  final Color cartaoEscuro;
  final Color textoCartaoEscuro;
  final Color textoCartaoEscuroSuave;

  static const claro = CoresDailyObra(
    fundo: Color(0xFFF6F7F9),
    superficie: Color(0xFFFFFFFF),
    superficieSutil: Color(0xFFF6F7F9),
    borda: Color(0xFFD5D8DD),
    texto: Color(0xFF252832),
    textoSuave: Color(0xFF535965),
    acao: Color(0xFFA43F05),
    acaoPressionada: Color(0xFF8A3504),
    textoSobreAcao: Color(0xFFFFFFFF),
    acento: Color(0xFFF36E21),
    sucesso: Color(0xFF166534),
    aviso: Color(0xFF9A5400),
    erro: Color(0xFFB42318),
    info: Color(0xFF1D4ED8),
    segPrevista: Color(0xFFE4E6EA),
    segNeutra: Color(0xFFB8BBC4),
    hachuraLaranja: Color(0xFFFCD9C3),
    hachuraVermelha: Color(0xFFF6D0CC),
    topo: Color(0xFFF36E21),
    textoSobreTopo: Color(0xFF252832),
    destaqueSuave: Color(0xFFFDE9DC),
    cartaoEscuro: Color(0xFF252832),
    textoCartaoEscuro: Color(0xFFFFFFFF),
    textoCartaoEscuroSuave: Color(0xFFB8BBC4),
  );

  static const escuro = CoresDailyObra(
    fundo: Color(0xFF141519),
    superficie: Color(0xFF1C1E23),
    superficieSutil: Color(0xFF24272E),
    borda: Color(0xFF343741),
    texto: Color(0xFFF2F3F5),
    textoSuave: Color(0xFFA8ACB6),
    acao: Color(0xFFF36E21),
    acaoPressionada: Color(0xFFFF8A45),
    textoSobreAcao: Color(0xFF1A0F07),
    acento: Color(0xFFF36E21),
    sucesso: Color(0xFF4CC38A),
    aviso: Color(0xFFF0B44C),
    erro: Color(0xFFFF8A80),
    info: Color(0xFF8AB4FF),
    segPrevista: Color(0xFF343741),
    segNeutra: Color(0xFF5A5E6A),
    hachuraLaranja: Color(0xFF5A341F),
    hachuraVermelha: Color(0xFF5C2A27),
    topo: Color(0xFFF36E21),
    textoSobreTopo: Color(0xFF252832),
    destaqueSuave: Color(0xFF3A2416),
    cartaoEscuro: Color(0xFF2A2D35),
    textoCartaoEscuro: Color(0xFFF2F3F5),
    textoCartaoEscuroSuave: Color(0xFFA8ACB6),
  );

  @override
  CoresDailyObra copyWith() => this;

  // Troca de tema sem animação de cor: os dois esquemas são fixos
  @override
  CoresDailyObra lerp(covariant CoresDailyObra? other, double t) => t < 0.5 || other == null ? this : other;
}

extension CoresContexto on BuildContext {
  CoresDailyObra get cores => Theme.of(this).extension<CoresDailyObra>() ?? CoresDailyObra.claro;
}

/// Razão de contraste WCAG 2.1 entre duas cores (1 a 21)
double contraste(Color a, Color b) {
  double canal(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminancia(Color c) => 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  final la = luminancia(a), lb = luminancia(b);
  final claro = math.max(la, lb), escuro = math.min(la, lb);
  return (claro + 0.05) / (escuro + 0.05);
}
