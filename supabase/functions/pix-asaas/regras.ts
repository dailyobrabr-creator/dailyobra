// Regras do PIX automático pelo Asaas, sem rede.

export const DIAS_PARA_PAGAR = 3;
const MARGEM_MS = 60 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Pedido =
  | { acao: "cobrar"; pedido: string | null; codigo: string | null }
  | { acao: "ligar_loja"; loja: string; valor: string };

export type Aberta = { asaas_id: string; valor: number; codigo: string; expira_em: string | null };

export type Dados = {
  pedido: string;
  valor: number;
  nome: string | null;
  documento: string;
  carteira: string;
  aberta: Aberta | null;
};

export function ehUuid(valor: unknown): valor is string {
  return typeof valor === "string" && UUID.test(valor);
}

/// Devolve o pedido ou a mensagem de erro.
export function lerPedido(corpo: unknown): Pedido | string {
  if (typeof corpo !== "object" || corpo === null) return "Pedido inválido.";
  const c = corpo as Record<string, unknown>;
  if (c.acao === "ligar_loja") {
    const valor = typeof c.valor === "string" ? c.valor.trim() : "";
    if (!ehUuid(c.loja) || valor.length === 0 || valor.length > 300) return "Cole a chave de API do Asaas.";
    return { acao: "ligar_loja", loja: c.loja, valor };
  }
  if (c.acao !== "cobrar") return "Pedido inválido.";
  if (typeof c.codigo === "string" && c.codigo.length > 0 && c.codigo.length <= 64) {
    return { acao: "cobrar", pedido: null, codigo: c.codigo };
  }
  if (ehUuid(c.pedido)) return { acao: "cobrar", pedido: c.pedido, codigo: null };
  return "Pedido inválido.";
}

const centavos = (valor: number) => Math.round(valor * 100);

/// A cobrança aberta ainda serve: mesmo valor e sem expirar na próxima hora.
export function aindaVale(aberta: Aberta | null, valor: number, agora: Date): aberta is Aberta {
  if (aberta === null || centavos(aberta.valor) !== centavos(valor)) return false;
  return aberta.expira_em === null || new Date(aberta.expira_em).getTime() > agora.getTime() + MARGEM_MS;
}

/// Vencimento no fuso do Brasil: perto da meia-noite a data do servidor já seria a do dia seguinte.
export function vencimento(agora: Date): string {
  const hoje = new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(agora);
  const dia = new Date(`${hoje}T12:00:00Z`);
  dia.setUTCDate(dia.getUTCDate() + DIAS_PARA_PAGAR);
  return dia.toISOString().slice(0, 10);
}

/// `notificationDisabled`: quem avisa o cliente é o DailyObra, não o Asaas.
export function corpoDoCliente(dados: Dados) {
  return { name: dados.nome?.trim() || "Cliente DailyObra", cpfCnpj: dados.documento, notificationDisabled: true };
}

/// O split é sobre o valor depois da tarifa: a carteira da loja recebe todo o líquido.
export function corpoDaCobranca(dados: Dados, cliente: string, agora: Date) {
  return {
    customer: cliente,
    billingType: "PIX",
    value: dados.valor,
    dueDate: vencimento(agora),
    description: `Pedido DO${dados.pedido.slice(0, 8).toUpperCase()}`,
    externalReference: dados.pedido,
    split: [{ walletId: dados.carteira, percentualValue: 100 }],
  };
}

export function idDaLista(resposta: unknown): string | null {
  const lista = (resposta as { data?: unknown } | null)?.data;
  if (!Array.isArray(lista)) return null;
  const id = (lista[0] as { id?: unknown } | undefined)?.id;
  return typeof id === "string" && id.length > 0 ? id : null;
}
