-- Regras do marketplace no servidor: cadastro de loja, envio de cotação, negociação, pedido e carteira.
-- Todas as funções conferem quem chamou (auth.uid()) e o papel, gravam evento e rodam numa transação.
-- Erros de regra: P0001 com mensagem em português, mostrada como está no app.
-- Reversão: drop das funções public.* e private.* criadas aqui e da visão public.carteira_saldos.

-- ---------- Utilidades ----------
create function private.brl(p numeric) returns text language sql immutable set search_path = '' as $$
  select 'R$ ' || replace(replace(replace(to_char(round(p, 2), 'FM999,999,999,990.00'), ',', '#'), '.', ','), '#', '.');
$$;

create function private.cnpj_valido(p text) returns boolean language plpgsql immutable set search_path = '' as $$
declare
  d text := regexp_replace(coalesce(p, ''), '\D', '', 'g');
  pesos1 int[] := array[5,4,3,2,9,8,7,6,5,4,3,2];
  pesos2 int[] := array[6,5,4,3,2,9,8,7,6,5,4,3,2];
  soma int; resto int; dv1 int; dv2 int;
begin
  if length(d) <> 14 or d ~ '^(\d)\1{13}$' then return false; end if;
  soma := 0;
  for i in 1..12 loop soma := soma + substr(d, i, 1)::int * pesos1[i]; end loop;
  resto := soma % 11; dv1 := case when resto < 2 then 0 else 11 - resto end;
  soma := 0;
  for i in 1..13 loop soma := soma + substr(d, i, 1)::int * pesos2[i]; end loop;
  resto := soma % 11; dv2 := case when resto < 2 then 0 else 11 - resto end;
  return substr(d, 13, 1)::int = dv1 and substr(d, 14, 1)::int = dv2;
end $$;

create function private.preco_vigente(p_preco numeric, p_promo numeric, p_ate date) returns numeric
language sql immutable set search_path = '' as $$
  select case when p_promo is not null and p_ate >= current_date then p_promo else p_preco end;
$$;

create function private.percentual_tier(p_tier smallint) returns numeric language sql stable set search_path = '' as $$
  select coalesce((select percentual from public.cashback_tiers where tier = p_tier), 0);
$$;

create function private.saldo(p_construtor uuid, p_conta text) returns numeric language sql stable set search_path = '' as $$
  select coalesce(sum(valor), 0) from public.carteira_lancamentos where construtor_id = p_construtor and conta = p_conta;
$$;

-- Lançamento em partidas dobradas: tira de uma conta e põe na outra, na mesma transação
create function private.mover(p_construtor uuid, p_de text, p_para text, p_valor numeric, p_tipo text, p_descricao text,
                              p_loja uuid, p_pedido uuid, p_proposta uuid, p_tier smallint default null)
returns void language plpgsql set search_path = '' as $$
declare t uuid := gen_random_uuid();
begin
  if p_valor is null or p_valor <= 0 then return; end if;
  insert into public.carteira_lancamentos (transacao_id, construtor_id, conta, valor, tipo, descricao, tier, loja_id, pedido_id, proposta_id)
  values (t, p_construtor, p_de, -p_valor, p_tipo, p_descricao, p_tier, p_loja, p_pedido, p_proposta),
         (t, p_construtor, p_para, p_valor, p_tipo, p_descricao, p_tier, p_loja, p_pedido, p_proposta);
end $$;

create function private.evento_proposta(p_proposta uuid, p_de text, p_para text, p_papel text, p_valores jsonb, p_justificativa text)
returns void language sql set search_path = '' as $$
  insert into public.proposta_eventos (proposta_id, de, para, autor, papel, valores, justificativa)
  values (p_proposta, p_de, p_para, (select auth.uid()), p_papel, p_valores, p_justificativa);
$$;

