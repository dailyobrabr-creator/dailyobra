import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

/// Abas da navegação principal. Qualquer tela pode trocar a aba com [irParaAba].
enum Aba { inicio, propostas, produtos, loja }

final abaAtual = ValueNotifier<Aba>(Aba.inicio);

void irParaAba(BuildContext context, Aba aba) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  abaAtual.value = aba;
}

/// Telas abertas por cima da navegação: no computador o conteúdo fica numa coluna de no máximo
/// 760 px. Com `heightFactor: 1` serve no `body` e no `bottomNavigationBar` do `Scaffold`.
class ColunaCentral extends StatelessWidget {
  const ColunaCentral({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: child,
    ),
  );
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

String _dois(int n) => n.toString().padLeft(2, '0');

/// "31/10 às 14:05"
String dataHora(DateTime d) =>
    '${_dois(d.day)}/${_dois(d.month)} às ${_dois(d.hour)}:${_dois(d.minute)}';

/// "14:05"
String hora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

/// "às 14:05" se for hoje; "em 31/10 às 14:05" se for outro dia
String quando(DateTime d, {DateTime? agora}) {
  final hoje = agora ?? DateTime.now();
  final mesmoDia =
      d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
  return mesmoDia ? 'às ${hora(d)}' : 'em ${dataHora(d)}';
}

/// "faltam 5 h" / "faltam 40 min" / "venceu"
String prazo(DateTime ate, {DateTime? agora}) {
  final resto = ate.difference(agora ?? DateTime.now());
  if (resto.isNegative) return 'venceu';
  if (resto.inHours >= 1) return 'faltam ${resto.inHours} h';
  return 'faltam ${resto.inMinutes.clamp(1, 59)} min';
}

String formatarQuantidade(double q) {
  if (q == q.roundToDouble()) {
    return numero.format(q).replaceFirst(RegExp(r',00$'), '');
  }
  return numero.format(q).replaceFirst(RegExp(r'0$'), '');
}

String telefone(String d) {
  if (d.length == 11) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  }
  if (d.length == 10) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  }
  return d;
}

/// Selo do ponto de vista da loja: o que ela precisa fazer.
(String, TomSelo) seloParaLoja(PropostaResumo p) {
  final pedido = p.pedido;
  if (pedido != null) {
    // O prazo do crediário espera a resposta do dono ou do gerente
    if (pedido.prazoStatus == StatusPrazo.pendente &&
        pedido.status != StatusPedido.cancelado) {
      return ('Prazo para aprovar', TomSelo.aviso);
    }
    return (
      pedido.status.rotulo,
      switch (pedido.status) {
        StatusPedido.entregue => TomSelo.sucesso,
        StatusPedido.cancelado => TomSelo.erro,
        _ => TomSelo.info,
      },
    );
  }
  return switch (p.status) {
    StatusProposta.enviada => (
      p.modo == ModoProposta.pedido ? 'Pedido novo' : 'Proposta nova',
      TomSelo.aviso,
    ),
    StatusProposta.contraproposta => ('Aguardando construtor', TomSelo.info),
    StatusProposta.aceita => ('Aceita', TomSelo.sucesso),
    StatusProposta.recusada => ('Recusada', TomSelo.neutro),
    StatusProposta.cancelada => ('Cancelada pelo construtor', TomSelo.neutro),
    StatusProposta.expirada => ('Expirada', TomSelo.neutro),
  };
}

/// Linha "rótulo .......... valor" dos resumos de valores.
class LinhaValor extends StatelessWidget {
  const LinhaValor(
    this.rotulo,
    this.valor, {
    super.key,
    this.destaque = false,
    this.cor,
  });
  final String rotulo;
  final String valor;
  final bool destaque;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final estilo = destaque
        ? t.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : t.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: estilo?.copyWith(
                color: destaque ? null : context.cores.textoSuave,
              ),
            ),
          ),
          Text(
            valor,
            style: estilo?.copyWith(color: cor, fontFeatures: numerosTabulares),
          ),
        ],
      ),
    );
  }
}

/// Pede uma confirmação simples; devolve true quando a pessoa confirma.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String acao,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(acao),
        ),
      ],
    ),
  );
  return ok == true;
}
