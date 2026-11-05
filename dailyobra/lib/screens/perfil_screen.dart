import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/carteira_service.dart';
import '../services/obras_service.dart';
import '../services/perfil_service.dart';
import 'componentes.dart';
import 'marca_screen.dart';
import 'menu_da_conta.dart';
import 'propostas_comerciais_screen.dart';
import 'simulador_screen.dart';

const _larguraDeDuasColunas = 960.0;
const _larguraDaLateral = 320.0;

/// Dados do construtor, carteira, cidade (ordena as lojas), tema, obras e saída da conta. Nas telas largas, a pessoa e os
/// caminhos ficam à esquerda e o que se edita fica à direita.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    required this.tema,
    this.consultarCep = buscarCep,
  });
  final PreferenciaTema tema;

  /// Busca do CEP; o padrão é o ViaCEP.
  final BuscarCep consultarCep;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _perfil = PerfilService.instance;
  late final _nome = TextEditingController(text: _perfil.nome);
  late final _empresa = TextEditingController(text: _perfil.empresa);
  late final _endereco = ControleEndereco(
    cep: _perfil.endereco['cep'],
    logradouro: _perfil.endereco['logradouro'] ?? '',
    numero: _perfil.endereco['numero'] ?? '',
    complemento: _perfil.endereco['complemento'] ?? '',
    bairro: _perfil.endereco['bairro'] ?? '',
    cidade: _perfil.cidade ?? '',
    uf: _perfil.uf,
  );
  Map<String, String> _errosEndereco = const {};
  late final _documento = TextEditingController(text: _perfil.documento ?? '');
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _perfil.addListener(_recarregar);
  }

  @override
  void dispose() {
    _perfil.removeListener(_recarregar);
    _nome.dispose();
    _empresa.dispose();
    _documento.dispose();
    _endereco.dispose();
    super.dispose();
  }

  /// Perfil chegou do servidor depois de a tela abrir: preenche os campos ainda intocados.
  void _recarregar() {
    if (_nome.text.isEmpty) _nome.text = _perfil.nome;
    if (_empresa.text.isEmpty) _empresa.text = _perfil.empresa;
    if (_documento.text.isEmpty) _documento.text = _perfil.documento ?? '';
    if (!_endereco.alterado) {
      setState(
        () => _endereco.preencher(
          cep: _perfil.endereco['cep'],
          logradouro: _perfil.endereco['logradouro'] ?? '',
          numero: _perfil.endereco['numero'] ?? '',
          complemento: _perfil.endereco['complemento'] ?? '',
          bairro: _perfil.endereco['bairro'] ?? '',
          cidade: _perfil.cidade ?? '',
          uf: _perfil.uf,
        ),
      );
    }
  }

  Future<void> _salvar() async {
    if (_nome.text.trim().length < 2) {
      avisar(context, 'Informe seu nome.');
      return;
    }
    if (_documento.text.trim().isNotEmpty &&
        !documentoValido(_documento.text)) {
      avisar(context, 'CPF ou CNPJ inválido. Confira os números.');
      return;
    }
    final erros = _endereco.validarOpcional();
    setState(() => _errosEndereco = erros);
    if (erros.isNotEmpty) {
      avisar(context, 'Confira o endereço.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await _perfil.salvar(
        nome: _nome.text,
        empresa: _empresa.text,
        cidade: _endereco.cidade.text,
        uf: _endereco.uf,
        documento: _documento.text,
        endereco: _endereco.partes(),
      );
      if (mounted) avisar(context, 'Perfil salvo.');
    } catch (e) {
      if (mounted) {
        avisar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _identidade() {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final suave = t.bodyMedium?.copyWith(color: c.textoSuave);
    Widget linha(IconData icone, String texto) => Padding(
      padding: const EdgeInsets.only(top: Espaco.s2),
      child: Row(
        children: [
          Icon(icone, size: 18, color: c.textoSuave),
          const SizedBox(width: Espaco.s2),
          Expanded(child: Text(texto, style: suave)),
        ],
      ),
    );

    return ListenableBuilder(
      listenable: _perfil,
      builder: (context, _) {
        final cidade = _perfil.cidade;
        return Painel(
          child: Padding(
            padding: const EdgeInsets.all(Espaco.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarDaConta(nome: _perfil.nome, tamanho: 64),
                    const SizedBox(width: Espaco.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _perfil.nome.isEmpty ? 'Seu perfil' : _perfil.nome,
                            style: t.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _perfil.email,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall?.copyWith(color: c.textoSuave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_perfil.empresa.isNotEmpty || cidade != null)
                  const SizedBox(height: Espaco.s2),
                if (_perfil.empresa.isNotEmpty)
                  linha(Icons.business_outlined, _perfil.empresa),
                if (cidade != null)
                  linha(
                    Icons.place_outlined,
                    _perfil.uf == null ? cidade : '$cidade, ${_perfil.uf}',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _carteira() {
    final carteira = CarteiraService.instance;
    return ListenableBuilder(
      listenable: carteira,
      builder: (context, _) {
        final c = context.cores;
        final t = Theme.of(context).textTheme;
        return Material(
          color: c.cartaoEscuro,
          borderRadius: BorderRadius.circular(Raio.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => abrirCarteira(context),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Carteira',
                          style: t.bodySmall?.copyWith(
                            color: c.textoCartaoEscuroSuave,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${brl.format(carteira.disponivel)} disponível',
                            style: t.titleLarge?.copyWith(
                              color: c.textoCartaoEscuro,
                              fontWeight: FontWeight.w700,
                              fontFeatures: numerosTabulares,
                            ),
                          ),
                        ),
                        Text(
                          carteira.pendente > 0
                              ? '+ ${brl.format(carteira.pendente)} a liberar depois da entrega'
                              : 'Ganhe cashback em cada pedido fechado pelo app',
                          style: t.bodySmall?.copyWith(
                            color: const Color(0xFFFFB98F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.textoCartaoEscuro),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _caminhos() {
    Widget linha(
      IconData icone,
      String titulo,
      String detalhe,
      VoidCallback aoTocar,
    ) => ListTile(
      leading: Icon(icone),
      title: Text(titulo),
      subtitle: Text(detalhe),
      trailing: const Icon(Icons.chevron_right),
      onTap: aoTocar,
    );
    void abrir(Widget tela) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    }

    return Painel(
      child: Column(
        children: [
          linha(
            Icons.home_work_outlined,
            'Minhas obras',
            'Orçamento, andamento e materiais',
            () => abrirMinhasObras(context),
          ),
          const Divider(height: 1),
          linha(
            Icons.request_quote_outlined,
            'Propostas comerciais',
            'Proposta em PDF com a sua marca',
            () => abrir(const PropostasComerciaisScreen()),
          ),
          const Divider(height: 1),
          linha(
            Icons.badge_outlined,
            'Sua marca nos documentos',
            'Logo e registro nos PDFs da obra',
            () => abrir(const MarcaScreen()),
          ),
          const Divider(height: 1),
          linha(
            Icons.calculate_outlined,
            'Simulador de obra',
            'Custo estimado por padrão e área',
            () => abrir(const SimuladorScreen()),
          ),
        ],
      ),
    );
  }

  Widget _botaoSair() {
    final c = context.cores;
    return Painel(
      child: ListTile(
        leading: Icon(Icons.logout, color: c.erro),
        title: Text('Sair da conta', style: TextStyle(color: c.erro)),
        onTap: () => sairDaConta(context),
      ),
    );
  }

  Widget _seusDados(bool largo) {
    final nome = CampoTexto(
      rotulo: 'Nome',
      controller: _nome,
      obrigatorio: true,
      autofill: const [AutofillHints.name],
    );
    final empresa = CampoTexto(
      rotulo: 'Empresa',
      controller: _empresa,
      dica: 'Construtora ou nome profissional',
    );
    final documento = CampoTexto(
      key: const ValueKey('perfil-documento'),
      rotulo: 'CPF ou CNPJ',
      controller: _documento,
      teclado: TextInputType.number,
      ajuda: 'Vai na nota quando você mesmo paga o pedido.',
    );
    return Painel(
      titulo: 'Seus dados',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: largo
              ? [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: nome),
                      const SizedBox(width: Espaco.s3),
                      Expanded(child: empresa),
                    ],
                  ),
                  const SizedBox(height: Espaco.s3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: documento),
                      const SizedBox(width: Espaco.s3),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ]
              : [
                  nome,
                  const SizedBox(height: Espaco.s3),
                  empresa,
                  const SizedBox(height: Espaco.s3),
                  documento,
                ],
        ),
      ),
    );
  }

  Widget _enderecoEBotao(bool largo) {
    final salvar = FilledButton(
      onPressed: _salvando ? null : _salvar,
      child: Text(_salvando ? 'Salvando…' : 'Salvar alterações'),
    );
    return Painel(
      titulo: 'Endereço',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CamposEndereco(
              controle: _endereco,
              erros: _errosEndereco,
              buscar: widget.consultarCep,
              exigeEndereco: false,
              exigeCidade: false,
              ajudaCidade: 'As lojas dela aparecem primeiro.',
            ),
            const SizedBox(height: Espaco.s4),
            if (largo)
              Align(alignment: Alignment.centerRight, child: salvar)
            else
              salvar,
          ],
        ),
      ),
    );
  }

  Widget _aparencia() {
    return Painel(
      titulo: 'Aparência',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: widget.tema,
          builder: (context, modo, _) => Segmentado<ThemeMode>(
            valor: modo,
            opcoes: const [
              (ThemeMode.system, 'Sistema'),
              (ThemeMode.light, 'Claro'),
              (ThemeMode.dark, 'Escuro'),
            ],
            onChanged: widget.tema.definir,
          ),
        ),
      ),
    );
  }

  Widget _coluna(List<Widget> filhos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, filho) in filhos.indexed) ...[
          if (i > 0) const SizedBox(height: Espaco.s3),
          filho,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: LayoutBuilder(
        builder: (context, limites) {
          final largo = limites.maxWidth >= _larguraDeDuasColunas;
          final m = margemLateral(limites.maxWidth, maximo: largo ? 1120 : 720);
          return ListView(
            padding: EdgeInsets.fromLTRB(m, Espaco.s4, m, Espaco.s8),
            children: [
              if (largo)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _larguraDaLateral,
                      child: _coluna([
                        _identidade(),
                        _carteira(),
                        _caminhos(),
                        _botaoSair(),
                      ]),
                    ),
                    const SizedBox(width: Espaco.s5),
                    Expanded(
                      child: _coluna([
                        _seusDados(true),
                        _enderecoEBotao(true),
                        _aparencia(),
                        const _ObraAtiva(),
                      ]),
                    ),
                  ],
                )
              else
                _coluna([
                  _identidade(),
                  _carteira(),
                  _caminhos(),
                  _seusDados(false),
                  _enderecoEBotao(false),
                  const _ObraAtiva(),
                  _aparencia(),
                  _botaoSair(),
                ]),
            ],
          );
        },
      ),
    );
  }
}

