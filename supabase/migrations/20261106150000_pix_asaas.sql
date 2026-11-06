-- PIX automático pelo Asaas: a cobrança sai da conta do DailyObra e o líquido vai para a carteira Asaas da loja (split).
-- O aviso do Asaas confirma o pedido sozinho. Loja sem carteira segue com o PIX da própria chave, confirmado à mão.

-- Carteira da loja no Asaas. Não é segredo: só diz para onde o dinheiro vai.
create table public.loja_asaas (
  loja_id uuid primary key references public.lojas (id) on delete cascade,
  carteira text not null check (carteira ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
  ligada_em timestamptz not null default now()
);
alter table public.loja_asaas enable row level security;
create policy "equipe ve a carteira" on public.loja_asaas for select to authenticated
  using (private.membro_loja(loja_id) is not null);
create policy "dono e gerente gravam a carteira" on public.loja_asaas for all to authenticated
  using (coalesce(private.pode_gerir_loja(loja_id), false)) with check (coalesce(private.pode_gerir_loja(loja_id), false));
revoke all on public.loja_asaas from anon;
revoke truncate on public.loja_asaas from authenticated;

-- Cobranças criadas no Asaas. Sem política: só o servidor lê.
create table public.pedido_cobrancas (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  asaas_id text not null unique,
  valor numeric(12, 2) not null check (valor > 0),
  codigo text not null,
  expira_em timestamptz,
  situacao text not null default 'aberta' check (situacao in ('aberta', 'paga', 'removida')),
  criada_em timestamptz not null default now(),
  paga_em timestamptz
);
create unique index pedido_cobrancas_uma_aberta on public.pedido_cobrancas (pedido_id) where situacao = 'aberta';
alter table public.pedido_cobrancas enable row level security;
revoke all on public.pedido_cobrancas from anon, authenticated;

-- O que o servidor precisa para cobrar. O documento nunca volta para o aparelho: só o servidor chama.
-- Nulo: este pedido fica no PIX da chave da loja.
create function public.cobranca_para_pix(p_pedido uuid, p_usuario uuid, p_codigo text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare pe public.pedidos; v_carteira text; v_documento text; c public.pedido_cobrancas;
begin
  if p_codigo is not null then
    select * into pe from public.pedidos where link_codigo = p_codigo;
  else
    select * into pe from public.pedidos where id = p_pedido and construtor_id = p_usuario;
  end if;
  if not found then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if private.situacao_pagamento(pe) in ('pago', 'cancelado') or pe.documento_informado_em is null or pe.total <= 0 then
    return null;
  end if;
  select a.carteira into v_carteira from public.loja_asaas a where a.loja_id = pe.loja_id;
  select d.documento into v_documento from public.pedido_documentos d where d.pedido_id = pe.id;
  if v_carteira is null or v_documento is null then return null; end if;
  select * into c from public.pedido_cobrancas where pedido_id = pe.id and situacao = 'aberta';
  return jsonb_build_object(
    'pedido', pe.id, 'valor', pe.total, 'nome', pe.pagador_nome, 'documento', v_documento, 'carteira', v_carteira,
    'aberta', case when c.id is null then null
      else jsonb_build_object('asaas_id', c.asaas_id, 'valor', c.valor, 'codigo', c.codigo, 'expira_em', c.expira_em) end);
end $$;

-- Falso: outra chamada gravou primeiro; quem perdeu apaga a cobrança que criou.
create function public.registrar_cobranca_pix(p_pedido uuid, p_asaas_id text, p_valor numeric, p_codigo text, p_expira timestamptz)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  insert into public.pedido_cobrancas (pedido_id, asaas_id, valor, codigo, expira_em)
  values (p_pedido, p_asaas_id, p_valor, p_codigo, p_expira)
  on conflict (pedido_id) where situacao = 'aberta' do nothing;
  return found;
end $$;

create function public.remover_cobranca_pix(p_asaas_id text) returns void
language sql security definer set search_path = '' as $$
  update public.pedido_cobrancas set situacao = 'removida' where asaas_id = p_asaas_id and situacao = 'aberta';
$$;

-- Dinheiro recebido. Devolve o que aconteceu, e o aviso repetido não muda nada.
-- Vale o total de agora: valor menor (o pedido subiu depois da cobrança) fica para a loja conferir.
create function public.confirmar_pix_asaas(p_asaas_id text, p_valor numeric) returns text
language plpgsql security definer set search_path = '' as $$
declare c public.pedido_cobrancas; pe public.pedidos;
begin
  select * into c from public.pedido_cobrancas where asaas_id = p_asaas_id for update;
  if not found then return 'desconhecida'; end if;
  if c.situacao = 'paga' then return 'repetido'; end if;
  update public.pedido_cobrancas set situacao = 'paga', paga_em = now() where id = c.id;
  select * into pe from public.pedidos where id = c.pedido_id for update;
  if pe.status = 'cancelado' then return 'pedido_cancelado'; end if;
  if pe.pagamento_confirmado_em is not null then return 'ja_confirmado'; end if;
  if p_valor is null or p_valor < pe.total then return 'valor_menor'; end if;
  update public.pedidos set pagamento_confirmado_em = now(), forma_pagamento = 'pix',
    prazo = null, prazo_status = null, prazo_respondido_em = null
   where id = pe.id;
  insert into public.pedido_eventos (pedido_id, de, para, autor) values (pe.id, pe.status, 'pagamento_confirmado', null);
  if pe.status = 'entregue' then perform private.liberar_cashback(pe.id); end if;
  return 'confirmado';
end $$;

revoke all on function public.cobranca_para_pix(uuid, uuid, text), public.registrar_cobranca_pix(uuid, text, numeric, text, timestamptz),
  public.remover_cobranca_pix(text), public.confirmar_pix_asaas(text, numeric) from public, anon, authenticated;
grant execute on function public.cobranca_para_pix(uuid, uuid, text), public.registrar_cobranca_pix(uuid, text, numeric, text, timestamptz),
  public.remover_cobranca_pix(text), public.confirmar_pix_asaas(text, numeric) to service_role;
