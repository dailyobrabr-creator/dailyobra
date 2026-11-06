// Testes do aviso do Asaas (sem rede). Rodar: node --test supabase/functions/asaas-aviso/regras.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";

import { lerAviso, tokenConfere } from "./regras.ts";

const recebido = { event: "PAYMENT_RECEIVED", payment: { id: "pay_1", value: 10.5, billingType: "PIX" } };

test("lê o PIX recebido", () => {
  assert.deepEqual(lerAviso(recebido), { cobranca: "pay_1", valor: 10.5 });
});

test("ignora os outros eventos", () => {
  for (const event of ["PAYMENT_CREATED", "PAYMENT_CONFIRMED", "PAYMENT_DELETED", "PAYMENT_OVERDUE"]) {
    assert.equal(lerAviso({ ...recebido, event }), null);
  }
});

test("ignora o que não é PIX", () => {
  assert.equal(lerAviso({ ...recebido, payment: { ...recebido.payment, billingType: "CREDIT_CARD" } }), null);
});

test("ignora aviso incompleto", () => {
  for (const corpo of [null, 5, {}, { event: "PAYMENT_RECEIVED" }]) assert.equal(lerAviso(corpo), null);
  assert.equal(lerAviso({ ...recebido, payment: { billingType: "PIX", value: 10 } }), null);
  assert.equal(lerAviso({ ...recebido, payment: { billingType: "PIX", id: "pay_1", value: "10" } }), null);
});

test("só aceita o token certo", () => {
  assert.equal(tokenConfere("abc123", "abc123"), true);
  assert.equal(tokenConfere("abc124", "abc123"), false);
  assert.equal(tokenConfere("abc12", "abc123"), false);
  assert.equal(tokenConfere(null, "abc123"), false);
});

test("sem token configurado ninguém entra", () => {
  assert.equal(tokenConfere("", ""), false);
});
