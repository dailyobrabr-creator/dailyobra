import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Manda um texto: no celular abre a escolha do aplicativo; na web, o WhatsApp.
Future<void> compartilharTexto(String texto) async {
  if (kIsWeb) {
    final link = 'https://wa.me/?text=${Uri.encodeComponent(texto)}';
    await launchUrl(Uri.parse(link), webOnlyWindowName: '_blank');
    return;
  }
  await SharePlus.instance.share(ShareParams(text: texto));
}

Future<void> compartilharPdf(
  Uint8List bytes,
  String nome, {
  required String titulo,
  String? texto,
}) => SharePlus.instance.share(
  ShareParams(
    files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: nome)],
    fileNameOverrides: [nome],
    title: titulo,
    text: texto,
  ),
);
