import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _validade = Duration(minutes: 30);
const _enderecoDoDolar = 'https://economia.awesomeapi.com.br/json/last/USD-BRL';

/// Dólar comercial no momento da consulta.
class CotacaoDolar {
  const CotacaoDolar({required this.valor, required this.variacao});

  /// Lê a resposta da AwesomeAPI, que traz os números como texto.
  factory CotacaoDolar.fromJson(Map<String, dynamic> j) {
    final dolar = j['USDBRL'] as Map<String, dynamic>;
    return CotacaoDolar(
      valor: double.parse(dolar['bid'] as String),
      variacao: double.parse(dolar['pctChange'] as String),
    );
  }

  final double valor;

  /// Variação do dia, em pontos percentuais.
  final double variacao;
}

/// Cotação do dólar no Dashboard. É um extra: sem resposta, o painel só não mostra a linha.
class MercadoService extends ChangeNotifier {
  MercadoService._();

  static final instance = MercadoService._();

  CotacaoDolar? _dolar;
  DateTime? _buscadoEm;
  Future<CotacaoDolar?> Function()? _buscarDeTeste;

  CotacaoDolar? get dolar => _dolar;

  @visibleForTesting
  void definirParaTeste(Future<CotacaoDolar?> Function() buscar) {
    _dolar = null;
    _buscadoEm = null;
    _buscarDeTeste = buscar;
  }

  Future<void> carregar({DateTime? agora}) async {
    final momento = agora ?? DateTime.now();
    final buscadoEm = _buscadoEm;
    if (buscadoEm != null && momento.difference(buscadoEm) < _validade) return;
    _buscadoEm = momento;
    final cotacao = await _buscar();
    if (cotacao == null) return;
    _dolar = cotacao;
    notifyListeners();
  }

  Future<CotacaoDolar?> _buscar() async {
    final buscar = _buscarDeTeste;
    if (buscar != null) return buscar();
    try {
      final resposta = await http.get(Uri.parse(_enderecoDoDolar));
      if (resposta.statusCode != 200) return null;
      return CotacaoDolar.fromJson(
        jsonDecode(resposta.body) as Map<String, dynamic>,
      );
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
  }
}
