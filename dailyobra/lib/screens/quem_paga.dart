import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/clientes_service.dart' show ClienteDoConstrutor;
import 'componentes.dart';
import 'qr_do_pix.dart';

typedef _Link = ({String codigo, String nome, String whatsapp});

const _documentoInvalido = 'CPF ou CNPJ inválido. Confira os números.';

/// "Quem paga este pedido?": o próprio construtor (nota no CPF/CNPJ dele e PIX da loja aqui)
/// ou o cliente, por um link enviado pelo WhatsApp do construtor.
class QuemPaga extends StatefulWidget {
  const QuemPaga({
    super.key,
    required this.pedido,
    required this.nomeLoja,
    required this.nomeTitular,
    required this.documentoDoPerfil,
    required this.saldoDisponivel,
    required this.saldoNoPedido,
    required this.pix,
    required this.pagarEuMesmo,
    required this.usarSaldo,
    required this.escolherPagamento,
    required this.criarLink,
    required this.abrirLink,
    required this.abrirBanco,
    this.formas = formasPadrao,
    this.formaSugerida,
    this.parcelasCartao = 1,
    this.parcelasBoleto = 1,
    this.prazoDuplicata,
    this.escolherParcelas,
    this.clientes = const [],
    this.salvarCliente,
  });
  final PedidoResumo pedido;
  final String nomeLoja;

  /// Nome do perfil do construtor: vai na nota quando ele mesmo paga.
  final String nomeTitular;
  final String? documentoDoPerfil;

  /// Saldo da carteira livre e o que já está abatido neste pedido.
  final double saldoDisponivel;
  final double saldoNoPedido;

  /// PIX copia e cola da loja para este pedido; nulo quando a loja não tem chave PIX.
  final Future<PixDoPedido?> Function() pix;
  final Future<void> Function(String documento) pagarEuMesmo;
  final Future<void> Function(bool usar) usarSaldo;
  final Future<void> Function(FormaPagamento forma, String? prazo)
  escolherPagamento;

  /// Cria (ou troca) o link de pagamento e devolve o código. Documento nulo: o cliente informa na página.
  final Future<String> Function(String nome, String whatsapp, String? documento)
  criarLink;
  final Future<void> Function(Uri) abrirLink;

  /// Tenta abrir o app do banco com o PIX pronto.
  final Future<void> Function(Uri) abrirBanco;

  /// Como a loja recebe.
  final List<FormaPagamento> formas;

  /// A forma escolhida na cotação.
  final FormaPagamento? formaSugerida;

  /// Até quantas vezes a loja parcela no cartão e no boleto.
  final int parcelasCartao;
  final int parcelasBoleto;

  /// Prazo da duplicata que a loja liberou para este construtor.
  final String? prazoDuplicata;

  /// Clientes já cadastrados pelo construtor, para enviar o link sem digitar de novo.
  final List<ClienteDoConstrutor> clientes;

  /// Guarda no cadastro o cliente novo que recebeu o link, quando tem CPF ou CNPJ.
  final Future<void> Function(String nome, String whatsapp, String documento)?
  salvarCliente;

  /// Troca as parcelas no cartão ou no boleto; sem ela, a tela não mostra a escolha.
  final Future<void> Function(FormaPagamento forma, int parcelas)?
  escolherParcelas;

  @override
  State<QuemPaga> createState() => _QuemPagaState();
}

class _QuemPagaState extends State<QuemPaga> {
  late Future<PixDoPedido?> _pix = widget.pix();
  late Pagador? _escolha = widget.pedido.pagador;
  late final _documento = TextEditingController(
    text: widget.documentoDoPerfil ?? '',
  );
  final _nome = TextEditingController();
  final _whatsapp = TextEditingController();
  final _documentoCliente = TextEditingController();
  String? _erroDocumento;
  String? _erroCliente;
  String? _erroDocumentoCliente;
  bool _ocupado = false;
  bool _documentoConfirmado = false;
  bool _alterandoTitular = false;
  bool _formaGravada = false;

