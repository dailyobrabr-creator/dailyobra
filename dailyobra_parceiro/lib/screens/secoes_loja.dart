import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/clientes_service.dart';
import '../services/loja_service.dart';
import 'componentes.dart';
import 'editor_horario.dart';

/// Formulário de uma seção das Configurações: para quem não gere a loja, só leitura e sem Salvar.
class _Formulario extends StatelessWidget {
  const _Formulario({
    required this.campos,
    required this.salvando,
    required this.onSalvar,
    this.topo,
    this.erro,
    this.rodape,
  });
  final List<Widget> campos;
  final bool salvando;
  final VoidCallback onSalvar;
  final Widget? topo;
  final String? erro;

  /// Abaixo do Salvar, para quem gere a loja.
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    final gere = LojaService.instance.meuPapel.gere;
    return ListView(
      padding: const EdgeInsets.only(bottom: Espaco.s8),
      children: [
        ?topo,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s4,
            Espaco.s4,
            0,
          ),
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
                  children: campos,
                ),
              ),
              if (erro case final mensagem?) ...[
                const SizedBox(height: Espaco.s3),
                Aviso(mensagem),
              ],
              if (gere) ...[
                const SizedBox(height: Espaco.s4),
                FilledButton(
                  onPressed: salvando ? null : onSalvar,
                  child: Text(salvando ? 'Salvando…' : 'Salvar'),
                ),
                if (rodape case final parte?) ...[
                  const SizedBox(height: Espaco.s8),
                  parte,
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Grava uma seção, mostra o resultado e trava o botão enquanto isso.
mixin _Gravacao<T extends StatefulWidget> on State<T> {
  bool salvando = false;

  Future<void> gravar(Future<void> Function() acao) async {
    setState(() => salvando = true);
    try {
      await acao();
      if (mounted) avisar(context, 'Dados salvos.');
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }
}

/// Logo, capa, nome, descrição e WhatsApp: o que o construtor vê no topo da loja.
class SecaoPerfil extends StatefulWidget {
  const SecaoPerfil({super.key, this.escolherImagem});

  /// Quem escolhe a imagem; o padrão é a galeria do aparelho.
  final Future<XFile?> Function(ImagemLoja tipo)? escolherImagem;

  @override
  State<SecaoPerfil> createState() => _SecaoPerfilState();
}

class _SecaoPerfilState extends State<SecaoPerfil> with _Gravacao {
  final _servico = LojaService.instance;
  late final _nome = TextEditingController(text: _servico.minhaLoja?.nome);
  late final _descricao = TextEditingController(
    text: _servico.minhaLoja?.descricao,
  );
  late final _whatsapp = TextEditingController(
    text: _servico.minhaLoja?.whatsapp,
  );
  bool _enviandoImagem = false;

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final zap = _whatsapp.text.replaceAll(RegExp(r'\D'), '');
    if (_nome.text.trim().length < 2) {
      return avisar(context, 'Informe o nome da loja.');
    }
    if (zap.isNotEmpty && (zap.length < 10 || zap.length > 13)) {
      return avisar(context, 'WhatsApp com DDD, só números.');
    }
    await gravar(
      () => _servico.atualizar({
        'nome': _nome.text.trim(),
        'descricao': _descricao.text.trim().isEmpty
            ? null
            : _descricao.text.trim(),
        'whatsapp': zap.isEmpty ? null : zap,
      }),
    );
  }

  Future<XFile?> _daGaleria(ImagemLoja tipo) => ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: tipo.maiorLado,
    maxHeight: tipo.maiorLado,
    imageQuality: 82,
  );

  Future<void> _trocarImagem(ImagemLoja tipo) async {
    final arquivo = await (widget.escolherImagem ?? _daGaleria)(tipo);
    if (arquivo == null) return;
    setState(() => _enviandoImagem = true);
    try {
      await _servico.enviarImagem(arquivo, tipo);
      if (mounted) avisar(context, tipo.feito);
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviandoImagem = false);
    }
  }

  Future<void> _removerBanner() async {
    final ok = await confirmar(
      context,
      titulo: 'Remover o banner?',
      texto: 'Ele some da página da loja. Você pode enviar outro depois.',
      acao: 'Remover',
    );
    if (ok) await gravar(() => _servico.atualizar({'banner_path': null}));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _servico,
    builder: (context, _) {
      final loja = _servico.minhaLoja;
      return _Formulario(
        salvando: salvando,
        onSalvar: _salvar,
        topo: loja == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Capa(
                    loja: loja,
                    pode: _servico.meuPapel.gere && !_enviandoImagem,
                    onCapa: () => _trocarImagem(ImagemLoja.capa),
                    onLogo: () => _trocarImagem(ImagemLoja.logo),
                  ),
                  if (_enviandoImagem) const LinearProgressIndicator(),
                  _BlocoBanner(
                    loja: loja,
                    gere: _servico.meuPapel.gere,
                    ocupado: _enviandoImagem,
                    onEnviar: () => _trocarImagem(ImagemLoja.banner),
                    onRemover: _removerBanner,
                  ),
                ],
              ),
        campos: [
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
        ],
      );
    },
  );
}

