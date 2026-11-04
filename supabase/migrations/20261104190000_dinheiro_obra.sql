-- Dinheiro da obra: orçado x realizado. O realizado vem dos gastos lançados à mão e dos pedidos cujo orçamento foi feito para a obra.
-- Valor real é assunto do responsável: tudo aqui fica em tabelas e num bucket próprios, porque a equipe inteira lê obra_etapas e
-- rdo-fotos. O mestre lança gastos e vê só os que lançou; os demais não entram. O orçamento estimado continua calculado no aparelho.

create table public.obra_gastos (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  etapa text check (etapa ~ '^[a-z0-9_]{1,60}$'),
  tipo text not null default 'material' check (tipo in ('material', 'mao_de_obra', 'servico', 'outro')),
  descricao text not null check (char_length(btrim(descricao)) between 1 and 200),
  fornecedor text check (char_length(fornecedor) <= 120),
  valor numeric(12, 2) not null check (valor > 0),
  data date not null,
  nota_path text,
  criado_por uuid default auth.uid() references auth.users (id) on delete set null,
  criado_em timestamptz not null default now()
);
create index obra_gastos_obra_idx on public.obra_gastos (obra_id, data desc);
alter table public.obra_gastos enable row level security;
create policy "responsavel e autor veem gastos" on public.obra_gastos for select to authenticated
  using (private.is_admin(obra_id) or (criado_por = (select auth.uid()) and private.lidera_obra(obra_id)));

-- Valor que o responsável digitou para a etapa, no lugar da estimativa
create table public.obra_orcado (
  obra_id uuid not null references public.obras (id) on delete cascade,
  etapa text not null check (etapa ~ '^[a-z0-9_]{1,60}$'),
  valor numeric(14, 2) not null check (valor >= 0),
  primary key (obra_id, etapa)
);
alter table public.obra_orcado enable row level security;
create policy "responsavel ve orcado" on public.obra_orcado for select to authenticated using (private.is_admin(obra_id));

-- Em qual etapa o responsável colocou cada pedido
create table public.pedido_etapas (
  pedido_id uuid primary key references public.pedidos (id) on delete cascade,
  etapa text not null check (etapa ~ '^[a-z0-9_]{1,60}$')
);
alter table public.pedido_etapas enable row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('obra-notas', 'obra-notas', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']);

create policy "quem lidera envia notas" on storage.objects for insert to authenticated
  with check (bucket_id = 'obra-notas' and private.lidera_obra(((storage.foldername(name))[1])::uuid));
create policy "responsavel e autor leem notas" on storage.objects for select to authenticated
  using (bucket_id = 'obra-notas' and (private.is_admin(((storage.foldername(name))[1])::uuid) or owner_id = (select auth.uid())::text));
create policy "responsavel e autor apagam notas" on storage.objects for delete to authenticated
  using (bucket_id = 'obra-notas' and (private.is_admin(((storage.foldername(name))[1])::uuid) or owner_id = (select auth.uid())::text));

create function private.mexe_no_gasto(g public.obra_gastos) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.is_admin(g.obra_id), false)
      or (coalesce(g.criado_por = (select auth.uid()), false) and coalesce(private.lidera_obra(g.obra_id), false));
$$;

create function public.lancamentos_da_obra(p_obra uuid)
returns table (
  id uuid, origem text, etapa text, tipo text, descricao text, fornecedor text, valor numeric, data date, nota_path text,
  autor text, posso_mexer boolean
)
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  chefe boolean := coalesce(private.is_admin(p_obra), false);
begin
  if not chefe and not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select g.id, 'gasto'::text, g.etapa, g.tipo, g.descricao, g.fornecedor, g.valor::numeric, g.data, g.nota_path,
           coalesce(nullif(btrim(a.nome), ''), 'Sem nome'), private.mexe_no_gasto(g)
      from public.obra_gastos g
      left join public.profiles a on a.id = g.criado_por
     where g.obra_id = p_obra and (chefe or coalesce(g.criado_por = uid, false))
    union all
    select p.id, 'pedido'::text, pe.etapa, 'material'::text, 'Pedido na ' || l.nome, l.nome, p.total::numeric,
           (p.criado_em at time zone 'America/Sao_Paulo')::date, null::text, coalesce(nullif(btrim(a.nome), ''), 'Sem nome'), true
      from public.pedidos p
      join public.propostas pr on pr.id = p.proposta_id
      join public.orcamentos o on o.id = pr.orcamento_id
      join public.lojas l on l.id = p.loja_id
      left join public.pedido_etapas pe on pe.pedido_id = p.id
      left join public.profiles a on a.id = p.construtor_id
     where chefe and o.obra_id = p_obra and p.status <> 'cancelado'
     order by 8 desc;
end $$;

