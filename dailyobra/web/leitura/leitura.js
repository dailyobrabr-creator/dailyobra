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

  // Foto de celular: gira pelo EXIF, deixa num tamanho bom para ler, tira a sombra do papel e firma o contraste.
  // O Tesseract erra muito com papel acinzentado, sombra da mão e fotos de 4000 px.
  async function prepararFoto(fonte) {
    let bmp;
    if (fonte instanceof Blob) {
      bmp = await createImageBitmap(fonte, { imageOrientation: 'from-image' });
    } else {
      bmp = fonte;
    }
    const maior = Math.max(bmp.width, bmp.height);
    const escala = maior > 2400 ? 2400 / maior : maior < 1400 ? 1400 / maior : 1;
    const w = Math.round(bmp.width * escala);
    const h = Math.round(bmp.height * escala);
    const tela = document.createElement('canvas');
    tela.width = w;
    tela.height = h;
    const ctx = tela.getContext('2d', { willReadFrequently: true });
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bmp, 0, 0, w, h);
    if (bmp.close) bmp.close();

    // Fundo do papel: a própria foto reduzida e ampliada de volta, o que apaga as letras e deixa a luz
    const pw = Math.max(8, Math.round(w / 32));
    const ph = Math.max(8, Math.round(h / 32));
    const peq = document.createElement('canvas');
    peq.width = pw;
    peq.height = ph;
    const pctx = peq.getContext('2d');
    pctx.imageSmoothingQuality = 'high';
    pctx.filter = 'blur(2px)';
    pctx.drawImage(tela, 0, 0, pw, ph);
    const fundoTela = document.createElement('canvas');
    fundoTela.width = w;
    fundoTela.height = h;
    const fctx = fundoTela.getContext('2d', { willReadFrequently: true });
    fctx.imageSmoothingQuality = 'high';
    fctx.drawImage(peq, 0, 0, w, h);

    const img = ctx.getImageData(0, 0, w, h);
    const fundo = fctx.getImageData(0, 0, w, h).data;
    const d = img.data;
    const cinza = new Float32Array(w * h);
    const hist = new Uint32Array(256);
    for (let i = 0, p = 0; i < d.length; i += 4, p++) {
      const g = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
      const f = 0.299 * fundo[i] + 0.587 * fundo[i + 1] + 0.114 * fundo[i + 2];
      const v = Math.min(255, (g / Math.max(f, 1)) * 255);
      cinza[p] = v;
      hist[v | 0]++;
    }
    // Estica o contraste: 1% mais escuro vira preto, o papel vira branco
    const total = w * h;
    let acum = 0, preto = 0;
    for (let v = 0; v < 256; v++) {
      acum += hist[v];
      if (acum >= total * 0.01) { preto = v; break; }
    }
    const branco = 245;
    const faixa = Math.max(1, branco - preto);
    for (let i = 0, p = 0; i < d.length; i += 4, p++) {
      const v = Math.max(0, Math.min(255, ((cinza[p] - preto) / faixa) * 255));
      d[i] = d[i + 1] = d[i + 2] = v;
      d[i + 3] = 255;
    }
    ctx.putImageData(img, 0, 0);
    return tela;
  }

  async function lerImagem(fonte) {
    const leitor = await leitorDeImagem();
    const pronta = await prepararFoto(fonte);
    const { data } = await leitor.recognize(pronta, { rotateAuto: true });
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
