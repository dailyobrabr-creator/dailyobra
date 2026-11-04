import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/marca_service.dart';
import '../services/obras_service.dart';
import 'componentes.dart';

/// O que aparece no topo dos PDFs da obra: logo, nome, registro e contato.
class MarcaScreen extends StatefulWidget {
  const MarcaScreen({super.key, this.escolherLogo});

  /// Os testes trocam a galeria.
  final Future<XFile?> Function()? escolherLogo;

  @override
  State<MarcaScreen> createState() => _MarcaScreenState();
}

class _MarcaScreenState extends State<MarcaScreen> {
  final _nome = TextEditingController();
  final _registro = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();

  /// A logo que está salva.
  String? _logoPath;
  String? _link;

  /// Logo nova só sobe ao salvar: desistir na tela não deixa arquivo perdido.
  Uint8List? _novoLogo;
  String _nomeDoLogo = '';
  bool _tirarLogo = false;

  bool _carregando = true;
  bool _ocupado = false;
  String? _erro;
  String? _erroEmail;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nome.dispose();
    _registro.dispose();
    _telefone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final m = await MarcaService.instance.minha();
      final path = m.logoPath;
      final link = path == null
          ? null
          : await MarcaService.instance.linkDoLogo(path);
      if (!mounted) return;
      _nome.text = m.nome;
      _registro.text = m.registro;
      _telefone.text = m.telefone;
      _email.text = m.email;
      setState(() {
        _logoPath = path;
        _link = link;
        _carregando = false;
      });
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _carregando = false;
        });
      }
    }
  }

  Future<XFile?> _abrirGaleria() => ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    imageQuality: 85,
  );

  Future<void> _escolher() async {
    final XFile? foto;
    try {
      foto = await (widget.escolherLogo ?? _abrirGaleria)();
    } catch (_) {
      if (mounted) avisar(context, 'Não foi possível abrir a galeria.');
      return;
    }
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    if (!mounted) return;
    if (bytes.length > MarcaService.tamanhoMaximo) {
      avisar(context, 'Use uma imagem de até 2 MB.');
      return;
    }
    setState(() {
      _novoLogo = bytes;
      _nomeDoLogo = foto!.name;
      _tirarLogo = false;
    });
  }

  Future<void> _salvar() async {
    final email = _email.text.trim();
    final emailOk = email.isEmpty || RegExp(r'^\S+@\S+\.\S+$').hasMatch(email);
    setState(() => _erroEmail = emailOk ? null : 'Confira o e-mail.');
    if (!emailOk) return;
    setState(() => _ocupado = true);
    final servico = MarcaService.instance;
    try {
      final antigo = _logoPath;
      final novo = _novoLogo;
      final caminho = novo != null
          ? await servico.enviarLogo(novo, _nomeDoLogo)
          : _tirarLogo
          ? null
          : antigo;
      await servico.salvar(
        MarcaEngenheiro(
          nome: _nome.text.trim(),
          registro: _registro.text.trim(),
          telefone: _telefone.text.trim(),
          email: email,
          logoPath: caminho,
        ),
      );
      if (antigo != null && antigo != caminho) {
        await servico.apagarLogo(antigo);
      }
      if (!mounted) return;
      avisar(context, 'Marca salva.');
      Navigator.pop(context);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
    }
  }

  bool get _temLogo => _novoLogo != null || (_logoPath != null && !_tirarLogo);

  Widget _previa() {
    final novo = _novoLogo;
    final link = _link;
    Widget vazio(BuildContext c) =>
        Center(child: Icon(Icons.image_outlined, color: c.cores.textoSuave));
    return Container(
      height: 84,
      padding: const EdgeInsets.all(Espaco.s2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Raio.sm),
        border: Border.all(color: context.cores.borda),
      ),
      child: novo != null
          ? Image.memory(novo, fit: BoxFit.contain)
          : _temLogo && link != null
          ? Image.network(
              link,
              fit: BoxFit.contain,
              errorBuilder: (c, _, _) => vazio(c),
            )
          : vazio(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final erro = _erro;
    return Scaffold(
      appBar: AppBar(title: const Text('Sua marca')),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: context.cores.acao))
          : erro != null
          ? Padding(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Aviso(erro),
                  const SizedBox(height: Espaco.s3),
                  OutlinedButton(
                    onPressed: _carregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(Espaco.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Aviso(
                    'Aparece no topo do relatório semanal e do diário em PDF.',
                    tom: TomSelo.info,
                  ),
                  const SizedBox(height: Espaco.s4),
                  const Rotulo('Logo'),
                  _previa(),
                  const SizedBox(height: Espaco.s2),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _ocupado ? null : _escolher,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                            _temLogo ? 'Trocar logo' : 'Escolher logo',
                          ),
                        ),
                      ),
                      if (_temLogo) ...[
                        const SizedBox(width: Espaco.s2),
                        TextButton(
                          onPressed: _ocupado
                              ? null
                              : () => setState(() {
                                  _novoLogo = null;
                                  _tirarLogo = true;
                                }),
                          child: const Text('Tirar'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Espaco.s4),
                  CampoTexto(
                    rotulo: 'Nome ou empresa',
                    controller: _nome,
                    ajuda: 'Em branco, usamos o nome do seu perfil.',
                    maxLength: 120,
                  ),
                  const SizedBox(height: Espaco.s4),
                  CampoTexto(
                    rotulo: 'Registro profissional',
                    controller: _registro,
                    dica: 'Ex.: CREA 12345/D',
                    maxLength: 60,
                  ),
                  const SizedBox(height: Espaco.s4),
                  CampoTexto(
                    rotulo: 'Telefone',
                    controller: _telefone,
                    teclado: TextInputType.phone,
                    maxLength: 30,
                  ),
                  const SizedBox(height: Espaco.s4),
                  CampoTexto(
                    rotulo: 'E-mail',
                    controller: _email,
                    teclado: TextInputType.emailAddress,
                    erro: _erroEmail,
                    maxLength: 120,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _carregando || erro != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.s4,
                  Espaco.s2,
                  Espaco.s4,
                  Espaco.s3,
                ),
                child: FilledButton(
                  onPressed: _ocupado ? null : _salvar,
                  child: const Text('Salvar'),
                ),
              ),
            ),
    );
  }
}
