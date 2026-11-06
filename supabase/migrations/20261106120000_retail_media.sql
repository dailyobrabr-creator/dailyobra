-- Retail Media: a loja cria anúncios (banner principal e destaque na busca) e acompanha o resultado.
-- As métricas são somadas por dia, sem guardar quem viu.

create function private.hoje_no_brasil() returns date
language sql stable set search_path = '' as $$
  select (now() at time zone 'America/Sao_Paulo')::date
$$;
revoke execute on function private.hoje_no_brasil() from public;
grant execute on function private.hoje_no_brasil() to authenticated;

create table public.anuncios (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.lojas (id) on delete cascade,
  tipo text not null check (tipo in ('banner', 'destaque')),
  titulo text not null check (char_length(titulo) between 3 and 60),
  imagem_path text,
  item_id text references public.catalogo_itens (id) on delete cascade,
  inicio date not null,
  fim date not null,
  pausado boolean not null default false,
  criado_em timestamptz not null default now(),
  check (fim >= inicio),
  check (
    (tipo = 'banner' and imagem_path is not null and item_id is null)
    or (tipo = 'destaque' and item_id is not null and imagem_path is null)
  )
);
create index anuncios_loja_idx on public.anuncios (loja_id);
create index anuncios_periodo_idx on public.anuncios (fim, inicio);

create table public.anuncio_metricas (
  anuncio_id uuid not null references public.anuncios (id) on delete cascade,
  dia date not null,
  impressoes integer not null default 0,
  cliques integer not null default 0,
  primary key (anuncio_id, dia)
);

alter table public.anuncios enable row level security;
alter table public.anuncio_metricas enable row level security;

-- A equipe vê tudo da loja; os outros, só o que está no ar em loja ativa
create policy "ver anuncios" on public.anuncios for select to authenticated
  using (
    private.membro_loja(loja_id) is not null
    or (
      not pausado
      and private.hoje_no_brasil() between inicio and fim
      and exists (select 1 from public.lojas l where l.id = loja_id and l.status = 'ativa')
    )
  );

revoke all on public.anuncios, public.anuncio_metricas from anon;
revoke insert, update, delete, truncate on public.anuncios, public.anuncio_metricas from authenticated;