create function public.salvar_gasto(p_obra uuid, p_id uuid, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  texto text := btrim(coalesce(d ->> 'descricao', ''));
  v numeric := (d ->> 'valor')::numeric;
  dia date := (d ->> 'data')::date;
  nota text := nullif(d ->> 'nota_path', '');
  atual public.obra_gastos;
  novo uuid;
begin
  if not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre lançam gastos.' using errcode = 'P0001';
  end if;
  if texto = '' then raise exception 'Diga o que foi pago.' using errcode = 'P0001'; end if;
  if char_length(texto) > 200 then raise exception 'Use no máximo 200 letras.' using errcode = 'P0001'; end if;
  if v is null or v <= 0 or v > 9999999999 then raise exception 'Digite um valor maior que zero.' using errcode = 'P0001'; end if;
  if dia is null then raise exception 'Escolha a data do gasto.' using errcode = 'P0001'; end if;
  if dia > (now() at time zone 'America/Sao_Paulo')::date + 1 then
    raise exception 'A data do gasto não pode estar no futuro.' using errcode = 'P0001';
  end if;
  if nota is not null and left(nota, 37) <> p_obra::text || '/' then
    raise exception 'Nota de outra obra.' using errcode = 'P0001';
  end if;
  if p_id is null then
    insert into public.obra_gastos (obra_id, etapa, tipo, descricao, fornecedor, valor, data, nota_path)
    values (p_obra, nullif(d ->> 'etapa', ''), coalesce(nullif(d ->> 'tipo', ''), 'material'), texto, nullif(btrim(coalesce(d ->> 'fornecedor', '')), ''), round(v, 2), dia, nota)
    returning id into novo;
    return novo;
  end if;
  select * into atual from public.obra_gastos where id = p_id and obra_id = p_obra for update;
  if not found or not private.mexe_no_gasto(atual) then
    raise exception 'Gasto não encontrado.' using errcode = 'P0001';
  end if;
  update public.obra_gastos
     set etapa = nullif(d ->> 'etapa', ''), tipo = coalesce(nullif(d ->> 'tipo', ''), 'material'), descricao = texto,
         fornecedor = nullif(btrim(coalesce(d ->> 'fornecedor', '')), ''), valor = round(v, 2), data = dia, nota_path = nota
   where id = p_id;
  return p_id;
end $$;

-- Devolve o caminho da nota, para o app apagar o arquivo
create function public.excluir_gasto(p_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare atual public.obra_gastos;
begin
  select * into atual from public.obra_gastos where id = p_id for update;
  if not found or not private.mexe_no_gasto(atual) then
    raise exception 'Gasto não encontrado.' using errcode = 'P0001';
  end if;
  delete from public.obra_gastos where id = p_id;
  return atual.nota_path;
end $$;

-- Valor nulo volta para a estimativa
create function public.definir_orcado(p_obra uuid, p_etapa text, p_valor numeric) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce(private.is_admin(p_obra), false) then
    raise exception 'Só o responsável muda o valor orçado.' using errcode = 'P0001';
  end if;
  if p_valor is null then
    delete from public.obra_orcado where obra_id = p_obra and etapa = p_etapa;
    return;
  end if;
  if p_valor < 0 then raise exception 'O valor orçado não pode ser negativo.' using errcode = 'P0001'; end if;
  insert into public.obra_orcado (obra_id, etapa, valor) values (p_obra, p_etapa, round(p_valor, 2))
  on conflict (obra_id, etapa) do update set valor = excluded.valor;
end $$;

create function public.classificar_pedido(p_pedido uuid, p_etapa text) returns void
language plpgsql security definer set search_path = '' as $$
declare obra uuid;
begin
  select o.obra_id into obra
    from public.pedidos p
    join public.propostas pr on pr.id = p.proposta_id
    join public.orcamentos o on o.id = pr.orcamento_id
   where p.id = p_pedido;
  if obra is null or not coalesce(private.is_admin(obra), false) then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;
  if nullif(p_etapa, '') is null then
    delete from public.pedido_etapas where pedido_id = p_pedido;
    return;
  end if;
  insert into public.pedido_etapas (pedido_id, etapa) values (p_pedido, p_etapa)
  on conflict (pedido_id) do update set etapa = excluded.etapa;
end $$;

revoke execute on function public.lancamentos_da_obra(uuid) from public, anon;
revoke execute on function public.salvar_gasto(uuid, uuid, jsonb) from public, anon;
revoke execute on function public.excluir_gasto(uuid) from public, anon;
revoke execute on function public.definir_orcado(uuid, text, numeric) from public, anon;
revoke execute on function public.classificar_pedido(uuid, text) from public, anon;
grant execute on function public.lancamentos_da_obra(uuid) to authenticated;
grant execute on function public.salvar_gasto(uuid, uuid, jsonb) to authenticated;
grant execute on function public.excluir_gasto(uuid) to authenticated;
grant execute on function public.definir_orcado(uuid, text, numeric) to authenticated;
grant execute on function public.classificar_pedido(uuid, text) to authenticated;
