// Leitura da lista de materiais no próprio aparelho: o PDF.js tira o texto do PDF e o Tesseract lê fotos e
// páginas escaneadas. Os arquivos ficam nesta pasta e nada sai do navegador. Carregado só quando alguém anexa.
(function () {
  const base = new URL('leitura/', document.baseURI).href;
  const MAX_PAGINAS = 20;
  let trabalhador = null;

  function carregarScript(src) {
    return new Promise((pronto, falhou) => {
      const s = document.createElement('script');
      s.src = src;
      s.onload = pronto;
      s.onerror = () => falhou(new Error('Não deu para carregar ' + src));
      document.head.appendChild(s);
    });
  }

  function leitorDeImagem() {
    if (!trabalhador) {
      trabalhador = (async () => {
        if (!window.Tesseract) await carregarScript(base + 'tesseract.min.js');
        // OEM 1: só a rede LSTM, que é o que o por.traineddata (best_int) traz
        return window.Tesseract.createWorker('por', 1, {
          workerPath: base + 'worker.min.js',
          corePath: base.replace(/\/$/, ''),
          langPath: base.replace(/\/$/, ''),
          workerBlobURL: false,
        });
      })();
      trabalhador.catch(() => { trabalhador = null; });
    }
    return trabalhador;
  }

  async function lerImagem(fonte) {
    const leitor = await leitorDeImagem();
    const { data } = await leitor.recognize(fonte);
    return data.text || '';
  }

  async function lerPdf(bytes) {
    const pdfjs = await import(base + 'pdf.min.mjs');
    pdfjs.GlobalWorkerOptions.workerSrc = base + 'pdf.worker.min.mjs';
    const doc = await pdfjs.getDocument({ data: bytes }).promise;
    if (doc.numPages > MAX_PAGINAS) {
      throw new Error('O PDF passa de ' + MAX_PAGINAS + ' páginas. Envie só as páginas da lista.');
    }
    const partes = [];
    for (let i = 1; i <= doc.numPages; i++) {
      const pagina = await doc.getPage(i);
      const conteudo = await pagina.getTextContent();
      let texto = '';
      for (const item of conteudo.items) {
        if (typeof item.str !== 'string') continue;
        texto += item.str + (item.hasEOL ? '\n' : ' ');
      }
      // Página escaneada não tem texto: desenha e lê como foto
      if (texto.replace(/\s/g, '').length < 10) {
        const vista = pagina.getViewport({ scale: 2 });
        const tela = document.createElement('canvas');
        tela.width = Math.ceil(vista.width);
        tela.height = Math.ceil(vista.height);
        await pagina.render({ canvasContext: tela.getContext('2d'), viewport: vista }).promise;
        texto = await lerImagem(tela);
      }
      partes.push(texto);
    }
    return partes.join('\n');
  }

  // Chamado pelo app: bytes do arquivo e o tipo (application/pdf, image/jpeg, image/png, image/webp)
  window.dailyobraLerArquivo = function (bytes, tipo) {
    if (tipo === 'application/pdf') return lerPdf(bytes);
    return lerImagem(new Blob([bytes], { type: tipo }));
  };
})();
