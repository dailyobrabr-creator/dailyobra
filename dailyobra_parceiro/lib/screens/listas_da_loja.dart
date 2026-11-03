import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/propostas_loja_service.dart';
import 'inicio_screen.dart';
import 'pedido_loja_screen.dart';
import 'proposta_loja_screen.dart';

/// Uma aba de [ListasDaLoja]: rótulo, propostas e o que dizer quando ela está vazia.
typedef AbaDaLista = ({
  String rotulo,
  List<PropostaResumo> lista,
  String vazioTitulo,
  String vazioTexto,
});

/// Listas em abas de Propostas e de Pedidos. No computador, o item tocado abre ao lado da lista.
class ListasDaLoja extends StatefulWidget {
  const ListasDaLoja({
    super.key,
    required this.titulo,
    required this.abas,
    required this.icone,
    required this.escolhaTitulo,
    required this.escolhaTexto,
  });
  final String titulo;
  final List<AbaDaLista> Function(PropostasLojaService servico) abas;
  final IconData icone;

  /// Coluna da direita antes de escolher um item.
  final String escolhaTitulo;
  final String escolhaTexto;

  @override
  State<ListasDaLoja> createState() => _ListasDaLojaState();
}

class _ListasDaLojaState extends State<ListasDaLoja> {
  /// Proposta aberta ao lado da lista (computador).
  String? _aberta;

  @override
  Widget build(BuildContext context) {
    final servico = PropostasLojaService.instance;
    final aoLado = formatoDoContexto(context) == Formato.computador;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final abas = widget.abas(servico);
        final listas = TabBarView(
          children: [
            for (final aba in abas)
              RefreshIndicator(
                color: context.cores.acao,
                onRefresh: servico.carregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.s4,
                    Espaco.s4,
                    Espaco.s4,
                    Espaco.s8,
                  ),
                  children: [
                    if (servico.erro != null) ...[
                      Aviso(servico.erro!),
                      const SizedBox(height: Espaco.s3),
                    ],
                    if (!servico.carregado)
                      for (var i = 0; i < 3; i++) ...[
                        const Esqueleto(altura: 96),
                        const SizedBox(height: Espaco.s3),
                      ]
                    else if (aba.lista.isEmpty)
                      EstadoVazio(
                        icone: widget.icone,
                        titulo: aba.vazioTitulo,
                        texto: aba.vazioTexto,
                      )
                    else
                      for (final p in aba.lista) ...[
                        CartaoPropostaLoja(
                          proposta: p,
                          onAbrir: aoLado
                              ? (p) => setState(() => _aberta = p.id)
                              : null,
                          selecionado: aoLado && p.id == _aberta,
                        ),
                        const SizedBox(height: Espaco.s3),
                      ],
                  ],
                ),
              ),
          ],
        );
        return DefaultTabController(
          length: abas.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.titulo),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final a in abas) Tab(text: a.rotulo)],
              ),
            ),
            body: aoLado
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 440, child: listas),
                      VerticalDivider(width: 1, color: context.cores.borda),
                      Expanded(child: _aberto(servico)),
                    ],
                  )
                : listas,
          ),
        );
      },
    );
  }

  /// Coluna da direita: a proposta aberta (ou o pedido em que ela virou), ou o aviso para escolher.
  Widget _aberto(PropostasLojaService servico) {
    final id = _aberta;
    final p = id == null ? null : servico.proposta(id);
    if (p == null) {
      return EstadoVazio(
        icone: widget.icone,
        titulo: widget.escolhaTitulo,
        texto: widget.escolhaTexto,
      );
    }
    final pedido = p.pedido;
    return pedido == null
        ? PropostaLojaScreen(key: ValueKey(p.id), id: p.id, embutida: true)
        : PedidoLojaScreen(
            key: ValueKey(pedido.id),
            pedidoId: pedido.id,
            embutida: true,
          );
  }
}
