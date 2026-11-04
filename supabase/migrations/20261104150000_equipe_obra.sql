-- Equipe da obra. Cada pessoa entra por convite (link ou código, porque mestre e empreiteiro quase nunca têm conta antes) e
-- tem uma função, que decide o que pode fazer. A coluna papel continua sendo o que as regras antigas leem:
--   responsável = admin; mestre, estagiário e empreiteiro = membro; cliente = cliente.
-- Finalizar o dia e mudar a etapa ficam com quem lidera a obra: responsável e mestre.

alter table public.obra_membros
  add column funcao text not null default 'responsavel'
    check (funcao in ('responsavel', 'mestre', 'estagiario', 'empreiteiro', 'cliente'));

update public.obra_membros
   set funcao = case papel when 'admin' then 'responsavel' when 'membro' then 'mestre' else 'cliente' end;

alter table public.obra_membros add constraint obra_membros_papel_da_funcao
  check (papel = case funcao when 'responsavel' then 'admin' when 'cliente' then 'cliente' else 'membro' end);

-- Entrar e sair da equipe passa pelas funções abaixo, para a função e o papel nunca ficarem diferentes
drop policy "admin gerencia membros" on public.obra_membros;

create function private.lidera_obra(p_obra uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.obra_membros m
    where m.obra_id = p_obra and m.user_id = (select auth.uid()) and m.funcao in ('responsavel', 'mestre')
  );
$$;

drop policy "atualizar etapas" on public.obra_etapas;
drop policy "registrar etapas" on public.obra_etapas;
create policy "atualizar etapas" on public.obra_etapas for update to authenticated
  using (private.lidera_obra(obra_id)) with check (private.lidera_obra(obra_id));
create policy "registrar etapas" on public.obra_etapas for insert to authenticated
  with check (private.lidera_obra(obra_id));

create table public.obra_convites (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  codigo text not null unique,
  funcao text not null check (funcao in ('mestre', 'estagiario', 'empreiteiro', 'cliente')),
  criado_por uuid default auth.uid() references auth.users (id) on delete set null,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null default now() + interval '7 days',
  usado_por uuid references auth.users (id) on delete set null,
  usado_em timestamptz
);
create index obra_convites_obra_idx on public.obra_convites (obra_id);
alter table public.obra_convites enable row level security;
create policy "administrador ve convites" on public.obra_convites for select to authenticated
  using (private.is_admin(obra_id));

create function public.criar_convite(p_obra uuid, p_funcao text) returns public.obra_convites
language plpgsql security definer set search_path = '' as $$
declare
  c public.obra_convites;
  bruto text := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
begin
  if not coalesce(private.is_admin(p_obra), false) then
    raise exception 'Só o responsável pela obra convida pessoas.' using errcode = 'P0001';
  end if;
  if p_funcao is null or p_funcao not in ('mestre', 'estagiario', 'empreiteiro', 'cliente') then
    raise exception 'Escolha a função da pessoa.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.obra_convites o where o.obra_id = p_obra and o.usado_em is null and o.expira_em > now()) >= 20 then
    raise exception 'Esta obra tem muitos convites abertos. Cancele os que não vai usar.' using errcode = 'P0001';
  end if;
  insert into public.obra_convites (obra_id, codigo, funcao)
  values (p_obra, substr(bruto, 1, 5) || '-' || substr(bruto, 6, 5), p_funcao)
  returning * into c;
  return c;
end $$;

-- Acha o convite aceitando o código como vier digitado; quem já usou este convite pode abrir o link de novo
create function private.convite_aberto(p_codigo text) returns public.obra_convites
language plpgsql security definer set search_path = '' as $$
declare
  c public.obra_convites;
  limpo text := upper(regexp_replace(coalesce(p_codigo, ''), '[^0-9A-Za-z]', '', 'g'));
begin
  if (select auth.uid()) is null then
    raise exception 'Entre na sua conta para aceitar o convite.' using errcode = 'P0001';
  end if;
  select * into c from public.obra_convites o
   where length(limpo) = 10 and o.codigo = substr(limpo, 1, 5) || '-' || substr(limpo, 6, 5)
   for update;
  if not found then
    raise exception 'Código não encontrado. Confira e tente de novo.' using errcode = 'P0001';
  end if;
  if c.usado_em is not null and c.usado_por is distinct from (select auth.uid()) then
    raise exception 'Este convite já foi usado. Peça um novo.' using errcode = 'P0001';
  end if;
  if c.usado_em is null and c.expira_em <= now() then
    raise exception 'Este convite venceu. Peça um novo.' using errcode = 'P0001';
  end if;
  return c;
end $$;

create function public.ver_convite(p_codigo text)
returns table (obra_nome text, funcao text, convidado_por text, ja_participa boolean)
language plpgsql security definer set search_path = '' as $$
declare c public.obra_convites := private.convite_aberto(p_codigo);
begin
  return query
    select o.nome, c.funcao, coalesce(nullif(btrim(p.nome), ''), 'O responsável pela obra'), coalesce(private.is_membro(c.obra_id), false)
      from public.obras o
      left join public.profiles p on p.id = c.criado_por
     where o.id = c.obra_id;
