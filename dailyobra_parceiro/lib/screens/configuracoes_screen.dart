import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/cep_service.dart';
import '../services/loja_service.dart';
import 'clientes_screen.dart';
import 'componentes.dart';
import 'equipe_screen.dart';
import 'secoes_loja.dart';

enum SecaoLoja {
  perfil(
    'Perfil da loja',
    'Logo, capa, nome, descrição e WhatsApp',
    Icons.storefront_outlined,
  ),
  enderecoHorario(
    'Endereço e horário',
    'CEP, outras unidades e horário de atendimento',
    Icons.place_outlined,
  ),
  entrega(
    'Entrega e pedido mínimo',
    'Frete e valor mínimo do pedido',
    Icons.local_shipping_outlined,
  ),
  pagamento('Pagamento', 'Chave PIX da loja', Icons.payments_outlined),
  equipe(
    'Equipe',
    'Gerentes e vendedores que usam o app',
    Icons.group_outlined,
  ),
  aparencia(
    'Aparência',
    'Tema claro, escuro ou do sistema',
    Icons.palette_outlined,
  ),
  conta('Conta', 'Sair da conta', Icons.person_outline);

  const SecaoLoja(this.titulo, this.descricao, this.icone);
  final String titulo;
  final String descricao;
  final IconData icone;
}

/// Configurações da loja em seções. No computador a seção abre ao lado da lista; no celular e no
/// tablet, em tela própria. Cada seção grava só o que é dela.
class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key, required this.tema, this.buscarCep});
  final PreferenciaTema tema;

  /// Busca do CEP; o padrão é o ViaCEP.
  final BuscarCep? buscarCep;

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  /// Seção aberta ao lado da lista (computador).
  SecaoLoja _aberta = SecaoLoja.perfil;

  Widget _secao(SecaoLoja s) => switch (s) {
    SecaoLoja.perfil => const SecaoPerfil(),
    SecaoLoja.enderecoHorario => SecaoEnderecoHorario(
      buscarCep: widget.buscarCep,
    ),
    SecaoLoja.entrega => const SecaoEntrega(),
    SecaoLoja.pagamento => const SecaoPagamento(),
    SecaoLoja.equipe => const EquipeScreen(),
    SecaoLoja.aparencia => SecaoAparencia(tema: widget.tema),
    SecaoLoja.conta => const SecaoConta(),
  };

  void _abrir(SecaoLoja s, {required bool aoLado}) {
    if (aoLado) {
      setState(() => _aberta = s);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => s == SecaoLoja.equipe
            ? _secao(s)
            : Scaffold(
                appBar: AppBar(title: Text(s.titulo)),
                body: ColunaCentral(child: _secao(s)),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servico = LojaService.instance;
    final aoLado = formatoDoContexto(context) == Formato.computador;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final loja = servico.minhaLoja;
        if (loja == null) {
          return const Scaffold(
            body: EstadoVazio(
              titulo: 'Loja não encontrada',
              texto: 'Entre de novo no app.',
            ),
          );
        }
        // Equipe é só do dono (convida e remove quem usa o app)
        final secoes = [
          for (final s in SecaoLoja.values)
            if (s != SecaoLoja.equipe || servico.meuPapel == PapelLoja.dono) s,
        ];
        final lista = ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s4,
            Espaco.s4,
            Espaco.s8,
          ),
          children: [
            _Cabecalho(loja: loja),
            if (servico.dados.status != 'ativa') ...[
              const SizedBox(height: Espaco.s3),
              const Aviso(
                'Loja suspensa pelo suporte. Ela não aparece para os construtores.',
              ),
            ],
            const SizedBox(height: Espaco.s4),
            // O celular não tem aba para Clientes: entra por aqui
            if (formatoDoContexto(context) == Formato.celular) ...[
              Painel(
                child: ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Clientes'),
                  subtitle: const Text('Quem comprou e quem só cotou'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClientesScreen()),
                  ),
                ),
              ),
              const SizedBox(height: Espaco.s3),
            ],
            Painel(
              child: Column(
                children: [
                  for (final (i, s) in secoes.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(s.icone),
                      title: Text(s.titulo),
                      subtitle: Text(s.descricao),
                      trailing: const Icon(Icons.chevron_right),
                      selected: aoLado && s == _aberta,
                      onTap: () => _abrir(s, aoLado: aoLado),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
        return Scaffold(
          appBar: AppBar(title: const Text('Configurações')),
          body: !aoLado
              ? ColunaCentral(child: lista)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 400, child: lista),
                    VerticalDivider(width: 1, color: context.cores.borda),
                    Expanded(
                      // Ficam montadas: trocar de seção não perde o que foi digitado. A equipe
                      // só carrega quando abre
                      child: IndexedStack(
                        index: secoes.contains(_aberta)
                            ? secoes.indexOf(_aberta)
                            : 0,
                        children: [
                          for (final s in secoes)
                            s != SecaoLoja.equipe
                                ? _SecaoAoLado(secao: s, filho: _secao(s))
                                : _aberta == s
                                ? _secao(s)
                                : const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Logo, nome e dados que só o suporte muda, no alto da lista de seções.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.loja});
  final Loja loja;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        LogoLoja(loja: loja, tamanho: 48),
        const SizedBox(width: Espaco.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loja.nome, style: t.titleLarge, maxLines: 2),
              Text(
                'CNPJ ${formatarCnpj(LojaService.instance.dados.cnpj)} · ${loja.cidade} · ${loja.uf}',
                style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Título da seção aberta na coluna da direita (no computador).
class _SecaoAoLado extends StatelessWidget {
  const _SecaoAoLado({required this.secao, required this.filho});
  final SecaoLoja secao;
  final Widget filho;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s4, Espaco.s4, 0),
        child: Text(
          secao.titulo,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      Expanded(child: ColunaCentral(child: filho)),
    ],
  );
}
