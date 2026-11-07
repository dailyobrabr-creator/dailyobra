import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/clientes_service.dart';
import '../services/loja_service.dart';
import '../services/propostas_loja_service.dart';
import 'componentes.dart';
import 'inicio_screen.dart';

typedef AbrirLink = Future<bool> Function(Uri uri);

Future<bool> _abrirNoAparelho(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Clientes e leads da loja, com busca, WhatsApp e o histórico de cada um. No computador, o cliente
/// tocado abre ao lado da lista.
class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key, this.abrirLink = _abrirNoAparelho});
  final AbrirLink abrirLink;

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _busca = TextEditingController();

  /// Cliente aberto ao lado da lista (computador).
  String? _aberto;

  @override
  void initState() {
    super.initState();
    ClientesService.instance.carregar();
    abaAtual.addListener(_aoTrocarDeAba);
  }

  @override
  void dispose() {
    abaAtual.removeListener(_aoTrocarDeAba);
    _busca.dispose();
    super.dispose();
  }

  void _aoTrocarDeAba() {
    if (abaAtual.value == Aba.clientes) ClientesService.instance.carregar();
  }

  Future<void> _chamar(ClienteLoja c) async {
    final loja = LojaService.instance.minhaLoja?.nome ?? 'loja';
    final primeiroNome = c.nome.trim().split(' ').first;
    final mensagem = primeiroNome.isEmpty
        ? 'Olá! Aqui é da $loja.'
        : 'Olá, $primeiroNome! Aqui é da $loja.';
    final mensageiro = ScaffoldMessenger.of(context);
    final abriu = await widget.abrirLink(linkWhatsApp(c.telefone, mensagem));
    if (!abriu) {
      mensageiro.showSnackBar(
        const SnackBar(content: Text('Não deu para abrir o WhatsApp.')),
      );
    }
  }

  void _abrir(ClienteLoja c, {required bool aoLado}) {
    if (aoLado) {
      setState(() => _aberto = c.construtorId);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalheCliente(cliente: c, onChamar: _chamar),
      ),
    );
  }

  /// O que aparece no lugar dos cartões quando a aba está vazia.
  Widget _vazio(ClientesService servico, FiltroCliente filtro) {
    if (_busca.text.trim().isNotEmpty) {
      return const EstadoVazio(
        icone: Icons.search_off,
        titulo: 'Ninguém encontrado',
        texto: 'Confira o que digitou ou limpe a busca.',
      );
    }
    if (filtro == FiltroCliente.leads && servico.lista.isNotEmpty) {
      return const EstadoVazio(
        icone: Icons.people_outline,
        titulo: 'Nenhum lead',
        texto: 'Quem cotou e ainda não comprou aparece aqui.',
      );
    }
    return EstadoVazio(
      icone: Icons.people_outline,
      titulo: 'Nenhum cliente ainda',
      texto: filtro == FiltroCliente.todos
          ? 'Quem mandar proposta para a loja aparece aqui.'
          : 'Quem fechar um pedido aparece aqui.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final servico = ClientesService.instance;
    final aoLado = formatoDoContexto(context) == Formato.computador;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final abas = [
          for (final f in FiltroCliente.values)
            (filtro: f, lista: filtrarClientes(servico.lista, f, _busca.text)),
        ];
        final listas = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s4,
                Espaco.s4,
                0,
              ),
              child: TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome, empresa, cidade ou telefone',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
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
                          if (!servico.carregado) ...[
                            if (servico.erro == null)
                              for (var i = 0; i < 3; i++) ...[
                                const Esqueleto(altura: 96),
                                const SizedBox(height: Espaco.s3),
                              ],
                          ] else if (aba.lista.isEmpty)
                            _vazio(servico, aba.filtro)
                          else
                            for (final c in aba.lista) ...[
                              CartaoCliente(
                                cliente: c,
                                selecionado:
                                    aoLado && c.construtorId == _aberto,
                                onAbrir: () => _abrir(c, aoLado: aoLado),
                                onChamar: () => _chamar(c),
                              ),
                              const SizedBox(height: Espaco.s3),
                            ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
        return DefaultTabController(
          length: abas.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Clientes'),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final a in abas)
                    Tab(text: '${a.filtro.rotulo} (${a.lista.length})'),
                ],
              ),
            ),
            body: aoLado
                ? ListaComDetalhe(
                    lista: listas,
                    detalhe: _aoLado(servico),
                    aviso: (i) {
                      final aba = abas[i];
                      if (!servico.carregado ||
                          servico.erro != null ||
                          aba.lista.isNotEmpty ||
                          servico.lista.any((c) => c.construtorId == _aberto)) {
                        return null;
                      }
                      return _vazio(servico, aba.filtro);
                    },
                  )
                : listas,
          ),
        );
      },
    );
  }

  /// Coluna da direita no computador.
  Widget _aoLado(ClientesService servico) {
    for (final c in servico.lista) {
      if (c.construtorId == _aberto) {
        return DetalheCliente(
          key: ValueKey(c.construtorId),
          cliente: c,
          onChamar: _chamar,
          embutida: true,
        );
      }
    }
    return const EstadoVazio(
      icone: Icons.people_outline,
      titulo: 'Escolha um cliente',
      texto: 'Toque num cliente da lista para ver o histórico aqui.',
    );
  }
}

