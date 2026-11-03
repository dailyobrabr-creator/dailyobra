import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/loja_service.dart';
import '../services/ofertas_service.dart';
import 'componentes.dart';

/// Preço da loja para um produto do catálogo: valor, promoção com data, disponibilidade e pausa.
class OfertaScreen extends StatefulWidget {
  const OfertaScreen({super.key, required this.itemId, this.salvar});
  final String itemId;

  /// Quem grava; o padrão é a tabela ofertas no servidor.
  final Future<void> Function(Oferta oferta)? salvar;

  @override
  State<OfertaScreen> createState() => _OfertaScreenState();
}

class _OfertaScreenState extends State<OfertaScreen> {
  late final Oferta? _atual = OfertasService.instance.minhas[widget.itemId];
  late final _preco = TextEditingController(
    text: _atual == null ? '' : numero.format(_atual.preco),
  );
  late final _promo = TextEditingController(
    text: _atual?.precoPromocional == null
        ? ''
        : numero.format(_atual!.precoPromocional),
  );
  late bool _emPromocao = _atual?.precoPromocional != null;
  late DateTime? _promoAte = _atual?.promoAte;
  late Disponibilidade _disponibilidade =
      _atual?.disponibilidade ?? Disponibilidade.disponivel;
  late bool _pausada = _atual?.pausada ?? false;
  String? _erroPreco;
  String? _erroPromo;
  bool _salvando = false;

  @override
  void dispose() {
    _preco.dispose();
    _promo.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _promoAte ?? hoje.add(const Duration(days: 7)),
      firstDate: DateTime(hoje.year, hoje.month, hoje.day),
      lastDate: hoje.add(const Duration(days: 365)),
      helpText: 'Promoção válida até',
    );
    if (d != null) setState(() => _promoAte = d);
  }

  Future<void> _salvar() async {
    final preco = lerNumero(_preco.text);
    final promo = _emPromocao ? lerNumero(_promo.text) : double.nan;
    String? erroPreco;
    String? erroPromo;
    if (preco.isNaN || preco <= 0) erroPreco = 'Informe o preço.';
    if (_emPromocao) {
      if (promo.isNaN || promo <= 0) {
        erroPromo = 'Informe o preço da promoção.';
      } else if (!preco.isNaN && promo >= preco) {
        erroPromo = 'A promoção precisa ser menor que o preço normal.';
      } else if (_promoAte == null) {
        erroPromo = 'Escolha até quando vale a promoção.';
      }
    }
    setState(() {
      _erroPreco = erroPreco;
      _erroPromo = erroPromo;
    });
    if (erroPreco != null || erroPromo != null) return;
    final oferta = Oferta(
      lojaId: LojaService.instance.minhaLoja?.id ?? '',
      itemId: widget.itemId,
      preco: (preco * 100).roundToDouble() / 100,
      precoPromocional: _emPromocao
          ? (promo * 100).roundToDouble() / 100
          : null,
      promoAte: _emPromocao ? _promoAte : null,
      disponibilidade: _disponibilidade,
      pausada: _pausada,
    );
    setState(() => _salvando = true);
    try {
      await (widget.salvar ?? OfertasService.instance.salvar)(oferta);
      if (mounted) {
        avisar(context, 'Preço salvo.');
        Navigator.maybePop(context);
      }
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _remover() async {
    if (!await confirmar(
      context,
      titulo: 'Tirar o preço?',
      texto: 'O produto deixa de aparecer para os construtores nesta loja.',
      acao: 'Tirar',
    )) {
      return;
    }
    try {
      await OfertasService.instance.remover(widget.itemId);
      if (mounted) {
        avisar(context, 'Preço retirado.');
        Navigator.maybePop(context);
      }
    } on FalhaComMensagem catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = OfertasService.instance.item(widget.itemId);
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVazio(
          titulo: 'Produto não encontrado',
          texto: 'Volte e escolha outro produto.',
        ),
      );
    }
    final formato = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Scaffold(
      appBar: AppBar(
        title: Text(_atual == null ? 'Colocar preço' : 'Editar preço'),
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
            Row(
              children: [
                ImagemProduto(item: item, tamanho: 56),
                const SizedBox(width: Espaco.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nome, style: t.titleMedium),
                      Text(
                        'Vendido por ${item.unidade}',
                        style: t.bodySmall?.copyWith(color: c.textoSuave),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaco.s5),
            const Rotulo('Preço', obrigatorio: true),
            TextField(
              controller: _preco,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: formato,
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                suffixText: '/ ${item.unidade}',
                errorText: _erroPreco,
              ),
            ),
            const SizedBox(height: Espaco.s3),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _emPromocao,
              onChanged: (v) => setState(() => _emPromocao = v),
              title: const Text('Em promoção'),
              subtitle: const Text(
                'Aparece em Ofertas no app do construtor, com o preço normal riscado.',
              ),
            ),
            if (_emPromocao) ...[
              const Rotulo('Preço da promoção'),
              TextField(
                controller: _promo,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: formato,
                decoration: InputDecoration(
                  prefixText: 'R\$ ',
                  errorText: _erroPromo,
                  errorMaxLines: 2,
                ),
              ),
              const SizedBox(height: Espaco.s2),
              OutlinedButton.icon(
                onPressed: _escolherData,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _promoAte == null
                      ? 'Válida até…'
                      : 'Válida até ${dataHora(_promoAte!).split(' ').first}',
                ),
              ),
            ],
            const SizedBox(height: Espaco.s4),
            const Rotulo('Disponibilidade'),
            Segmentado<Disponibilidade>(
              valor: _disponibilidade,
              opcoes: [for (final d in Disponibilidade.values) (d, d.rotulo)],
              onChanged: (d) => setState(() => _disponibilidade = d),
            ),
            const SizedBox(height: Espaco.s3),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pausada,
              onChanged: (v) => setState(() => _pausada = v),
              title: const Text('Pausar este produto'),
              subtitle: const Text(
                'Some das cotações sem perder o preço cadastrado.',
              ),
            ),
            if (_atual != null) ...[
              const SizedBox(height: Espaco.s2),
              TextButton.icon(
                onPressed: _remover,
                icon: Icon(Icons.delete_outline, color: c.erro),
                label: Text(
                  'Tirar o preço deste produto',
                  style: TextStyle(color: c.erro),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: ColunaCentral(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaco.s4,
              Espaco.s2,
              Espaco.s4,
              Espaco.s3,
            ),
            child: FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando…' : 'Salvar preço'),
            ),
          ),
        ),
      ),
    );
  }
}
