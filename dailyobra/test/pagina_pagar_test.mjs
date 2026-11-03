// Testes da página do cliente (dailyobra/web/pagar/index.html) sem navegador: o script da página roda num
// contexto do Node com o pouco de DOM que ele usa ao abrir sem código de link.
// Rodar na raiz do repositório: node --test dailyobra/test/pagina_pagar_test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync(new URL('../web/pagar/index.html', import.meta.url), 'utf8');
const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]).join('\n');
const pagina = vm.createContext({ URLSearchParams, location: { search: '' }, document: { getElementById: () => ({}) } });
vm.runInContext(script, pagina);

const pedido = (extra = {}) => ({
  loja: { nome: 'Loja', cidade: 'Rondonópolis', uf: 'MT', whatsapp: '5566999990000', whatsapp_link: 'https://wa.me/5566999990000' },
  itens: [{ nome: 'Cimento', quantidade: 10, unidade: 'saco', preco: 45, total: 450 }],
  desconto: 0, frete: 0, total: 450, situacao: 'aguardando_dados', pagador_nome: 'Ana', documento_informado: false, pix: null,
  ...extra,
});

test('Falar com a loja usa o link pronto do banco, com o 55 uma vez só', () => {
  const resumo = pagina.resumo(pedido());
  assert.match(resumo, /href="https:\/\/wa\.me\/5566999990000"/);
  assert.doesNotMatch(resumo, /wa\.me\/5555/);
});

test('loja sem WhatsApp não mostra Falar com a loja', () => {
  const semZap = pedido({ loja: { nome: 'Loja', cidade: 'Rondonópolis', uf: 'MT', whatsapp: null, whatsapp_link: null } });
  assert.doesNotMatch(pagina.resumo(semZap), /Falar com a loja/);
});

test('cada situação abre a tela certa', () => {
  assert.equal(pagina.tela(pedido()), 'formulario');
  assert.equal(pagina.tela(pedido({ situacao: 'aguardando_pagamento', documento_informado: true, pix: '000201' })), 'pagamento');
  assert.equal(pagina.tela(pedido({ situacao: 'informado', documento_informado: true })), 'informado');
  assert.equal(pagina.tela(pedido({ situacao: 'pago', documento_informado: true })), 'pago');
  assert.equal(pagina.tela(pedido({ situacao: 'cancelado' })), 'cancelado');
});

test('dados enviados e loja sem chave PIX não voltam ao formulário', () => {
  assert.equal(pagina.tela(pedido({ situacao: 'aguardando_pagamento', documento_informado: true, pix: null })), 'sem_chave');
});

const comPix = (extra = {}) => pedido({ situacao: 'aguardando_pagamento', documento_informado: true, pix: '000201', ...extra });

test('pagamento mostra o documento mascarado e Corrigir', () => {
  const html = pagina.pagamento(comPix({ documento_mascarado: '***.982.247-**' }));
  assert.ok(html.includes('Nota no CPF/CNPJ ***.982.247-**'));
  assert.match(html, /id="corrigir"/);
  assert.ok(pagina.pagamento(comPix({ documento_mascarado: '<i>' })).includes('Nota no CPF/CNPJ &lt;i&gt;'));
});

test('sem documento mascarado não há Corrigir', () => {
  const html = pagina.pagamento(comPix());
  assert.doesNotMatch(html, /Nota no CPF\/CNPJ/);
  assert.doesNotMatch(html, /id="corrigir"/);
});

test('Corrigir volta ao formulário', () => {
  assert.equal(pagina.tela(comPix(), true), 'formulario');
  assert.equal(pagina.tela(comPix()), 'pagamento');
  assert.equal(pagina.tela(pedido({ situacao: 'informado', documento_informado: true }), true), 'informado');
  assert.match(pagina.formulario(comPix(), true), /id="voltar"/);
  assert.doesNotMatch(pagina.formulario(pedido()), /id="voltar"/);
});
