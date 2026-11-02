// Lê a lista de materiais de um PDF ou foto com o Claude e devolve uma linha por material,
// no formato que a lista inteligente do app já entende.
// Entrada (JSON): { nome, tipo, base64 }. Saída: { texto } ou { erro } com o status HTTP.
// Precisa do segredo ANTHROPIC_API_KEY (Supabase > Edge Functions > Secrets).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

import { contarPaginasPdf, INSTRUCOES, limparLista, MAX_PAGINAS, validarArquivo } from "./regras.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta(405, { erro: "Use POST." });

  // Cliente com o usuário da requisição: só quem entrou na conta lê arquivos
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return resposta(401, { erro: "Entre na sua conta para ler arquivos." });

  const chave = Deno.env.get("ANTHROPIC_API_KEY");
  if (!chave) {
    return resposta(503, { erro: "A leitura de arquivos ainda não está ligada. Cole o texto da lista." });
  }

  let tipo = "";
  let base64 = "";
  try {
    const corpo = await req.json();
    tipo = String(corpo.tipo ?? "");
    base64 = String(corpo.base64 ?? "").replace(/\s/g, "");
  } catch {
    return resposta(400, { erro: "Arquivo não recebido. Tente de novo." });
  }
  const invalido = validarArquivo(tipo, base64);
  if (invalido) return resposta(400, { erro: invalido });
  if (tipo === "application/pdf") {
    const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
    if (contarPaginasPdf(bytes) > MAX_PAGINAS) {
      return resposta(400, { erro: `O PDF passa de ${MAX_PAGINAS} páginas. Envie só as páginas da lista.` });
    }
  }

  // Limite diário: o banco recusa acima de 30 leituras em 24 horas
  const { error: limite } = await supabase.rpc("registrar_leitura_lista");
  if (limite) {
    const status = limite.code === "P0001" ? 429 : 500;
    return resposta(status, { erro: limite.code === "P0001" ? limite.message : "Não deu para ler agora. Tente de novo." });
  }

  const arquivo = tipo === "application/pdf"
    ? { type: "document" as const, source: { type: "base64" as const, media_type: "application/pdf" as const, data: base64 } }
    : {
      type: "image" as const,
      source: { type: "base64" as const, media_type: tipo as "image/jpeg" | "image/png" | "image/webp", data: base64 },
    };

  const claude = new Anthropic({ apiKey: chave });
  try {
    const mensagem = await claude.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      output_config: { effort: "medium" },
      // Se um filtro de segurança recusar, a própria API tenta o modelo recomendado
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: INSTRUCOES,
      messages: [{
        role: "user",
        content: [arquivo, { type: "text", text: "Extraia a lista de materiais deste arquivo." }],
      }],
    } as Anthropic.Beta.Messages.MessageCreateParamsNonStreaming);

    if (mensagem.stop_reason === "refusal") {
      return resposta(422, { erro: "Não conseguimos ler este arquivo. Cole o texto da lista." });
    }
    const texto = mensagem.content
      .flatMap((b) => (b.type === "text" ? [b.text] : []))
      .join("\n");
    const linhas = limparLista(texto);
    if (linhas.length === 0) {
      return resposta(422, { erro: "Não encontramos materiais de construção neste arquivo." });
    }
    return resposta(200, { texto: linhas.join("\n") });
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) {
      return resposta(503, { erro: "Muitas leituras agora. Tente de novo em alguns segundos." });
    }
    if (e instanceof Anthropic.BadRequestError) {
      return resposta(400, { erro: "Não conseguimos abrir este arquivo. Confira se ele não está protegido por senha." });
    }
    if (e instanceof Anthropic.APIError) {
      console.error("Claude", e.status, e.message);
      return resposta(502, { erro: "A leitura está fora do ar. Tente mais tarde ou cole o texto da lista." });
    }
    console.error(e);
    return resposta(500, { erro: "Não deu para ler agora. Tente de novo." });
  }
});
