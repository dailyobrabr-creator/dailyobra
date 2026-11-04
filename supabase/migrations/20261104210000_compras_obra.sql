-- Compras da obra. Cada obra passa a ter a própria lista de materiais, que nasce do orçamento e o responsável ajusta. Dela saem o
-- que comprar nos próximos dias, o saldo (previsto, comprado, recebido) e a conferência do que chegou na obra.
-- Quem cuida das compras: responsável, mestre e estagiário. Quantidades, sem preço pago: valor continua só com o responsável.

create function private.cuida_das_compras(p_obra uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.obra_membros m
    where m.obra_id = p_obra and m.user_id = (select auth.uid()) and m.funcao in ('responsavel', 'mestre', 'estagiario')
  );
$$;

create table public.obra_materiais (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  etapa text check (etapa ~ '^[a-z0-9_]{1,60}$'),
  item_id text references public.catalogo_itens (id) on delete set null,
  nome text not null check (char_length(btrim(nome)) between 1 and 160),
  unidade text not null check (char_length(btrim(unidade)) between 1 and 20),
  quantidade numeric(14, 3) not null check (quantidade > 0),
  preco_base numeric(12, 2) check (preco_base >= 0),
  criado_em timestamptz not null default now()
);
create index obra_materiais_obra_idx on public.obra_materiais (obra_id);
alter table public.obra_materiais enable row level security;
create policy "compras leem materiais" on public.obra_materiais for select to authenticated
  using (private.cuida_das_compras(obra_id));

create table public.obra_recebimentos (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  pedido_id uuid references public.pedidos (id) on delete set null,
  item_id text references public.catalogo_itens (id) on delete set null,
  nome text not null check (char_length(btrim(nome)) between 1 and 160),
  unidade text not null check (char_length(btrim(unidade)) between 1 and 20),
  quantidade numeric(14, 3) not null check (quantidade > 0),
  data date not null,
  observacao text check (char_length(observacao) <= 300),
  foto_path text,
  criado_por uuid default auth.uid() references auth.users (id) on delete set null,
  criado_em timestamptz not null default now()
);
create index obra_recebimentos_obra_idx on public.obra_recebimentos (obra_id, data desc);
alter table public.obra_recebimentos enable row level security;
create policy "compras leem recebimentos" on public.obra_recebimentos for select to authenticated
  using (private.cuida_das_compras(obra_id));

-- Troca a lista inteira de uma vez: é o que acontece ao montar a lista a partir do orçamento
create function public.salvar_materiais(p_obra uuid, p_itens jsonb) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre montam a lista de materiais.' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_itens) is distinct from 'array' then
    raise exception 'Lista inválida.' using errcode = 'P0001';
  end if;
  if jsonb_array_length(p_itens) > 1000 then
    raise exception 'Lista grande demais.' using errcode = 'P0001';
  end if;
  delete from public.obra_materiais where obra_id = p_obra;
  insert into public.obra_materiais (obra_id, etapa, item_id, nome, unidade, quantidade, preco_base)
  select p_obra, nullif(e ->> 'etapa', ''), nullif(e ->> 'item_id', ''), btrim(e ->> 'nome'), btrim(e ->> 'unidade'),
         (e ->> 'quantidade')::numeric, (e ->> 'preco_base')::numeric
    from jsonb_array_elements(p_itens) e;
end $$;

