// Testes das regras do PIX automático (sem rede). Rodar: node --test supabase/functions/pix-asaas/regras.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";

import {
  aindaVale,
  corpoDaCobranca,
  corpoDoCliente,
  type Dados,
  ehUuid,
  idDaLista,
  lerPedido,
  vencimento,
} from "./regras.ts";

const id = "6ae57008-1111-4222-8333-444455556666";
const carteira = "7bafd95a-e783-4a62-9be1-23999af742c6";
const agora = new Date("2026-11-06T15:00:00Z");
const dados: Dados = { pedido: id, valor: 10, nome: "Ana", documento: "52998224725", carteira, aberta: null };

test("lê o pedido do construtor e o do link", () => {
  assert.deepEqual(lerPedido({ acao: "cobrar", pedido: id }), { acao: "cobrar", pedido: id, codigo: null });
  assert.deepEqual(lerPedido({ acao: "cobrar", codigo: "ABC" }), { acao: "cobrar", pedido: null, codigo: "ABC" });
});

test("o código do link vale mesmo com um pedido junto", () => {
  assert.deepEqual(lerPedido({ acao: "cobrar", pedido: id, codigo: "ABC" }), { acao: "cobrar", pedido: null, codigo: "ABC" });
});

test("recusa pedido sem identificação", () => {
  for (const corpo of [null, 5, {}, { acao: "x" }, { acao: "cobrar" }, { acao: "cobrar", pedido: "1" }, { acao: "cobrar", codigo: "x".repeat(65) }]) {
    assert.equal(lerPedido(corpo), "Pedido inválido.");
  }
});

test("ligar a loja pede loja e chave", () => {
  assert.deepEqual(lerPedido({ acao: "ligar_loja", loja: id, valor: "  $aact_x  " }), { acao: "ligar_loja", loja: id, valor: "$aact_x" });
  assert.equal(lerPedido({ acao: "ligar_loja", loja: id, valor: "  " }), "Cole a chave de API do Asaas.");
  assert.equal(lerPedido({ acao: "ligar_loja", loja: "1", valor: "x" }), "Cole a chave de API do Asaas.");
});

test("reconhece a carteira", () => {
  assert.equal(ehUuid(carteira), true);
  assert.equal(ehUuid("$aact_prod_abc"), false);
  assert.equal(ehUuid(null), false);
});

test("cobrança aberta serve com o mesmo valor", () => {
  const aberta = { asaas_id: "pay_1", valor: 10, codigo: "x", expira_em: "2026-11-09T15:00:00Z" };
  assert.equal(aindaVale(aberta, 10, agora), true);
  assert.equal(aindaVale({ ...aberta, expira_em: null }, 10, agora), true);
});

test("sem cobrança aberta, com outro valor ou perto de expirar, cria outra", () => {
  const aberta = { asaas_id: "pay_1", valor: 10, codigo: "x", expira_em: "2026-11-09T15:00:00Z" };
  assert.equal(aindaVale(null, 10, agora), false);
  assert.equal(aindaVale(aberta, 9.99, agora), false);
  assert.equal(aindaVale({ ...aberta, expira_em: "2026-11-06T15:30:00Z" }, 10, agora), false);
});

test("centavo de arredondamento não troca a cobrança", () => {
  const aberta = { asaas_id: "pay_1", valor: 0.1 + 0.2, codigo: "x", expira_em: null };
  assert.equal(aindaVale(aberta, 0.3, agora), true);
});

test("vencimento em três dias, no fuso do Brasil", () => {
  assert.equal(vencimento(agora), "2026-11-09");
  assert.equal(vencimento(new Date("2026-11-07T01:00:00Z")), "2026-11-09", "ainda é dia 6 no Brasil");
  assert.equal(vencimento(new Date("2026-12-30T15:00:00Z")), "2027-01-02");
});

test("o cliente vai sem aviso do Asaas", () => {
  assert.deepEqual(corpoDoCliente(dados), { name: "Ana", cpfCnpj: "52998224725", notificationDisabled: true });
  assert.equal(corpoDoCliente({ ...dados, nome: "  " }).name, "Cliente DailyObra");
  assert.equal(corpoDoCliente({ ...dados, nome: null }).name, "Cliente DailyObra");
});

test("a cobrança é PIX e manda todo o líquido para a carteira da loja", () => {
  const corpo = corpoDaCobranca(dados, "cus_1", agora);
  assert.equal(corpo.customer, "cus_1");
  assert.equal(corpo.billingType, "PIX");
  assert.equal(corpo.value, 10);
  assert.equal(corpo.dueDate, "2026-11-09");
  assert.equal(corpo.externalReference, id);
  assert.equal(corpo.description, "Pedido DO6AE57008");
  assert.deepEqual(corpo.split, [{ walletId: carteira, percentualValue: 100 }]);
});

test("pega o primeiro id da lista", () => {
  assert.equal(idDaLista({ data: [{ id: "cus_1" }, { id: "cus_2" }] }), "cus_1");
  assert.equal(idDaLista({ data: [] }), null);
  assert.equal(idDaLista({ data: [{ id: "" }] }), null);
  assert.equal(idDaLista(null), null);
});
