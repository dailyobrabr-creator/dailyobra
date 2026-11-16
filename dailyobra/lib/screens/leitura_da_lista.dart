import 'package:dailyobra_comum/dailyobra_comum.dart';
import 'package:flutter/material.dart';

import '../services/leitura_lista_service.dart';

/// Foto ou PDF já lido, com quantos materiais do catálogo saíram dele.
class ArquivoLido {
  const ArquivoLido(this.arquivo, this.materiais);
  final ArquivoLista arquivo;
  final int materiais;
}

/// Resultado de ler um ou mais arquivos: o texto junto (um material por linha), o que deu certo e a primeira falha.
class LeituraDosArquivos {
  const LeituraDosArquivos(this.texto, this.lidos, this.falhas);
  final String texto;
  final List<ArquivoLido> lidos;
  final List<String> falhas;
}

/// Lê os arquivos um por um no aparelho. Um arquivo que falha não derruba os outros.
Future<LeituraDosArquivos> lerArquivosDaLista(
  List<ArquivoLista> arquivos,
) async {
  final servico = LeituraListaService.instance;
  final partes = <String>[];
  final lidos = <ArquivoLido>[];
  final falhas = <String>[];
  for (final arquivo in arquivos) {
    try {
      final texto = (await servico.ler(arquivo)).trim();
      final materiais = texto
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .length;
      partes.add(texto);
      lidos.add(ArquivoLido(arquivo, materiais));
    } on FalhaComMensagem catch (e) {
      falhas.add(e.mensagem);
    }
  }
  return LeituraDosArquivos(partes.join('\n'), lidos, falhas);
}

/// Aviso depois da leitura: quantos materiais vieram e, se alguma foto falhou, o porquê.
String? avisoDaLeitura(LeituraDosArquivos r) {
  if (r.falhas.isEmpty) return null;
  if (r.lidos.isEmpty) return r.falhas.first;
  final n = r.falhas.length;
  return n == 1
      ? '1 arquivo não deu para ler. ${r.falhas.first}'
      : '$n arquivos não deram para ler. ${r.falhas.first}';
}

/// Fotos e PDFs já lidos, em miniatura. Tocar abre a foto grande para conferir com a lista.
class MiniaturasDaLista extends StatelessWidget {
  const MiniaturasDaLista({super.key, required this.lidos});
  final List<ArquivoLido> lidos;

  static const _lado = 64.0;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = Theme.of(context).textTheme;
    return Wrap(
      spacing: Espaco.s2,
      runSpacing: Espaco.s2,
      children: [
        for (final (i, l) in lidos.indexed)
          Tooltip(
            message: l.arquivo.ehFoto ? 'Ver a foto' : l.arquivo.nome,
            child: InkWell(
              key: Key('miniatura-$i'),
              borderRadius: BorderRadius.circular(Raio.md),
              onTap: l.arquivo.ehFoto
                  ? () => _ampliar(context, l.arquivo)
                  : null,
              child: SizedBox(
                width: _lado,
                child: Column(
                  children: [
                    Container(
                      width: _lado,
                      height: _lado,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: c.superficieSutil,
                        borderRadius: BorderRadius.circular(Raio.md),
                        border: Border.all(color: c.borda),
                      ),
                      child: l.arquivo.ehFoto
                          ? Image.memory(
                              l.arquivo.bytes,
                              fit: BoxFit.cover,
                              cacheWidth: 192,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.image_outlined,
                                color: c.textoSuave,
                              ),
                            )
                          : Icon(
                              Icons.picture_as_pdf_outlined,
                              color: c.textoSuave,
                            ),
                    ),
                    const SizedBox(height: Espaco.s1),
                    Text(
                      l.materiais == 1 ? '1 item' : '${l.materiais} itens',
                      style: t.labelMedium,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _ampliar(BuildContext context, ArquivoLista foto) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(Espaco.s4),
      child: Stack(
        children: [
          InteractiveViewer(
            maxScale: 5,
            child: Image.memory(
              foto.bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 200,
                child: Center(child: Icon(Icons.image_outlined)),
              ),
            ),
          ),
          Positioned(
            top: Espaco.s2,
            right: Espaco.s2,
            child: IconButton.filledTonal(
              tooltip: 'Fechar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  );
}
