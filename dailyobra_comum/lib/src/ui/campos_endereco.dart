import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../marketplace/cep.dart';
import '../marketplace/texto.dart';
import '../obras/obra.dart';
import '../supabase/erros.dart';
import '../tema/cores.dart';
import '../tema/tema.dart';
import 'ui.dart';

String _comTraco(String digitos) {
  final d = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
  return d.length > 5 ? '${d.substring(0, 5)}-${d.substring(5)}' : d;
}

String? _ouNulo(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

/// CEP como 00000-000 enquanto digita (só números, até 8).
class MascaraCep extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final texto = _comTraco(novo.text.replaceAll(RegExp(r'\D'), ''));
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}

/// "Av. Brasil, 10, sala 2 – Centro, CEP 78700-000", pulando o que falta. Mesmo formato que o banco monta para a loja.
String enderecoEmTexto({String logradouro = '', String numero = '', String complemento = '', String bairro = '', String cep = ''}) {
  final rua = [logradouro, numero, complemento].map((p) => p.trim()).where((p) => p.isNotEmpty).join(', ');
  final d = cep.replaceAll(RegExp(r'\D'), '');
  return [
    rua,
    if (bairro.trim().isNotEmpty) '${rua.isEmpty ? '' : '– '}${bairro.trim()}',
  ].where((p) => p.isNotEmpty).join(' ') + (d.isEmpty ? '' : '${rua.isEmpty && bairro.trim().isEmpty ? '' : ', '}CEP ${_comTraco(d)}');
}

/// Os campos do endereço e o que vai para o banco.
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
  }) : cep = TextEditingController(text: _comTraco((cep ?? '').replaceAll(RegExp(r'\D'), ''))),
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

  /// Põe nos campos o endereço salvo (ao abrir a tela e depois de salvar).
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
    this.cep.text = _comTraco((cep ?? '').replaceAll(RegExp(r'\D'), ''));
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

  String _foto() => [cep.text, logradouro.text, numero.text, complemento.text, bairro.text, cidade.text, uf ?? '', outrasUnidades.text].join('\u0000');

  String get _digitos => cep.text.replaceAll(RegExp(r'\D'), '');

  /// Começou a informar o endereço pelo CEP.
  bool get preenchido => _digitos.isNotEmpty;

  /// Mexeu em algum campo do endereço desde que ele foi preenchido.
  bool get alterado => _foto() != _salvo;

  /// Endereço obrigatório, como o da loja.
  Map<String, String> validar() => {
    if (_digitos.length != 8) 'cep': 'Informe o CEP com 8 números.',
    if (logradouro.text.trim().isEmpty) 'logradouro': 'Informe a rua.',
    if (numero.text.trim().isEmpty) 'numero': 'Informe o número (ou S/N).',
    if (cidade.text.trim().length < 2) 'cidade': 'Informe a cidade.',
    if (uf == null) 'uf': 'Escolha o estado.',
  };

  /// Endereço que pode ficar em branco: confere só o que foi começado.
  Map<String, String> validarOpcional() {
    final rua = logradouro.text.trim().isNotEmpty;
    final numeroCheio = numero.text.trim().isNotEmpty;
    return {
      if (_digitos.isNotEmpty && _digitos.length != 8) 'cep': 'Informe o CEP com 8 números.',
      if (numeroCheio && !rua) 'logradouro': 'Informe a rua.',
      if (rua && !numeroCheio) 'numero': 'Informe o número (ou S/N).',
      if ((rua || numeroCheio) && cidade.text.trim().length < 2) 'cidade': 'Escolha a cidade.',
    };
  }

  /// Só as partes do endereço, sem cidade e estado, para quem guarda essas duas em outro lugar.
  Map<String, String?> partes() => {
    'cep': _digitos.isEmpty ? null : _digitos,
    'logradouro': _ouNulo(logradouro),
    'numero': _ouNulo(numero),
    'complemento': _ouNulo(complemento),
    'bairro': _ouNulo(bairro),
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
    for (final c in [cep, logradouro, numero, complemento, bairro, cidade, outrasUnidades]) {
      c.dispose();
    }
  }
}

/// Endereço completo: com 8 números no CEP, busca no ViaCEP e preenche rua, bairro, cidade e estado. Sem CEP, a cidade vem
/// da lista do IBGE, para o nome conferir com o das lojas.
class CamposEndereco extends StatefulWidget {
  const CamposEndereco({
    super.key,
    required this.controle,
    this.erros = const {},
    this.buscar,
    this.buscarCidades = cidadesDoEstado,
    this.exigeEndereco = true,
    this.exigeCidade = true,
    this.comOutrasUnidades = false,
    this.ajudaCidade,
    this.aoMudar,
  });
  final ControleEndereco controle;