  /// Sem forma gravada vem a da cotação ou a primeira da loja; só grava quando a tela de pagar aparece.
  late FormaPagamento _forma =
      widget.pedido.formaPagamento ??
      (widget.formas.contains(widget.formaSugerida)
          ? widget.formaSugerida!
          : widget.formas.first);
  late String _prazo = widget.pedido.prazo ?? prazosCrediario.first;

  /// Link enviado nesta tela, antes de o pedido voltar do servidor com ele.
  _Link? _enviado;
  bool _trocandoCliente = false;

  @override
  void dispose() {
    _documento.dispose();
    _nome.dispose();
    _whatsapp.dispose();
    _documentoCliente.dispose();
    super.dispose();
  }

  /// O pedido mudou no servidor (outro aparelho, o cliente ou a loja): a tela passa a seguir o que veio.
  @override
  void didUpdateWidget(QuemPaga antigo) {
    super.didUpdateWidget(antigo);
    final a = antigo.pedido;
    final p = widget.pedido;
    if (a.pagador != p.pagador || a.linkCodigo != p.linkCodigo) {
      _escolha = p.pagador ?? _escolha;
      _enviado = null;
      _trocandoCliente = false;
      _documentoConfirmado = false;
      _pix = widget.pix();
    } else if (a.total != p.total) {
      // Saldo ligado ou desligado: o PIX sai com o valor novo
      _pix = widget.pix();
    }
    if (a.formaPagamento != p.formaPagamento && p.formaPagamento != null) {
      _forma = p.formaPagamento!;
    }
  }

  bool get _proprioConfirmado =>
      _documentoConfirmado ||
      (widget.pedido.pagador == Pagador.proprio &&
          widget.pedido.documentoInformadoEm != null);

  _Link? get _link {
    if (_trocandoCliente) return null;
    if (_enviado != null) return _enviado;
    final p = widget.pedido;
    if (p.pagador != Pagador.cliente || p.linkCodigo == null) return null;
    return (
      codigo: p.linkCodigo!,
      nome: p.pagadorNome ?? '',
      whatsapp: p.pagadorWhatsapp ?? '',
    );
  }

