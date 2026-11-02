import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../tema/tema.dart';
import '../tema/cores.dart';

final brl = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final brlInteiro = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 0);
final numero = NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 2);

/// Bloco com borda, sem sombra (o manual prefere borda a sombra em telas densas)
class Painel extends StatelessWidget {
  const Painel({super.key, this.titulo, this.acao, required this.child});
  final String? titulo;
  final Widget? acao;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material (e não Container com cor): itens tocáveis dentro, como ExpansionTile, precisam dele para
    // pintar o efeito do toque; com Container o Flutter acusa erro no modo de desenvolvimento
    return Material(
      color: context.cores.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg), side: BorderSide(color: context.cores.borda)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null)
            Container(
              padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s3, Espaco.s3, Espaco.s3),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.cores.borda))),
              child: Row(
                children: [
                  Expanded(child: Text(titulo!, style: Theme.of(context).textTheme.titleSmall)),
                  ?acao,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

enum TomSelo { neutro, sucesso, aviso, erro, info }

class Selo extends StatelessWidget {
  const Selo(this.texto, {super.key, this.tom = TomSelo.neutro});
  final String texto;
  final TomSelo tom;

  @override
  Widget build(BuildContext context) {
    final cor = switch (tom) {
      TomSelo.neutro => context.cores.textoSuave,
      TomSelo.sucesso => context.cores.sucesso,
      TomSelo.aviso => context.cores.aviso,
      TomSelo.erro => context.cores.erro,
      TomSelo.info => context.cores.info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tom == TomSelo.neutro ? context.cores.superficieSutil : cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tom == TomSelo.neutro ? context.cores.borda : cor.withValues(alpha: 0.3)),
      ),
      child: Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cor)),
    );
  }
}

/// Aviso em faixa: erro, sucesso ou informação. Usa texto, não só cor.
class Aviso extends StatelessWidget {
  const Aviso(this.texto, {super.key, this.tom = TomSelo.erro});
  final String texto;
  final TomSelo tom;

  @override
  Widget build(BuildContext context) {
    final cor = switch (tom) {
      TomSelo.sucesso => context.cores.sucesso,
      TomSelo.info => context.cores.info,
      TomSelo.aviso => context.cores.aviso,
      _ => context.cores.erro,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Espaco.s3, vertical: 10),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(Raio.sm),
          border: Border.all(color: cor.withValues(alpha: 0.3)),
        ),
        child: Text(texto, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cor, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

/// Controle segmentado no estilo do app web: opção escolhida em branco sobre fundo cinza claro
class Segmentado<T> extends StatelessWidget {
  const Segmentado({super.key, required this.valor, required this.opcoes, required this.onChanged});
  final T valor;
  final List<(T, String)> opcoes;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.cores.superficieSutil,
        borderRadius: BorderRadius.circular(Raio.sm),
        border: Border.all(color: context.cores.borda),
      ),
      child: Row(
        children: [
          for (final (v, rotulo) in opcoes)
            Expanded(
              child: Semantics(
                selected: v == valor,
                button: true,
                child: Material(
                  color: v == valor ? context.cores.superficie : Colors.transparent,
                  elevation: v == valor ? 1 : 0,
                  shadowColor: const Color(0x14191D23),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => onChanged(v),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: Espaco.s2),
                      child: Text(
                        rotulo,
                        textAlign: TextAlign.center,
                        style: t.labelLarge?.copyWith(
                          fontWeight: v == valor ? FontWeight.w600 : FontWeight.w500,
                          color: v == valor ? context.cores.texto : context.cores.textoSuave,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rótulo acima do campo, com asterisco quando obrigatório (labels persistentes, como pede o manual)
class Rotulo extends StatelessWidget {
  const Rotulo(this.texto, {super.key, this.obrigatorio = false});
  final String texto;
  final bool obrigatorio;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(text: texto, style: t, children: [
        if (obrigatorio) TextSpan(text: ' *', style: t?.copyWith(color: context.cores.erro)),
      ])),
    );
  }
}

class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.rotulo,
    required this.controller,
    this.obrigatorio = false,
    this.dica,
    this.ajuda,
    this.erro,
    this.teclado,
    this.acao,
    this.senha = false,
    this.autofill,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
  });

  final String rotulo;
  final TextEditingController controller;
  final bool obrigatorio;
  final String? dica;
  final String? ajuda;
  final String? erro;
  final TextInputType? teclado;
  final TextInputAction? acao;
  final bool senha;
  final Iterable<String>? autofill;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  /// Senha à mostra pelo botão do olho
  bool _visivel = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Rotulo(w.rotulo, obrigatorio: w.obrigatorio),
        TextField(
          controller: w.controller,
          keyboardType: w.teclado,
          textInputAction: w.acao,
          obscureText: w.senha && !_visivel,
          autofillHints: w.autofill,
          maxLength: w.maxLength,
          onChanged: w.onChanged,
          onSubmitted: w.onSubmitted,
          decoration: InputDecoration(
            hintText: w.dica,
            helperText: w.erro == null ? w.ajuda : null,
            errorText: w.erro,
            counterText: '',
            suffixIcon: w.senha
                ? IconButton(
                    tooltip: _visivel ? 'Esconder senha' : 'Mostrar senha',
                    onPressed: () => setState(() => _visivel = !_visivel),
                    icon: Icon(_visivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Esqueleto de carregamento: bloco cinza no lugar do conteúdo
class Esqueleto extends StatelessWidget {
  const Esqueleto({super.key, this.altura = 120});
  final double altura;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: altura,
      decoration: BoxDecoration(
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(Raio.md),
        border: Border.all(color: context.cores.borda),
      ),
    );
  }
}