/// Obra da faixa do Início. Some quando não há obra cadastrada.
class _ObraAtiva extends StatelessWidget {
  const _ObraAtiva();

  @override
  Widget build(BuildContext context) {
    final servico = ObrasService.instance;
    return ListenableBuilder(
      listenable: servico,
      builder: (context, _) {
        final obras = servico.obras ?? const <Obra>[];
        if (obras.isEmpty) return const SizedBox.shrink();
        final ativa = servico.obraAtiva?.id;
        final c = context.cores;
        final t = Theme.of(context).textTheme;
        return Painel(
          titulo: 'Obra ativa',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s3,
                  Espaco.s4,
                  Espaco.s1,
                ),
                child: Text(
                  'A obra que aparece na faixa do Início.',
                  style: t.bodySmall?.copyWith(color: c.textoSuave),
                ),
              ),
              for (final o in obras)
                ListTile(
                  selected: o.id == ativa,
                  selectedColor: c.acao,
                  leading: Icon(
                    o.id == ativa
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(o.dados.nome),
                  subtitle: Text(
                    [
                      o.dados.cidade,
                      o.dados.uf,
                    ].where((s) => s.isNotEmpty).join(' – '),
                  ),
                  onTap: () => servico.fixarAtiva(o.id),
                ),
            ],
          ),
        );
      },
    );
  }
}