-- Devolve à conta disponível o saldo reservado numa proposta que não virou pedido
create function private.devolver_reserva(p_proposta uuid) returns void language plpgsql set search_path = '' as $$
declare p record; reservado numeric;
begin
  select pr.*, l.nome as loja_nome into p from public.propostas pr join public.lojas l on l.id = pr.loja_id where pr.id = p_proposta;
  select coalesce(sum(valor), 0) into reservado from public.carteira_lancamentos
   where proposta_id = p_proposta and conta = 'reservado';
  perform private.mover(p.construtor_id, 'reservado', 'disponivel', reservado, 'saldo_devolvido',
                        'Saldo devolvido: proposta à ' || p.loja_nome || ' encerrada', p.loja_id, null, p_proposta);
end $$;

-- Propostas sem resposta no prazo viram expiradas e devolvem a reserva
create function public.expirar_propostas() returns int language plpgsql security definer set search_path = '' as $$
declare p record; n int := 0;
begin
  for p in select id, status from public.propostas
            where status in ('enviada', 'contraproposta') and valida_ate < now()
            for update skip locked loop
    update public.propostas set status = 'expirada' where id = p.id;
    perform private.devolver_reserva(p.id);
    insert into public.proposta_eventos (proposta_id, de, para, papel, justificativa)
    values (p.id, p.status, 'expirada', 'sistema', 'Prazo de resposta vencido');
    n := n + 1;
  end loop;
  return n;
end $$;

-- ---------- Loja ----------
create function public.criar_loja(p jsonb) returns uuid language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); id_loja uuid; cnpj text := regexp_replace(coalesce(p->>'cnpj', ''), '\D', '', 'g');
begin
  if uid is null then raise exception 'Entre na sua conta para cadastrar a loja.' using errcode = 'P0001'; end if;
  if not private.cnpj_valido(cnpj) then raise exception 'CNPJ inválido. Confira os números.' using errcode = 'P0001'; end if;
  if char_length(btrim(coalesce(p->>'nome', ''))) < 2 then raise exception 'Informe o nome da loja.' using errcode = 'P0001'; end if;
  if char_length(btrim(coalesce(p->>'cidade', ''))) < 2 then raise exception 'Informe a cidade da loja.' using errcode = 'P0001'; end if;
  if coalesce(p->>'uf', '') !~ '^[A-Z]{2}$' then raise exception 'Escolha o estado da loja.' using errcode = 'P0001'; end if;
  begin
    insert into public.lojas (nome, cnpj, descricao, whatsapp, endereco, cidade, uf, horario, frete_fixo, pedido_minimo)
    values (btrim(p->>'nome'), cnpj, nullif(btrim(p->>'descricao'), ''), nullif(regexp_replace(coalesce(p->>'whatsapp', ''), '\D', '', 'g'), ''),
            nullif(btrim(p->>'endereco'), ''), btrim(p->>'cidade'), p->>'uf', nullif(btrim(p->>'horario'), ''),
            coalesce((p->>'frete_fixo')::numeric, 0), coalesce((p->>'pedido_minimo')::numeric, 0))
    returning id into id_loja;
  exception when unique_violation then
    raise exception 'Já existe uma loja cadastrada com este CNPJ.' using errcode = 'P0001';
  end;
  insert into public.loja_membros (loja_id, user_id, papel) values (id_loja, uid, 'dono');
  return id_loja;
end $$;

