import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'componentes.dart';

typedef _Link = ({String codigo, String nome, String whatsapp});

/// "Quem paga este pedido?": o próprio construtor (nota no CPF/CNPJ dele e PIX da loja aqui)
/// ou o cliente, por um link enviado pelo WhatsApp do construtor.
class QuemPaga extends StatefulWidget {
  const QuemPaga({
    super.key,
    required this.pedido,
    required this.nomeLoja,
    required this.documentoDoPerfil,
    required this.pix,
    required this.pagarEuMesmo,
    required this.criarLink,
    required this.abrirLink,
  });
  final PedidoResumo pedido;
  final String nomeLoja;
  final String? documentoDoPerfil;

  /// PIX copia e cola da loja para este pedido; nulo quando a loja não tem chave PIX.
  final Future<String?> Function() pix;
  final Future<void> Function(String documento) pagarEuMesmo;

  /// Cria (ou troca) o link de pagamento e devolve o código.
  final Future<String> Function(String nome, String whatsapp) criarLink;
  final Future<void> Function(Uri) abrirLink;

  @override
  State<QuemPaga> createState() => _QuemPagaState();
}

class _QuemPagaState extends State<QuemPaga> {
  late final Future<String?> _pix = widget.pix();
  late Pagador? _escolha = widget.pedido.pagador;
  late final _documento = TextEditingController(
    text: widget.documentoDoPerfil ?? '',
  );
  final _nome = TextEditingController();
  final _whatsapp = TextEditingController();
  String? _erroDocumento;
  String? _erroCliente;
  bool _ocupado = false;
  bool _documentoConfirmado = false;

  /// Link enviado nesta tela, antes de o pedido voltar do servidor com ele.
  _Link? _enviado;
  bool _trocandoCliente = false;

  @override
  void dispose() {
    _documento.dispose();
    _nome.dispose();
    _whatsapp.dispose();
    super.dispose();
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
      setState(
        () => _erroDocumento = 'CPF ou CNPJ inválido. Confira os números.',
      );
      return;
    }
    setState(() => _erroDocumento = null);
    await _ocupar(() async {
      await widget.pagarEuMesmo(doc);
      if (mounted) setState(() => _documentoConfirmado = true);
    });
  }

  Future<void> _enviarLink() async {
    final nome = _nome.text.trim();
    final zap = somenteDigitos(_whatsapp.text);
    final erro = nome.length < 2
        ? 'Informe o nome do cliente.'
        : zap.length < 10 || zap.length > 13
        ? 'WhatsApp inválido. Use DDD + número.'
        : null;
    setState(() => _erroCliente = erro);
    if (erro != null) return;
    await _ocupar(() async {
      final codigo = await widget.criarLink(nome, zap);
      final enviado = (codigo: codigo, nome: nome, whatsapp: zap);
      if (!mounted) return;
      setState(() {
        _enviado = enviado;
        _trocandoCliente = false;
      });
      await _abrirWhatsApp(enviado);
    });
  }

  Future<void> _abrirWhatsApp(_Link l) => widget.abrirLink(
    linkWhatsApp(
      l.whatsapp,
      mensagemDoLink(
        nome: l.nome,
        loja: widget.nomeLoja,
        total: widget.pedido.total,
        link: linkDePagamento(l.codigo),
      ),
    ),
  );

  void _trocarCliente() => setState(() {
    _trocandoCliente = true;
    _enviado = null;
    _nome.clear();
    _whatsapp.clear();
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return Painel(
      titulo: 'Quem paga este pedido?',
      child: Padding(
        padding: const EdgeInsets.all(Espaco.s4),
        child: FutureBuilder<String?>(
          future: _pix,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final pix = snap.data;
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
                if (pix == null) ...[
                  const SizedBox(height: Espaco.s2),
                  Text(
                    'A loja ainda não cadastrou a chave PIX.',
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                  ),
                ],
                if (_escolha == Pagador.proprio) ...[
                  const SizedBox(height: Espaco.s4),
                  ..._euPago(t, c, pix),
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

  List<Widget> _euPago(TextTheme t, CoresDailyObra c, String? pix) {
    if (!_proprioConfirmado) {
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
    if (pix == null) {
      return [Text('Combine o pagamento com a loja.', style: t.bodyMedium)];
    }
    return [
      Text('PIX da loja (copia e cola)', style: t.titleSmall),
      const SizedBox(height: Espaco.s2),
      SelectableText(pix, style: t.bodySmall),
      const SizedBox(height: Espaco.s2),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: pix));
            if (mounted) avisar(context, 'PIX copiado');
          },
          child: const Text('Copiar'),
        ),
      ),
      const SizedBox(height: Espaco.s2),
      Text(
        'Pague pelo app do seu banco. A loja confirma aqui quando receber.',
        style: t.bodySmall?.copyWith(color: c.textoSuave),
      ),
    ];
  }

  List<Widget> _cliente(TextTheme t, CoresDailyObra c) {
    final l = _link;
    if (l == null) {
      return [
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
