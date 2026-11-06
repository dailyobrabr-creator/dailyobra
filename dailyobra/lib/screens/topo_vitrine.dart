import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/novidades_service.dart';
import '../services/perfil_service.dart';
import 'componentes.dart';
import 'menu_da_conta.dart';
import 'novidades_screen.dart';

/// Barra laranja da vitrine: saudação, endereço, tema, sino e iniciais.
/// [compacto] é a versão do celular: só isso, com os cantos arredondados embaixo, porque a busca é a aba Busca.
/// Nas telas maiores o campo de busca fica no meio da barra e leva à mesma aba.
class TopoVitrine extends StatelessWidget {
  const TopoVitrine({
    super.key,
    required this.compacto,
    this.tema,
    this.novidades,
    this.onSino,
    this.comBusca = true,
  });
  final bool compacto;
  final PreferenciaTema? tema;

  /// Na aba Busca a tela já traz o campo: a barra não repete.
  final bool comBusca;

  /// Número no sino; sem valor, usa as não vistas do NovidadesService.
  final int? novidades;

  /// Toque no sino; sem valor, abre as novidades.
  final VoidCallback? onSino;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final perfil = PerfilService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([perfil, NovidadesService.instance]),
      builder: (context, _) {
        final nome = perfil.primeiroNome;
        final saudacao = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nome.isEmpty ? 'Olá' : 'Olá, $nome',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleLarge?.copyWith(
                color: c.textoSobreTopo,
                fontWeight: FontWeight.w700,
              ),
            ),
            Semantics(
              button: true,
              label: 'Mudar endereço no perfil',
              child: InkWell(
                borderRadius: BorderRadius.circular(Raio.sm),
                onTap: () => irParaAba(context, Aba.perfil),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        perfil.cidade == null
                            ? 'Informe sua cidade no perfil'
                            : '${perfil.cidade}${perfil.uf == null ? '' : ' · ${perfil.uf}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          color: c.textoSobreTopo,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: c.textoSobreTopo,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        final acoes = [
          if (tema != null) _BotaoTema(tema: tema!),
          const SizedBox(width: Espaco.s2),
          _Sino(
            novidades: novidades ?? NovidadesService.instance.naoVistas,
            onTap: onSino ?? () => abrirNovidades(context),
          ),
          const SizedBox(width: Espaco.s2),
          MenuDaConta(cor: c.textoSobreTopo, corDoTexto: Colors.white),
        ];
        return Material(
          color: c.topo,
          shape: compacto
              ? const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                )
              : null,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: compacto
                  ? const EdgeInsets.symmetric(
                      horizontal: Espaco.s4,
                      vertical: Espaco.s3,
                    )
                  : const EdgeInsets.symmetric(
                      horizontal: Espaco.s8,
                      vertical: 18,
                    ),
              child: compacto
                  ? Row(
                      children: [
                        Expanded(child: saudacao),
                        ...acoes,
                      ],
                    )
                  : Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: saudacao,
                        ),
                        const SizedBox(width: Espaco.s6),
                        Expanded(
                          child: comBusca
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 620,
                                    ),
                                    child: const _CampoBusca(),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: Espaco.s4),
                        ...acoes,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _CampoBusca extends StatelessWidget {
  const _CampoBusca();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Buscar produtos',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => irParaAba(context, Aba.busca),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espaco.s4),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF535965)),
                  const SizedBox(width: Espaco.s2),
                  Expanded(
                    child: Text(
                      'Buscar cimento, tijolo, torneira…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge?.copyWith(
                        color: const Color(0xFF535965),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoTema extends StatelessWidget {
  const _BotaoTema({required this.tema});
  final PreferenciaTema tema;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return _Redondo(
      rotulo: escuro ? 'Usar tema claro' : 'Usar tema escuro',
      icone: escuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      onTap: () => tema.definir(escuro ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

class _Sino extends StatelessWidget {
  const _Sino({required this.novidades, required this.onTap});
  final int novidades;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _Redondo(
          rotulo: novidades > 0 ? '$novidades novidades' : 'Novidades',
          icone: Icons.notifications_none,
          onTap: onTap,
        ),
        if (novidades > 0)
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: context.cores.textoSobreTopo,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  novidades > 99 ? '99+' : '$novidades',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Redondo extends StatelessWidget {
  const _Redondo({required this.rotulo, required this.icone, this.onTap});
  final String rotulo;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: rotulo,
      child: Material(
        color: Colors.white.withValues(alpha: 0.28),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icone, color: context.cores.textoSobreTopo),
          ),
        ),
      ),
    );
  }
}
