import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/obras_service.dart';
import '../services/perfil_service.dart';
import 'componentes.dart';
import 'obras_screen.dart';
import 'simulador_screen.dart';

/// Dados do construtor, cidade (ordena as lojas), tema, obras e saída da conta.
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
  late String _cidade = _perfil.cidade ?? '';
  late final _documento = TextEditingController(text: _perfil.documento ?? '');
  late String? _uf = _perfil.uf;
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
    super.dispose();
  }

  /// Perfil chegou do servidor depois de a tela abrir: preenche os campos ainda intocados.
  void _recarregar() {
    if (_nome.text.isEmpty) _nome.text = _perfil.nome;
    if (_empresa.text.isEmpty) _empresa.text = _perfil.empresa;
    if (_documento.text.isEmpty) _documento.text = _perfil.documento ?? '';
    setState(() {
      if (_cidade.isEmpty) _cidade = _perfil.cidade ?? '';
      _uf ??= _perfil.uf;
    });
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
    setState(() => _salvando = true);
    try {
      await _perfil.salvar(
        nome: _nome.text,
        empresa: _empresa.text,
        cidade: _cidade,
        uf: _uf,
        documento: _documento.text,
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

  Future<void> _sair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Suas obras, propostas e saldo continuam na conta. Para ver de novo, é só entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthService.sair();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: LayoutBuilder(
        builder: (context, limites) {
          final m = margemLateral(limites.maxWidth, maximo: 720);
          return ListView(
            padding: EdgeInsets.fromLTRB(m, Espaco.s4, m, Espaco.s8),
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.acao.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      LogoLoja.iniciais(
                        _perfil.nome.isEmpty ? '?' : _perfil.nome,
                      ),
                      style: t.titleMedium?.copyWith(color: c.acao),
                    ),
                  ),
                  const SizedBox(width: Espaco.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _perfil.nome.isEmpty ? 'Seu perfil' : _perfil.nome,
                          style: t.titleMedium,
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
              const SizedBox(height: Espaco.s4),
              Painel(
                titulo: 'Seus dados',
                child: Padding(
                  padding: const EdgeInsets.all(Espaco.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampoTexto(
                        rotulo: 'Nome',
                        controller: _nome,
                        obrigatorio: true,
                        autofill: const [AutofillHints.name],
                      ),
                      const SizedBox(height: Espaco.s3),
                      CampoTexto(
                        rotulo: 'Empresa',
                        controller: _empresa,
                        dica: 'Construtora ou nome profissional',
                      ),
                      const SizedBox(height: Espaco.s3),
                      CampoTexto(
                        key: const ValueKey('perfil-documento'),
                        rotulo: 'CPF ou CNPJ',
                        controller: _documento,
                        teclado: TextInputType.number,
                        ajuda: 'Vai na nota quando você mesmo paga o pedido.',
                      ),
                      const SizedBox(height: Espaco.s3),
                      CampoRegiao(
                        cidade: _cidade,
                        uf: _uf ?? '',
                        ajuda: 'As lojas dela aparecem primeiro.',
                        consultarCep: widget.consultarCep,
                        onEscolher: (cidade, uf) => setState(() {
                          _cidade = cidade;
                          _uf = uf;
                        }),
                      ),
                      const SizedBox(height: Espaco.s4),
                      FilledButton(
                        onPressed: _salvando ? null : _salvar,
                        child: Text(_salvando ? 'Salvando…' : 'Salvar'),
                      ),
                    ],
                  ),
                ),
              ),
              const _ObraAtiva(),
              const SizedBox(height: Espaco.s3),
              Painel(
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
              ),
              const SizedBox(height: Espaco.s3),
              Painel(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home_work_outlined),
                      title: const Text('Minhas obras'),
                      subtitle: const Text('Orçamento, andamento e materiais'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ObrasScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.calculate_outlined),
                      title: const Text('Simulador de obra'),
                      subtitle: const Text('Custo estimado por padrão e área'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SimuladorScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Espaco.s3),
              Painel(
                child: ListTile(
                  leading: Icon(Icons.logout, color: c.erro),
                  title: Text('Sair da conta', style: TextStyle(color: c.erro)),
                  onTap: _sair,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Obra do cartão do Início. Some quando não há obra cadastrada.
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
        return Padding(
          padding: const EdgeInsets.only(top: Espaco.s3),
          child: Painel(
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
                    'A obra que aparece no Início, com o andamento e os materiais.',
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
          ),
        );
      },
    );
  }
}