  Future<void> _ocupar(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _confirmarDocumento() async {
    final doc = somenteDigitos(_documento.text);
    if (!documentoValido(doc)) {
      setState(() => _erroDocumento = _documentoInvalido);
      return;
    }
    setState(() => _erroDocumento = null);
    if (!await _podeTrocarParaEuPago() || !mounted) return;
    await _ocupar(() async {
      await widget.pagarEuMesmo(doc);
      if (mounted) {
        setState(() {
          _documentoConfirmado = true;
          _alterandoTitular = false;
        });
      }
    });
  }

  /// PIX e cartão gravam na hora; o crediário só depois de escolher o prazo ("Pedir prazo").
  void _escolherForma(FormaPagamento forma) {
    setState(() => _forma = forma);
    if (forma != FormaPagamento.crediario) {
      _ocupar(() => widget.escolherPagamento(forma, null));
    }
  }

  /// Com link enviado, "Eu pago" desliga o link do cliente (e o aviso de "Já paguei"): confirma antes.
  Future<bool> _podeTrocarParaEuPago() async {
    final p = widget.pedido;
    if (p.pagador != Pagador.cliente || p.linkCodigo == null) return true;
    final nome = p.pagadorNome ?? 'o cliente';
    final informou = p.pagamentoInformadoEm != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          informou ? 'O cliente já avisou que pagou' : 'Trocar para "Eu pago"?',
        ),
        content: Text(
          informou
              ? '$nome tocou em "Já paguei". Se você pagar também, a loja pode receber duas vezes. Confira com a loja antes.'
              : 'O link enviado para $nome vai parar de funcionar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Trocar para Eu pago'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _enviarLink() async {
    final nome = _nome.text.trim();
    final zap = somenteDigitos(_whatsapp.text);
    final erro = nome.length < 2
        ? 'Informe o nome do cliente.'
        : zap.length < 10 || zap.length > 13
        ? 'WhatsApp inválido. Use DDD + número.'
        : null;
    final doc = _documentoCliente.text.trim().isEmpty
        ? null
        : somenteDigitos(_documentoCliente.text);
    final erroDoc = doc == null || documentoValido(doc)
        ? null
        : _documentoInvalido;
    setState(() {
      _erroCliente = erro;
      _erroDocumentoCliente = erroDoc;
    });
    if (erro != null || erroDoc != null) return;
    await _ocupar(() async {
      final codigo = await widget.criarLink(nome, zap, doc);
      final salvar = widget.salvarCliente;
      if (doc != null && salvar != null) {
        try {
          await salvar(nome, zap, doc);
        } on Exception {
          // O link já foi; só o cadastro ficou para depois
        }
      }
      final enviado = (codigo: codigo, nome: nome, whatsapp: zap);
      if (!mounted) return;
      setState(() {
        _enviado = enviado;
        _trocandoCliente = false;
      });
      await _abrirWhatsApp(enviado);
    });
  }

  /// O link devolve o saldo abatido no "Eu pago": o cliente paga o total sem o abatimento.
  String _mensagem(String nome, String codigo) => mensagemDoLink(
    nome: nome,
    loja: widget.nomeLoja,
    total: widget.pedido.total + widget.saldoNoPedido,
    link: linkDePagamento(codigo),
  );

  Future<void> _abrirWhatsApp(_Link l) =>
      widget.abrirLink(linkWhatsApp(l.whatsapp, _mensagem(l.nome, l.codigo)));

  void _trocarCliente() => setState(() {
    _trocandoCliente = true;
    _enviado = null;
    _nome.clear();
    _whatsapp.clear();
    _documentoCliente.clear();
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return Painel(
      titulo: 'Quem paga este pedido?',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: FutureBuilder<PixDoPedido?>(
          future: _pix,
          builder: (context, snap) {
            // Ao buscar de novo, segue mostrando o PIX que já tinha
            if (snap.connectionState != ConnectionState.done && !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            // Falha de rede não é "loja sem chave PIX": avisa e deixa tentar de novo
            if (snap.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Não deu para carregar o PIX da loja.',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: Espaco.s2),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _pix = widget.pix();
                    }),
                    child: const Text('Tentar de novo'),
                  ),
                ],
              );
            }
            // Saldo DailyObra cobriu tudo: não há PIX nem link, só os dados da nota
            final semValor = widget.pedido.total <= 0;
            final pix = semValor ? null : snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Espaco.s2,
                  runSpacing: Espaco.s2,
                  children: [
                    ChoiceChip(
                      label: const Text('Eu pago'),
                      selected: _escolha == Pagador.proprio,
                      onSelected: _ocupado
                          ? null
                          : (_) => setState(() => _escolha = Pagador.proprio),
                    ),
                    ChoiceChip(
                      label: const Text('Enviar para o cliente'),
                      selected: _escolha == Pagador.cliente,
                      onSelected: pix == null || _ocupado
                          ? null
                          : (_) => setState(() => _escolha = Pagador.cliente),
                    ),
                  ],
                ),
                if (pix == null &&
                    (semValor ||
                        widget.formas.contains(FormaPagamento.pix))) ...[
                  const SizedBox(height: Espaco.s2),
                  Text(
                    semValor
                        ? 'O saldo DailyObra cobriu este pedido. Não há nada a pagar.'
                        : 'A loja ainda não cadastrou a chave PIX.',
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                ],
                if (_escolha == Pagador.proprio) ...[
                  const SizedBox(height: Espaco.s4),
                  ..._euPago(t, c, pix, semValor: semValor),
                ],
                if (_escolha == Pagador.cliente && pix != null) ...[
                  const SizedBox(height: Espaco.s4),
                  ..._cliente(t, c),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _euPago(
    TextTheme t,
    CoresDailyObra c,
    PixDoPedido? pix, {
    required bool semValor,
  }) {
    if (!_proprioConfirmado || _alterandoTitular) {
      return [
        CampoTexto(
          key: const ValueKey('documento'),
          rotulo: 'CPF ou CNPJ',
          controller: _documento,
          teclado: TextInputType.number,
          ajuda: 'A nota sai no seu nome.',
          erro: _erroDocumento,
        ),
        const SizedBox(height: Espaco.s3),
        FilledButton(
          onPressed: _ocupado ? null : _confirmarDocumento,
          child: const Text('Confirmar'),
        ),
      ];
    }
    final doc = somenteDigitos(_documento.text);
    final saldoTotal = widget.saldoDisponivel + widget.saldoNoPedido;
    final saldoLigado = widget.saldoNoPedido > 0;
    return [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nota no nome de ${widget.nomeTitular}',
                  style: t.titleSmall,
                ),
                if (doc.isNotEmpty)
                  Text(
                    formatarDocumento(doc),
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _ocupado
                ? null
                : () => setState(() => _alterandoTitular = true),
            child: const Text('Alterar'),
          ),
        ],
      ),
      if (saldoTotal > 0)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Usar saldo da carteira (${brl.format(saldoTotal)})'),
          subtitle: saldoLigado
              ? Text('Abate ${brl.format(widget.saldoNoPedido)} neste pedido.')
              : null,
          value: saldoLigado,
          onChanged: _ocupado
              ? null
              : (usar) => _ocupar(() => widget.usarSaldo(usar)),
        ),
      const SizedBox(height: Espaco.s3),
      if (semValor)
        Text('A nota sai no seu nome.', style: t.bodyMedium)
      else ...[
        Text('Forma de pagamento', style: t.titleSmall),
        const SizedBox(height: Espaco.s2),
        Wrap(
          spacing: Espaco.s2,
          runSpacing: Espaco.s2,
          children: [
            for (final f in widget.formas)
              ChoiceChip(
                label: Text(f.rotulo),
                selected: _forma == f,
                onSelected: _ocupado ? null : (_) => _escolherForma(f),
              ),
          ],
        ),
        const SizedBox(height: Espaco.s3),
        ...switch (_forma) {
          FormaPagamento.pix => _pagarComPix(t, c, pix),
          FormaPagamento.cartao => _pagarNaLoja(
            t,
            'Pague na maquininha da loja na entrega ou retirada.',
            maximo: widget.parcelasCartao,
          ),
          FormaPagamento.boleto => _pagarNaLoja(
            t,
            'A loja envia o boleto depois de confirmar o pedido.',
            maximo: widget.parcelasBoleto,
          ),
          FormaPagamento.duplicata => _pagarNaLoja(
            t,
            widget.pedido.formaPagamento == FormaPagamento.duplicata &&
                    widget.pedido.prazo != null
                ? 'Duplicata liberada pela loja, em ${widget.pedido.prazo} dias. Nada a pagar agora.'
                : widget.prazoDuplicata == null
                ? 'A loja ainda não liberou duplicata para você.'
                : 'Duplicata liberada pela loja, em ${widget.prazoDuplicata} dias. Nada a pagar agora.',
          ),
          FormaPagamento.dinheiro => _pagarNaLoja(
            t,
            'Pague em dinheiro na entrega ou retirada.',
          ),
          FormaPagamento.crediario => _crediario(t),
        },
        const SizedBox(height: Espaco.s3),
        Row(
          children: [
            Expanded(child: Text('Total a pagar', style: t.titleSmall)),
            Text(brl.format(widget.pedido.total), style: t.titleSmall),
          ],
        ),
      ],
    ];
  }