  /// Mensagens de [ControleEndereco.validar], por campo.
  final Map<String, String> erros;

  /// Busca do CEP (nos testes, uma falsa); no app, o ViaCEP.
  final BuscarCep? buscar;
  final BuscarCidades buscarCidades;

  /// Marca CEP, rua e número como obrigatórios.
  final bool exigeEndereco;
  final bool exigeCidade;

  /// Campo das outras lojas da rede.
  final bool comOutrasUnidades;
  final String? ajudaCidade;

  /// Avisa de qualquer mudança nos campos.
  final VoidCallback? aoMudar;

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

  void _mudou([String? _]) => widget.aoMudar?.call();

  /// A resposta de um CEP que já foi trocado é descartada.
  Future<void> _cepMudou(String texto) async {
    _mudou();
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
          // CEP da cidade inteira vem sem rua: não apaga o que já foi escrito
          if (achado.logradouro.isNotEmpty) c.logradouro.text = achado.logradouro;
          if (achado.bairro.isNotEmpty) c.bairro.text = achado.bairro;
          c.cidade.text = achado.cidade;
          if (ufs.contains(achado.uf)) c.uf = achado.uf;
        }
      });
      if (achado != null) {
        _mudou();
        _numero.requestFocus();
      }
    } on FalhaComMensagem catch (f) {
      if (!mounted || meu != _pedido) return;
      setState(() {
        _buscando = false;
        _aviso = f.mensagem;
      });
    }
  }

  Future<void> _escolherCidade() async {
    FocusScope.of(context).unfocus();
    final escolha = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ListaDeCidades(buscar: widget.buscarCidades),
    );
    if (escolha == null || !mounted) return;
    setState(() {
      widget.controle.cidade.text = escolha.$1;
      widget.controle.uf = escolha.$2;
    });
    _mudou();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controle;
    final erros = widget.erros;
    final t = Theme.of(context).textTheme;
    final cores = context.cores;
    final cidade = c.cidade.text.trim();
    final erroCidade = erros['cidade'] ?? erros['uf'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          key: const Key('endereco-cep'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Rotulo('CEP', obrigatorio: widget.exigeEndereco),
            TextField(
              controller: c.cep,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [MascaraCep()],
              onChanged: _cepMudou,
              decoration: InputDecoration(hintText: '00000-000', errorText: erros['cep']),
            ),
          ],
        ),
        if (_buscando || _aviso != null)
          Padding(
            padding: const EdgeInsets.only(top: Espaco.s1),
            child: Text(
              _buscando ? 'Buscando o CEP…' : _aviso!,
              style: t.bodySmall?.copyWith(color: _buscando ? cores.textoSuave : cores.aviso),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _escolherCidade, child: const Text('Não sei o CEP')),
        ),
        CampoTexto(
          key: const Key('endereco-rua'),
          rotulo: 'Rua',
          controller: c.logradouro,
          obrigatorio: widget.exigeEndereco,
          erro: erros['logradouro'],
          maxLength: 120,
          acao: TextInputAction.next,
          onChanged: _mudou,
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
                  Rotulo('Número', obrigatorio: widget.exigeEndereco),
                  TextField(
                    controller: c.numero,
                    focusNode: _numero,
                    maxLength: 20,
                    textInputAction: TextInputAction.next,
                    onChanged: _mudou,
                    decoration: InputDecoration(errorText: erros['numero'], errorMaxLines: 3, counterText: ''),
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
                onChanged: _mudou,
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
          onChanged: _mudou,
        ),
        const SizedBox(height: Espaco.s3),
        Column(
          key: const Key('endereco-cidade'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rotulo('Cidade e estado', obrigatorio: widget.exigeCidade),
            OutlinedButton(
              onPressed: _escolherCidade,
              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: Espaco.s3)),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, size: 20, color: cores.textoSuave),
                  const SizedBox(width: Espaco.s2),
                  Expanded(
                    child: Text(
                      cidade.isEmpty ? 'Escolher cidade' : (c.uf == null ? cidade : '$cidade · ${c.uf}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge?.copyWith(color: cidade.isEmpty ? cores.textoSuave : cores.texto),
                    ),
                  ),
                  Icon(Icons.expand_more, color: cores.textoSuave),
                ],
              ),
            ),
            if (erroCidade != null) ...[
              const SizedBox(height: Espaco.s1),
              Text(erroCidade, style: t.bodySmall?.copyWith(color: cores.erro)),
            ],
            if (widget.ajudaCidade != null) ...[
              const SizedBox(height: Espaco.s1),
              Text(widget.ajudaCidade!, style: t.bodySmall?.copyWith(color: cores.textoSuave)),
            ],
          ],
        ),
        if (widget.comOutrasUnidades) ...[
          const SizedBox(height: Espaco.s3),
          CampoTexto(
            key: const Key('endereco-outras'),
            rotulo: 'Outras unidades',
            controller: c.outrasUnidades,
            maxLength: 200,
            ajuda: 'Outras lojas da rede, por exemplo: Sagrada Família e Médici',
            onChanged: _mudou,
          ),
        ],
      ],
    );
  }
}