create function public.salvar_anuncio(
  p_loja uuid,
  p_id uuid,
  p_tipo text,
  p_titulo text,
  p_imagem text,
  p_item text,
  p_inicio date,
  p_fim date
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  nome text := btrim(coalesce(p_titulo, ''));
  atual record;
  resultado uuid;
begin
  if not coalesce(private.pode_gerir_loja(p_loja), false) then
    raise exception 'Só o dono ou o gerente da loja cuidam dos anúncios.' using errcode = 'P0001';
  end if;
  if coalesce(p_tipo, '') not in ('banner', 'destaque') then
    raise exception 'Escolha o tipo do anúncio.' using errcode = 'P0001';
  end if;
  if char_length(nome) < 3 or char_length(nome) > 60 then
    raise exception 'O título do anúncio tem de 3 a 60 caracteres.' using errcode = 'P0001';
  end if;
  if p_inicio is null or p_fim is null or p_fim < p_inicio then
    raise exception 'Confira as datas do anúncio.' using errcode = 'P0001';
  end if;
  if p_id is null and p_fim < private.hoje_no_brasil() then
    raise exception 'O fim do anúncio já passou.' using errcode = 'P0001';
  end if;
  if p_tipo = 'banner' and (p_imagem is null or left(p_imagem, 37) <> p_loja::text || '/') then
    raise exception 'Envie a imagem do banner.' using errcode = 'P0001';
  end if;
  if p_tipo = 'destaque' and not exists (
    select 1 from public.ofertas o
     where o.loja_id = p_loja and o.item_id = p_item and not o.pausada
  ) then
    raise exception 'Coloque preço neste produto antes de anunciar.' using errcode = 'P0001';
  end if;
  if p_id is not null then
    select * into atual from public.anuncios a where a.id = p_id and a.loja_id = p_loja for update;
    if not found then
      raise exception 'Anúncio não encontrado.' using errcode = 'P0001';
    end if;
    if atual.tipo <> p_tipo then
      raise exception 'O tipo do anúncio não muda depois de criado.' using errcode = 'P0001';
    end if;
  end if;
  -- Sem isso, uma loja só poderia ocupar todo o carrossel do Início
  perform pg_advisory_xact_lock(hashtext('anuncios:' || p_loja::text));
  if (select count(*) from public.anuncios a
       where a.loja_id = p_loja and a.tipo = p_tipo and not a.pausado
         and a.id is distinct from p_id
         and a.inicio <= p_fim and a.fim >= p_inicio) >= 3 then
    raise exception 'A loja pode ter até 3 anúncios deste tipo ao mesmo tempo.' using errcode = 'P0001';
  end if;
  if p_id is null then
    insert into public.anuncios (loja_id, tipo, titulo, imagem_path, item_id, inicio, fim)
    values (
      p_loja, p_tipo, nome,
      case when p_tipo = 'banner' then p_imagem end,
      case when p_tipo = 'destaque' then p_item end,
      p_inicio, p_fim
    )
    returning id into resultado;
    return resultado;
  end if;
  update public.anuncios a
     set titulo = nome,
         imagem_path = case when p_tipo = 'banner' then p_imagem end,
         item_id = case when p_tipo = 'destaque' then p_item end,
         inicio = p_inicio,
         fim = p_fim
   where a.id = p_id;
  return p_id;
end $$;

create function public.pausar_anuncio(p_anuncio uuid, p_pausado boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare a record;
begin
  select * into a from public.anuncios where id = p_anuncio for update;
  if not found or private.membro_loja(a.loja_id) is null then
    raise exception 'Anúncio não encontrado.' using errcode = 'P0001';
  end if;
  if not coalesce(private.pode_gerir_loja(a.loja_id), false) then
    raise exception 'Só o dono ou o gerente da loja cuidam dos anúncios.' using errcode = 'P0001';
  end if;
  if p_pausado is null then
    raise exception 'Escolha pausar ou retomar.' using errcode = 'P0001';
  end if;
  if not p_pausado then
    perform pg_advisory_xact_lock(hashtext('anuncios:' || a.loja_id::text));
    if (select count(*) from public.anuncios o
         where o.loja_id = a.loja_id and o.tipo = a.tipo and not o.pausado and o.id <> a.id
           and o.inicio <= a.fim and o.fim >= a.inicio) >= 3 then
      raise exception 'A loja pode ter até 3 anúncios deste tipo ao mesmo tempo.' using errcode = 'P0001';
    end if;
  end if;
  update public.anuncios set pausado = p_pausado where id = p_anuncio;
end $$;

-- Devolve o arquivo do banner, para o app apagar a imagem também
create function public.excluir_anuncio(p_anuncio uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare a record;
begin
  select * into a from public.anuncios where id = p_anuncio for update;
  if not found or private.membro_loja(a.loja_id) is null then
    raise exception 'Anúncio não encontrado.' using errcode = 'P0001';
  end if;
  if not coalesce(private.pode_gerir_loja(a.loja_id), false) then
    raise exception 'Só o dono ou o gerente da loja cuidam dos anúncios.' using errcode = 'P0001';
  end if;
  delete from public.anuncios where id = p_anuncio;
  return a.imagem_path;
end $$;

-- Conta impressão ou clique do dia. A equipe da própria loja não conta, e anúncio fora do ar é ignorado sem erro.
create function public.registrar_evento_anuncio(p_anuncio uuid, p_evento text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a record;
  hoje date := private.hoje_no_brasil();
begin
  if coalesce(p_evento, '') not in ('impressao', 'clique') then
    raise exception 'Evento inválido.' using errcode = 'P0001';
  end if;
  select * into a from public.anuncios where id = p_anuncio;
  if not found or a.pausado or hoje not between a.inicio and a.fim then
    return;
  end if;
  if private.membro_loja(a.loja_id) is not null then
    return;
  end if;
  insert into public.anuncio_metricas as m (anuncio_id, dia, impressoes, cliques)
  values (
    p_anuncio, hoje,
    case when p_evento = 'impressao' then 1 else 0 end,
    case when p_evento = 'clique' then 1 else 0 end
  )
  on conflict (anuncio_id, dia) do update
    set impressoes = m.impressoes + excluded.impressoes,
        cliques = m.cliques + excluded.cliques;
end $$;

-- Anúncios da loja com os resultados. Vendidos: quantidade do produto em pedidos não cancelados durante o anúncio.
create function public.anuncios_da_loja(p_loja uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare resultado jsonb;
begin
  if not coalesce(private.pode_gerir_loja(p_loja), false) then
    raise exception 'Só o dono ou o gerente da loja cuidam dos anúncios.' using errcode = 'P0001';
  end if;
  select coalesce(jsonb_agg(linha order by (linha ->> 'criado_em') desc), '[]'::jsonb) into resultado
    from (
      select jsonb_build_object(
        'id', a.id, 'loja_id', a.loja_id, 'tipo', a.tipo, 'titulo', a.titulo, 'imagem_path', a.imagem_path,
        'item_id', a.item_id, 'item_nome', i.nome, 'unidade', i.unidade, 'inicio', a.inicio, 'fim', a.fim,
        'pausado', a.pausado, 'criado_em', a.criado_em,
        'impressoes', coalesce((select sum(m.impressoes) from public.anuncio_metricas m where m.anuncio_id = a.id), 0),
        'cliques', coalesce((select sum(m.cliques) from public.anuncio_metricas m where m.anuncio_id = a.id), 0),
        'vendidos', case when a.tipo = 'destaque' then coalesce((
          select sum(pi.quantidade)
            from public.pedidos pe
            join public.proposta_itens pi on pi.proposta_id = pe.proposta_id
           where pe.loja_id = a.loja_id and pe.status <> 'cancelado' and pi.item_id = a.item_id
             and (pe.criado_em at time zone 'America/Sao_Paulo')::date between a.inicio and a.fim
        ), 0) end
      ) as linha
        from public.anuncios a
        left join public.catalogo_itens i on i.id = a.item_id
       where a.loja_id = p_loja
    ) t;
  return resultado;
end $$;

revoke execute on function public.salvar_anuncio(uuid, uuid, text, text, text, text, date, date) from public, anon;
revoke execute on function public.pausar_anuncio(uuid, boolean) from public, anon;
revoke execute on function public.excluir_anuncio(uuid) from public, anon;
revoke execute on function public.registrar_evento_anuncio(uuid, text) from public, anon;
revoke execute on function public.anuncios_da_loja(uuid) from public, anon;
grant execute on function public.salvar_anuncio(uuid, uuid, text, text, text, text, date, date) to authenticated;
grant execute on function public.pausar_anuncio(uuid, boolean) to authenticated;
grant execute on function public.excluir_anuncio(uuid) to authenticated;
grant execute on function public.registrar_evento_anuncio(uuid, text) to authenticated;
grant execute on function public.anuncios_da_loja(uuid) to authenticated;
