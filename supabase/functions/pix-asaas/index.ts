// PIX automático pelo Asaas.
// { acao: "cobrar", pedido } (construtor) ou { acao: "cobrar", codigo } (link do cliente): devolve { codigo } com o copia e
// cola da cobrança, ou { codigo: null } para o aparelho usar o PIX da chave da loja. Toda falha do Asaas cai nesse caminho.
// { acao: "ligar_loja", loja, valor }: valor é a carteira ou a chave de API da loja, usada uma vez e nunca guardada.
// Precisa dos segredos ASAAS_API_KEY e, no teste, ASAAS_URL (Supabase > Edge Functions > Secrets).
// Publicada sem verificação de JWT porque o link do cliente não tem conta: o usuário é conferido aqui.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { aindaVale, corpoDaCobranca, corpoDoCliente, type Dados, ehUuid, idDaLista, lerPedido, type Pedido } from "./regras.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const URL_ASAAS = Deno.env.get("ASAAS_URL") ?? "https://api.asaas.com/v3";
const SEM_CHAVE = "Não deu para achar a carteira com essa chave. Confira se copiou a chave inteira.";

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

function usuarioDe(req: Request) {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
}

function servidor() {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
}

function asaas(chave: string, metodo: string, caminho: string, corpo?: unknown) {
  return fetch(`${URL_ASAAS}${caminho}`, {
    method: metodo,
    headers: { access_token: chave, "Content-Type": "application/json", "User-Agent": "dailyobra/1.0" },
    body: corpo === undefined ? undefined : JSON.stringify(corpo),
  });
}

/// O Asaas aceita cliente repetido, então procura pelo documento antes de criar.
async function clienteDoAsaas(chave: string, dados: Dados): Promise<string> {
  const busca = await asaas(chave, "GET", `/customers?cpfCnpj=${dados.documento}`);
  if (!busca.ok) throw new Error(`buscar cliente ${busca.status}`);
  const achado = idDaLista(await busca.json());
  if (achado) return achado;
  const criado = await asaas(chave, "POST", "/customers", corpoDoCliente(dados));
  if (!criado.ok) throw new Error(`criar cliente ${criado.status}`);
  return (await criado.json()).id;
}

async function cobrar(req: Request, pedido: Extract<Pedido, { acao: "cobrar" }>, chave: string): Promise<Response> {
  let usuario: string | null = null;
  if (pedido.codigo === null) {
    const { data: { user } } = await usuarioDe(req).auth.getUser();
    if (!user) return resposta(401, { erro: "Entre na sua conta." });
    usuario = user.id;
  }
  const banco = servidor();
  const parametros = { p_pedido: pedido.pedido, p_usuario: usuario, p_codigo: pedido.codigo };
  const { data, error } = await banco.rpc("cobranca_para_pix", parametros);
  if (error) {
    return error.code === "P0001" ? resposta(404, { erro: error.message }) : resposta(200, { codigo: null });
  }
  const dados = data as Dados | null;
  if (!dados) return resposta(200, { codigo: null });

  const agora = new Date();
  if (aindaVale(dados.aberta, dados.valor, agora)) return resposta(200, { codigo: dados.aberta.codigo });
  try {
    if (dados.aberta) {
      const removida = await asaas(chave, "DELETE", `/payments/${dados.aberta.asaas_id}`);
      if (!removida.ok && removida.status !== 404) throw new Error(`remover ${removida.status}`);
      await banco.rpc("remover_cobranca_pix", { p_asaas_id: dados.aberta.asaas_id });
    }
    const cliente = await clienteDoAsaas(chave, dados);
    const criada = await asaas(chave, "POST", "/payments", corpoDaCobranca(dados, cliente, agora));
    if (!criada.ok) throw new Error(`criar cobrança ${criada.status}`);
    const { id } = await criada.json();
    const qr = await asaas(chave, "GET", `/payments/${id}/pixQrCode`);
    if (!qr.ok) {
      await asaas(chave, "DELETE", `/payments/${id}`);
      throw new Error(`qr ${qr.status}`);
    }
    const { payload, expirationDate } = await qr.json();
    const gravou = await banco.rpc("registrar_cobranca_pix", {
      p_pedido: dados.pedido,
      p_asaas_id: id,
      p_valor: dados.valor,
      p_codigo: payload,
      p_expira: expirationDate ?? null,
    });
    if (gravou.error) throw new Error(`gravar ${gravou.error.code}`);
    if (gravou.data === true) return resposta(200, { codigo: payload });
    // Duas telas ao mesmo tempo: fica a cobrança que gravou primeiro
    await asaas(chave, "DELETE", `/payments/${id}`);
    const outra = await banco.rpc("cobranca_para_pix", parametros);
    return resposta(200, { codigo: (outra.data as Dados | null)?.aberta?.codigo ?? null });
  } catch (e) {
    // Sem dados do pagador no log: só a etapa e o status
    console.error("pix-asaas", e instanceof Error ? e.message : "falha");
    return resposta(200, { codigo: null });
  }
}

async function ligarLoja(req: Request, pedido: Extract<Pedido, { acao: "ligar_loja" }>): Promise<Response> {
  const cliente = usuarioDe(req);
  const { data: { user } } = await cliente.auth.getUser();
  if (!user) return resposta(401, { erro: "Entre na sua conta." });

  let carteira: string | null = ehUuid(pedido.valor) ? pedido.valor.toLowerCase() : null;
  if (carteira === null) {
    try {
      const contas = await asaas(pedido.valor, "GET", "/wallets/");
      carteira = contas.ok ? idDaLista(await contas.json()) : null;
    } catch {
      carteira = null;
    }
  }
  if (carteira === null) return resposta(400, { erro: SEM_CHAVE });

  // Com o cliente do usuário: a regra do banco decide quem pode gravar
  const { error } = await cliente.from("loja_asaas").upsert({ loja_id: pedido.loja, carteira });
  if (error) return resposta(403, { erro: "Só o dono ou o gerente liga o PIX automático." });
  return resposta(200, { ligada: true });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta(405, { erro: "Use POST." });

  let pedido: Pedido | string;
  try {
    pedido = lerPedido(await req.json());
  } catch {
    pedido = "Pedido inválido.";
  }
  if (typeof pedido === "string") return resposta(400, { erro: pedido });

  const chave = Deno.env.get("ASAAS_API_KEY");
  if (pedido.acao === "ligar_loja") {
    if (!chave) return resposta(503, { erro: "O PIX automático ainda não está disponível." });
    return await ligarLoja(req, pedido);
  }
  if (!chave) return resposta(200, { codigo: null });
  return await cobrar(req, pedido, chave);
});
