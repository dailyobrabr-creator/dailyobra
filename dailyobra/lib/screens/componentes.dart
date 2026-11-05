import 'dart:math' as math;

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Abas da navegação principal. Qualquer tela pode trocar a aba com [irParaAba].
enum Aba { inicio, busca, obras, orcamentos, perfil }

final abaAtual = ValueNotifier<Aba>(Aba.inicio);

/// Volta para a navegação principal e abre a aba (ex.: "Ver orçamento" depois de adicionar).
void irParaAba(BuildContext context, Aba aba) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  abaAtual.value = aba;
}

final _quantidade = NumberFormat.decimalPatternDigits(
  locale: 'pt_BR',
  decimalDigits: 0,
);
final _quantidadeDecimal = NumberFormat.decimalPatternDigits(
  locale: 'pt_BR',
  decimalDigits: 2,
);

/// "100", "1.000", "2,5"
String formatarQuantidade(double q) => q == q.roundToDouble()
    ? _quantidade.format(q)
    : _quantidadeDecimal.format(q).replaceFirst(RegExp(r',?0+$'), '');

void avisarAdicionado(BuildContext context, String nome) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$nome no orçamento'),
        action: SnackBarAction(
          label: 'Ver orçamento',
          onPressed: () => irParaAba(context, Aba.orcamentos),
        ),
      ),
    );
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Linha na tela da obra que leva a uma parte dela. Com [alerta], o texto vem em destaque e com ícone.
class EntradaDaObra extends StatelessWidget {
  const EntradaDaObra({
    super.key,
    required this.icone,
    required this.titulo,
    required this.detalhe,
    required this.aoTocar,
    this.alerta = false,
  });

  final IconData icone;
  final String titulo;
  final String detalhe;
  final VoidCallback aoTocar;
  final bool alerta;

  Widget _comoBloco(BuildContext context, String tom) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final cor = coresDaCategoria(tom, Theme.of(context).brightness);
    final corDoDetalhe = alerta ? c.erro : c.textoSuave;
    return Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
        side: BorderSide(color: c.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cor.fundo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: cor.icone, size: 22),
              ),
              const SizedBox(height: Espaco.s2),
              Text(
                titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (alerta) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: corDoDetalhe,
                      ),
                    ),
                    const SizedBox(width: Espaco.s1),
                  ],
                  Expanded(
                    child: Text(
                      detalhe,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: corDoDetalhe),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloco = context.dependOnInheritedWidgetOfExactType<BlocoDaObra>();
    if (bloco != null) return _comoBloco(context, bloco.tom);
    final t = Theme.of(context).textTheme;
    final cor = alerta ? context.cores.erro : context.cores.textoSuave;
    return Painel(
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.s4),
          child: Row(
            children: [
              Icon(icone, color: context.cores.textoSuave),
              const SizedBox(width: Espaco.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: t.titleSmall),
                    Row(
                      children: [
                        if (alerta) ...[
                          Icon(Icons.warning_amber, size: 14, color: cor),
                          const SizedBox(width: Espaco.s1),
                        ],
                        Expanded(
                          child: Text(
                            detalhe,
                            style: t.bodySmall?.copyWith(color: cor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.cores.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faz a [EntradaDaObra] de dentro virar um bloco de grade, na cor da categoria [tom].
class BlocoDaObra extends InheritedWidget {
  const BlocoDaObra({super.key, required this.tom, required super.child});
  final String tom;

  @override
  bool updateShouldNotify(BlocoDaObra oldWidget) => oldWidget.tom != tom;
}

/// Campo de data: tocar abre o calendário. Mostra "Escolher data" enquanto estiver vazio.
class CampoData extends StatelessWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
    this.ate,
    this.limpavel = true,
  });

  final String rotulo;
  final DateTime? valor;
  final ValueChanged<DateTime?> aoMudar;

  /// Última data que pode ser escolhida.
  final DateTime? ate;
  final bool limpavel;

  Future<void> _escolher(BuildContext context) async {
    final ultima = ate ?? DateTime(2100);
    final atual = valor ?? DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: atual.isAfter(ultima) ? ultima : atual,
      firstDate: DateTime(2000),
      lastDate: ultima,
      helpText: rotulo,
    );
    if (data != null) aoMudar(data);
  }

  @override
  Widget build(BuildContext context) {
    final v = valor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Rotulo(rotulo),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _escolher(context),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  v == null
                      ? 'Escolher data'
                      : '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}',
                ),
              ),
            ),
            if (limpavel && v != null)
              IconButton(
                tooltip: 'Limpar $rotulo',
                onPressed: () => aoMudar(null),
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ],
    );
  }
}

/// − quantidade + ; tocar no número abre o teclado para digitar.
class SeletorQuantidade extends StatelessWidget {
  const SeletorQuantidade({
    super.key,
    required this.valor,
    required this.onChanged,
    this.unidade,
    this.minimo = 1,
  });
  final double valor;
  final ValueChanged<double> onChanged;
  final String? unidade;
  final double minimo;