/// Banner de campanha da loja: como ele aparece, e enviar, trocar ou remover para quem gere.
class _BlocoBanner extends StatelessWidget {
  const _BlocoBanner({
    required this.loja,
    required this.gere,
    required this.ocupado,
    required this.onEnviar,
    required this.onRemover,
  });
  final Loja loja;
  final bool gere;
  final bool ocupado;
  final VoidCallback onEnviar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final url = loja.bannerUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s4, Espaco.s4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Banner da loja', style: t.titleSmall),
          const SizedBox(height: 2),
          Text(
            'Sua campanha na página da loja, abaixo dos dados. Use imagem deitada, de 1920 × 600 pixels.',
            style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
          ),
          if (url != null) ...[
            const SizedBox(height: Espaco.s2),
            ClipRRect(
              borderRadius: BorderRadius.circular(Raio.md),
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                semanticLabel: 'Banner da loja',
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (gere) ...[
            const SizedBox(height: Espaco.s2),
            Wrap(
              spacing: Espaco.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: ocupado ? null : onEnviar,
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: Text(url == null ? 'Enviar banner' : 'Trocar banner'),
                ),
                if (url != null)
                  TextButton(
                    onPressed: ocupado ? null : onRemover,
                    child: const Text('Remover'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Endereço pelo CEP e horário por dia. Loja antiga sem CEP: o endereço só é conferido (e enviado)
/// quando a loja mexe nele; o horário só vai quando o editor foi mexido, para não trocar o texto
/// que o app não entendeu.
class SecaoEnderecoHorario extends StatefulWidget {
  const SecaoEnderecoHorario({super.key, this.buscarCep});

  /// Busca do CEP; o padrão é o ViaCEP.
  final BuscarCep? buscarCep;

  @override
  State<SecaoEnderecoHorario> createState() => _SecaoEnderecoHorarioState();
}

class _SecaoEnderecoHorarioState extends State<SecaoEnderecoHorario>
    with _Gravacao {
  final _servico = LojaService.instance;
  final _endereco = ControleEndereco();
  final _horario = ControleHorario.doTexto('');
  Map<String, String> _erros = const {};
  String? _erroHorario;

  @override
  void initState() {
    super.initState();
    _preencher();
  }

  @override
  void dispose() {
    _endereco.dispose();
    _horario.dispose();
    super.dispose();
  }

  void _preencher() {
    final d = _servico.dados;
    _endereco.preencher(
      cep: d.cep,
      logradouro: d.logradouro,
      numero: d.numero,
      complemento: d.complemento,
      bairro: d.bairro,
      cidade: _servico.minhaLoja?.cidade ?? '',
      uf: _servico.minhaLoja?.uf,
      outrasUnidades: d.outrasUnidades,
    );
    _horario.ler(d.horario);
  }

  Future<void> _salvar() async {
    final mexeuNoEndereco = _endereco.preenchido || _endereco.alterado;
    final mudouEndereco = _endereco.alterado;
    final erros = mexeuNoEndereco
        ? _endereco.validar()
        : const <String, String>{};
    final erroHorario = _horario.alterado ? _horario.validar() : null;
    setState(() {
      _erros = erros;
      _erroHorario = erroHorario;
    });
    if (erros.isNotEmpty) return avisar(context, erros.values.first);
    if (erroHorario != null) return;
    if (!mudouEndereco && !_horario.alterado) {
      return avisar(context, 'Nada mudou.');
    }
    final horario = _horario.texto();
    await gravar(() async {
      await _servico.atualizar({
        if (mudouEndereco) ..._endereco.campos(),
        if (_horario.alterado) 'horario': horario.isEmpty ? null : horario,
      });
      _preencher();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _servico,
    builder: (context, _) {
      final t = Theme.of(context).textTheme;
      final d = _servico.dados;
      return _Formulario(
        salvando: salvando,
        onSalvar: _salvar,
        erro: _erroHorario,
        campos: [
          if (d.cep == null && d.endereco.isNotEmpty) ...[
            Text(
              'Endereço atual: ${d.endereco}',
              style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
            ),
            const SizedBox(height: Espaco.s2),
          ],
          CamposEndereco(
            comOutrasUnidades: true,
            controle: _endereco,
            erros: _erros,
            buscar: widget.buscarCep,
          ),
          const SizedBox(height: Espaco.s3),
          const Rotulo('Horário de atendimento'),
          EditorHorario(controle: _horario),
        ],
      );
    },
  );
}

/// Frete e pedido mínimo. Salvar aqui tira a loja do "frete a combinar", mesmo com frete zero.
class SecaoEntrega extends StatefulWidget {
  const SecaoEntrega({super.key});

  @override
  State<SecaoEntrega> createState() => _SecaoEntregaState();
}

class _SecaoEntregaState extends State<SecaoEntrega> with _Gravacao {
  final _servico = LojaService.instance;
  late final _frete = TextEditingController(
    text: numero.format(_servico.minhaLoja?.freteFixo ?? 0),
  );
  late final _minimo = TextEditingController(
    text: numero.format(_servico.minhaLoja?.pedidoMinimo ?? 0),
  );

  @override
  void dispose() {
    _frete.dispose();
    _minimo.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final frete = _frete.text.trim().isEmpty ? 0.0 : lerNumero(_frete.text);
    final minimo = _minimo.text.trim().isEmpty ? 0.0 : lerNumero(_minimo.text);
    if (frete.isNaN || frete < 0 || minimo.isNaN || minimo < 0) {
      return avisar(context, 'Confira o frete e o pedido mínimo.');
    }
    await gravar(
      () => _servico.atualizar({'frete_fixo': frete, 'pedido_minimo': minimo}),
    );
  }

  @override
  Widget build(BuildContext context) => _Formulario(
    salvando: salvando,
    onSalvar: _salvar,
    campos: [
      CampoTexto(
        rotulo: 'Frete (R\$)',
        controller: _frete,
        teclado: const TextInputType.numberWithOptions(decimal: true),
        ajuda: '0 = frete grátis',
      ),
      const SizedBox(height: Espaco.s3),
      CampoTexto(
        rotulo: 'Pedido mínimo (R\$)',
        controller: _minimo,
        teclado: const TextInputType.numberWithOptions(decimal: true),
        ajuda: '0 = sem mínimo',
      ),
    ],
  );
}

/// Chave PIX da loja. Vai para loja_pix, que só a equipe lê (quem paga vê só o PIX do pedido).
class SecaoPagamento extends StatefulWidget {
  const SecaoPagamento({super.key});

  @override
  State<SecaoPagamento> createState() => _SecaoPagamentoState();
}

class _SecaoPagamentoState extends State<SecaoPagamento> with _Gravacao {
  final _servico = LojaService.instance;
  late final _chave = TextEditingController(text: _servico.dados.chavePix);
  late final _atuais = _servico.minhaLoja?.formasPagamento ?? formasPadrao;
  late final _formas = {..._atuais};

  @override
  void dispose() {
    _chave.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final chave = normalizarChavePix(_chave.text);
    if (chave.isNotEmpty) {
      if (chavePixInvalida(chave) case final erro?) {
        return avisar(context, erro);
      }
    }
    if (_formas.isEmpty) {
      return avisar(context, 'Escolha pelo menos uma forma de pagamento.');
    }
    final mudouChave = chave != (_servico.dados.chavePix ?? '');
    final mudouFormas =
        _formas.length != _atuais.length || !_atuais.every(_formas.contains);
    if (!mudouChave && !mudouFormas) return avisar(context, 'Nada mudou.');
    await gravar(() async {
      if (mudouFormas) {
        await _servico.atualizar({
          'formas_pagamento': [
            for (final f in FormaPagamento.values)
              if (_formas.contains(f)) f.codigo,
          ],
        });
      }
      if (mudouChave) {
        await _servico.salvarChavePix(chave.isEmpty ? null : chave);
      }
    });
  }

  @override
  Widget build(BuildContext context) => _Formulario(
    salvando: salvando,
    onSalvar: _salvar,
    rodape: const _PixAutomatico(),
    campos: [
      CampoTexto(
        key: const ValueKey('chave-pix'),
        rotulo: 'Chave PIX',
        controller: _chave,
        maxLength: 77,
        ajuda: 'CPF, CNPJ, e-mail, celular com +55 ou chave aleatória',
      ),
      const SizedBox(height: Espaco.s4),
      Text(
        'Formas que a loja recebe',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: Espaco.s2),
      Wrap(
        spacing: Espaco.s2,
        runSpacing: Espaco.s2,
        children: [
          for (final f in FormaPagamento.values)
            FilterChip(
              key: ValueKey('recebe-${f.codigo}'),
              label: Text(f.rotulo),
              selected: _formas.contains(f),
              onSelected: (marcada) =>
                  setState(() => marcada ? _formas.add(f) : _formas.remove(f)),
            ),
        ],
      ),
    ],
  );
}

/// Liga a loja ao Asaas: pedido pago por PIX confirma sozinho e o valor cai na conta da loja lá.
class _PixAutomatico extends StatefulWidget {
  const _PixAutomatico();

  @override
  State<_PixAutomatico> createState() => _PixAutomaticoState();
}

class _PixAutomaticoState extends State<_PixAutomatico> with _Gravacao {
  final _servico = LojaService.instance;
  final _chave = TextEditingController();

  @override
  void dispose() {
    _chave.dispose();
    super.dispose();
  }

  Future<void> _ligar() async {
    final chave = _chave.text.trim();
    if (chave.isEmpty) return avisar(context, 'Cole a chave de API do Asaas.');
    await gravar(() => _servico.ligarPixAutomatico(chave));
    if (mounted) _chave.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return ListenableBuilder(
      listenable: _servico,
      builder: (context, _) {
        final ligado = _servico.dados.carteiraAsaas != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('PIX automático', style: t.titleSmall),
            const SizedBox(height: Espaco.s1),
            Text(
              ligado
                  ? 'Ligado. Pedido pago por PIX confirma sozinho e o valor cai na sua conta Asaas, já sem a tarifa.'
                  : 'Com uma conta no Asaas, o pedido pago por PIX confirma sozinho e o valor cai lá, já sem a tarifa.',
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
            const SizedBox(height: Espaco.s3),
            if (ligado)
              OutlinedButton(
                onPressed: salvando
                    ? null
                    : () => gravar(_servico.desligarPixAutomatico),
                child: const Text('Desligar PIX automático'),
              )
            else ...[
              CampoTexto(
                key: const ValueKey('asaas-chave'),
                rotulo: 'Chave de API do Asaas',
                controller: _chave,
                senha: true,
                ajuda: 'No Asaas: Integrações, Chaves de API. Usamos uma vez para achar sua carteira e não guardamos.',
              ),
              const SizedBox(height: Espaco.s3),
              OutlinedButton(
                onPressed: salvando ? null : _ligar,
                child: Text(salvando ? 'Ligando…' : 'Ligar PIX automático'),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Até quantas vezes a loja parcela no cartão e no boleto, sem juros. O construtor vê o valor da parcela na cotação.
class SecaoParcelamento extends StatefulWidget {
  const SecaoParcelamento({super.key});

  @override
  State<SecaoParcelamento> createState() => _SecaoParcelamentoState();
}

class _SecaoParcelamentoState extends State<SecaoParcelamento> with _Gravacao {
  final _servico = LojaService.instance;
  late int _cartao = _servico.minhaLoja?.parcelasCartao ?? 1;
  late int _boleto = _servico.minhaLoja?.parcelasBoleto ?? 1;

  Future<void> _salvar() async {
    final loja = _servico.minhaLoja;
    if (_cartao == (loja?.parcelasCartao ?? 1) &&
        _boleto == (loja?.parcelasBoleto ?? 1)) {
      return avisar(context, 'Nada mudou.');
    }
    await gravar(
      () => _servico.atualizar({
        'parcelas_cartao': _cartao,
        'parcelas_boleto': _boleto,
      }),
    );
  }

  Widget _vezes(
    String chave,
    String rotulo,
    int valor,
    ValueChanged<int> mudou,
  ) => DropdownButtonFormField<int>(
    key: ValueKey(chave),
    initialValue: valor,
    isExpanded: true,
    decoration: InputDecoration(labelText: rotulo),
    items: [
      for (var n = 1; n <= 12; n++)
        DropdownMenuItem(
          value: n,
          child: Text(n == 1 ? 'À vista' : 'Em até ${n}x sem juros'),
        ),
    ],
    onChanged: (n) {
      if (n != null) setState(() => mudou(n));
    },
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final formas = _servico.minhaLoja?.formasPagamento ?? formasPadrao;
    final semForma = [
      for (final f in [FormaPagamento.cartao, FormaPagamento.boleto])
        if (!formas.contains(f)) f.rotulo,
    ];
    return _Formulario(
      salvando: salvando,
      onSalvar: _salvar,
      campos: [
        Text(
          'O construtor escolhe em quantas vezes paga, até o limite que você definir. O valor de cada parcela aparece na cotação.',
          style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
        ),
        const SizedBox(height: Espaco.s4),
        _vezes(
          'parcelas-cartao',
          'Cartão na loja',
          _cartao,
          (n) => _cartao = n,
        ),
        const SizedBox(height: Espaco.s3),
        _vezes('parcelas-boleto', 'Boleto', _boleto, (n) => _boleto = n),
        if (semForma.isNotEmpty) ...[
          const SizedBox(height: Espaco.s3),
          Aviso(
            'Marque ${semForma.join(' e ')} em Recebimento para o parcelamento aparecer.',
            tom: TomSelo.info,
          ),
        ],
      ],
    );
  }
}

/// Duplicata depende da análise de crédito da loja: só aparece para o cliente que a loja liberar, no prazo escolhido.
class SecaoDuplicata extends StatefulWidget {
  const SecaoDuplicata({super.key});

  @override
  State<SecaoDuplicata> createState() => _SecaoDuplicataState();
}

class _SecaoDuplicataState extends State<SecaoDuplicata> with _Gravacao {
  final _servico = LojaService.instance;
  final _clientes = ClientesService.instance;

  @override
  void initState() {
    super.initState();
    if (!_clientes.carregado) _clientes.carregar();
  }

  String _nome(String construtorId) {
    for (final c in _clientes.lista) {
      if (c.construtorId == construtorId) return c.exibicao;
    }
    return 'Cliente';
  }

  Future<void> _liberar() async {
    final liberados = {for (final d in _servico.duplicatas) d.construtorId};
    final candidatos = [
      for (final c in _clientes.lista)
        if (!liberados.contains(c.construtorId)) c,
    ];
    if (candidatos.isEmpty) {
      return avisar(
        context,
        'Nenhum cliente para liberar. Quem já pediu orçamento à loja aparece aqui.',
      );
    }
    final escolha = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _DialogoDuplicata(clientes: candidatos),
    );
    if (escolha == null) return;
    await gravar(() => _servico.liberarDuplicata(escolha.$1, escolha.$2));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return ListenableBuilder(
      listenable: Listenable.merge([_servico, _clientes]),
      builder: (context, _) {
        final gere = _servico.meuPapel.gere;
        final formas = _servico.minhaLoja?.formasPagamento ?? formasPadrao;
        final duplicatas = _servico.duplicatas;
        return ListView(
          padding: const EdgeInsets.all(Espaco.s4),
          children: [
            Text(
              'A duplicata só aparece para o cliente que você liberar, depois de analisar o crédito dele.',
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
            if (!formas.contains(FormaPagamento.duplicata)) ...[
              const SizedBox(height: Espaco.s3),
              const Aviso(
                'Marque Duplicata em Recebimento para ela aparecer aos clientes liberados.',
                tom: TomSelo.info,
              ),
            ],
            if (gere) ...[
              const SizedBox(height: Espaco.s4),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('liberar-duplicata'),
                  onPressed: salvando ? null : _liberar,
                  icon: const Icon(Icons.add),
                  label: const Text('Liberar para um cliente'),
                ),
              ),
            ],
            const SizedBox(height: Espaco.s4),
            if (duplicatas.isEmpty)
              const EstadoVazio(
                icone: Icons.request_page_outlined,
                titulo: 'Nenhum cliente com duplicata',
                texto: 'Libere depois de analisar o crédito do cliente.',
              )
            else
              Painel(
                titulo: 'Clientes liberados',
                child: Column(
                  children: [
                    for (final d in duplicatas)
                      ListTile(
                        title: Text(_nome(d.construtorId)),
                        subtitle: Text('Prazo de ${d.prazo} dias'),
                        trailing: gere
                            ? TextButton(
                                onPressed: salvando
                                    ? null
                                    : () => gravar(
                                        () => _servico.retirarDuplicata(
                                          d.construtorId,
                                        ),
                                      ),
                                child: const Text('Retirar'),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DialogoDuplicata extends StatefulWidget {
  const _DialogoDuplicata({required this.clientes});
  final List<ClienteLoja> clientes;

  @override
  State<_DialogoDuplicata> createState() => _DialogoDuplicataState();
}

class _DialogoDuplicataState extends State<_DialogoDuplicata> {
  late String _cliente = widget.clientes.first.construtorId;
  String _prazo = prazosCrediario.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Liberar duplicata'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('duplicata-cliente'),
          initialValue: _cliente,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Cliente'),
          items: [
            for (final c in widget.clientes)
              DropdownMenuItem(value: c.construtorId, child: Text(c.exibicao)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _cliente = v);
          },
        ),
        const SizedBox(height: Espaco.s3),
        DropdownButtonFormField<String>(
          key: const ValueKey('duplicata-prazo'),
          initialValue: _prazo,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Prazo'),
          items: [
            for (final p in prazosCrediario)
              DropdownMenuItem(value: p, child: Text('$p dias')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _prazo = v);
          },
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (_cliente, _prazo)),
        child: const Text('Liberar'),
      ),
    ],
  );
}

class SecaoAparencia extends StatelessWidget {
  const SecaoAparencia({super.key, required this.tema});
  final PreferenciaTema tema;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(Espaco.s4),
    children: [
      ValueListenableBuilder<ThemeMode>(
        valueListenable: tema,
        builder: (context, modo, _) => Segmentado<ThemeMode>(
          valor: modo,
          opcoes: const [
            (ThemeMode.system, 'Sistema'),
            (ThemeMode.light, 'Claro'),
            (ThemeMode.dark, 'Escuro'),
          ],
          onChanged: tema.definir,
        ),
      ),
    ],
  );
}

class SecaoConta extends StatelessWidget {
  const SecaoConta({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return ListView(
      padding: const EdgeInsets.all(Espaco.s4),
      children: [
        Painel(
          child: ListTile(
            leading: Icon(Icons.logout, color: c.erro),
            title: Text('Sair da conta', style: TextStyle(color: c.erro)),
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
