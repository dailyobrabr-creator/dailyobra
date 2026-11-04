import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/loja_service.dart';
import 'assumir_loja_screen.dart';
import 'campos_endereco.dart';
import 'componentes.dart';
import 'editor_horario.dart';

/// Formata o CNPJ enquanto digita (00.000.000/0000-00).
class _MascaraCnpj extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    final texto = formatarCnpj(novo.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Primeiro acesso de quem entrou no Parceiros sem loja: cadastro com CNPJ.
class CadastroLojaScreen extends StatefulWidget {
  const CadastroLojaScreen({super.key, this.criar, this.buscarCep});

  /// Quem cria a loja; o padrão é a função criar_loja do servidor.
  final Future<String> Function(Map<String, dynamic> dados)? criar;

  /// Busca do CEP; o padrão é o ViaCEP.
  final BuscarCep? buscarCep;

  @override
  State<CadastroLojaScreen> createState() => _CadastroLojaScreenState();
}

class _CadastroLojaScreenState extends State<CadastroLojaScreen> {
  final _nome = TextEditingController();
  final _cnpj = TextEditingController();
  final _whatsapp = TextEditingController();
  final _endereco = ControleEndereco();
  final _horario = ControleHorario.doTexto('');
  final _frete = TextEditingController();
  final _minimo = TextEditingController();
  final _descricao = TextEditingController();
  Map<String, String> _erros = const {};
  String? _erroServidor;
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_nome, _cnpj, _whatsapp, _frete, _minimo, _descricao]) {
      c.dispose();
    }
    _endereco.dispose();
    _horario.dispose();
    super.dispose();
  }

  static String _digitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  double? _valor(TextEditingController c) {
    if (c.text.trim().isEmpty) return 0;
    final v = lerNumero(c.text);
    return v.isNaN || v < 0 ? null : v;
  }

  Map<String, String> _validar() {
    final erros = <String, String>{};
    if (_nome.text.trim().length < 2) erros['nome'] = 'Informe o nome da loja.';
    if (!cnpjValido(_cnpj.text)) {
      erros['cnpj'] = 'CNPJ inválido. Confira os números.';
    }
    erros.addAll(_endereco.validar());
    if (_horario.validar() case final erro?) erros['horario'] = erro;
    final zap = _digitos(_whatsapp.text);
    if (zap.isNotEmpty && (zap.length < 10 || zap.length > 13)) {
      erros['whatsapp'] = 'WhatsApp com DDD, só números.';
    }
    if (_valor(_frete) == null) erros['frete'] = 'Valor inválido.';
    if (_valor(_minimo) == null) erros['minimo'] = 'Valor inválido.';
    return erros;
  }

  void _abrirAssumir() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AssumirLojaScreen()),
  );

  Future<void> _cadastrar() async {
    FocusScope.of(context).unfocus();
    final erros = _validar();
    setState(() {
      _erros = erros;
      _erroServidor = null;
    });
    if (erros.isNotEmpty) return;
    setState(() => _enviando = true);
    try {
      await (widget.criar ?? LojaService.instance.criar)({
        'nome': _nome.text.trim(),
        'cnpj': _digitos(_cnpj.text),
        'whatsapp': _digitos(_whatsapp.text),
        ..._endereco.campos(),
        'horario': _horario.texto(),
        'descricao': _descricao.text.trim(),
        'frete_fixo': _valor(_frete),
        'pedido_minimo': _valor(_minimo),
      });
    } on FalhaComMensagem catch (e) {
      if (mounted) setState(() => _erroServidor = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar loja'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: AuthService.sair,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ColunaCentral(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.s4,
            Espaco.s4,
            Espaco.s4,
            Espaco.s8,
          ),
          children: [
            Text('Sua loja no DailyObra', style: t.headlineSmall),
            const SizedBox(height: Espaco.s1),
            Text(
              'Construtores da sua região vão ver seus preços e ofertas e mandar orçamentos para você.',
              style: t.bodyMedium?.copyWith(color: c.textoSuave),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _abrirAssumir,
                child: const Text('Minha loja já está no DailyObra'),
              ),
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Nome da loja',
              controller: _nome,
              obrigatorio: true,
              erro: _erros['nome'],
              maxLength: 80,
              acao: TextInputAction.next,
            ),
            const SizedBox(height: Espaco.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Rotulo('CNPJ', obrigatorio: true),
                TextField(
                  controller: _cnpj,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9./-]')),
                    _MascaraCnpj(),
                  ],
                  decoration: InputDecoration(
                    hintText: '00.000.000/0000-00',
                    errorText: _erros['cnpj'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'WhatsApp da loja',
              controller: _whatsapp,
              teclado: TextInputType.phone,
              dica: '(44) 99999-0000',
              erro: _erros['whatsapp'],
              acao: TextInputAction.next,
            ),
            const SizedBox(height: Espaco.s3),
            CamposEndereco(
              controle: _endereco,
              erros: _erros,
              buscar: widget.buscarCep,
            ),
            const SizedBox(height: Espaco.s3),
            const Rotulo('Horário de atendimento'),
            EditorHorario(controle: _horario),
            if (_erros['horario'] case final erro?) ...[
              const SizedBox(height: Espaco.s2),
              Aviso(erro),
            ],
            const SizedBox(height: Espaco.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CampoTexto(
                    rotulo: 'Frete (R\$)',
                    controller: _frete,
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    dica: '0 = grátis',
                    erro: _erros['frete'],
                  ),
                ),
                const SizedBox(width: Espaco.s3),
                Expanded(
                  child: CampoTexto(
                    rotulo: 'Pedido mínimo (R\$)',
                    controller: _minimo,
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    dica: '0 = sem mínimo',
                    erro: _erros['minimo'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaco.s3),
            CampoTexto(
              rotulo: 'Sobre a loja',
              controller: _descricao,
              maxLength: 600,
              dica: 'O que a loja tem de melhor',
            ),
            const SizedBox(height: Espaco.s5),
            if (_erroServidor != null) ...[
              Aviso(_erroServidor!),
              // CNPJ de loja pré-cadastrada: quem é da empresa entra pelo código de acesso
              if (_erroServidor!.startsWith('Já existe uma loja'))
                TextButton(
                  onPressed: _abrirAssumir,
                  child: const Text('A loja é minha: entrar com o código'),
                ),
              const SizedBox(height: Espaco.s3),
            ],
            if (_erros.isNotEmpty) ...[
              const Aviso('Confira os campos marcados.', tom: TomSelo.aviso),
              const SizedBox(height: Espaco.s3),
            ],
            FilledButton(
              onPressed: _enviando ? null : _cadastrar,
              child: Text(_enviando ? 'Cadastrando…' : 'Cadastrar loja'),
            ),
            const SizedBox(height: Espaco.s2),
            Text(
              'Logo, capa e preços você coloca depois, no painel da loja.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: c.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}