  Future<void> _digitar(BuildContext context) async {
    final novo = await mostrarJanela<double>(
      context,
      construtor: (_) => _JanelaQuantidade(valor: valor, unidade: unidade),
    );
    if (novo != null && !novo.isNaN && novo >= minimo && novo <= 999999) {
      onChanged(novo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.borda),
        borderRadius: BorderRadius.circular(Raio.md),
        color: c.superficie,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir',
            visualDensity: VisualDensity.compact,
            onPressed: valor - 1 >= minimo ? () => onChanged(valor - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Flexible(
            child: InkWell(
              onTap: () => _digitar(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    unidade == null
                        ? formatarQuantidade(valor)
                        : '${formatarQuantidade(valor)} $unidade',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontFeatures: numerosTabulares),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar',
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(valor + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

String _dois(int n) => n.toString().padLeft(2, '0');

/// "31/10 às 14:05" (sem depender dos dados de localização do intl)
String dataHora(DateTime d) =>
    '${_dois(d.day)}/${_dois(d.month)} às ${_dois(d.hour)}:${_dois(d.minute)}';

/// Selo com o andamento da proposta ou, quando já virou pedido, do pedido.
(String, TomSelo) seloDaProposta(StatusProposta status, StatusPedido? pedido) {
  if (pedido != null) {
    return (
      pedido.rotulo,
      switch (pedido) {
        StatusPedido.entregue => TomSelo.sucesso,
        StatusPedido.cancelado => TomSelo.erro,
        _ => TomSelo.info,
      },
    );
  }
  return switch (status) {
    StatusProposta.enviada => ('Aguardando a loja', TomSelo.neutro),
    StatusProposta.contraproposta => ('Contraproposta', TomSelo.aviso),
    StatusProposta.aceita => ('Aceita', TomSelo.sucesso),
    StatusProposta.recusada => ('Recusada', TomSelo.erro),
    StatusProposta.cancelada => ('Cancelada', TomSelo.neutro),
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

const mesesCurtos = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];
const mesesExtenso = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

class _JanelaQuantidade extends StatefulWidget {
  const _JanelaQuantidade({required this.valor, this.unidade});
  final double valor;
  final String? unidade;

  @override
  State<_JanelaQuantidade> createState() => _JanelaQuantidadeState();
}

class _JanelaQuantidadeState extends State<_JanelaQuantidade> {
  late final _controle = TextEditingController(
    text: formatarQuantidade(widget.valor),
  );

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Espaco.s4,
        0,
        Espaco.s4,
        Espaco.s4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quantidade', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Espaco.s3),
          TextField(
            controller: _controle,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(suffixText: widget.unidade),
            onSubmitted: (t) => Navigator.pop(context, lerNumero(t)),
          ),
          const SizedBox(height: Espaco.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: Espaco.s2),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, lerNumero(_controle.text)),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Janela: centralizada (até 560 px) no computador; sobe de baixo no celular e no tablet.
Future<T?> mostrarJanela<T>(
  BuildContext context, {
  required WidgetBuilder construtor,
}) {
  if (formatoDoContexto(context) == Formato.computador) {
    return showDialog<T>(
      context: context,
      builder: (c) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.only(top: Espaco.s5),
            child: construtor(c),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: construtor,
  );
}

/// Margem lateral que centraliza o conteúdo em até [maximo] px, com a rolagem na borda da tela.
double margemLateral(double largura, {double maximo = 1200}) =>
    math.max(Espaco.s4, (largura - maximo) / 2);

/// Colunas da grade de produtos: 3 no tablet e 4 no computador.
int colunasDaGrade(Formato formato) => formato == Formato.computador ? 4 : 3;

/// Cartões em colunas de largura igual.
class GradeCartoes extends StatelessWidget {
  const GradeCartoes({super.key, required this.colunas, required this.filhos});
  final int colunas;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final largura =
            ((limites.maxWidth - (colunas - 1) * Espaco.s4) / colunas)
                .floorToDouble();
        return Wrap(
          spacing: Espaco.s4,
          runSpacing: Espaco.s4,
          children: [
            for (final f in filhos) SizedBox(width: largura, child: f),
          ],
        );
      },
    );
  }
}

/// [CartaoOferta] com o botão de adicionar ao orçamento sobre a foto.
class CartaoOfertaComBotao extends StatelessWidget {
  const CartaoOfertaComBotao({
    super.key,
    required this.item,
    required this.oferta,
    required this.hoje,
    this.nomeLoja,
    this.noOrcamento = false,
    this.onTap,
    this.onAdicionar,
  });
  final ItemCatalogo item;
  final Oferta? oferta;
  final DateTime hoje;
  final String? nomeLoja;
  final bool noOrcamento;
  final VoidCallback? onTap;
  final VoidCallback? onAdicionar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Stack(
      children: [
        CartaoOferta(
          item: item,
          oferta: oferta,
          hoje: hoje,
          nomeLoja: nomeLoja,
          onTap: onTap,
        ),
        if (onAdicionar != null)
          Positioned(
            top: Espaco.s2,
            right: Espaco.s2,
            child: IconButton.filled(
              tooltip: noOrcamento
                  ? '${item.nome} já está no orçamento. Adicionar mais'
                  : 'Adicionar ${item.nome} ao orçamento',
              style: IconButton.styleFrom(
                backgroundColor: noOrcamento ? c.sucesso : c.acao,
                foregroundColor: c.textoSobreAcao,
              ),
              onPressed: onAdicionar,
              icon: Icon(noOrcamento ? Icons.check : Icons.add),
            ),
          ),
      ],
    );
  }
}