-- ---------- Envio de cotação ----------
create function public.enviar_cotacao(p_itens jsonb, p_modo text, p_obra uuid, p_usar_saldo boolean, p_mensagem text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  it jsonb; loja record; o record; ci record;
  id_orc uuid; id_prop uuid;
  qtd numeric; preco numeric; atualizados boolean := false;
  subtotal numeric; cashback numeric; total_geral numeric := 0;
  resultado jsonb := '[]'::jsonb;
  disponivel numeric; aplicado numeric; restante numeric; prop record; i int; n int;
begin
  if uid is null then raise exception 'Entre na sua conta para enviar o orçamento.' using errcode = 'P0001'; end if;
  if p_modo not in ('negociacao', 'pedido') then raise exception 'Escolha entre proposta e pedido.' using errcode = 'P0001'; end if;
  if jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'O orçamento está vazio.' using errcode = 'P0001';
  end if;
  if jsonb_array_length(p_itens) > 300 then raise exception 'Orçamento com itens demais (máximo 300).' using errcode = 'P0001'; end if;
  if p_obra is not null and not exists (select 1 from public.obras ob where ob.id = p_obra and (ob.created_by = uid or private.is_membro(ob.id))) then
    raise exception 'Obra não encontrada na sua conta.' using errcode = 'P0001';
  end if;
  perform public.expirar_propostas();

  -- Valida todos os itens antes de gravar qualquer coisa
  for it in select * from jsonb_array_elements(p_itens) loop
    qtd := (it->>'quantidade')::numeric;
    if qtd is null or qtd <= 0 then raise exception 'Quantidade inválida no orçamento.' using errcode = 'P0001'; end if;
    select * into loja from public.lojas where id = (it->>'loja_id')::uuid;
    if not found or loja.status <> 'ativa' then raise exception 'Uma das lojas do orçamento não está disponível.' using errcode = 'P0001'; end if;
    select * into ci from public.catalogo_itens where id = it->>'item_id';
    if not found then raise exception 'Produto não encontrado no catálogo.' using errcode = 'P0001'; end if;
    select * into o from public.ofertas where loja_id = loja.id and item_id = ci.id;
    if not found or o.pausada or o.disponibilidade = 'sem_estoque' then
      raise exception '% não está mais à venda na %. Troque a loja deste item.', ci.nome, loja.nome using errcode = 'P0001';
    end if;
  end loop;

  insert into public.orcamentos (construtor_id, obra_id, modo, mensagem) values (uid, p_obra, p_modo, nullif(btrim(p_mensagem), ''))
  returning id into id_orc;

  for loja in select l.* from public.lojas l
               where l.id in (select distinct (e->>'loja_id')::uuid from jsonb_array_elements(p_itens) e) order by l.nome loop
    subtotal := 0; cashback := 0;
    insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, subtotal_anunciado, frete, total, valida_ate, mensagem_construtor)
    values (id_orc, loja.id, uid, p_modo, 0, loja.frete_fixo, 0, now() + interval '48 hours', nullif(btrim(p_mensagem), ''))
    returning id into id_prop;
    -- Itens repetidos da mesma loja somam as quantidades
    for it in select jsonb_build_object('item_id', e->>'item_id', 'quantidade', sum((e->>'quantidade')::numeric),
                                        'preco_visto', max((e->>'preco_visto')::numeric))
                from jsonb_array_elements(p_itens) e where (e->>'loja_id')::uuid = loja.id group by e->>'item_id' loop
      select * into ci from public.catalogo_itens where id = it->>'item_id';
      select * into o from public.ofertas where loja_id = loja.id and item_id = ci.id;
      preco := private.preco_vigente(o.preco, o.preco_promocional, o.promo_ate);
      if it->>'preco_visto' is not null and round((it->>'preco_visto')::numeric, 2) <> preco then atualizados := true; end if;
      qtd := (it->>'quantidade')::numeric;
      insert into public.proposta_itens (proposta_id, item_id, nome, unidade, tier, quantidade, preco_anunciado)
      values (id_prop, ci.id, ci.nome, ci.unidade, ci.tier_cashback, qtd, preco);
      subtotal := subtotal + round(qtd * preco, 2);
      cashback := cashback + round(qtd * preco, 2) * private.percentual_tier(ci.tier_cashback);
    end loop;
    if subtotal < loja.pedido_minimo then
      raise exception 'O pedido mínimo da % é %. Faltam % nesta loja.', loja.nome, private.brl(loja.pedido_minimo),
        private.brl(loja.pedido_minimo - subtotal) using errcode = 'P0001';
    end if;
    update public.propostas set subtotal_anunciado = subtotal, total = subtotal + loja.frete_fixo, cashback_previsto = round(cashback, 2)
     where id = id_prop;
    perform private.evento_proposta(id_prop, null, 'enviada', 'construtor', jsonb_build_object('subtotal', subtotal, 'frete', loja.frete_fixo), null);
    total_geral := total_geral + subtotal + loja.frete_fixo;
  end loop;

  -- Saldo da carteira: reserva proporcional ao total de cada proposta, sem passar do disponível
  if p_usar_saldo then
    perform pg_advisory_xact_lock(hashtext('carteira:' || uid::text));
    disponivel := private.saldo(uid, 'disponivel');
    restante := least(disponivel, total_geral);
    select count(*) into n from public.propostas where orcamento_id = id_orc;
    i := 0;
    for prop in select pr.id, pr.total, pr.loja_id, l.nome as loja_nome from public.propostas pr join public.lojas l on l.id = pr.loja_id
                 where pr.orcamento_id = id_orc order by pr.total desc loop
      i := i + 1;
      aplicado := case when i = n then restante else least(restante, round(least(disponivel, total_geral) * prop.total / nullif(total_geral, 0), 2)) end;
      aplicado := least(aplicado, prop.total);
      if aplicado > 0 then
        update public.propostas set saldo_aplicado = aplicado where id = prop.id;
        perform private.mover(uid, 'disponivel', 'reservado', aplicado, 'saldo_reservado', 'Saldo reservado: proposta à ' || prop.loja_nome, prop.loja_id, null, prop.id);
        restante := restante - aplicado;
      end if;
    end loop;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'loja_id', loja_id, 'total', total, 'saldo_aplicado', saldo_aplicado) order by total desc), '[]'::jsonb)
    into resultado from public.propostas where orcamento_id = id_orc;
  return jsonb_build_object('orcamento_id', id_orc, 'propostas', resultado, 'precos_atualizados', atualizados);
