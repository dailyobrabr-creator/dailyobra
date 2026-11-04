-- Dono entrando numa loja que já está no DailyObra. A loja pré-cadastrada não tem equipe e o CNPJ dela já existe, então
-- criar_loja recusa quem é da empresa. O DailyObra gera um código por loja e entrega a quem responde por ela. O CNPJ não
-- serve de prova porque é público. Só o hash fica guardado; cinco erros bloqueiam o código e ele vence em 30 dias.

create table private.codigos_loja (
  loja_id uuid primary key references public.lojas (id) on delete cascade,
  codigo_hash bytea not null,
  tentativas integer not null default 0,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null default now() + interval '30 days',
  usado_em timestamptz,
  usado_por uuid references auth.users (id) on delete set null
);
revoke all on private.codigos_loja from public, anon, authenticated;

-- Fica no schema private, fora da API: quem gera é o DailyObra, pelo SQL Editor. O código só aparece aqui, uma vez
create function private.gerar_codigo_loja(p_loja uuid) returns text
language plpgsql set search_path = '' as $$
declare bruto text := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
begin
  if not exists (select 1 from public.lojas where id = p_loja) then
    raise exception 'Loja não encontrada.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.loja_membros where loja_id = p_loja) then
    raise exception 'Esta loja já tem equipe.' using errcode = 'P0001';
  end if;
  insert into private.codigos_loja (loja_id, codigo_hash) values (p_loja, sha256(convert_to(bruto, 'UTF8')))
  on conflict (loja_id) do update
    set codigo_hash = excluded.codigo_hash, tentativas = 0, criado_em = now(),
        expira_em = now() + interval '30 days', usado_em = null, usado_por = null;
  return substr(bruto, 1, 4) || '-' || substr(bruto, 5, 4) || '-' || substr(bruto, 9, 4);
end $$;
revoke all on function private.gerar_codigo_loja(uuid) from public, anon, authenticated;

-- Devolve a loja, ou nulo quando CNPJ e código não conferem. Erro de código não levanta exceção porque a exceção desfaria
-- a contagem de tentativas
create function public.assumir_loja(p_cnpj text, p_codigo text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  v_cnpj text := regexp_replace(coalesce(p_cnpj, ''), '\D', '', 'g');
  v_codigo text := upper(regexp_replace(coalesce(p_codigo, ''), '[^0-9A-Za-z]', '', 'g'));
  c private.codigos_loja;
begin
  if uid is null then raise exception 'Entre na sua conta para assumir a loja.' using errcode = 'P0001'; end if;
  if exists (select 1 from public.loja_membros where user_id = uid) then
    raise exception 'Esta conta já faz parte de uma loja.' using errcode = 'P0001';
  end if;
  select k.* into c from private.codigos_loja k join public.lojas l on l.id = k.loja_id where l.cnpj = v_cnpj for update of k;
  if not found then return null; end if;
  if c.usado_em is not null or exists (select 1 from public.loja_membros where loja_id = c.loja_id) then
    raise exception 'Esta loja já tem dono. Peça um convite a ele.' using errcode = 'P0001';
  end if;
  if c.expira_em < now() then raise exception 'Código vencido. Peça outro ao DailyObra.' using errcode = 'P0001'; end if;
  if c.tentativas >= 5 then
    raise exception 'Código bloqueado depois de muitas tentativas. Peça outro ao DailyObra.' using errcode = 'P0001';
  end if;
  if sha256(convert_to(v_codigo, 'UTF8')) <> c.codigo_hash then
    update private.codigos_loja set tentativas = tentativas + 1 where loja_id = c.loja_id;
    return null;
  end if;
  insert into public.loja_membros (loja_id, user_id, papel) values (c.loja_id, uid, 'dono');
  update private.codigos_loja set usado_em = now(), usado_por = uid where loja_id = c.loja_id;
  return c.loja_id;
end $$;

revoke execute on function public.assumir_loja(text, text) from public, anon;
grant execute on function public.assumir_loja(text, text) to authenticated;
