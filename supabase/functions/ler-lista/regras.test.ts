// Testes das regras da leitura de lista (sem rede). Rodar: node --test supabase/functions/ler-lista/
import { test } from "node:test";
import assert from "node:assert/strict";

import { contarPaginasPdf, limparLista, validarArquivo } from "./regras.ts";

const latin1 = (s: string) => Uint8Array.from(s, (c) => c.charCodeAt(0));

test("aceita PDF e fotos comuns", () => {
  for (const tipo of ["application/pdf", "image/jpeg", "image/png", "image/webp"]) {
    assert.equal(validarArquivo(tipo, "QUJD"), null, tipo);
  }
});

test("recusa outro tipo de arquivo", () => {
  assert.match(validarArquivo("application/zip", "QUJD")!, /PDF, JPG, PNG ou WEBP/);
});

test("recusa arquivo vazio e acima de 10 MB", () => {
  assert.match(validarArquivo("image/png", "")!, /vazio/);
  const onzeMb = "A".repeat(Math.ceil((11 * 1024 * 1024 * 4) / 3));
  assert.match(validarArquivo("image/png", onzeMb)!, /10 MB/);
});

test("conta as páginas do PDF sem contar o nó Pages", () => {
  const pdf = latin1(
    "%PDF-1.4 1 0 obj<</Type /Pages /Count 3>> 2 0 obj<</Type /Page>> 3 0 obj<</Type/Page /Parent 1 0 R>> 4 0 obj<</Type /Page\n>>",
  );
  assert.equal(contarPaginasPdf(pdf), 3);
});

test("limpa marcadores, numeração e linhas vazias da resposta", () => {
  const texto = "- 100 sacos de cimento CP II\n\n2) 20 barras de ferro 5/16\n• 8 m³ de areia média\n  * 500 tijolos  \n";
  assert.deepEqual(limparLista(texto), [
    "100 sacos de cimento CP II",
    "20 barras de ferro 5/16",
    "8 m³ de areia média",
    "500 tijolos",
  ]);
});

test("NADA vira lista vazia", () => {
  assert.deepEqual(limparLista("NADA"), []);
  assert.deepEqual(limparLista("  nada.  "), []);
});