  List<Widget> _crediario(TextTheme t) {
    final p = widget.pedido;
    final pedido = p.formaPagamento == FormaPagamento.crediario;
    final texto = switch (pedido ? p.prazoStatus : null) {
      StatusPrazo.pendente => 'Aguardando a loja aprovar o prazo.',
      StatusPrazo.aprovado => 'Prazo aprovado: ${p.prazo} dias.',
      StatusPrazo.recusado => 'A loja recusou o prazo. Escolha PIX ou cartão.',
      null => null,
    };
    if (texto != null) return [Text(texto, style: t.bodyMedium)];
    return [
      Wrap(
        spacing: Espaco.s2,
        runSpacing: Espaco.s2,
        children: [
          for (final prazo in prazosCrediario)
            ChoiceChip(
              label: Text('$prazo dias'),
              selected: _prazo == prazo,
              onSelected: _ocupado
                  ? null
                  : (_) => setState(() => _prazo = prazo),
            ),
        ],
      ),
      const SizedBox(height: Espaco.s3),
      FilledButton(
        onPressed: _ocupado
            ? null
            : () => _ocupar(
                () =>
                    widget.escolherPagamento(FormaPagamento.crediario, _prazo),
              ),
        child: const Text('Pedir prazo'),
      ),
    ];
  }

