// Ajudas da IA na obra: organiza o relato do dia nos campos do diário e lê a foto de uma nota para lançar um gasto.
// Entrada (JSON): { acao: "diario", obra, texto } ou { acao: "nota", obra, caminho }. Saída: { dia } ou { nota }, ou { erro } com o status.
// A resposta só preenche o formulário: quem usa confere antes de salvar. Não registra o texto nem a foto em log.
// Precisa do segredo ANTHROPIC_API_KEY (Supabase > Edge Functions > Secrets).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

import {
  diaVazio,
  FORMATO_DIA,
  FORMATO_NOTA,
  INSTRUCOES_DIA,
  INSTRUCOES_NOTA,
  lerPedido,
  MAX_BYTES,
  mensagemDoDia,
  normalizarDia,
  normalizarNota,
  paraBase64,
  type Pedido,
  tipoDaImagem,
} from "./regras.ts";

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

  // Cliente com o usuário da requisição: a nota só abre para quem pode ver a nota
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return resposta(401, { erro: "Entre na sua conta para usar a IA." });

  const chave = Deno.env.get("ANTHROPIC_API_KEY");
  if (!chave) return resposta(503, { erro: "A IA ainda não está ligada. Preencha à mão." });

  let pedido: Pedido | string;
  try {
    pedido = lerPedido(await req.json());
  } catch {
    pedido = "Pedido inválido.";
  }
  if (typeof pedido === "string") return resposta(400, { erro: pedido });

  // A foto vem antes do limite: uma foto que não abre não gasta o uso do dia
  let conteudo: Anthropic.Beta.Messages.BetaContentBlockParam[];
  if (pedido.acao === "diario") {
    conteudo = [{ type: "text", text: mensagemDoDia(pedido.texto) }];
  } else {
    const { data: arquivo, error } = await supabase.storage.from("obra-notas").download(pedido.caminho);
    if (error || !arquivo) return resposta(404, { erro: "Não achamos esta nota. Envie a foto de novo." });
    if (arquivo.size > MAX_BYTES) return resposta(400, { erro: "Esta foto passou de 5 MB. Escolha outra." });
    const bytes = new Uint8Array(await arquivo.arrayBuffer());
    const tipo = tipoDaImagem(bytes);
    if (!tipo) return resposta(400, { erro: "Envie uma foto JPG, PNG ou WEBP." });
    conteudo = [
      { type: "image", source: { type: "base64", media_type: tipo, data: paraBase64(bytes) } },
      { type: "text", text: "Extraia os dados desta foto." },
    ];
  }

  // Quem pode pedir e quanto: o banco recusa acima de 30 usos em 24 horas
  const { error: limite } = await supabase.rpc("registrar_uso_ia", { p_obra: pedido.obra, p_tipo: pedido.acao });
  if (limite) {
    return limite.code === "P0001"
      ? resposta(429, { erro: limite.message })
      : resposta(500, { erro: "Não deu para usar a IA agora. Tente de novo." });
  }

  const claude = new Anthropic({ apiKey: chave });
  try {
    const mensagem = await claude.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      output_config: {
        effort: "medium",
        format: { type: "json_schema", schema: pedido.acao === "diario" ? FORMATO_DIA : FORMATO_NOTA },
      },
      // Se um filtro de segurança recusar, a própria API tenta o modelo recomendado
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: pedido.acao === "diario" ? INSTRUCOES_DIA : INSTRUCOES_NOTA,
      messages: [{ role: "user", content: conteudo }],
    } as Anthropic.Beta.Messages.MessageCreateParamsNonStreaming);

    if (mensagem.stop_reason === "refusal" || mensagem.stop_reason === "max_tokens") {
      return resposta(422, { erro: "A IA não conseguiu organizar isto. Preencha à mão." });
    }
    const json = mensagem.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
    const dados = JSON.parse(json);

    if (pedido.acao === "diario") {
      const dia = normalizarDia(dados);
      if (diaVazio(dia)) return resposta(422, { erro: "Não encontramos o que registrar neste texto." });
      return resposta(200, { dia });
    }
    const nota = normalizarNota(dados, new Date().toISOString().slice(0, 10));
    if (!nota) return resposta(422, { erro: "Esta foto não parece uma nota. Preencha à mão." });
    return resposta(200, { nota });
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) {
      return resposta(503, { erro: "Muitos pedidos agora. Tente de novo em alguns segundos." });
    }
    if (e instanceof Anthropic.BadRequestError) {
      console.error("Claude", e.status, e.message);
      return resposta(400, { erro: "A IA não conseguiu abrir isto. Preencha à mão." });
    }
    if (e instanceof Anthropic.APIError) {
      console.error("Claude", e.status, e.message);
      return resposta(502, { erro: "A IA está fora do ar. Tente mais tarde ou preencha à mão." });
    }
    // Sem o erro inteiro no log: uma resposta malformada pode trazer o texto da pessoa
    console.error("ia-obra", e instanceof Error ? e.name : "erro");
    return resposta(500, { erro: "Não deu para usar a IA agora. Tente de novo." });
  }
});
