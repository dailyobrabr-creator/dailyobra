import 'dart:convert';

import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orçamento em montagem (o "carrinho"): produtos e quantidades, guardados no aparelho para não
/// se perderem ao fechar o app. Preço não fica aqui: a cotação é refeita com as ofertas do momento.
class CarrinhoService extends ChangeNotifier {
  CarrinhoService._();

  static final instance = CarrinhoService._();
  static const chave = 'dailyobra.carrinho.v1';
  static const chaveObra = 'dailyobra.carrinho.obra.v1';

  final List<ItemDesejado> _itens = [];
  String? _obraId;

  /// Obra para a qual este orçamento é feito: o pedido fechado entra no dinheiro dela.
  String? get obraId => _obraId;

  List<ItemDesejado> get itens => List.unmodifiable(_itens);
  bool get vazio => _itens.isEmpty;
  bool contem(String itemId) => _itens.any((i) => i.itemId == itemId);

  Future<void> carregar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final texto = p.getString(chave);
      _obraId = p.getString(chaveObra);
      _itens.clear();
      if (texto != null) {
        for (final j in jsonDecode(texto) as List) {
          final item = ItemDesejado.fromJson(
            Map<String, dynamic>.from(j as Map),
          );
          if (item.quantidade > 0) _itens.add(item);
        }
      }
    } catch (_) {
      // Dado salvo ilegível (versão antiga, aparelho sem espaço): começa um orçamento novo
      _itens.clear();
    }
    notifyListeners();
  }

  void _mudou() {
    notifyListeners();
    final texto = jsonEncode([for (final i in _itens) i.toJson()]);
    final obra = _obraId;
    SharedPreferences.getInstance().then((p) async {
      await p.setString(chave, texto);
      if (obra == null) {
        await p.remove(chaveObra);
      } else {
        await p.setString(chaveObra, obra);
      }
    }).ignore();
  }

  void escolherObra(String? obraId) {
    if (obraId == _obraId) return;
    _obraId = obraId;
    _mudou();
  }

  int _indice(String itemId) => _itens.indexWhere((i) => i.itemId == itemId);

  /// Soma à quantidade se o produto já está no orçamento; [lojaFixada] troca a loja escolhida.
  void adicionar(String itemId, double quantidade, {String? lojaFixada}) {
    if (quantidade <= 0) return;
    final i = _indice(itemId);
    if (i < 0) {
      _itens.add(
        ItemDesejado(
          itemId: itemId,
          quantidade: quantidade,
          lojaFixada: lojaFixada,
        ),
      );
    } else {
      _itens[i] = _itens[i].copyWith(
        quantidade: _itens[i].quantidade + quantidade,
        lojaFixada: lojaFixada,
      );
    }
    _mudou();
  }

  void alterarQuantidade(String itemId, double quantidade) {
    final i = _indice(itemId);
    if (i < 0) return;
    if (quantidade <= 0) {
      _itens.removeAt(i);
    } else {
      _itens[i] = _itens[i].copyWith(quantidade: quantidade);
    }
    _mudou();
  }

  /// [lojaId] nulo devolve o produto para a escolha automática (menor preço).
  void fixarLoja(String itemId, String? lojaId) {
    final i = _indice(itemId);
    if (i < 0) return;
    _itens[i] = lojaId == null
        ? _itens[i].copyWith(soltarLoja: true)
        : _itens[i].copyWith(lojaFixada: lojaId);
    _mudou();
  }

  void remover(String itemId) {
    _itens.removeWhere((i) => i.itemId == itemId);
    _mudou();
  }

  void limpar() {
    if (_itens.isEmpty && _obraId == null) return;
    _itens.clear();
    _obraId = null;
    _mudou();
  }

  /// Troca todo o orçamento por estas quantidades (lista de materiais de uma obra).
  void substituirPor(Map<String, double> quantidades, {String? obraId}) {
    _obraId = obraId;
    _itens
      ..clear()
      ..addAll([
        for (final MapEntry(key: id, value: q) in quantidades.entries)
          if (q > 0) ItemDesejado(itemId: id, quantidade: q),
      ]);
    _mudou();
  }
}
