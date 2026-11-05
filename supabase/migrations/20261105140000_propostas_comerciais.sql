-- Proposta comercial do engenheiro para o cliente dele. Nasce antes da obra, por isso é da pessoa e não de uma obra. Não confundir com
-- public.propostas, que é a resposta de uma loja a um orçamento. Itens e parcelas ficam juntos na proposta porque só fazem sentido nela.
-- Quando o cliente aceita, a proposta vira obra e as parcelas entram no caixa como entradas previstas. Depois disso ela não muda.
-- Excluir a conta agora apaga as propostas: elas guardam nome e contato de clientes.

create table public.construtor_propostas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  numero int not null,
  cliente text not null check (char_length(btrim(cliente)) between 1 and 160),
  contato text check (char_length(contato) <= 120),
  titulo text not null check (char_length(btrim(titulo)) between 1 and 160),
  endereco text check (char_length(endereco) <= 300),
  cidade text check (char_length(cidade) <= 120),
  uf text check (char_length(uf) <= 2),
  area numeric(10, 2) check (area is null or area > 0),
  padrao text check (padrao in ('economico', 'medio', 'media_alta', 'alto')),
  itens jsonb not null default '[]'::jsonb,
  desconto numeric(12, 2) not null default 0 check (desconto >= 0),
  mostrar_valores boolean not null default true,
  parcelas jsonb not null default '[]'::jsonb,
  inclui text check (char_length(inclui) <= 2000),
  nao_inclui text check (char_length(nao_inclui) <= 2000),
  prazo_dias int check (prazo_dias is null or prazo_dias between 1 and 3650),
  validade date,
  observacoes text check (char_length(observacoes) <= 2000),
  situacao text not null default 'rascunho' check (situacao in ('rascunho', 'enviada', 'aceita', 'recusada')),
  obra_id uuid references public.obras (id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (user_id, numero)
);
create index construtor_propostas_obra_idx on public.construtor_propostas (obra_id);
alter table public.construtor_propostas enable row level security;
create policy "cada um le as suas propostas" on public.construtor_propostas for select to authenticated
  using (user_id = (select auth.uid()));
create policy "cada um apaga as suas propostas" on public.construtor_propostas for delete to authenticated
  using (user_id = (select auth.uid()));