end $$;

-- ---------- Aceite: vira pedido, usa o saldo reservado e lança o cashback pendente ----------
create function private.aceitar(p_proposta uuid, p_papel text) returns void language plpgsql set search_path = '' as $$
declare p record; id_pedido uuid; reservado numeric; tier_max smallint;
begin
  select pr.*, l.nome as loja_nome into p from public.propostas pr join public.lojas l on l.id = pr.loja_id where pr.id = p_proposta;
  update public.propostas set status = 'aceita' where id = p_proposta;
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total)
  values (p_proposta, p.loja_id, p.construtor_id, greatest(p.total - p.saldo_aplicado, 0)) returning id into id_pedido;
  insert into public.pedido_eventos (pedido_id, de, para, autor) values (id_pedido, null, 'confirmado', (select auth.uid()));
  perform private.evento_proposta(p_proposta, p.status, 'aceita', p_papel, jsonb_build_object('total', p.total), null);
  select coalesce(sum(valor), 0) into reservado from public.carteira_lancamentos where proposta_id = p_proposta and conta = 'reservado';
  perform private.mover(p.construtor_id, 'reservado', 'emissor', reservado, 'saldo_usado', 'Saldo usado no pedido da ' || p.loja_nome,
                        p.loja_id, id_pedido, p_proposta);
  select max(tier) into tier_max from public.proposta_itens where proposta_id = p_proposta;
  perform private.mover(p.construtor_id, 'emissor', 'pendente', p.cashback_previsto, 'cashback_previsto',
                        'Cashback do pedido na ' || p.loja_nome, p.loja_id, id_pedido, p_proposta, tier_max);
end $$;

-- ---------- Resposta da loja ----------
create function public.responder_proposta(p_proposta uuid, p_acao text, p_precos jsonb, p_desconto numeric,
                                          p_mensagem text, p_motivo text, p_validade_horas int)
returns text language plpgsql security definer set search_path = '' as $$
declare
  p record; papel text; it jsonb; item record; novo numeric;
  subtotal_of numeric; base_cashback numeric; v_desconto numeric := coalesce(p_desconto, 0); total_novo numeric;
  baixou boolean := false; excesso numeric;
