import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cep_service.dart';

/// CEP como 00000-000 enquanto a loja digita (só números, até 8).
class _MascaraCep extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    final texto = _comTraco(novo.text.replaceAll(RegExp(r'\D'), ''));
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

String _comTraco(String digitos) {
  final d = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
  return d.length > 5 ? '${d.substring(0, 5)}-${d.substring(5)}' : d;
}

String? _ouNulo(TextEditingController c) =>
    c.text.trim().isEmpty ? null : c.text.trim();

/// Os campos do endereço da loja e o que vai para o banco (o banco monta o texto que o construtor vê).
class ControleEndereco {
  ControleEndereco({
    String? cep,
    String logradouro = '',
    String numero = '',
    String complemento = '',
    String bairro = '',
    String cidade = '',
    this.uf,
    String outrasUnidades = '',
  }) : cep = TextEditingController(text: _comTraco(cep ?? '')),
       logradouro = TextEditingController(text: logradouro),
       numero = TextEditingController(text: numero),
       complemento = TextEditingController(text: complemento),
       bairro = TextEditingController(text: bairro),
       cidade = TextEditingController(text: cidade),
       outrasUnidades = TextEditingController(text: outrasUnidades) {
    _salvo = _foto();
  }

  final TextEditingController cep;
  final TextEditingController logradouro;
  final TextEditingController numero;
  final TextEditingController complemento;
  final TextEditingController bairro;
  final TextEditingController cidade;
  final TextEditingController outrasUnidades;
  String? uf;

  /// Põe nos campos o endereço salvo (Minha loja, ao abrir e depois de salvar).
  void preencher({
    String? cep,
    String logradouro = '',
    String numero = '',
    String complemento = '',
    String bairro = '',
    String cidade = '',
    String? uf,
    String outrasUnidades = '',
  }) {
    this.cep.text = _comTraco(cep ?? '');
    this.logradouro.text = logradouro;
    this.numero.text = numero;
    this.complemento.text = complemento;
    this.bairro.text = bairro;
    this.cidade.text = cidade;
    this.uf = uf;
    this.outrasUnidades.text = outrasUnidades;
    _salvo = _foto();
  }

  /// Os campos como vieram (do construtor ou do último [preencher]).
  late String _salvo;

  String _foto() => [
    cep.text,
    logradouro.text,
    numero.text,
    complemento.text,
    bairro.text,
    cidade.text,
    uf ?? '',
    outrasUnidades.text,
  ].join('\u0000');

  String get _digitos => cep.text.replaceAll(RegExp(r'\D'), '');

  /// A loja começou a informar o endereço pelo CEP.
  bool get preenchido => _digitos.isNotEmpty;

  /// A loja mexeu em algum campo do endereço desde que ele foi preenchido.
  bool get alterado => _foto() != _salvo;

  Map<String, String> validar() => {
    if (_digitos.length != 8) 'cep': 'Informe o CEP com 8 números.',
    if (logradouro.text.trim().isEmpty) 'logradouro': 'Informe a rua.',
    if (numero.text.trim().isEmpty) 'numero': 'Informe o número (ou S/N).',
    if (cidade.text.trim().length < 2) 'cidade': 'Informe a cidade.',
    if (uf == null) 'uf': 'Escolha o estado.',
  };

  Map<String, dynamic> campos() => {
    'cep': _digitos,
    'logradouro': logradouro.text.trim(),
    'numero': numero.text.trim(),
    'complemento': _ouNulo(complemento),
    'bairro': _ouNulo(bairro),
    'cidade': cidade.text.trim(),
    'uf': uf,
    'outras_unidades': _ouNulo(outrasUnidades),
  };

  void dispose() {
    for (final c in [
      cep,
      logradouro,
      numero,
      complemento,
      bairro,
      cidade,
      outrasUnidades,
    ]) {
      c.dispose();
    }
  }
}

/// Endereço da loja: com 8 números no CEP, busca no ViaCEP e preenche rua, bairro, cidade e UF (todos editáveis).
class CamposEndereco extends StatefulWidget {
  const CamposEndereco({
    super.key,
    required this.controle,
    this.erros = const {},
    this.buscar,
  });
  final ControleEndereco controle;

  /// Mensagens de [ControleEndereco.validar], por campo.
  final Map<String, String> erros;

  /// Busca do CEP (nos testes, uma falsa); no app, o ViaCEP.
  final BuscarCep? buscar;

