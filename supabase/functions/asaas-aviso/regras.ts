// Regras do aviso do Asaas, sem rede.

export type Aviso = { cobranca: string; valor: number };

/// Só o PIX recebido interessa: é quando o dinheiro já está na conta.
export function lerAviso(corpo: unknown): Aviso | null {
  const c = corpo as { event?: unknown; payment?: { id?: unknown; value?: unknown; billingType?: unknown } } | null;
  if (c?.event !== "PAYMENT_RECEIVED") return null;
  const p = c.payment;
  if (p?.billingType !== "PIX" || typeof p.id !== "string" || typeof p.value !== "number") return null;
  return { cobranca: p.id, valor: p.value };
}

/// Compara sem parar no primeiro caractere diferente, para o tempo de resposta não revelar o token.
export function tokenConfere(recebido: string | null, esperado: string): boolean {
  if (recebido === null || esperado.length === 0 || recebido.length !== esperado.length) return false;
  let diferenca = 0;
  for (let i = 0; i < esperado.length; i++) {
    diferenca |= recebido.charCodeAt(i) ^ esperado.charCodeAt(i);
  }
  return diferenca === 0;
}
