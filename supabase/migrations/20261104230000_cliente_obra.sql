-- Cliente da obra: marca do engenheiro nos documentos e aprovação de mudanças.
-- A marca é do responsável e aparece nos PDFs, por isso quem está na obra lê os dados dela por função. Quem aprova mudança é só
-- o cliente: o registro de quem aprovou e quando não muda depois. O mestre vê a mudança para executar, sem o valor combinado.
-- Excluir a conta agora apaga a marca e passa a obra compartilhada para quem continua nela: sem isso a obra ficava sem responsável.
-- O cliente passa a ver só os dias finalizados do diário: rascunho é trabalho da equipe, ainda não revisado.

drop policy "membros leem rdos" on public.rdos;
create policy "membros leem rdos" on public.rdos for select to authenticated
  using (private.is_membro(obra_id) and (status <> 'rascunho' or private.pode_editar(obra_id)));

create table public.construtor_marca (
  user_id uuid primary key references auth.users (id) on delete cascade,
  nome text check (char_length(nome) <= 120),
  registro text check (char_length(registro) <= 60),
  telefone text check (char_length(telefone) <= 30),
  email text check (char_length(email) <= 120),
  logo_path text,
  atualizado_em timestamptz not null default now()
);
alter table public.construtor_marca enable row level security;
create policy "cada um cuida da sua marca" on public.construtor_marca for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Logo não é segredo: quem tem conta lê, e cada um só mexe na própria pasta
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('marcas', 'marcas', false, 2097152, array['image/jpeg', 'image/png', 'image/webp']);
create policy "quem tem conta le marcas" on storage.objects for select to authenticated using (bucket_id = 'marcas');
create policy "cada um envia a sua marca" on storage.objects for insert to authenticated
  with check (bucket_id = 'marcas' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "cada um apaga a sua marca" on storage.objects for delete to authenticated
  using (bucket_id = 'marcas' and (storage.foldername(name))[1] = (select auth.uid())::text);

create function public.marca_da_obra(p_obra uuid)
returns table (nome text, registro text, telefone text, email text, logo_path text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not coalesce(private.is_membro(p_obra), false) then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select coalesce(nullif(btrim(c.nome), ''), nullif(btrim(p.empresa), ''), nullif(btrim(p.nome), ''), 'Responsável pela obra'),
           c.registro, coalesce(nullif(btrim(c.telefone), ''), p.telefone), c.email, c.logo_path
      from public.obra_membros m
      left join public.construtor_marca c on c.user_id = m.user_id
      left join public.profiles p on p.id = m.user_id
     where m.obra_id = p_obra and m.funcao = 'responsavel'
     limit 1;
end $$;

create table public.obra_mudancas (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  titulo text not null check (char_length(btrim(titulo)) between 1 and 120),
  descricao text check (char_length(descricao) <= 1000),
  valor numeric(12, 2),
  dias int,
  situacao text not null default 'pendente' check (situacao in ('pendente', 'aprovada', 'recusada')),
  resposta text check (char_length(resposta) <= 500),
  criado_por uuid default auth.uid() references auth.users (id) on delete set null,
  criado_em timestamptz not null default now(),
  respondido_por uuid references auth.users (id) on delete set null,
  respondido_em timestamptz
);
create index obra_mudancas_obra_idx on public.obra_mudancas (obra_id, criado_em desc);
alter table public.obra_mudancas enable row level security;

create function public.mudancas_da_obra(p_obra uuid)
returns table (
  id uuid, titulo text, descricao text, valor numeric, dias int, situacao text, resposta text, respondido_por text,
  criado_em timestamptz, respondido_em timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
declare f text;
begin
  select m.funcao into f from public.obra_membros m where m.obra_id = p_obra and m.user_id = (select auth.uid());
  if f is null or f not in ('responsavel', 'mestre', 'cliente') then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select x.id, x.titulo, x.descricao, case when f = 'mestre' then null else x.valor end, x.dias, x.situacao, x.resposta,
           case when x.respondido_por is not null then coalesce(nullif(btrim(p.nome), ''), 'Sem nome') end,
           x.criado_em, x.respondido_em
      from public.obra_mudancas x
      left join public.profiles p on p.id = x.respondido_por
     where x.obra_id = p_obra
     order by x.criado_em desc;
end $$;

create function public.salvar_mudanca(p_obra uuid, p_id uuid, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  texto text := btrim(coalesce(d ->> 'titulo', ''));
  detalhe text := nullif(btrim(coalesce(d ->> 'descricao', '')), '');
  v numeric := (d ->> 'valor')::numeric;
  prazo int := (d ->> 'dias')::int;
  atual public.obra_mudancas;
  novo uuid;
begin
  if not coalesce(private.is_admin(p_obra), false) then
    raise exception 'Só o responsável pede a aprovação de uma mudança.' using errcode = 'P0001';
  end if;
  if texto = '' then raise exception 'Diga qual é a mudança.' using errcode = 'P0001'; end if;
  if char_length(texto) > 120 then raise exception 'Use no máximo 120 letras no título.' using errcode = 'P0001'; end if;
  if char_length(detalhe) > 1000 then raise exception 'Use no máximo 1000 letras na descrição.' using errcode = 'P0001'; end if;
  if abs(coalesce(v, 0)) > 9999999999 then raise exception 'Valor grande demais.' using errcode = 'P0001'; end if;
  if p_id is null then
    insert into public.obra_mudancas (obra_id, titulo, descricao, valor, dias)
    values (p_obra, texto, detalhe, round(v, 2), prazo)
    returning id into novo;
    return novo;
  end if;
  select * into atual from public.obra_mudancas where id = p_id and obra_id = p_obra for update;
  if not found then raise exception 'Mudança não encontrada.' using errcode = 'P0001'; end if;
  if atual.situacao <> 'pendente' then
    raise exception 'Mudança já respondida não pode ser alterada.' using errcode = 'P0001';
  end if;
  update public.obra_mudancas set titulo = texto, descricao = detalhe, valor = round(v, 2), dias = prazo where id = p_id;
  return p_id;
end $$;

create function public.excluir_mudanca(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare atual public.obra_mudancas;
begin
  select * into atual from public.obra_mudancas where id = p_id for update;
  if not found or not coalesce(private.is_admin(atual.obra_id), false) then
    raise exception 'Mudança não encontrada.' using errcode = 'P0001';
  end if;
  if atual.situacao <> 'pendente' then
    raise exception 'Mudança já respondida fica no histórico da obra.' using errcode = 'P0001';
  end if;
  delete from public.obra_mudancas where id = p_id;
end $$;

create function public.responder_mudanca(p_id uuid, p_aprovar boolean, p_resposta text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  atual public.obra_mudancas;
  texto text := nullif(btrim(coalesce(p_resposta, '')), '');
begin
  select * into atual from public.obra_mudancas where id = p_id for update;
  if not found or not coalesce(private.is_membro(atual.obra_id), false) then
    raise exception 'Mudança não encontrada.' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.obra_membros m
     where m.obra_id = atual.obra_id and m.user_id = (select auth.uid()) and m.funcao = 'cliente'
  ) then
    raise exception 'Só o cliente aprova ou recusa uma mudança.' using errcode = 'P0001';
  end if;
  if atual.situacao <> 'pendente' then raise exception 'Esta mudança já foi respondida.' using errcode = 'P0001'; end if;
  if p_aprovar is null then raise exception 'Escolha aprovar ou recusar.' using errcode = 'P0001'; end if;
  if char_length(texto) > 500 then raise exception 'Use no máximo 500 letras.' using errcode = 'P0001'; end if;
  update public.obra_mudancas
     set situacao = case when p_aprovar then 'aprovada' else 'recusada' end, resposta = texto,
         respondido_por = (select auth.uid()), respondido_em = now()
   where id = p_id;
end $$;

revoke execute on function public.marca_da_obra(uuid) from public, anon;
revoke execute on function public.mudancas_da_obra(uuid) from public, anon;
revoke execute on function public.salvar_mudanca(uuid, uuid, jsonb) from public, anon;
revoke execute on function public.excluir_mudanca(uuid) from public, anon;
revoke execute on function public.responder_mudanca(uuid, boolean, text) from public, anon;
grant execute on function public.marca_da_obra(uuid) to authenticated;
grant execute on function public.mudancas_da_obra(uuid) to authenticated;
grant execute on function public.salvar_mudanca(uuid, uuid, jsonb) to authenticated;
grant execute on function public.excluir_mudanca(uuid) to authenticated;
grant execute on function public.responder_mudanca(uuid, boolean, text) to authenticated;

create or replace function public.excluir_conta(p_confirmacao text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  id_loja uuid;
  p record;
  id_obra uuid;
  sucessor uuid;
begin
  if uid is null then raise exception 'Entre na sua conta para excluir.' using errcode = 'P0001'; end if;
  if upper(btrim(coalesce(p_confirmacao, ''))) <> 'EXCLUIR' then
    raise exception 'Digite EXCLUIR para confirmar.' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtext('carteira:' || uid::text));

  if exists (select 1 from public.pedidos where construtor_id = uid and status in ('confirmado', 'em_separacao', 'saiu_entrega')) then
    raise exception 'Você tem pedido em andamento. Espere a entrega ou cancele antes de excluir a conta.' using errcode = 'P0001';
  end if;

  for id_loja in select loja_id from public.loja_membros where user_id = uid and papel = 'dono' loop
    if exists (select 1 from public.pedidos where loja_id = id_loja and status in ('confirmado', 'em_separacao', 'saiu_entrega')) then
      raise exception 'A loja tem pedido em andamento. Conclua ou cancele antes de excluir a conta.' using errcode = 'P0001';
    end if;
    if exists (select 1 from public.loja_membros where loja_id = id_loja and user_id <> uid) then
      raise exception 'A loja ainda tem equipe. Remova as pessoas em Configurações > Equipe antes de excluir a conta.' using errcode = 'P0001';
    end if;
    for p in select id, status from public.propostas where loja_id = id_loja and status in ('enviada', 'contraproposta') for update loop
      update public.propostas set status = 'recusada', motivo_recusa = 'A loja saiu do DailyObra.' where id = p.id;
      perform private.devolver_reserva(p.id);
      perform private.evento_proposta(p.id, p.status, 'recusada', 'dono', null, 'A loja saiu do DailyObra.');
    end loop;
    perform set_config('dailyobra.saida_de_conta', 'sim', true);
    update public.lojas set status = 'suspensa', aberta = false where id = id_loja;
    delete from public.loja_pix where loja_id = id_loja;
  end loop;

  for p in select id, status from public.propostas where construtor_id = uid and status in ('enviada', 'contraproposta') for update loop
    update public.propostas set status = 'cancelada' where id = p.id;
    perform private.devolver_reserva(p.id);
    perform private.evento_proposta(p.id, p.status, 'cancelada', 'construtor', null, 'Conta excluída');
  end loop;

  delete from public.loja_membros where user_id = uid;
  delete from public.construtor_documentos where user_id = uid;
  delete from public.construtor_enderecos where user_id = uid;
  delete from public.construtor_marca where user_id = uid;
  delete from public.leituras_lista where user_id = uid;
  -- Obra compartilhada fica com quem continua nela
  delete from public.obras o
   where o.created_by = uid
     and not exists (select 1 from public.obra_membros m where m.obra_id = o.id and m.user_id <> uid);
  -- Sem responsável ninguém mais administra a obra: passa para quem está mais perto de tocar ela
  for id_obra in select m.obra_id from public.obra_membros m where m.user_id = uid and m.funcao = 'responsavel' loop
    select m.user_id into sucessor
      from public.obra_membros m
     where m.obra_id = id_obra and m.user_id <> uid
     order by array_position(array['mestre', 'estagiario', 'empreiteiro', 'cliente'], m.funcao)
     limit 1;
    if sucessor is not null then
      update public.obra_membros set funcao = 'responsavel', papel = 'admin' where obra_id = id_obra and user_id = sucessor;
    end if;
  end loop;
  delete from public.obra_membros where user_id = uid;
  update public.profiles set nome = 'Conta excluída', empresa = null, cidade = null, uf = null, telefone = null where id = uid;

  delete from auth.sessions where user_id = uid;
  delete from auth.identities where user_id = uid;
  delete from auth.mfa_factors where user_id = uid;
  delete from auth.one_time_tokens where user_id = uid;
  update auth.users
     set email = 'excluida-' || uid::text || '@contas.dailyobra.invalid', encrypted_password = '', phone = null,
         raw_user_meta_data = '{}'::jsonb, email_change = '', banned_until = 'infinity', deleted_at = now()
   where id = uid;
end $$;