create function public.salvar_material(p_obra uuid, p_id uuid, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  texto text := btrim(coalesce(d ->> 'nome', ''));
  medida text := btrim(coalesce(d ->> 'unidade', ''));
  q numeric := (d ->> 'quantidade')::numeric;
  novo uuid;
begin
  if not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre mexem na lista de materiais.' using errcode = 'P0001';
  end if;
  if texto = '' then raise exception 'Diga qual é o material.' using errcode = 'P0001'; end if;
  if medida = '' then raise exception 'Diga a unidade do material.' using errcode = 'P0001'; end if;
  if q is null or q <= 0 then raise exception 'Digite uma quantidade maior que zero.' using errcode = 'P0001'; end if;
  if p_id is null then
    insert into public.obra_materiais (obra_id, etapa, item_id, nome, unidade, quantidade, preco_base)
    values (p_obra, nullif(d ->> 'etapa', ''), nullif(d ->> 'item_id', ''), texto, medida, q, (d ->> 'preco_base')::numeric)
    returning id into novo;
    return novo;
  end if;
  update public.obra_materiais
     set etapa = nullif(d ->> 'etapa', ''), item_id = nullif(d ->> 'item_id', ''), nome = texto, unidade = medida, quantidade = q,
         preco_base = (d ->> 'preco_base')::numeric
   where id = p_id and obra_id = p_obra;
  if not found then raise exception 'Material não encontrado.' using errcode = 'P0001'; end if;
  return p_id;
end $$;

create function public.excluir_material(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare alvo uuid;
begin
  select obra_id into alvo from public.obra_materiais where id = p_id;
  if alvo is null or not coalesce(private.lidera_obra(alvo), false) then
    raise exception 'Material não encontrado.' using errcode = 'P0001';
  end if;
  delete from public.obra_materiais where id = p_id;
end $$;

-- O que foi pedido para a obra, sem preço: o mestre confere a entrega, mas valor é com o responsável
create function public.itens_dos_pedidos(p_obra uuid)
returns table (pedido_id uuid, loja text, situacao text, data date, item_id text, nome text, unidade text, quantidade numeric)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not coalesce(private.cuida_das_compras(p_obra), false) then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select p.id, l.nome, p.status, (p.criado_em at time zone 'America/Sao_Paulo')::date, i.item_id, i.nome, i.unidade, i.quantidade::numeric
      from public.pedidos p
      join public.propostas pr on pr.id = p.proposta_id
      join public.orcamentos o on o.id = pr.orcamento_id
      join public.lojas l on l.id = p.loja_id
      join public.proposta_itens i on i.proposta_id = pr.id
     where o.obra_id = p_obra and p.status <> 'cancelado'
     order by p.criado_em desc, i.nome;
end $$;

-- Sem pedido, é material comprado fora do app: conta como comprado e recebido ao mesmo tempo
create function public.registrar_recebimento(
  p_obra uuid, p_pedido uuid, p_itens jsonb, p_data date default null, p_observacao text default null, p_foto text default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  dia date := coalesce(p_data, hoje);
  obs text := nullif(btrim(coalesce(p_observacao, '')), '');
  e jsonb;
begin
  if not coalesce(private.cuida_das_compras(p_obra), false) then
    raise exception 'Só quem cuida das compras registra o que chegou.' using errcode = 'P0001';
  end if;
  if p_pedido is not null and not exists (
    select 1 from public.pedidos p
      join public.propostas pr on pr.id = p.proposta_id
      join public.orcamentos o on o.id = pr.orcamento_id
     where p.id = p_pedido and o.obra_id = p_obra and p.status <> 'cancelado'
  ) then
    raise exception 'Pedido não encontrado nesta obra.' using errcode = 'P0001';
  end if;
  if dia > hoje + 1 then raise exception 'A data não pode estar no futuro.' using errcode = 'P0001'; end if;
  if char_length(obs) > 300 then raise exception 'Use no máximo 300 letras.' using errcode = 'P0001'; end if;
  if p_foto is not null and left(p_foto, 37) <> p_obra::text || '/' then
    raise exception 'Foto de outra obra.' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_itens) is distinct from 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Informe pelo menos um material.' using errcode = 'P0001';
  end if;
  for e in select * from jsonb_array_elements(p_itens) loop
    if btrim(coalesce(e ->> 'nome', '')) = '' or btrim(coalesce(e ->> 'unidade', '')) = '' then
      raise exception 'Informe o material e a unidade.' using errcode = 'P0001';
    end if;
    if coalesce((e ->> 'quantidade')::numeric, 0) <= 0 then
      raise exception 'Digite uma quantidade maior que zero.' using errcode = 'P0001';
    end if;
    insert into public.obra_recebimentos (obra_id, pedido_id, item_id, nome, unidade, quantidade, data, observacao, foto_path)
    values (p_obra, p_pedido, nullif(e ->> 'item_id', ''), btrim(e ->> 'nome'), btrim(e ->> 'unidade'), (e ->> 'quantidade')::numeric, dia, obs, p_foto);
  end loop;
end $$;

-- Devolve o caminho da foto, para o app apagar o arquivo se ninguém mais usar
create function public.excluir_recebimento(p_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare atual public.obra_recebimentos;
begin
  select * into atual from public.obra_recebimentos where id = p_id for update;
  if not found or not coalesce(private.cuida_das_compras(atual.obra_id), false) then
    raise exception 'Recebimento não encontrado.' using errcode = 'P0001';
  end if;
  if not coalesce(private.lidera_obra(atual.obra_id), false) and not coalesce(atual.criado_por = (select auth.uid()), false) then
    raise exception 'Só quem registrou ou quem lidera a obra exclui.' using errcode = 'P0001';
  end if;
  delete from public.obra_recebimentos where id = p_id;
  if exists (select 1 from public.obra_recebimentos r where r.foto_path = atual.foto_path) then return null; end if;
  return atual.foto_path;
end $$;

revoke execute on function public.salvar_materiais(uuid, jsonb) from public, anon;
revoke execute on function public.salvar_material(uuid, uuid, jsonb) from public, anon;
revoke execute on function public.excluir_material(uuid) from public, anon;
revoke execute on function public.itens_dos_pedidos(uuid) from public, anon;
revoke execute on function public.registrar_recebimento(uuid, uuid, jsonb, date, text, text) from public, anon;
revoke execute on function public.excluir_recebimento(uuid) from public, anon;
grant execute on function public.salvar_materiais(uuid, jsonb) to authenticated;
grant execute on function public.salvar_material(uuid, uuid, jsonb) to authenticated;
grant execute on function public.excluir_material(uuid) to authenticated;
grant execute on function public.itens_dos_pedidos(uuid) to authenticated;
grant execute on function public.registrar_recebimento(uuid, uuid, jsonb, date, text, text) to authenticated;
grant execute on function public.excluir_recebimento(uuid) to authenticated;
