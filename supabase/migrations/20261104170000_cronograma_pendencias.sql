-- Cronograma e pendências da obra. As datas previstas ficam em cada etapa; as reais nascem quando alguém marca a etapa como
-- iniciada ou concluída, para quem está na obra não precisar digitar o dia. Quem lidera pode acertar depois.
-- Pendência é assunto da equipe: o cliente não vê.

alter table public.obra_etapas
  add column inicio_previsto date,
  add column fim_previsto date,
  add column inicio_real date,
  add column fim_real date,
  add constraint obra_etapas_previsto_em_ordem check (inicio_previsto is null or fim_previsto is null or fim_previsto >= inicio_previsto),
  add constraint obra_etapas_real_em_ordem check (inicio_real is null or fim_real is null or fim_real >= inicio_real);

-- Etapas já marcadas ganham como data real o dia da marcação, sem mudar quem marcou
alter table public.obra_etapas disable trigger obra_etapas_carimbo;
update public.obra_etapas
   set inicio_real = case when status in ('iniciada', 'concluida') then atualizado_em::date end,
       fim_real = case when status = 'concluida' then atualizado_em::date end;
alter table public.obra_etapas enable trigger obra_etapas_carimbo;

create function private.datar_etapa() returns trigger
language plpgsql set search_path = '' as $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  if tg_op = 'UPDATE' and new.status = old.status then return new; end if;
  if new.status = 'prevista' then
    if tg_op = 'UPDATE' then
      new.inicio_real := null;
      new.fim_real := null;
    end if;
    return new;
  end if;
  if new.status = 'concluida' then
    new.fim_real := coalesce(new.fim_real, hoje);
    new.inicio_real := coalesce(new.inicio_real, new.fim_real);
    return new;
  end if;
  new.fim_real := null;
  if new.status = 'iniciada' then new.inicio_real := coalesce(new.inicio_real, hoje); end if;
  return new;
end $$;

create trigger obra_etapas_datas before insert or update of status on public.obra_etapas
  for each row execute function private.datar_etapa();

-- Grava as datas de várias etapas de uma vez. Item sem as chaves de data real mantém as que já existem
create function public.salvar_cronograma(p_obra uuid, p_etapas jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  ip date;
  fp date;
  ir date;
  fr date;
  limite date := (now() at time zone 'America/Sao_Paulo')::date + 1;
begin
  if not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre mexem no cronograma.' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_etapas) is distinct from 'array' then
    raise exception 'Cronograma inválido.' using errcode = 'P0001';
  end if;
  for e in select * from jsonb_array_elements(p_etapas) loop
    ip := (e ->> 'inicio_previsto')::date;
    fp := (e ->> 'fim_previsto')::date;
    ir := (e ->> 'inicio_real')::date;
    fr := (e ->> 'fim_real')::date;
    if fp < ip then
      raise exception 'O fim previsto não pode vir antes do início.' using errcode = 'P0001';
    end if;
    if fr < ir then
      raise exception 'O fim real não pode vir antes do início.' using errcode = 'P0001';
    end if;
    if ir > limite or fr > limite then
      raise exception 'A data real não pode estar no futuro.' using errcode = 'P0001';
    end if;
    insert into public.obra_etapas (obra_id, etapa, inicio_previsto, fim_previsto, inicio_real, fim_real)
    values (p_obra, e ->> 'etapa', ip, fp, ir, fr)
    on conflict (obra_id, etapa) do update
      set inicio_previsto = excluded.inicio_previsto,
          fim_previsto = excluded.fim_previsto,
          inicio_real = case when e ? 'inicio_real' then excluded.inicio_real else public.obra_etapas.inicio_real end,
          fim_real = case when e ? 'fim_real' then excluded.fim_real else public.obra_etapas.fim_real end;
  end loop;
end $$;

create table public.obra_pendencias (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  descricao text not null check (char_length(btrim(descricao)) between 1 and 500),
  etapa text check (etapa ~ '^[a-z0-9_]{1,60}$'),
  responsavel_id uuid references auth.users (id) on delete set null,
  prazo date,
  foto_path text,
  situacao text not null default 'aberta' check (situacao in ('aberta', 'resolvida')),
  criada_por uuid default auth.uid() references auth.users (id) on delete set null,
  criada_em timestamptz not null default now(),
  resolvida_por uuid references auth.users (id) on delete set null,
  resolvida_em timestamptz
);
create index obra_pendencias_obra_idx on public.obra_pendencias (obra_id, situacao);
alter table public.obra_pendencias enable row level security;
create policy "equipe le pendencias" on public.obra_pendencias for select to authenticated
  using (private.pode_editar(obra_id));

-- Quem lidera a obra, quem criou a pendência e quem foi escolhido para resolvê-la
create function private.mexe_na_pendencia(p public.obra_pendencias) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.lidera_obra(p.obra_id), false)
      or p.criada_por = (select auth.uid())
      or p.responsavel_id = (select auth.uid());
$$;