begin
  perform public.expirar_propostas();
  select * into p from public.propostas where id = p_proposta for update;
  if not found then raise exception 'Proposta não encontrada.' using errcode = 'P0001'; end if;
  papel := private.membro_loja(p.loja_id);
  if papel is null then raise exception 'Esta proposta não é da sua loja.' using errcode = 'P0001'; end if;
  if p.status <> 'enviada' then
    raise exception 'Esta proposta não está mais aguardando resposta (situação: %).', p.status using errcode = 'P0001';
  end if;

  if p_acao = 'aceitar' then
    perform private.aceitar(p_proposta, papel);
    return 'aceita';
  elsif p_acao = 'recusar' then
    if char_length(btrim(coalesce(p_motivo, ''))) < 3 then raise exception 'Informe o motivo da recusa.' using errcode = 'P0001'; end if;
    update public.propostas set status = 'recusada', motivo_recusa = btrim(p_motivo), mensagem_loja = nullif(btrim(p_mensagem), '') where id = p_proposta;
    perform private.devolver_reserva(p_proposta);
    perform private.evento_proposta(p_proposta, 'enviada', 'recusada', papel, null, btrim(p_motivo));
    return 'recusada';
  elsif p_acao = 'contrapropor' then
    if p.modo <> 'negociacao' then
      raise exception 'Pedido direto não aceita contraproposta: confirme ou recuse.' using errcode = 'P0001';
    end if;
    if coalesce(p_validade_horas, 0) not in (24, 48, 72) then raise exception 'Escolha a validade: 24, 48 ou 72 horas.' using errcode = 'P0001'; end if;
    if v_desconto < 0 then raise exception 'O desconto não pode ser negativo.' using errcode = 'P0001'; end if;
    for it in select * from jsonb_array_elements(coalesce(p_precos, '[]'::jsonb)) loop
      select * into item from public.proposta_itens where proposta_id = p_proposta and item_id = it->>'item_id';
      if not found then raise exception 'Item da contraproposta não está nesta proposta.' using errcode = 'P0001'; end if;
      novo := round((it->>'preco')::numeric, 2);
      if novo is null or novo <= 0 then raise exception 'Preço inválido para %.', item.nome using errcode = 'P0001'; end if;
      if novo > item.preco_anunciado then
        raise exception 'O preço de % só pode baixar (anunciado %).', item.nome, private.brl(item.preco_anunciado) using errcode = 'P0001';
      end if;
      if novo < item.preco_anunciado then baixou := true; end if;
      update public.proposta_itens set preco_ofertado = novo where id = item.id;
    end loop;
    select coalesce(sum(round(quantidade * coalesce(preco_ofertado, preco_anunciado), 2)), 0),
           coalesce(sum(round(quantidade * coalesce(preco_ofertado, preco_anunciado), 2) * private.percentual_tier(tier)), 0)
      into subtotal_of, base_cashback from public.proposta_itens where proposta_id = p_proposta;
    if v_desconto > subtotal_of then raise exception 'O desconto não pode passar de %.', private.brl(subtotal_of) using errcode = 'P0001'; end if;
    if not baixou and v_desconto = 0 then
      raise exception 'Para fazer contraproposta, baixe ao menos um preço ou dê desconto.' using errcode = 'P0001';
    end if;
    total_novo := subtotal_of - v_desconto + p.frete;
    update public.propostas
       set status = 'contraproposta', desconto = v_desconto, total = total_novo,
           cashback_previsto = round(case when subtotal_of > 0 then base_cashback * (subtotal_of - v_desconto) / subtotal_of else 0 end, 2),
           mensagem_loja = nullif(btrim(p_mensagem), ''), valida_ate = now() + make_interval(hours => p_validade_horas)
     where id = p_proposta;
    -- Saldo reservado nunca maior que o novo total
    excesso := p.saldo_aplicado - total_novo;
    if excesso > 0 then
      update public.propostas set saldo_aplicado = total_novo where id = p_proposta;
      perform private.mover(p.construtor_id, 'reservado', 'disponivel', excesso, 'saldo_devolvido', 'Saldo devolvido: proposta com novo total', p.loja_id, null, p_proposta);
    end if;
    perform private.evento_proposta(p_proposta, 'enviada', 'contraproposta', papel,
      jsonb_build_object('subtotal', subtotal_of, 'desconto', v_desconto, 'total', total_novo, 'precos', p_precos), nullif(btrim(p_mensagem), ''));
    return 'contraproposta';
  else
    raise exception 'Ação inválida.' using errcode = 'P0001';
  end if;