  @override
  State<CamposEndereco> createState() => _CamposEnderecoState();
}

class _CamposEnderecoState extends State<CamposEndereco> {
  final _numero = FocusNode();
  int _pedido = 0;
  bool _buscando = false;
  String? _aviso;

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  /// A resposta de um CEP que a loja já trocou é descartada.
  Future<void> _cepMudou(String texto) async {
    final cep = texto.replaceAll(RegExp(r'\D'), '');
    final meu = ++_pedido;
    if (cep.length != 8) {
      if (_buscando || _aviso != null) {
        setState(() {
          _buscando = false;
          _aviso = null;
        });
      }
      return;
    }
    setState(() {
      _buscando = true;
      _aviso = null;
    });
    try {
      final achado = await (widget.buscar ?? buscarCep)(cep);
      if (!mounted || meu != _pedido) return;
      final c = widget.controle;
      setState(() {
        _buscando = false;
        if (achado == null) {
          _aviso = 'CEP não encontrado.';
        } else {
          c.logradouro.text = achado.logradouro;
          c.bairro.text = achado.bairro;
          c.cidade.text = achado.cidade;
          if (ufs.contains(achado.uf)) c.uf = achado.uf;
        }
      });
      if (achado != null) _numero.requestFocus();
    } on FalhaComMensagem catch (f) {
      if (!mounted || meu != _pedido) return;
      setState(() {
        _buscando = false;
        _aviso = f.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controle;
    final erros = widget.erros;
    final t = Theme.of(context).textTheme;
    final cores = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          key: const Key('endereco-cep'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Rotulo('CEP', obrigatorio: true),
            TextField(
              controller: c.cep,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [_MascaraCep()],
              onChanged: _cepMudou,
              decoration: InputDecoration(
                hintText: '00000-000',
                errorText: erros['cep'],
              ),
            ),
          ],
        ),
        if (_buscando || _aviso != null)
          Padding(
            padding: const EdgeInsets.only(top: Espaco.s1),
            child: Text(
              _buscando ? 'Buscando o CEP…' : _aviso!,
              style: t.bodySmall?.copyWith(
                color: _buscando ? cores.textoSuave : cores.aviso,
              ),
            ),
          ),
        const SizedBox(height: Espaco.s3),
        CampoTexto(
          key: const Key('endereco-rua'),
          rotulo: 'Rua',
          controller: c.logradouro,
          obrigatorio: true,
          erro: erros['logradouro'],
          maxLength: 120,
          acao: TextInputAction.next,
        ),
        const SizedBox(height: Espaco.s3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Column(
                key: const Key('endereco-numero'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Rotulo('Número', obrigatorio: true),
                  TextField(
                    controller: c.numero,
                    focusNode: _numero,
                    maxLength: 20,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      errorText: erros['numero'],
                      errorMaxLines: 3,
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espaco.s3),
            Expanded(
              child: CampoTexto(
                key: const Key('endereco-complemento'),
                rotulo: 'Complemento',
                controller: c.complemento,
                maxLength: 60,
                acao: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: Espaco.s3),
        CampoTexto(
          key: const Key('endereco-bairro'),
          rotulo: 'Bairro',
          controller: c.bairro,
          maxLength: 80,
          acao: TextInputAction.next,
        ),
        const SizedBox(height: Espaco.s3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CampoTexto(
                key: const Key('endereco-cidade'),
                rotulo: 'Cidade',
                controller: c.cidade,
                obrigatorio: true,
                erro: erros['cidade'],
                acao: TextInputAction.next,
              ),
            ),
            const SizedBox(width: Espaco.s3),
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Rotulo('UF', obrigatorio: true),
                  DropdownButtonFormField<String>(
                    // A chave muda com a UF para o campo mostrar a que veio do CEP
                    key: ValueKey('uf-${c.uf}'),
                    initialValue: c.uf,
                    isExpanded: true,
                    hint: const Text('UF'),
                    decoration: InputDecoration(
                      errorText: erros['uf'],
                      errorMaxLines: 2,
                    ),
                    items: [
                      for (final u in ufs)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (u) => setState(() => c.uf = u),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Espaco.s3),
        CampoTexto(
          key: const Key('endereco-outras'),
          rotulo: 'Outras unidades',
          controller: c.outrasUnidades,
          maxLength: 200,
          ajuda: 'Outras lojas da rede, por exemplo: Sagrada Família e Médici',
        ),
      ],
    );
  }
}
