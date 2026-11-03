import 'package:flutter/widgets.dart';

/// Celular abaixo de 600 px, tablet até 1023 px, computador a partir de 1024 px.
enum Formato { celular, tablet, computador }

Formato formatoDe(double largura) => largura < 600 ? Formato.celular : largura < 1024 ? Formato.tablet : Formato.computador;

Formato formatoDoContexto(BuildContext context) => formatoDe(MediaQuery.sizeOf(context).width);
