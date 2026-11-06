// Aviso do Asaas: PIX recebido confirma o pedido sozinho.
// Publicada sem verificação de JWT, porque quem chama é o Asaas: entra só com o token do webhook no header
// asaas-access-token, guardado no segredo ASAAS_WEBHOOK_TOKEN (Supabase > Edge Functions > Secrets).
// Responde 200 para o que não interessa, porque erro repetido pausa a fila de avisos do Asaas.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { type Aviso, lerAviso, tokenConfere } from "./regras.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("ok");
  const token = Deno.env.get("ASAAS_WEBHOOK_TOKEN") ?? "";
  if (!tokenConfere(req.headers.get("asaas-access-token"), token)) {
    return new Response("negado", { status: 401 });
  }

  let aviso: Aviso | null;
  try {
    aviso = lerAviso(await req.json());
  } catch {
    aviso = null;
  }
  if (aviso === null) return new Response("ignorado");

  const banco = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await banco.rpc("confirmar_pix_asaas", { p_asaas_id: aviso.cobranca, p_valor: aviso.valor });
  if (error) {
    // Erro no banco: o Asaas tenta de novo
    console.error("asaas-aviso", error.code);
    return new Response("erro", { status: 500 });
  }
  console.log("asaas-aviso", data);
  return new Response("ok");
});
