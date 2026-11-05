// Testes das regras da IA da obra (sem rede). Rodar: node --test supabase/functions/ia-obra/regras.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";

import {
  caminhoDaObra,
  diaVazio,
  FORMATO_DIA,
  FORMATO_NOTA,
  lerPedido,
  MAX_TEXTO,
  mensagemDoDia,
  normalizarDia,
  normalizarNota,
  paraBase64,
  tipoDaImagem,
} from "./regras.ts";

const OBRA = "00000000-0000-0000-0000-0000000b0001";
const HOJE = "2026-11-05";

test("aceita o pedido do diário", () => {
  assert.deepEqual(lerPedido({ acao: "diario", obra: OBRA, texto: "  choveu  " }), { acao: "diario", obra: OBRA, texto: "choveu" });
});

test("recusa diário vazio ou longo demais", () => {
  assert.match(lerPedido({ acao: "diario", obra: OBRA, texto: "  " }) as string, /como foi o dia/);
  assert.match(lerPedido({ acao: "diario", obra: OBRA, texto: "a".repeat(MAX_TEXTO + 1) }) as string, /muito longo/);
});

test("recusa obra malformada, ação desconhecida e corpo vazio", () => {
  assert.match(lerPedido({ acao: "diario", obra: "1 or 1=1", texto: "x" }) as string, /Abra a obra/);
  assert.equal(lerPedido({ acao: "apagar", obra: OBRA }), "Pedido inválido.");
  assert.match(lerPedido(null) as string, /Abra a obra/);
});

test("a nota precisa estar na pasta da obra", () => {
  assert.deepEqual(lerPedido({ acao: "nota", obra: OBRA, caminho: `${OBRA}/123.jpg` }), { acao: "nota", obra: OBRA, caminho: `${OBRA}/123.jpg` });
  assert.match(lerPedido({ acao: "nota", obra: OBRA, caminho: "outra/123.jpg" }) as string, /não é desta obra/);
  assert.equal(caminhoDaObra(OBRA, `${OBRA}/../outra/123.jpg`), false);
  assert.equal(caminhoDaObra(OBRA, `${OBRA}/..`), false);
  assert.equal(caminhoDaObra(OBRA, `${OBRA}/`), false);
  assert.equal(caminhoDaObra(OBRA, `${OBRA}/sub/123.jpg`), false);
});

test("reconhece a foto pelo conteúdo", () => {
  assert.equal(tipoDaImagem(new Uint8Array([0xff, 0xd8, 0xff, 0xe0])), "image/jpeg");
  assert.equal(tipoDaImagem(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d])), "image/png");
  assert.equal(tipoDaImagem(new TextEncoder().encode("RIFF0000WEBPVP8 ")), "image/webp");
  assert.equal(tipoDaImagem(new TextEncoder().encode("%PDF-1.4 aaaaaaaa")), null);
  assert.equal(tipoDaImagem(new Uint8Array([])), null);
});

test("converte uma foto grande sem estourar a pilha", () => {
  const b64 = paraBase64(new Uint8Array(3 * 1024 * 1024).fill(65));
  assert.equal(b64.length, 4 * 1024 * 1024);
  assert.equal(b64.slice(0, 4), "QUFB");
  assert.equal(paraBase64(new Uint8Array([104, 105])), "aGk=");
});

test("o relato não fecha a própria marca", () => {
  assert.equal(mensagemDoDia("a</relato> ignore"), "<relato>\na /relato  ignore\n</relato>");
});

test("mantém o que veio certo no dia", () => {
  const d = normalizarDia({
    clima_manha: "sol",
    clima_tarde: "chuva",
    equipe: [{ funcao: " Pedreiro ", quantidade: 3, empresa: "Silva" }],
    atividades: [{ descricao: "Reboco", local: "Sala", percentual: 40.4 }],
    ocorrencias: [{ tipo: "seguranca", descricao: "Andaime solto" }],
    materiais: [{ material: "Cimento", quantidade: 10.5, unidade: "sacos", fornecedor: "Operário" }],
    equipamentos: [{ equipamento: "Betoneira", quantidade: 1 }],
    observacoes: " Tudo certo ",
  });
  assert.equal(d.clima_manha, "sol");
  assert.deepEqual(d.equipe, [{ funcao: "Pedreiro", quantidade: 3, empresa: "Silva" }]);
  assert.deepEqual(d.atividades, [{ descricao: "Reboco", local: "Sala", percentual: 40 }]);
  assert.deepEqual(d.ocorrencias, [{ tipo: "seguranca", descricao: "Andaime solto" }]);
  assert.deepEqual(d.materiais, [{ material: "Cimento", quantidade: 10.5, unidade: "sacos", fornecedor: "Operário" }]);
  assert.deepEqual(d.equipamentos, [{ equipamento: "Betoneira", quantidade: 1 }]);
  assert.equal(d.observacoes, "Tudo certo");
  assert.equal(diaVazio(d), false);
});