end $$;

-- ---------- Decisão do construtor ----------
create function public.decidir_contraproposta(p_proposta uuid, p_aceitar boolean) returns text
language plpgsql security definer set search_path = '' as $$
declare p record;
begin
  perform public.expirar_propostas();
  select * into p from public.propostas where id = p_proposta for update;
  if not found or p.construtor_id <> (select auth.uid()) then raise exception 'Proposta não encontrada.' using errcode = 'P0001'; end if;
  if p.status <> 'contraproposta' then raise exception 'Não há contraproposta aberta nesta proposta.' using errcode = 'P0001'; end if;
  if p_aceitar then
    perform private.aceitar(p_proposta, 'construtor');
    return 'aceita';
  end if;
  update public.propostas set status = 'recusada', motivo_recusa = 'Contraproposta recusada pelo construtor' where id = p_proposta;
  perform private.devolver_reserva(p_proposta);
  perform private.evento_proposta(p_proposta, 'contraproposta', 'recusada', 'construtor', null, 'Contraproposta recusada pelo construtor');
  return 'recusada';
end $$;

create function public.cancelar_proposta(p_proposta uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare p record;
begin
  perform public.expirar_propostas();
  select * into p from public.propostas where id = p_proposta for update;
  if not found or p.construtor_id <> (select auth.uid()) then raise exception 'Proposta não encontrada.' using errcode = 'P0001'; end if;
  if p.status not in ('enviada', 'contraproposta') then raise exception 'Esta proposta não pode mais ser cancelada.' using errcode = 'P0001'; end if;
  update public.propostas set status = 'cancelada' where id = p_proposta;
  perform private.devolver_reserva(p_proposta);
  perform private.evento_proposta(p_proposta, p.status, 'cancelada', 'construtor', null, null);
  return 'cancelada';
end $$;

-- ---------- Pedido ----------
create function private.liberar_cashback(p_pedido uuid) returns void language plpgsql set search_path = '' as $$
declare pe record; pendente numeric;
begin
  select pd.*, l.nome as loja_nome into pe from public.pedidos pd join public.lojas l on l.id = pd.loja_id where pd.id = p_pedido;
  select coalesce(sum(valor), 0) into pendente from public.carteira_lancamentos where pedido_id = p_pedido and conta = 'pendente';
  perform private.mover(pe.construtor_id, 'pendente', 'disponivel', pendente, 'cashback_liberado',
                        'Cashback liberado: pedido na ' || pe.loja_nome, pe.loja_id, p_pedido, pe.proposta_id);
end $$;

create function public.atualizar_pedido(p_pedido uuid, p_status text) returns text
language plpgsql security definer set search_path = '' as $$
declare pe record; papel text; uid uuid := (select auth.uid()); pendente numeric; usado numeric;
  proximo text;
begin
  select pd.*, l.nome as loja_nome into pe from public.pedidos pd join public.lojas l on l.id = pd.loja_id where pd.id = p_pedido for update of pd;
  if not found then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  papel := private.membro_loja(pe.loja_id);
  if papel is null and pe.construtor_id <> uid then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  proximo := case pe.status when 'confirmado' then 'em_separacao' when 'em_separacao' then 'saiu_entrega' when 'saiu_entrega' then 'entregue' end;

  if p_status = 'cancelado' then
    if not ((papel is not null and pe.status in ('confirmado', 'em_separacao')) or (pe.construtor_id = uid and pe.status = 'confirmado')) then
      raise exception 'Este pedido não pode mais ser cancelado.' using errcode = 'P0001';
    end if;
    update public.pedidos set status = 'cancelado' where id = p_pedido;
    select coalesce(sum(valor), 0) into pendente from public.carteira_lancamentos where pedido_id = p_pedido and conta = 'pendente';
    perform private.mover(pe.construtor_id, 'pendente', 'emissor', pendente, 'cashback_estornado', 'Cashback estornado: pedido cancelado na ' || pe.loja_nome,
                          pe.loja_id, p_pedido, pe.proposta_id);
    select coalesce(-sum(valor), 0) into usado from public.carteira_lancamentos
     where pedido_id = p_pedido and conta = 'reservado' and tipo = 'saldo_usado';
    perform private.mover(pe.construtor_id, 'emissor', 'disponivel', usado, 'saldo_devolvido', 'Saldo devolvido: pedido cancelado na ' || pe.loja_nome,
                          pe.loja_id, p_pedido, pe.proposta_id);
  elsif papel is not null and p_status = proximo then
    update public.pedidos set status = p_status, entregue_em = case when p_status = 'entregue' then now() else entregue_em end where id = p_pedido;
    if p_status = 'entregue' and pe.pagamento_confirmado_em is not null then perform private.liberar_cashback(p_pedido); end if;
  else
    raise exception 'Não é possível mudar o pedido de "%" para "%".', pe.status, p_status using errcode = 'P0001';
  end if;
  insert into public.pedido_eventos (pedido_id, de, para, autor) values (p_pedido, pe.status, p_status, uid);
  return p_status;
end $$;

create function public.confirmar_pagamento(p_pedido uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare pe record;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or private.membro_loja(pe.loja_id) is null then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if not private.pode_gerir_loja(pe.loja_id) then raise exception 'Só o dono ou o gerente da loja confirmam pagamento.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Pedido cancelado não recebe pagamento.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then raise exception 'O pagamento deste pedido já foi confirmado.' using errcode = 'P0001'; end if;
  update public.pedidos set pagamento_confirmado_em = now() where id = p_pedido;
  insert into public.pedido_eventos (pedido_id, de, para, autor) values (p_pedido, pe.status, 'pagamento_confirmado', (select auth.uid()));
  if pe.status = 'entregue' then perform private.liberar_cashback(p_pedido); end if;
end $$;

-- ---------- Saldos da carteira (cada um vê só o seu, pelo RLS da tabela) ----------
create view public.carteira_saldos with (security_invoker = true) as
  select construtor_id,
         coalesce(sum(valor) filter (where conta = 'disponivel'), 0) as disponivel,
         coalesce(sum(valor) filter (where conta = 'pendente'), 0) as pendente,
         coalesce(sum(valor) filter (where conta = 'reservado'), 0) as reservado
    from public.carteira_lancamentos group by construtor_id;

-- ---------- Permissões ----------
revoke execute on function private.brl(numeric), private.cnpj_valido(text), private.preco_vigente(numeric, numeric, date),
  private.percentual_tier(smallint), private.saldo(uuid, text),
  private.mover(uuid, text, text, numeric, text, text, uuid, uuid, uuid, smallint),
  private.evento_proposta(uuid, text, text, text, jsonb, text), private.devolver_reserva(uuid),
  private.aceitar(uuid, text), private.liberar_cashback(uuid) from public;
revoke execute on function public.expirar_propostas(), public.criar_loja(jsonb),
  public.enviar_cotacao(jsonb, text, uuid, boolean, text),
  public.responder_proposta(uuid, text, jsonb, numeric, text, text, int),
  public.decidir_contraproposta(uuid, boolean), public.cancelar_proposta(uuid),
  public.atualizar_pedido(uuid, text), public.confirmar_pagamento(uuid) from public, anon;
grant execute on function public.expirar_propostas(), public.criar_loja(jsonb),
  public.enviar_cotacao(jsonb, text, uuid, boolean, text),
  public.responder_proposta(uuid, text, jsonb, numeric, text, text, int),
  public.decidir_contraproposta(uuid, boolean), public.cancelar_proposta(uuid),
  public.atualizar_pedido(uuid, text), public.confirmar_pagamento(uuid) to authenticated;
grant select on public.carteira_saldos to authenticated;
