-- Faturamento / Caixa: o pedido é lançado à mão no Santri e a loja registra aqui o número da venda.
-- Fica fora de public.pedidos porque o construtor lê essa tabela e o número é assunto interno da loja.

create table public.pedido_faturamento (
  pedido_id uuid primary key references public.pedidos (id) on delete cascade,
  numero text not null check (char_length(numero) between 1 and 40),
  lancado_em timestamptz not null default now(),
  lancado_por uuid references auth.users (id) on delete set null
);

alter table public.pedido_faturamento enable row level security;

create policy "equipe ve faturamento" on public.pedido_faturamento
  for select to authenticated
  using (exists (
    select 1 from public.pedidos p
     where p.id = pedido_id and private.membro_loja(p.loja_id) is not null
  ));

revoke all on public.pedido_faturamento from anon;
revoke insert, update, delete, truncate on public.pedido_faturamento from authenticated;

-- Pronto para lançar: pagamento confirmado ou crediário com o prazo aprovado.
create function public.registrar_faturamento(p_pedido uuid, p_numero text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pe record;
  numero text := btrim(coalesce(p_numero, ''));
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or private.membro_loja(pe.loja_id) is null then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;
  if not coalesce(private.pode_gerir_loja(pe.loja_id), false) then
    raise exception 'Só o dono ou o gerente da loja lançam o pedido.' using errcode = 'P0001';
  end if;
  if pe.status = 'cancelado' then
    raise exception 'Pedido cancelado não vai para o faturamento.' using errcode = 'P0001';
  end if;
  if pe.pagamento_confirmado_em is null
     and not coalesce(pe.forma_pagamento = 'crediario' and pe.prazo_status = 'aprovado', false) then
    raise exception 'Confirme o pagamento ou aprove o prazo antes de lançar.' using errcode = 'P0001';
  end if;
  if numero = '' then
    raise exception 'Informe o número da venda no Santri.' using errcode = 'P0001';
  end if;
  if char_length(numero) > 40 then
    raise exception 'O número da venda tem no máximo 40 caracteres.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.pedido_faturamento f where f.pedido_id = p_pedido) then
    raise exception 'Este pedido já foi lançado.' using errcode = 'P0001';
  end if;
  insert into public.pedido_faturamento (pedido_id, numero, lancado_por)
  values (p_pedido, numero, (select auth.uid()));
  -- Atualiza o pedido para os outros painéis abertos receberem a mudança em tempo real
  update public.pedidos set atualizado_em = now() where id = p_pedido;
end $$;

-- Lançado por engano: volta para a fila.
create function public.desfazer_faturamento(p_pedido uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare pe record;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or private.membro_loja(pe.loja_id) is null then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;
  if not coalesce(private.pode_gerir_loja(pe.loja_id), false) then
    raise exception 'Só o dono ou o gerente da loja desfazem o lançamento.' using errcode = 'P0001';
  end if;
  delete from public.pedido_faturamento where pedido_id = p_pedido;
  if not found then
    raise exception 'Este pedido não está lançado.' using errcode = 'P0001';
  end if;
  update public.pedidos set atualizado_em = now() where id = p_pedido;
end $$;

revoke execute on function public.registrar_faturamento(uuid, text) from public, anon;
revoke execute on function public.desfazer_faturamento(uuid) from public, anon;
grant execute on function public.registrar_faturamento(uuid, text) to authenticated;
grant execute on function public.desfazer_faturamento(uuid) to authenticated;