create function public.pendencias_da_obra(p_obra uuid)
returns table (
  id uuid, descricao text, etapa text, responsavel_id uuid, responsavel_nome text, prazo date, foto_path text,
  situacao text, criada_em timestamptz, resolvida_em timestamptz, posso_mexer boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not coalesce(private.pode_editar(p_obra), false) then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select p.id, p.descricao, p.etapa, p.responsavel_id,
           case when p.responsavel_id is not null then coalesce(nullif(btrim(r.nome), ''), 'Sem nome') end,
           p.prazo, p.foto_path, p.situacao, p.criada_em, p.resolvida_em, private.mexe_na_pendencia(p)
      from public.obra_pendencias p
      left join public.profiles r on r.id = p.responsavel_id
     where p.obra_id = p_obra
     order by p.prazo nulls last, p.criada_em desc;
end $$;

create function public.salvar_pendencia(p_obra uuid, p_id uuid, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  texto text := btrim(coalesce(d ->> 'descricao', ''));
  resp uuid := nullif(d ->> 'responsavel_id', '')::uuid;
  foto text := nullif(d ->> 'foto_path', '');
  atual public.obra_pendencias;
  novo uuid;
begin
  if not coalesce(private.pode_editar(p_obra), false) then
    raise exception 'Só quem toca a obra registra pendências.' using errcode = 'P0001';
  end if;
  if texto = '' then raise exception 'Descreva a pendência.' using errcode = 'P0001'; end if;
  if char_length(texto) > 500 then raise exception 'Use no máximo 500 letras.' using errcode = 'P0001'; end if;
  if resp is not null and not exists (
    select 1 from public.obra_membros m where m.obra_id = p_obra and m.user_id = resp and m.funcao <> 'cliente'
  ) then
    raise exception 'O responsável precisa estar na equipe da obra.' using errcode = 'P0001';
  end if;
  if foto is not null and left(foto, 37) <> p_obra::text || '/' then
    raise exception 'Foto de outra obra.' using errcode = 'P0001';
  end if;
  if p_id is null then
    insert into public.obra_pendencias (obra_id, descricao, etapa, responsavel_id, prazo, foto_path)
    values (p_obra, texto, nullif(d ->> 'etapa', ''), resp, (d ->> 'prazo')::date, foto)
    returning id into novo;
    return novo;
  end if;
  select * into atual from public.obra_pendencias where id = p_id and obra_id = p_obra for update;
  if not found then raise exception 'Pendência não encontrada.' using errcode = 'P0001'; end if;
  if not private.mexe_na_pendencia(atual) then
    raise exception 'Só quem criou, quem vai resolver ou quem lidera a obra altera esta pendência.' using errcode = 'P0001';
  end if;
  update public.obra_pendencias
     set descricao = texto, etapa = nullif(d ->> 'etapa', ''), responsavel_id = resp, prazo = (d ->> 'prazo')::date, foto_path = foto
   where id = p_id;
  return p_id;
end $$;

create function public.resolver_pendencia(p_id uuid, p_resolvida boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare atual public.obra_pendencias;
begin
  select * into atual from public.obra_pendencias where id = p_id for update;
  if not found or not coalesce(private.pode_editar(atual.obra_id), false) then
    raise exception 'Pendência não encontrada.' using errcode = 'P0001';
  end if;
  if not private.mexe_na_pendencia(atual) then
    raise exception 'Só quem criou, quem vai resolver ou quem lidera a obra altera esta pendência.' using errcode = 'P0001';
  end if;
  update public.obra_pendencias
     set situacao = case when p_resolvida then 'resolvida' else 'aberta' end,
         resolvida_por = case when p_resolvida then (select auth.uid()) end,
         resolvida_em = case when p_resolvida then now() end
   where id = p_id;
end $$;

-- Devolve o caminho da foto, para o app apagar o arquivo
create function public.excluir_pendencia(p_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare atual public.obra_pendencias;
begin
  select * into atual from public.obra_pendencias where id = p_id for update;
  if not found or not coalesce(private.pode_editar(atual.obra_id), false) then
    raise exception 'Pendência não encontrada.' using errcode = 'P0001';
  end if;
  if not coalesce(private.lidera_obra(atual.obra_id), false) and atual.criada_por is distinct from (select auth.uid()) then
    raise exception 'Só quem criou ou quem lidera a obra exclui uma pendência.' using errcode = 'P0001';
  end if;
  delete from public.obra_pendencias where id = p_id;
  return atual.foto_path;
end $$;

revoke execute on function public.salvar_cronograma(uuid, jsonb) from public, anon;
revoke execute on function public.pendencias_da_obra(uuid) from public, anon;
revoke execute on function public.salvar_pendencia(uuid, uuid, jsonb) from public, anon;
revoke execute on function public.resolver_pendencia(uuid, boolean) from public, anon;
revoke execute on function public.excluir_pendencia(uuid) from public, anon;
grant execute on function public.salvar_cronograma(uuid, jsonb) to authenticated;
grant execute on function public.pendencias_da_obra(uuid) to authenticated;
grant execute on function public.salvar_pendencia(uuid, uuid, jsonb) to authenticated;
grant execute on function public.resolver_pendencia(uuid, boolean) to authenticated;
grant execute on function public.excluir_pendencia(uuid) to authenticated;