/// Folha de baixo: escolhe o estado e depois a cidade. Devolve (cidade, uf).
class _ListaDeCidades extends StatefulWidget {
  const _ListaDeCidades({required this.buscar});
  final BuscarCidades buscar;

  @override
  State<_ListaDeCidades> createState() => _ListaDeCidadesState();
}

class _ListaDeCidadesState extends State<_ListaDeCidades> {
  final _busca = TextEditingController();
  final _digitada = TextEditingController();
  String? _uf;
  List<String>? _cidades;
  bool _falhou = false;
  int _pedido = 0;

  @override
  void dispose() {
    _busca.dispose();
    _digitada.dispose();
    super.dispose();
  }

  Future<void> _carregar(String uf) async {
    final meu = ++_pedido;
    setState(() {
      _uf = uf;
      _cidades = null;
      _falhou = false;
      _busca.clear();
    });
    try {
      final cidades = await widget.buscar(uf);
      if (mounted && meu == _pedido) setState(() => _cidades = cidades);
    } on FalhaComMensagem {
      if (mounted && meu == _pedido) setState(() => _falhou = true);
    }
  }

  void _voltarAoEstado() {
    _pedido++;
    setState(() {
      _uf = null;
      _cidades = null;
      _falhou = false;
    });
  }

  Widget _estados() => SingleChildScrollView(
    padding: const EdgeInsets.all(Espaco.s4),
    child: Wrap(
      spacing: Espaco.s2,
      runSpacing: Espaco.s2,
      children: [for (final u in ufs) ActionChip(label: Text(u), onPressed: () => _carregar(u))],
    ),
  );

  Widget _semLista(String uf) => ListView(
    padding: const EdgeInsets.all(Espaco.s4),
    children: [
      const Aviso('Não deu para carregar as cidades.'),
      const SizedBox(height: Espaco.s2),
      OutlinedButton(onPressed: () => _carregar(uf), child: const Text('Tentar de novo')),
      const SizedBox(height: Espaco.s4),
      CampoTexto(rotulo: 'Ou digite a cidade', controller: _digitada),
      const SizedBox(height: Espaco.s2),
      FilledButton(
        onPressed: () {
          final cidade = _digitada.text.trim();
          if (cidade.length >= 2) Navigator.pop(context, (cidade, uf));
        },
        child: const Text('Usar esta cidade'),
      ),
    ],
  );

  Widget _cidadesDe(String uf, List<String> cidades) {
    final termo = normalizar(_busca.text);
    final achadas = [
      for (final nome in cidades)
        if (termo.isEmpty || normalizar(nome).contains(termo)) nome,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Espaco.s4, 0, Espaco.s4, Espaco.s2),
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Buscar cidade', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: achadas.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(achadas[i]),
              onTap: () => Navigator.pop(context, (achadas[i], uf)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final uf = _uf;
    final cidades = _cidades;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s4, Espaco.s2, Espaco.s2),
            child: Row(
              children: [
                Expanded(child: Text(uf == null ? 'Escolha o estado' : 'Cidades de $uf', style: t.titleMedium)),
                if (uf != null) TextButton(onPressed: _voltarAoEstado, child: const Text('Trocar estado')),
              ],
            ),
          ),
          Expanded(
            child: uf == null
                ? _estados()
                : _falhou
                ? _semLista(uf)
                : cidades == null
                ? const Center(child: CircularProgressIndicator())
                : _cidadesDe(uf, cidades),
          ),
        ],
      ),
    );
  }
}
