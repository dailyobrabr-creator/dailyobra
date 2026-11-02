import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/loja_service.dart';
import 'componentes.dart';
import 'equipe_screen.dart';

/// Perfil da loja como o construtor vê: capa, logo, descrição, contato, frete e pedido mínimo.
class MinhaLojaScreen extends StatefulWidget {
  const MinhaLojaScreen({super.key, required this.tema});
  final PreferenciaTema tema;

  @override
  State<MinhaLojaScreen> createState() => _MinhaLojaScreenState();
}

class _MinhaLojaScreenState extends State<MinhaLojaScreen> {
  final _servico = LojaService.instance;
  final _nome = TextEditingController();
  final _descricao = TextEditingController();
  final _whatsapp = TextEditingController();
  final _endereco = TextEditingController();
  final _horario = TextEditingController();
  final _frete = TextEditingController();
  final _minimo = TextEditingController();
  String? _lojaPreenchida;
  bool _salvando = false;
  bool _enviandoImagem = false;

  @override
  void dispose() {
    for (final c in [
      _nome,
      _descricao,
      _whatsapp,
      _endereco,
      _horario,
      _frete,
      _minimo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _preencher(Loja loja) {
    if (_lojaPreenchida == loja.id) return;
    _lojaPreenchida = loja.id;
    _nome.text = loja.nome;
    _descricao.text = loja.descricao;
    _whatsapp.text = loja.whatsapp;
    _endereco.text = _servico.dados.endereco;
    _horario.text = _servico.dados.horario;
    _frete.text = numero.format(loja.freteFixo);
    _minimo.text = numero.format(loja.pedidoMinimo);
  }

  Future<void> _salvar() async {
    final frete = _frete.text.trim().isEmpty ? 0.0 : lerNumero(_frete.text);
    final minimo = _minimo.text.trim().isEmpty ? 0.0 : lerNumero(_minimo.text);
    final zap = _whatsapp.text.replaceAll(RegExp(r'\D'), '');
    if (_nome.text.trim().length < 2) {
      return avisar(context, 'Informe o nome da loja.');
    }
    if (frete.isNaN || frete < 0 || minimo.isNaN || minimo < 0) {
      return avisar(context, 'Confira o frete e o pedido mínimo.');
    }
    if (zap.isNotEmpty && (zap.length < 10 || zap.length > 13)) {
      return avisar(context, 'WhatsApp com DDD, só números.');
    }
    setState(() => _salvando = true);
    try {
      await _servico.atualizar({
        'nome': _nome.text.trim(),
        'descricao': _descricao.text.trim().isEmpty
            ? null
            : _descricao.text.trim(),
        'whatsapp': zap.isEmpty ? null : zap,
        'endereco': _endereco.text.trim().isEmpty
            ? null
            : _endereco.text.trim(),
        'horario': _horario.text.trim().isEmpty ? null : _horario.text.trim(),
        'frete_fixo': frete,
        'pedido_minimo': minimo,
      });
      _lojaPreenchida = null;
      if (mounted) avisar(context, 'Dados da loja salvos.');
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _trocarImagem({required bool capa}) async {
    final arquivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: capa ? 1600 : 800,
      maxHeight: capa ? 1600 : 800,
      imageQuality: 82,
    );
    if (arquivo == null) return;
    setState(() => _enviandoImagem = true);
    try {
      await _servico.enviarImagem(arquivo, capa: capa);
      if (mounted) {
        avisar(context, capa ? 'Capa atualizada.' : 'Logo atualizada.');
      }
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviandoImagem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _servico,
      builder: (context, _) {
        final loja = _servico.minhaLoja;
        final t = Theme.of(context).textTheme;
        final c = context.cores;
        if (loja == null) {
          return const Scaffold(
            body: EstadoVazio(
              titulo: 'Loja não encontrada',
              texto: 'Entre de novo no app.',
            ),
          );
        }
        _preencher(loja);
        final gere = _servico.meuPapel.gere;
        final dono = _servico.meuPapel == PapelLoja.dono;
        return Scaffold(
          appBar: AppBar(title: const Text('Minha loja')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: Espaco.s8),
            children: [
              _Capa(
                loja: loja,
                pode: gere && !_enviandoImagem,
                onCapa: () => _trocarImagem(capa: true),
                onLogo: () => _trocarImagem(capa: false),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s3,
                  Espaco.s4,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(loja.nome, style: t.headlineSmall),
                    Text(
                      'CNPJ ${formatarCnpj(_servico.dados.cnpj)} · ${loja.cidade} · ${loja.uf}',
                      style: t.bodySmall?.copyWith(color: c.textoSuave),
                    ),
                    if (_servico.dados.status != 'ativa') ...[
                      const SizedBox(height: Espaco.s3),
                      const Aviso(
                        'Loja suspensa pelo suporte. Ela não aparece para os construtores.',
                      ),
                    ],
                    if (_enviandoImagem) ...[
                      const SizedBox(height: Espaco.s3),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: Espaco.s4),
                    Painel(
                      titulo: 'Dados da loja',
                      child: Padding(
                        padding: const EdgeInsets.all(Espaco.s4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!gere) ...[
                              const Aviso(
                                'Só o dono ou o gerente altera os dados da loja.',
                                tom: TomSelo.info,
                              ),
                              const SizedBox(height: Espaco.s3),
                            ],
                            IgnorePointer(
                              ignoring: !gere,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CampoTexto(
                                    rotulo: 'Nome da loja',
                                    controller: _nome,
                                    obrigatorio: true,
                                    maxLength: 80,
                                  ),
                                  const SizedBox(height: Espaco.s3),
                                  CampoTexto(
                                    rotulo: 'Sobre a loja',
                                    controller: _descricao,
                                    maxLength: 600,
                                    dica: 'O que a loja tem de melhor',
                                  ),
                                  const SizedBox(height: Espaco.s3),
                                  CampoTexto(
                                    rotulo: 'WhatsApp',
                                    controller: _whatsapp,
                                    teclado: TextInputType.phone,
                                    dica: '(44) 99999-0000',
                                  ),
                                  const SizedBox(height: Espaco.s3),
                                  CampoTexto(
                                    rotulo: 'Endereço',
                                    controller: _endereco,
                                    maxLength: 200,
                                  ),
                                  const SizedBox(height: Espaco.s3),
                                  CampoTexto(
                                    rotulo: 'Horário de atendimento',
                                    controller: _horario,
                                    maxLength: 120,
                                  ),
                                  const SizedBox(height: Espaco.s3),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: CampoTexto(
                                          rotulo: 'Frete (R\$)',
                                          controller: _frete,
                                          teclado:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: Espaco.s3),
                                      Expanded(
                                        child: CampoTexto(
                                          rotulo: 'Pedido mínimo (R\$)',
                                          controller: _minimo,
                                          teclado:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (gere) ...[
                              const SizedBox(height: Espaco.s4),
                              FilledButton(
                                onPressed: _salvando ? null : _salvar,
                                child: Text(
                                  _salvando ? 'Salvando…' : 'Salvar dados',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Espaco.s3),
                    Painel(
                      child: Column(
                        children: [
                          if (dono) ...[
                            ListTile(
                              leading: const Icon(Icons.group_outlined),
                              title: const Text('Equipe'),
                              subtitle: const Text(
                                'Gerentes e vendedores que usam o app',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EquipeScreen(),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(Espaco.s4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Aparência', style: t.titleSmall),
                                const SizedBox(height: Espaco.s2),
                                ValueListenableBuilder<ThemeMode>(
                                  valueListenable: widget.tema,
                                  builder: (context, modo, _) =>
                                      Segmentado<ThemeMode>(
                                        valor: modo,
                                        opcoes: const [
                                          (ThemeMode.system, 'Sistema'),
                                          (ThemeMode.light, 'Claro'),
                                          (ThemeMode.dark, 'Escuro'),
                                        ],
                                        onChanged: widget.tema.definir,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Espaco.s3),
                    Painel(
                      child: ListTile(
                        leading: Icon(Icons.logout, color: c.erro),
                        title: Text(
                          'Sair da conta',
                          style: TextStyle(color: c.erro),
                        ),
                        onTap: () async {
                          if (await confirmar(
                            context,
                            titulo: 'Sair da conta?',
                            texto: 'A loja continua no DailyObra. Para ver as propostas de novo, é só entrar.',
                            acao: 'Sair',
                          )) {
                            await AuthService.sair();
                          }
                        },
                      ),
                    ),
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

class _Capa extends StatelessWidget {
  const _Capa({
    required this.loja,
    required this.pode,
    required this.onCapa,
    required this.onLogo,
  });
  final Loja loja;
  final bool pode;
  final VoidCallback onCapa;
  final VoidCallback onLogo;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final fundo = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.acao.withValues(alpha: 0.22),
            c.acento.withValues(alpha: 0.08),
          ],
        ),
      ),
    );
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 140,
            child: loja.capaUrl == null
                ? fundo
                : Image.network(
                    loja.capaUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fundo,
                  ),
          ),
          if (pode)
            Positioned(
              right: Espaco.s3,
              top: Espaco.s3,
              child: FilledButton.tonalIcon(
                onPressed: onCapa,
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: const Text('Trocar capa'),
              ),
            ),
          Positioned(
            left: Espaco.s4,
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.fundo, width: 3),
                  ),
                  child: LogoLoja(loja: loja, tamanho: 76),
                ),
                if (pode)
                  Positioned(
                    right: -6,
                    bottom: -2,
                    child: IconButton.filled(
                      tooltip: 'Trocar logo',
                      iconSize: 18,
                      onPressed: onLogo,
                      icon: const Icon(Icons.edit),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