  List<Widget> _pagarNaLoja(TextTheme t, String texto, {int maximo = 1}) {
    _gravarFormaMarcada();
    final escolher = widget.escolherParcelas;
    final total = widget.pedido.total;
    final forma = _forma;
    return [
      Text(texto, style: t.bodyMedium),
      if (maximo > 1 && escolher != null) ...[
        const SizedBox(height: Espaco.s3),
        DropdownButtonFormField<int>(
          key: Key('parcelas-${forma.codigo}'),
          initialValue:
              (widget.pedido.formaPagamento == forma
                      ? widget.pedido.parcelas ?? 1
                      : 1)
                  .clamp(1, maximo),
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Parcelas'),
          items: [
            for (var n = 1; n <= maximo; n++)
              DropdownMenuItem(
                value: n,
                child: Text(
                  n == 1
                      ? 'À vista, ${brl.format(total)}'
                      : '${n}x de ${brl.format(valorDaParcela(total, n))} sem juros',
                ),
              ),
          ],
          onChanged: _ocupado
              ? null
              : (n) {
                  if (n != null) _ocupar(() => escolher(forma, n));
                },
        ),
      ],
    ];
  }

  /// Com a tela de pagar aberta a forma marcada vale: a loja passa a ver no pedido.
  void _gravarFormaMarcada() {
    final p = widget.pedido;
    final forma = _forma;
    if (_formaGravada ||
        p.formaPagamento != null ||
        p.pagamentoConfirmadoEm != null ||
        p.pagamentoInformadoEm != null) {
      return;
    }
    _formaGravada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.escolherPagamento(forma, null);
      } on Exception {
        // Só falta a forma no pedido: o pagamento segue igual
      }
    });
  }

  /// O código vai copiado antes: se nenhum banco abrir o link, é só colar no Pix do app.
  Future<void> _abrirNoBanco(String pix) async {
    await Clipboard.setData(ClipboardData(text: pix));
    if (!mounted) return;
    avisar(context, 'PIX copiado. Se o banco não abrir, cole no Pix do app.');
    await widget.abrirBanco(linkDoPix(pix));
  }

  List<Widget> _pagarComPix(TextTheme t, CoresDailyObra c, PixDoPedido? dados) {
    if (dados == null) {
      return [Text('Combine o pagamento com a loja.', style: t.bodyMedium)];
    }
    final pix = dados.codigo;
    _gravarFormaMarcada();
    return [
      Text('PIX da loja', style: t.titleSmall),
      const SizedBox(height: Espaco.s3),
      Center(child: QrDoPix(codigo: pix)),
      const SizedBox(height: Espaco.s3),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => _abrirNoBanco(pix),
          child: const Text('Abrir no app do banco'),
        ),
      ),
      const SizedBox(height: Espaco.s2),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: pix));
            if (mounted) avisar(context, 'PIX copiado');
          },
          child: const Text('Copiar'),
        ),
      ),
      const SizedBox(height: Espaco.s3),
      Text('Código copia e cola', style: t.labelMedium),
      const SizedBox(height: Espaco.s1),
      SelectableText(pix, style: t.bodySmall),
      const SizedBox(height: Espaco.s2),
      Text(
        dados.automatico
            ? 'Pague pelo app do seu banco. O pedido confirma sozinho quando o pagamento cair.'
            : 'Pague pelo app do seu banco. A loja confirma aqui quando receber.',
        style: t.bodySmall?.copyWith(color: c.textoSuave),
      ),
    ];
  }

  List<Widget> _cliente(TextTheme t, CoresDailyObra c) {
    final l = _link;
    if (l == null) {
      return [
        if (widget.clientes.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            key: const ValueKey('cliente-cadastrado'),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cliente cadastrado'),
            items: [
              for (final cliente in widget.clientes)
                DropdownMenuItem(
                  value: cliente.id,
                  child: Text(cliente.nome, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              for (final cliente in widget.clientes) {
                if (cliente.id != id) continue;
                setState(() {
                  _nome.text = cliente.nome;
                  _whatsapp.text = cliente.whatsapp;
                  _documentoCliente.text = formatarDocumento(cliente.documento);
                });
              }
            },
          ),
          const SizedBox(height: Espaco.s3),
        ],
        CampoTexto(
          key: const ValueKey('cliente-nome'),
          rotulo: 'Nome do cliente',
          controller: _nome,
          autofill: const [AutofillHints.name],
        ),
        const SizedBox(height: Espaco.s3),
        CampoTexto(
          key: const ValueKey('cliente-whatsapp'),
          rotulo: 'WhatsApp do cliente',
          controller: _whatsapp,
          teclado: TextInputType.phone,
          dica: '(66) 99999-0000',
          erro: _erroCliente,
        ),
        const SizedBox(height: Espaco.s3),
        CampoTexto(
          key: const ValueKey('cliente-documento'),
          rotulo: 'CPF ou CNPJ do cliente (opcional)',
          controller: _documentoCliente,
          teclado: TextInputType.number,
          erro: _erroDocumentoCliente,
        ),
        const SizedBox(height: Espaco.s3),
        // O código do link só existe depois do envio
        ValueListenableBuilder(
          valueListenable: _nome,
          builder: (context, nome, _) => Container(
            padding: const EdgeInsets.all(Espaco.s3),
            decoration: BoxDecoration(
              color: c.superficieSutil,
              borderRadius: BorderRadius.circular(Raio.md),
              border: Border.all(color: c.borda),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mensagem que vai no WhatsApp', style: t.titleSmall),
                const SizedBox(height: Espaco.s2),
                Text(
                  _mensagem(
                    nome.text.trim().isEmpty ? 'cliente' : nome.text.trim(),
                    '…',
                  ),
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.s3),
        FilledButton(
          onPressed: _ocupado ? null : _enviarLink,
          child: const Text('Enviar pelo WhatsApp'),
        ),
        const SizedBox(height: Espaco.s2),
        Text(
          'O cliente confere os materiais, informa o CPF ou CNPJ e paga por PIX direto à loja.',
          style: t.bodySmall?.copyWith(color: c.textoSuave),
        ),
      ];
    }
    final situacao =
        _enviado != null && widget.pedido.linkCodigo != _enviado!.codigo
        ? SituacaoPagamento.aguardandoDados
        : widget.pedido.situacaoPagamento;
    return [
      Text('Link para ${l.nome}', style: t.titleSmall),
      const SizedBox(height: Espaco.s1),
      Text(switch (situacao) {
        SituacaoPagamento.aguardandoPagamento =>
          'Aguardando o pagamento do cliente.',
        SituacaoPagamento.informado =>
          'O cliente avisou que pagou. A loja vai conferir.',
        _ => 'Link enviado. Aguardando o cliente informar os dados.',
      }, style: t.bodyMedium),
      const SizedBox(height: Espaco.s3),
      Wrap(
        spacing: Espaco.s2,
        runSpacing: Espaco.s2,
        children: [
          OutlinedButton(
            onPressed: _ocupado ? null : () => _abrirWhatsApp(l),
            child: const Text('Reenviar link'),
          ),
          TextButton(
            onPressed: _ocupado ? null : _trocarCliente,
            child: const Text('Trocar cliente'),
          ),
        ],
      ),
    ];
  }
}
