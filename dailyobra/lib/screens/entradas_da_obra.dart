import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import 'caixa_screen.dart';
import 'checklists_screen.dart';
import 'compras_screen.dart';
import 'contratos_screen.dart';
import 'cronograma_screen.dart';
import 'dinheiro_screen.dart';
import 'documentos_screen.dart';
import 'equipe_screen.dart';
import 'mao_de_obra_screen.dart';
import 'mudancas_screen.dart';
import 'pendencias_screen.dart';
import 'relatorio_screen.dart';

/// As partes da obra que esta pessoa pode abrir, na ordem da rotina. A tela da obra e o painel do Início usam a mesma lista,
/// para o que cada função vê não mudar de um lugar para o outro.
List<Widget> entradasDaObra(Obra obra, ResumoCronograma resumo) {
  final funcao = obra.funcao;
  return [
    EntradaDoCronograma(obra: obra, resumo: resumo),
    if (funcao.registra) EntradaDasPendencias(obra: obra),
    if (funcao.cuidaDasCompras) EntradaDasCompras(obra: obra),
    if (funcao.lidera) ...[
      EntradaDoDinheiro(obra: obra),
      EntradaDaMaoDeObra(obra: obra),
    ],
    if (funcao.administra) EntradaDoCaixa(obra: obra),
    if (funcao == FuncaoObra.empreiteiro) EntradaDoContrato(obra: obra),
    if (funcao.veMudancas && funcao != FuncaoObra.cliente)
      EntradaDasMudancas(obra: obra),
    if (funcao.veMudancas) EntradaDoRelatorio(obra: obra),
    EntradaDosDocumentos(obra: obra),
    if (funcao.inspeciona) EntradaDosChecklists(obra: obra),
    EntradaDaEquipe(obra: obra),
  ];
}
