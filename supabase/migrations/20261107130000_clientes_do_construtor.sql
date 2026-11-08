-- Clientes do construtor: quem paga a obra dele. Na cotação o construtor escolhe se paga ou se o cliente paga; com cliente,
-- o pedido nasce no nome dele, com o documento para a nota e o link de pagamento pronto para enviar pelo WhatsApp.

create table public.construtor_clientes (
  id uuid primary key default gen_random_uuid(),
  construtor_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nome text not null check (char_length(btrim(nome)) between 2 and 120),
  whatsapp text not null check (whatsapp ~ '^[0-9]{10,13}$'),
  documento text not null check (private.documento_valido(documento)),
  criado_em timestamptz not null default now(),
  unique (construtor_id, documento)
);
alter table public.construtor_clientes enable row level security;
create policy "cada um cuida dos seus clientes" on public.construtor_clientes for all to authenticated
  using (construtor_id = (select auth.uid())) with check (construtor_id = (select auth.uid()));
revoke all on public.construtor_clientes from anon;
revoke truncate on public.construtor_clientes from authenticated;

alter table public.propostas add column cliente_id uuid references public.construtor_clientes (id) on delete set null;

-- Chamada logo depois de enviar_cotacao. Cliente nulo: o construtor paga.
create function public.definir_pagador_do_orcamento(p_orcamento uuid, p_cliente uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid());
begin
  if not exists (select 1 from public.orcamentos o where o.id = p_orcamento and o.construtor_id = uid) then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if p_cliente is not null and not exists (select 1 from public.construtor_clientes c where c.id = p_cliente and c.construtor_id = uid) then
    raise exception 'Cliente não encontrado.' using errcode = 'P0001';
  end if;
  update public.propostas set cliente_id = p_cliente where orcamento_id = p_orcamento;
end $$;
revoke all on function public.definir_pagador_do_orcamento(uuid, uuid) from public, anon;
grant execute on function public.definir_pagador_do_orcamento(uuid, uuid) to authenticated;

-- O pedido de proposta com cliente nasce no nome dele, com o link e por PIX, como o link do cliente faz.
-- Roda depois de pedidos_forma_da_proposta (ordem alfabética), então a forma da cotação dá lugar ao PIX do link.
create function private.pagador_da_proposta() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_nome text; v_whatsapp text; cod text;
begin
  if new.pagador is not null then return new; end if;
  select c.nome, c.whatsapp into v_nome, v_whatsapp
    from public.propostas p join public.construtor_clientes c on c.id = p.cliente_id
   where p.id = new.proposta_id;
  if v_nome is null then return new; end if;
  loop
    -- 16 bytes aleatórios em base64 URL-safe: exatamente 22 caracteres
    cod := translate(encode(decode(replace(gen_random_uuid()::text, '-', ''), 'hex'), 'base64'), '+/=', '-_');
    exit when not exists (select 1 from public.pedidos where link_codigo = cod);
  end loop;
  new.pagador := 'cliente';
  new.pagador_nome := left(btrim(v_nome), 120);
  new.pagador_whatsapp := v_whatsapp;
  new.link_codigo := cod;
  new.documento_informado_em := now();
  new.forma_pagamento := 'pix';
  new.parcelas := null;
  new.prazo := null;
  new.prazo_status := null;
  new.prazo_respondido_em := null;
  return new;
end $$;
create trigger pedidos_pagador_da_proposta before insert on public.pedidos
  for each row execute function private.pagador_da_proposta();

-- O documento só existe depois do pedido: vai para pedido_documentos, que só a loja lê
create function private.documento_do_cliente() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.pagador = 'cliente' and new.link_codigo is not null
     and not exists (select 1 from public.pedido_documentos d where d.pedido_id = new.id) then
    insert into public.pedido_documentos (pedido_id, documento)
    select new.id, c.documento
      from public.propostas p join public.construtor_clientes c on c.id = p.cliente_id
     where p.id = new.proposta_id;
  end if;
  return null;
end $$;
create trigger pedidos_documento_do_cliente after insert on public.pedidos
  for each row execute function private.documento_do_cliente();

-- Excluir a conta também apaga os clientes cadastrados
create or replace function public.excluir_conta(p_confirmacao text)
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
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
  delete from public.construtor_propostas where user_id = uid;
  delete from public.construtor_clientes where construtor_id = uid;
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
end $function$;
