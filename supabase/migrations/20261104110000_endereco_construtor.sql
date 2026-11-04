-- Endereço completo do construtor e da obra. O do construtor fica fora de profiles porque toda loja que recebe proposta lê
-- aquela linha inteira, e endereço residencial é dado privado: só o próprio lê, como o documento. Cidade e estado continuam
-- em profiles, porque ordenam as lojas. A obra guarda as partes, e `endereco` segue como o texto mostrado nas telas.

create table public.construtor_enderecos (
  user_id uuid primary key references auth.users (id) on delete cascade,
  cep text check (cep ~ '^\d{8}$'),
  logradouro text check (char_length(logradouro) <= 120),
  numero text check (char_length(numero) <= 20),
  complemento text check (char_length(complemento) <= 60),
  bairro text check (char_length(bairro) <= 80)
);
alter table public.construtor_enderecos enable row level security;
create policy "endereco proprio" on public.construtor_enderecos for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke all on public.construtor_enderecos from anon;
revoke truncate on public.construtor_enderecos from authenticated;

alter table public.obras
  add column cep text check (cep ~ '^\d{8}$'),
  add column logradouro text check (char_length(logradouro) <= 120),
  add column numero text check (char_length(numero) <= 20),
  add column complemento text check (char_length(complemento) <= 60),
  add column bairro text check (char_length(bairro) <= 80);

-- A exclusão de conta também apaga o endereço; só a linha de construtor_enderecos é nova
create or replace function public.excluir_conta(p_confirmacao text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  id_loja uuid;
  p record;
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
  delete from public.leituras_lista where user_id = uid;
  -- Obra compartilhada fica com quem continua nela
  delete from public.obras o
   where o.created_by = uid
     and not exists (select 1 from public.obra_membros m where m.obra_id = o.id and m.user_id <> uid);
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
