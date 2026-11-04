import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/equipe_service.dart';
import '../services/obras_service.dart';
import 'obra_screen.dart';

/// Pede o código (ou usa o do link), mostra para qual obra é o convite e, se a pessoa aceitar,
/// abre a obra.
Future<void> entrarComConvite(BuildContext context, {String? codigo}) async {
  final obraId = await showDialog<String>(
    context: context,
    builder: (_) => _JanelaConvite(codigo: codigo),
  );
  if (obraId == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ObraScreen(id: obraId)),
  );
}

/// Abre o convite que veio no link, uma vez, assim que a pessoa está dentro do app.
class AbreConvite extends StatefulWidget {
  const AbreConvite({super.key, required this.codigo, required this.child});
  final String? codigo;
  final Widget child;

  @override
  State<AbreConvite> createState() => _AbreConviteState();
}

class _AbreConviteState extends State<AbreConvite> {
  @override
  void initState() {
    super.initState();
    final codigo = widget.codigo;
    if (codigo == null || codigo.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) entrarComConvite(context, codigo: codigo);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _JanelaConvite extends StatefulWidget {
  const _JanelaConvite({this.codigo});

  /// Veio do link: a pessoa não precisa digitar.
  final String? codigo;

  @override
  State<_JanelaConvite> createState() => _JanelaConviteState();
}

class _JanelaConviteState extends State<_JanelaConvite> {
  late final _codigo = TextEditingController(text: widget.codigo ?? '');
  PreviaConvite? _previa;
  String? _erro;
  late bool _ocupado = widget.codigo != null;

  @override
  void initState() {
    super.initState();
    if (widget.codigo != null) _ver();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _ver() async {
    final codigo = _codigo.text.trim();
    if (codigo.isEmpty) {
      setState(() => _erro = 'Digite o código do convite.');
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final previa = await EquipeService.instance.verConvite(codigo);
      if (!mounted) return;
      // Abrir de novo o link de uma obra em que a pessoa já está não pede nada
      if (previa.jaParticipa && widget.codigo != null) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _ocupado = false;
        if (previa.jaParticipa) {
          _erro = 'Você já participa desta obra.';
        } else {
          _previa = previa;
        }
      });
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _erro = e.mensagem;
        });
      }
    }
  }

  Future<void> _entrar() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final id = await EquipeService.instance.aceitar(_codigo.text.trim());
      if (mounted) Navigator.pop(context, id);
    } on FalhaAoSalvar catch (e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _previa = null;
          _erro = e.mensagem;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previa = _previa;
    return AlertDialog(
      scrollable: true,
      title: Text(previa == null ? 'Código de convite' : 'Convite para a obra'),
      content: SizedBox(
        width: 360,
        child: previa != null
            ? _Previa(previa: previa)
            : _ocupado && widget.codigo != null && _erro == null
            ? Center(
                child: CircularProgressIndicator(color: context.cores.acao),
              )
            : CampoTexto(
                rotulo: 'Código',
                controller: _codigo,
                dica: 'Ex.: AB12C-3DE45',
                erro: _erro,
                maxLength: 16,
                acao: TextInputAction.go,
                onSubmitted: (_) => _ver(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: Text(previa == null ? 'Cancelar' : 'Agora não'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : (previa == null ? _ver : _entrar),
          child: Text(previa == null ? 'Continuar' : 'Entrar na obra'),
        ),
      ],
    );
  }
}

class _Previa extends StatelessWidget {
  const _Previa({required this.previa});
  final PreviaConvite previa;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${previa.convidadoPor} convidou você para:', style: t.bodyMedium),
        const SizedBox(height: Espaco.s2),
        Text(previa.obra, style: t.titleMedium),
        const SizedBox(height: Espaco.s3),
        Text(previa.funcao.rotulo, style: t.titleSmall),
        const SizedBox(height: Espaco.s1),
        Text(
          previa.funcao.descricao,
          style: t.bodySmall?.copyWith(color: context.cores.textoSuave),
        ),
      ],
    );
  }
}
