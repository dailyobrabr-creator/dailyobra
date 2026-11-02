// Regras da leitura de lista que não dependem de rede: tipos e tamanho aceitos, páginas do PDF
// e limpeza da resposta. Testadas em regras.test.ts.

export const TIPOS_ACEITOS = ["application/pdf", "image/jpeg", "image/png", "image/webp"];
export const MAX_BYTES = 10 * 1024 * 1024;
export const MAX_PAGINAS = 20;

/// Mensagem para a tela quando o arquivo não serve; null quando serve.
export function validarArquivo(tipo: string, base64: string): string | null {
  if (!TIPOS_ACEITOS.includes(tipo)) {
    return "Envie um arquivo PDF, JPG, PNG ou WEBP.";
  }
  if (!base64) return "O arquivo está vazio.";
  const bytes = Math.floor((base64.length * 3) / 4);
  if (bytes > MAX_BYTES) return "O arquivo passa de 10 MB. Envie um menor ou tire uma foto só da lista.";
  return null;
}

/// Páginas de um PDF, contando os objetos "/Type /Page" (o nó "/Pages" fica de fora).
export function contarPaginasPdf(bytes: Uint8Array): number {
  let texto = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    texto += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return (texto.match(/\/Type\s*\/Page(?![a-zA-Z])/g) ?? []).length;
}

/// Linhas da lista sem marcadores, numeração e linhas vazias; "NADA" vira lista vazia.
export function limparLista(texto: string): string[] {
  if (/^\s*nada\.?\s*$/i.test(texto)) return [];
  return texto
    .split(/\r?\n/)
    .map((l) => l.replace(/^\s*(?:[-*•·]|\d+[.)])\s*/, "").trim())
    .filter((l) => l.length > 0);
}

export const INSTRUCOES = `Você lê arquivos enviados por construtores (fotos de listas escritas à mão, PDFs de orçamentos, projetos ou memoriais) e extrai a lista de materiais de construção que eles querem comprar.

Responda só com a lista, em português do Brasil, um material por linha, no formato "quantidade unidade material", por exemplo:
100 sacos de cimento CP II 50 kg
20 barras de ferro 5/16
8 m³ de areia média

Regras:
- Copie quantidades e especificações (bitola, medida, marca, tipo) como estão no arquivo; não invente nem arredonde.
- Se um material não tiver quantidade, escreva só o material.
- Junte linhas repetidas do mesmo material somando as quantidades.
- Ignore preços, totais, nomes de lojas, mão de obra e serviços.
- Sem títulos, comentários, numeração ou marcadores.
- Se o arquivo não tiver nenhum material de construção, responda apenas: NADA`;