/// Cartão da lista: quem é, o que já comprou e quando falou com a loja por último.
class CartaoCliente extends StatelessWidget {
  const CartaoCliente({
    super.key,
    required this.cliente,
    required this.onAbrir,
    required this.onChamar,
    this.selecionado = false,
  });
  final ClienteLoja cliente;
  final VoidCallback onAbrir;
  final VoidCallback onChamar;

  /// O que está aberto ao lado da lista.
  final bool selecionado;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    final suave = t.bodySmall?.copyWith(color: c.textoSuave);
    return Material(
      color: selecionado ? c.superficieSutil : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
        side: BorderSide(color: c.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s3,
            Espaco.s2,
            Espaco.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cliente.exibicao,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium,
                          ),
                        ),
                        const SizedBox(width: Espaco.s2),
                        _SeloCliente(cliente),
                      ],
                    ),
                    if (cliente.linha.isNotEmpty)
                      Text(
                        cliente.linha,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: suave,
                      ),
                    const SizedBox(height: Espaco.s1),
                    Text(cliente.resumo, style: t.bodyMedium),
                    Text(
                      'Último contato ${quando(cliente.ultimoContato)}',
                      style: suave,
                    ),
                  ],
                ),
              ),
              if (cliente.telefone.isNotEmpty)
                IconButton(
                  tooltip: 'Chamar no WhatsApp',
                  icon: const Icon(Icons.chat_outlined),
                  onPressed: onChamar,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeloCliente extends StatelessWidget {
  const _SeloCliente(this.cliente);
  final ClienteLoja cliente;

  @override
  Widget build(BuildContext context) => cliente.comprou
      ? const Selo('Cliente', tom: TomSelo.sucesso)
      : const Selo('Lead', tom: TomSelo.info);
}

/// Um cliente: contato, números e as propostas e pedidos dele com a loja.
class DetalheCliente extends StatelessWidget {
  const DetalheCliente({
    super.key,
    required this.cliente,
    required this.onChamar,
    this.embutida = false,
  });
  final ClienteLoja cliente;
  final ValueChanged<ClienteLoja> onChamar;

  /// Ao lado da lista no computador, sem barra de título própria.
  final bool embutida;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final servico = PropostasLojaService.instance;
    final corpo = ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final historico = [
          for (final p in servico.todas)
            if (p.construtorId == cliente.construtorId) p,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s4,
            Espaco.s4,
            Espaco.s8,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cliente.exibicao,
                    style: t.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Espaco.s2),
                _SeloCliente(cliente),
              ],
            ),
            if (cliente.linha.isNotEmpty)
              Text(
                cliente.linha,
                style: t.bodyMedium?.copyWith(color: c.textoSuave),
              ),
            const SizedBox(height: Espaco.s3),
            if (cliente.telefone.isNotEmpty)
              FilledButton.icon(
                onPressed: () => onChamar(cliente),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Chamar no WhatsApp'),
              )
            else
              Text(
                'Sem telefone no cadastro.',
                style: t.bodyMedium?.copyWith(color: c.textoSuave),
              ),
            const SizedBox(height: Espaco.s4),
            Painel(
              child: Column(
                children: [
                  _Numero('Propostas', '${cliente.propostas}'),
                  const Divider(height: 1),
                  _Numero('Pedidos', '${cliente.pedidos}'),
                  const Divider(height: 1),
                  _Numero('Comprou', brl.format(cliente.total)),
                  const Divider(height: 1),
                  _Numero('Último contato', dataHora(cliente.ultimoContato)),
                ],
              ),
            ),
            const SizedBox(height: Espaco.s5),
            Text('Histórico', style: t.titleMedium),
            const SizedBox(height: Espaco.s3),
            for (final p in historico) ...[
              CartaoPropostaLoja(proposta: p),
              const SizedBox(height: Espaco.s3),
            ],
            // A lista do painel traz só as 200 propostas mais recentes da loja
            if (historico.length < cliente.propostas)
              Text(
                'Mostrando só as propostas mais recentes da loja.',
                style: t.bodySmall?.copyWith(color: c.textoSuave),
              ),
          ],
        );
      },
    );
    return embutida
        ? corpo
        : Scaffold(
            appBar: AppBar(title: Text(cliente.exibicao)),
            body: ColunaCentral(child: corpo),
          );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.rotulo, this.valor);
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.s3,
        vertical: Espaco.s2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rotulo,
            style: t.bodyMedium?.copyWith(color: context.cores.textoSuave),
          ),
          const SizedBox(width: Espaco.s3),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