-- O número segue a sequência de cada pessoa. Devolve o id e o número, porque o PDF sai logo depois de salvar.
create function public.salvar_proposta_comercial(p_id uuid, p_dados jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  nome text := btrim(coalesce(d ->> 'cliente', ''));
  texto text := btrim(coalesce(d ->> 'titulo', ''));
  servicos jsonb := coalesce(d -> 'itens', '[]'::jsonb);
  pagamento jsonb := coalesce(d -> 'parcelas', '[]'::jsonb);
  x jsonb;
  atual public.construtor_propostas;
  id_final uuid;
  n int;
begin
  if uid is null then raise exception 'Entre na sua conta para salvar.' using errcode = 'P0001'; end if;
  if nome = '' then raise exception 'Diga quem é o cliente.' using errcode = 'P0001'; end if;
  if texto = '' then raise exception 'Diga o nome da obra ou do serviço.' using errcode = 'P0001'; end if;
  if char_length(nome) > 160 or char_length(texto) > 160 then
    raise exception 'Use no máximo 160 letras nos nomes.' using errcode = 'P0001';
  end if;
  if jsonb_typeof(servicos) is distinct from 'array' or jsonb_typeof(pagamento) is distinct from 'array' then
    raise exception 'Proposta inválida.' using errcode = 'P0001';
  end if;
  if jsonb_array_length(servicos) > 100 then raise exception 'Use no máximo 100 itens.' using errcode = 'P0001'; end if;
  if jsonb_array_length(pagamento) > 24 then raise exception 'Use no máximo 24 parcelas.' using errcode = 'P0001'; end if;
  for x in select * from jsonb_array_elements(servicos) loop
    if char_length(btrim(coalesce(x ->> 'descricao', ''))) not between 1 and 200 then
      raise exception 'Cada item precisa de uma descrição de até 200 letras.' using errcode = 'P0001';
    end if;
    if coalesce((x ->> 'valor')::numeric, -1) < 0 then
      raise exception 'Confira os valores dos itens.' using errcode = 'P0001';
    end if;
  end loop;
  for x in select * from jsonb_array_elements(pagamento) loop
    if char_length(btrim(coalesce(x ->> 'descricao', ''))) not between 1 and 120 then
      raise exception 'Cada parcela precisa de uma descrição de até 120 letras.' using errcode = 'P0001';
    end if;
    if coalesce((x ->> 'percentual')::numeric, -1) not between 0 and 100 then
      raise exception 'Confira os percentuais das parcelas.' using errcode = 'P0001';
    end if;
    if coalesce((x ->> 'dias')::int, 0) not between 0 and 3650 then
      raise exception 'Confira os prazos das parcelas.' using errcode = 'P0001';
    end if;
  end loop;

  if p_id is null then
    perform pg_advisory_xact_lock(hashtext('proposta:' || uid::text));
    select coalesce(max(p.numero), 0) + 1 into n from public.construtor_propostas p where p.user_id = uid;
    insert into public.construtor_propostas (
      user_id, numero, cliente, contato, titulo, endereco, cidade, uf, area, padrao, itens, desconto, mostrar_valores, parcelas,
      inclui, nao_inclui, prazo_dias, validade, observacoes, situacao
    ) values (
      uid, n, nome, nullif(btrim(coalesce(d ->> 'contato', '')), ''), texto, nullif(btrim(coalesce(d ->> 'endereco', '')), ''),
      nullif(btrim(coalesce(d ->> 'cidade', '')), ''), nullif(btrim(coalesce(d ->> 'uf', '')), ''), (d ->> 'area')::numeric,
      nullif(d ->> 'padrao', ''), servicos, round(coalesce((d ->> 'desconto')::numeric, 0), 2),
      coalesce((d ->> 'mostrar_valores')::boolean, true), pagamento, nullif(btrim(coalesce(d ->> 'inclui', '')), ''),
      nullif(btrim(coalesce(d ->> 'nao_inclui', '')), ''), (d ->> 'prazo_dias')::int, (d ->> 'validade')::date,
      nullif(btrim(coalesce(d ->> 'observacoes', '')), ''), coalesce(nullif(d ->> 'situacao', ''), 'rascunho')
    ) returning id into id_final;
    return jsonb_build_object('id', id_final, 'numero', n);
  end if;

  select * into atual from public.construtor_propostas p where p.id = p_id and p.user_id = uid for update;
  if not found then raise exception 'Proposta não encontrada.' using errcode = 'P0001'; end if;
  if atual.obra_id is not null then raise exception 'Proposta que virou obra não muda.' using errcode = 'P0001'; end if;
  update public.construtor_propostas p
     set cliente = nome, contato = nullif(btrim(coalesce(d ->> 'contato', '')), ''), titulo = texto,
         endereco = nullif(btrim(coalesce(d ->> 'endereco', '')), ''), cidade = nullif(btrim(coalesce(d ->> 'cidade', '')), ''),
         uf = nullif(btrim(coalesce(d ->> 'uf', '')), ''), area = (d ->> 'area')::numeric, padrao = nullif(d ->> 'padrao', ''),
         itens = servicos, desconto = round(coalesce((d ->> 'desconto')::numeric, 0), 2),
         mostrar_valores = coalesce((d ->> 'mostrar_valores')::boolean, true), parcelas = pagamento,
         inclui = nullif(btrim(coalesce(d ->> 'inclui', '')), ''), nao_inclui = nullif(btrim(coalesce(d ->> 'nao_inclui', '')), ''),
         prazo_dias = (d ->> 'prazo_dias')::int, validade = (d ->> 'validade')::date,
         observacoes = nullif(btrim(coalesce(d ->> 'observacoes', '')), ''), situacao = coalesce(nullif(d ->> 'situacao', ''), p.situacao),
         atualizado_em = now()
   where p.id = p_id;
  return jsonb_build_object('id', p_id, 'numero', atual.numero);
end $$;

-- Liga a proposta aceita à obra e leva as parcelas para o caixa. A última parcela fecha o total, sem sobra de arredondamento.
create function public.proposta_vira_obra(p_id uuid, p_obra uuid, p_inicio date) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  p public.construtor_propostas;
  total numeric;
  acumulado numeric := 0;
  v numeric;
  n int;
  x jsonb;
  ordem bigint;
begin
  select * into p from public.construtor_propostas c where c.id = p_id and c.user_id = uid for update;
  if not found then raise exception 'Proposta não encontrada.' using errcode = 'P0001'; end if;
  if not coalesce(private.is_admin(p_obra), false) then raise exception 'Obra não encontrada.' using errcode = 'P0001'; end if;
  if p.situacao <> 'aceita' then raise exception 'Marque a proposta como aceita antes de criar a obra.' using errcode = 'P0001'; end if;
  if p.obra_id is not null then raise exception 'Esta proposta já virou obra.' using errcode = 'P0001'; end if;
  if p_inicio is null then raise exception 'Escolha a data de início.' using errcode = 'P0001'; end if;
  select greatest(coalesce(sum((i ->> 'valor')::numeric), 0) - p.desconto, 0) into total from jsonb_array_elements(p.itens) i;
  n := jsonb_array_length(p.parcelas);
  for x, ordem in select e, o from jsonb_array_elements(p.parcelas) with ordinality as t (e, o) loop
    v := case when ordem = n then total - acumulado else round(total * (x ->> 'percentual')::numeric / 100, 2) end;
    acumulado := acumulado + v;
    if v > 0 then
      insert into public.obra_entradas (obra_id, descricao, valor, data, recebido)
      values (p_obra, left(x ->> 'descricao', 200), v, p_inicio + coalesce((x ->> 'dias')::int, 0), false);
    end if;
  end loop;
  update public.construtor_propostas c set obra_id = p_obra, atualizado_em = now() where c.id = p_id;
end $$;

revoke execute on function public.salvar_proposta_comercial(uuid, jsonb) from public, anon;
revoke execute on function public.proposta_vira_obra(uuid, uuid, date) from public, anon;
grant execute on function public.salvar_proposta_comercial(uuid, jsonb) to authenticated;
grant execute on function public.proposta_vira_obra(uuid, uuid, date) to authenticated;

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
  delete from public.construtor_propostas where user_id = uid;
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
