import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/obras_service.dart';
import 'componentes.dart';
import 'hoje_na_obra.dart';
import 'menu_da_conta.dart';
import 'obras_screen.dart';

/// A aba do engenheiro: a obra ativa com tudo o que dá para fazer nela. Sem obra, é o caminho para cadastrar a primeira.
class AbaObrasScreen extends StatelessWidget {
  const AbaObrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servico = ObrasService.instance;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final ativa = servico.obraAtiva;
        if (ativa == null) return const ObrasScreen(titulo: 'Obras');
        final celular = formatoDoContexto(context) == Formato.celular;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Obras'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: Espaco.s2),
                child: TextButton(
                  onPressed: () => abrirMinhasObras(context),
                  child: const Text('Minhas obras'),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, limites) {
              final m = margemLateral(limites.maxWidth);
              return RefreshIndicator(
                color: context.cores.acao,
                onRefresh: servico.carregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(m, Espaco.s3, m, Espaco.s8),
                  children: [
                    if (servico.erro != null) ...[
                      Aviso(servico.erro!),
                      const SizedBox(height: Espaco.s3),
                    ],
                    _SeletorDeObra(obras: servico.obras!, ativa: ativa),
                    const SizedBox(height: Espaco.s3),
                    HojeNaObra(
                      key: ValueKey(ativa.id),
                      obra: ativa,
                      compacto: celular,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Troca a obra da aba em um toque e cadastra outra sem sair daqui.
class _SeletorDeObra extends StatelessWidget {
  const _SeletorDeObra({required this.obras, required this.ativa});
  final List<Obra> obras;
  final Obra ativa;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final obra in obras) ...[
            ChoiceChip(
              label: Text(obra.nome),
              selected: obra.id == ativa.id,
              selectedColor: c.acao,
              checkmarkColor: c.textoSobreAcao,
              labelStyle: TextStyle(
                color: obra.id == ativa.id ? c.textoSobreAcao : c.texto,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => ObrasService.instance.fixarAtiva(obra.id),
            ),
            const SizedBox(width: Espaco.s2),
          ],
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Nova obra'),
            onPressed: () => novaObra(context),
          ),
        ],
      ),
    );
  }
}