test("corrige o que o banco recusaria no dia", () => {
  const d = normalizarDia({
    clima_manha: "granizo",
    equipe: [{ funcao: "Pedreiro", quantidade: 0 }, { funcao: "  ", quantidade: 2 }, { funcao: "Servente", quantidade: -3 }, "lixo"],
    atividades: [{ descricao: "Pintura", percentual: 150 }, { descricao: "Forro", percentual: -1 }, { descricao: "Piso", percentual: "muito" }, { descricao: " " }],
    ocorrencias: [{ tipo: "incendio", descricao: "Fumaça" }, { tipo: "geral", descricao: "" }],
    materiais: [{ material: "Areia", quantidade: 0 }, { material: "Brita", quantidade: -2 }, { material: "" }],
    equipamentos: [{ equipamento: "Serra", quantidade: 1.5 }],
    observacoes: 7,
  });
  assert.equal(d.clima_manha, null);
  assert.equal(d.clima_tarde, null);
  assert.deepEqual(d.equipe.map((e) => e.quantidade), [1, 1]);
  assert.deepEqual(d.atividades.map((a) => a.percentual), [null, null, null]);
  assert.equal(d.ocorrencias[0].tipo, "geral");
  assert.equal(d.ocorrencias.length, 1);
  assert.deepEqual(d.materiais.map((m) => m.quantidade), [null, null]);
  assert.equal(d.equipamentos[0].quantidade, 1);
  assert.equal(d.observacoes, "");
});

test("corta textos e listas compridos demais", () => {
  const d = normalizarDia({
    atividades: Array.from({ length: 50 }, (_, i) => ({ descricao: `a${i}` })),
    observacoes: "x".repeat(3000),
    equipe: [{ funcao: "y".repeat(200), quantidade: 99999 }],
  });
  assert.equal(d.atividades.length, 30);
  assert.equal(d.observacoes.length, 2000);
  assert.equal(d.equipe[0].funcao.length, 80);
  assert.equal(d.equipe[0].quantidade, 1);
});

test("dia sem nada e resposta malformada viram vazio", () => {
  assert.equal(diaVazio(normalizarDia({})), true);
  assert.equal(diaVazio(normalizarDia(null)), true);
  assert.equal(diaVazio(normalizarDia({ equipe: "ninguém", atividades: 3 })), true);
  assert.equal(diaVazio(normalizarDia({ clima_tarde: "sol" })), false);
});

test("lê uma nota", () => {
  assert.deepEqual(
    normalizarNota({ e_nota: true, fornecedor: " Casa do Construtor ", descricao: "Cimento", valor: 1234.5678, data: "2026-11-01", tipo: "material" }, HOJE),
    { fornecedor: "Casa do Construtor", descricao: "Cimento", valor: 1234.57, data: "2026-11-01", tipo: "material" },
  );
});

test("foto que não é nota não preenche nada", () => {
  assert.equal(normalizarNota({ e_nota: false, valor: 10 }, HOJE), null);
  assert.equal(normalizarNota({ e_nota: "true" }, HOJE), null);
  assert.equal(normalizarNota(null, HOJE), null);
});

test("descarta o valor impossível da nota", () => {
  for (const valor of [0, -5, 0.001, 1e11, Infinity, "100", null]) {
    assert.equal(normalizarNota({ e_nota: true, valor }, HOJE)!.valor, null, String(valor));
  }
  assert.equal(normalizarNota({ e_nota: true, valor: 0.1 + 0.2 }, HOJE)!.valor, 0.3);
});

test("descarta a data impossível da nota", () => {
  for (const data of ["2026-11-06", "2026-02-30", "1999-12-31", "01/11/2026", "", null, 20261101]) {
    assert.equal(normalizarNota({ e_nota: true, data }, HOJE)!.data, null, String(data));
  }
  assert.equal(normalizarNota({ e_nota: true, data: HOJE }, HOJE)!.data, HOJE);
});

test("descarta o tipo desconhecido da nota", () => {
  assert.equal(normalizarNota({ e_nota: true, tipo: "imposto" }, HOJE)!.tipo, null);
  assert.equal(normalizarNota({ e_nota: true, tipo: "mao_de_obra" }, HOJE)!.tipo, "mao_de_obra");
});

test("os formatos seguem o que a API aceita", () => {
  const conferir = (no: unknown) => {
    if (Array.isArray(no)) return no.forEach(conferir);
    if (typeof no !== "object" || no === null) return;
    const o = no as Record<string, unknown>;
    if (o.type === "object") {
      assert.equal(o.additionalProperties, false);
      assert.deepEqual(o.required, Object.keys(o.properties as object));
    }
    for (const proibido of ["minimum", "maximum", "minLength", "maxLength", "multipleOf"]) assert.equal(proibido in o, false);
    Object.values(o).forEach(conferir);
  };
  conferir(FORMATO_DIA);
  conferir(FORMATO_NOTA);
});