end $$;

create function public.aceitar_convite(p_codigo text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  c public.obra_convites := private.convite_aberto(p_codigo);
  uid uuid := (select auth.uid());
begin
  -- Quem já está na obra continua com a função que tem, e o convite segue valendo para outra pessoa
  if coalesce(private.is_membro(c.obra_id), false) then return c.obra_id; end if;
  insert into public.obra_membros (obra_id, user_id, papel, funcao)
  values (c.obra_id, uid, case c.funcao when 'cliente' then 'cliente' else 'membro' end, c.funcao);
  update public.obra_convites set usado_por = uid, usado_em = now() where id = c.id;
  return c.obra_id;
end $$;

create function public.cancelar_convite(p_convite uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare alvo uuid;
begin
  select obra_id into alvo from public.obra_convites where id = p_convite and usado_em is null;
  if alvo is null or not coalesce(private.is_admin(alvo), false) then
    raise exception 'Convite não encontrado.' using errcode = 'P0001';
  end if;
  delete from public.obra_convites where id = p_convite;
end $$;

create function public.equipe_da_obra(p_obra uuid)
returns table (user_id uuid, nome text, funcao text, eu boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not coalesce(private.is_membro(p_obra), false) then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select m.user_id, coalesce(nullif(btrim(p.nome), ''), 'Sem nome'), m.funcao, m.user_id = (select auth.uid())
      from public.obra_membros m
      left join public.profiles p on p.id = m.user_id
     where m.obra_id = p_obra
     order by array_position(array['responsavel', 'mestre', 'estagiario', 'empreiteiro', 'cliente'], m.funcao), p.nome;
end $$;

create function public.mudar_funcao_membro(p_obra uuid, p_usuario uuid, p_funcao text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce(private.is_admin(p_obra), false) then
    raise exception 'Só o responsável pela obra muda a função de alguém.' using errcode = 'P0001';
  end if;
  if p_funcao is null or p_funcao not in ('mestre', 'estagiario', 'empreiteiro', 'cliente') then
    raise exception 'Escolha a função da pessoa.' using errcode = 'P0001';
  end if;
  update public.obra_membros
     set funcao = p_funcao, papel = case p_funcao when 'cliente' then 'cliente' else 'membro' end
   where obra_id = p_obra and user_id = p_usuario and funcao <> 'responsavel';
  if not found then
    raise exception 'Esta pessoa não pode ter a função alterada.' using errcode = 'P0001';
  end if;
end $$;

-- O responsável tira quem quiser; cada pessoa pode sair por conta própria. Só o responsável não sai, para a obra não ficar sem dono
create function public.remover_membro(p_obra uuid, p_usuario uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  alvo text;
begin
  if uid is distinct from p_usuario and not coalesce(private.is_admin(p_obra), false) then
    raise exception 'Só o responsável pela obra remove pessoas.' using errcode = 'P0001';
  end if;
  select funcao into alvo from public.obra_membros where obra_id = p_obra and user_id = p_usuario;
  if alvo is null then raise exception 'Esta pessoa não está na obra.' using errcode = 'P0001'; end if;
  if alvo = 'responsavel' then
    raise exception 'O responsável não pode sair da obra.' using errcode = 'P0001';
  end if;
  delete from public.obra_membros where obra_id = p_obra and user_id = p_usuario;
end $$;

-- Igual à migração diario_obra, mais a regra de quem finaliza
create or replace function public.salvar_dia_obra(p_obra uuid, p_data date, p_dados jsonb, p_finalizar boolean default false) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  id_rdo uuid;
  situacao text;
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  foto jsonb;
  tem_algo boolean;
begin
  if not coalesce(private.pode_editar(p_obra), false) then
    raise exception 'Só quem toca a obra preenche o diário.' using errcode = 'P0001';
  end if;
  if p_finalizar and not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre finalizam o dia.' using errcode = 'P0001';
  end if;
  if p_data is null then raise exception 'Escolha o dia.' using errcode = 'P0001'; end if;
  -- Um dia de folga cobre a diferença de fuso entre o aparelho e o banco
  if p_data > (now() at time zone 'utc')::date + 1 then
    raise exception 'Não dá para preencher um dia que ainda não chegou.' using errcode = 'P0001';
  end if;
  select status into situacao from public.rdos where obra_id = p_obra and data = p_data for update;
  if situacao is not null and situacao <> 'rascunho' then
    raise exception 'Este dia já foi finalizado. Reabra para alterar.' using errcode = 'P0001';
  end if;
  if jsonb_array_length(coalesce(d -> 'fotos', '[]'::jsonb)) > 10 then
    raise exception 'Cada dia aceita até 10 fotos.' using errcode = 'P0001';
  end if;
  for foto in select * from jsonb_array_elements(coalesce(d -> 'fotos', '[]'::jsonb)) loop
    if left(coalesce(foto ->> 'caminho', ''), 37) <> p_obra::text || '/' then
      raise exception 'Foto de outra obra.' using errcode = 'P0001';
    end if;
  end loop;

  tem_algo := jsonb_array_length(coalesce(d -> 'equipe', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'atividades', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'ocorrencias', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'materiais', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'equipamentos', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'fotos', '[]'::jsonb)) > 0
    or btrim(coalesce(d ->> 'observacoes', '')) <> '';
  if p_finalizar and not tem_algo then
    raise exception 'Preencha alguma coisa antes de finalizar o dia.' using errcode = 'P0001';
  end if;

  insert into public.rdos (obra_id, data, clima_manha, clima_tarde, observacoes, status)
  values (p_obra, p_data, nullif(d ->> 'clima_manha', ''), nullif(d ->> 'clima_tarde', ''), nullif(btrim(coalesce(d ->> 'observacoes', '')), ''),
          case when p_finalizar then 'finalizado' else 'rascunho' end)
  on conflict (obra_id, data) do update
    set clima_manha = excluded.clima_manha, clima_tarde = excluded.clima_tarde, observacoes = excluded.observacoes,
        status = excluded.status, updated_at = now()
  returning id into id_rdo;

  delete from public.rdo_efetivo where rdo_id = id_rdo;
  delete from public.rdo_atividades where rdo_id = id_rdo;
  delete from public.rdo_ocorrencias where rdo_id = id_rdo;
  delete from public.rdo_materiais where rdo_id = id_rdo;
  delete from public.rdo_equipamentos where rdo_id = id_rdo;
  delete from public.rdo_fotos where rdo_id = id_rdo;

  insert into public.rdo_efetivo (rdo_id, funcao, quantidade, empresa, ordem)
  select id_rdo, btrim(e ->> 'funcao'), coalesce((e ->> 'quantidade')::int, 1), nullif(btrim(coalesce(e ->> 'empresa', '')), ''), n
    from jsonb_array_elements(coalesce(d -> 'equipe', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'funcao', '')) <> '';
  insert into public.rdo_atividades (rdo_id, descricao, local, percentual, ordem)
  select id_rdo, btrim(e ->> 'descricao'), nullif(btrim(coalesce(e ->> 'local', '')), ''), (e ->> 'percentual')::int, n
    from jsonb_array_elements(coalesce(d -> 'atividades', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'descricao', '')) <> '';
  insert into public.rdo_ocorrencias (rdo_id, tipo, descricao, ordem)
  select id_rdo, coalesce(nullif(e ->> 'tipo', ''), 'geral'), btrim(e ->> 'descricao'), n
    from jsonb_array_elements(coalesce(d -> 'ocorrencias', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'descricao', '')) <> '';
  insert into public.rdo_materiais (rdo_id, material, quantidade, unidade, fornecedor, ordem)
  select id_rdo, btrim(e ->> 'material'), (e ->> 'quantidade')::numeric, nullif(btrim(coalesce(e ->> 'unidade', '')), ''), nullif(btrim(coalesce(e ->> 'fornecedor', '')), ''), n
    from jsonb_array_elements(coalesce(d -> 'materiais', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'material', '')) <> '';
  insert into public.rdo_equipamentos (rdo_id, equipamento, quantidade, ordem)
  select id_rdo, btrim(e ->> 'equipamento'), coalesce((e ->> 'quantidade')::int, 1), n
    from jsonb_array_elements(coalesce(d -> 'equipamentos', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'equipamento', '')) <> '';
  insert into public.rdo_fotos (rdo_id, storage_path, legenda, ordem)
  select id_rdo, e ->> 'caminho', nullif(btrim(coalesce(e ->> 'legenda', '')), ''), n
    from jsonb_array_elements(coalesce(d -> 'fotos', '[]'::jsonb)) with ordinality as t(e, n);

  return id_rdo;
end $$;

revoke execute on function public.criar_convite(uuid, text) from public, anon;
revoke execute on function public.ver_convite(text) from public, anon;
revoke execute on function public.aceitar_convite(text) from public, anon;
revoke execute on function public.cancelar_convite(uuid) from public, anon;
revoke execute on function public.equipe_da_obra(uuid) from public, anon;
revoke execute on function public.mudar_funcao_membro(uuid, uuid, text) from public, anon;
revoke execute on function public.remover_membro(uuid, uuid) from public, anon;
grant execute on function public.criar_convite(uuid, text) to authenticated;
grant execute on function public.ver_convite(text) to authenticated;
grant execute on function public.aceitar_convite(text) to authenticated;
grant execute on function public.cancelar_convite(uuid) to authenticated;
grant execute on function public.equipe_da_obra(uuid) to authenticated;
grant execute on function public.mudar_funcao_membro(uuid, uuid, text) to authenticated;
grant execute on function public.remover_membro(uuid, uuid) to authenticated;
