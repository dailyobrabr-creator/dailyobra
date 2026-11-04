-- Oferta do construtor e Mesa do Gerente. Na proposta aberta em negociação o construtor oferece um total menor. Enquanto a
-- oferta espera, a proposta segue como está e só dono ou gerente respondem: aprovar vira desconto no total e cria o pedido
-- na hora; recusar mantém a proposta no valor de antes, e o construtor pode oferecer de novo. A tela normal de resposta fica
-- bloqueada com oferta pendente, para a loja não fechar pelo preço cheio quem pediu menos.

alter table public.propostas
  add column oferta_valor numeric(12, 2) check (oferta_valor > 0),
  add column oferta_status text check (oferta_status in ('pendente', 'aprovada', 'recusada')),
  add column oferta_mensagem text check (char_length(oferta_mensagem) <= 300),
  add column oferta_motivo text check (char_length(oferta_motivo) <= 300),
  add column oferta_em timestamptz,
  add constraint propostas_oferta_completa check ((oferta_status is null) = (oferta_valor is null));

create index propostas_ofertas_pendentes_idx on public.propostas (loja_id) where oferta_status = 'pendente';

create function public.fazer_oferta(p_proposta uuid, p_valor numeric, p_mensagem text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare p record; v numeric := round(p_valor, 2); mensagem text := left(nullif(btrim(p_mensagem), ''), 300);
begin
  perform public.expirar_propostas();
  select * into p from public.propostas where id = p_proposta for update;
  if not found or p.construtor_id <> (select auth.uid()) then raise exception 'Proposta não encontrada.' using errcode = 'P0001'; end if;
  if p.status not in ('enviada', 'contraproposta') then raise exception 'Esta proposta não aceita mais oferta.' using errcode = 'P0001'; end if;
  if p.modo <> 'negociacao' then raise exception 'Pedido direto não aceita oferta.' using errcode = 'P0001'; end if;
  if p.oferta_status = 'pendente' then raise exception 'Você já fez uma oferta. Aguarde a resposta da loja.' using errcode = 'P0001'; end if;
  if v is null or v >= p.total then
    raise exception 'A oferta precisa ser menor que o total de %.', private.brl(p.total) using errcode = 'P0001';
  end if;
  if v <= p.frete then
    raise exception 'A oferta precisa ser maior que o frete de %.', private.brl(p.frete) using errcode = 'P0001';
  end if;
  update public.propostas
     set oferta_valor = v, oferta_status = 'pendente', oferta_mensagem = mensagem, oferta_motivo = null, oferta_em = now()
   where id = p_proposta;
  perform private.evento_proposta(p_proposta, p.status, p.status, 'construtor', jsonb_build_object('oferta', v, 'decisao', 'feita'), mensagem);
end $$;

create function public.responder_oferta(p_proposta uuid, p_aprovar boolean, p_motivo text default null) returns text
language plpgsql security definer set search_path = '' as $$
declare
  p record; papel text; subtotal_of numeric; base_cashback numeric; v_desconto numeric; excesso numeric;
  motivo text := left(btrim(coalesce(p_motivo, '')), 300);
begin
  perform public.expirar_propostas();
  select * into p from public.propostas where id = p_proposta for update;
  if not found then raise exception 'Proposta não encontrada.' using errcode = 'P0001'; end if;
  papel := private.membro_loja(p.loja_id);
  if papel is null then raise exception 'Esta proposta não é da sua loja.' using errcode = 'P0001'; end if;
  if not coalesce(private.pode_gerir_loja(p.loja_id), false) then
    raise exception 'Só o dono ou o gerente responde à oferta.' using errcode = 'P0001';
  end if;
  if p.oferta_status is distinct from 'pendente' or p.status not in ('enviada', 'contraproposta') then
    raise exception 'Esta oferta não está mais aguardando resposta.' using errcode = 'P0001';
  end if;

  if not coalesce(p_aprovar, false) then
    if char_length(motivo) < 3 then raise exception 'Informe o motivo da recusa.' using errcode = 'P0001'; end if;
    update public.propostas set oferta_status = 'recusada', oferta_motivo = motivo where id = p_proposta;
    perform private.evento_proposta(p_proposta, p.status, p.status, papel, jsonb_build_object('oferta', p.oferta_valor, 'decisao', 'recusada'), motivo);
    return 'recusada';
  end if;

  select coalesce(sum(round(quantidade * coalesce(preco_ofertado, preco_anunciado), 2)), 0),
         coalesce(sum(round(quantidade * coalesce(preco_ofertado, preco_anunciado), 2) * private.percentual_tier(tier)), 0)
    into subtotal_of, base_cashback from public.proposta_itens where proposta_id = p_proposta;
  v_desconto := subtotal_of + p.frete - p.oferta_valor;
  update public.propostas
     set oferta_status = 'aprovada', desconto = v_desconto, total = p.oferta_valor,
         cashback_previsto = round(case when subtotal_of > 0 then base_cashback * (subtotal_of - v_desconto) / subtotal_of else 0 end, 2)
   where id = p_proposta;
  -- Saldo reservado nunca maior que o novo total
  excesso := p.saldo_aplicado - p.oferta_valor;
  if excesso > 0 then
    update public.propostas set saldo_aplicado = p.oferta_valor where id = p_proposta;
    perform private.mover(p.construtor_id, 'reservado', 'disponivel', excesso, 'saldo_devolvido', 'Saldo devolvido: proposta com novo total', p.loja_id, null, p_proposta);
  end if;
  perform private.evento_proposta(p_proposta, p.status, p.status, papel, jsonb_build_object('oferta', p.oferta_valor, 'decisao', 'aprovada', 'desconto', v_desconto), null);
  perform private.aceitar(p_proposta, papel);
  return 'aprovada';
end $$;

revoke execute on function public.fazer_oferta(uuid, numeric, text) from public, anon;
revoke execute on function public.responder_oferta(uuid, boolean, text) from public, anon;
grant execute on function public.fazer_oferta(uuid, numeric, text) to authenticated;
grant execute on function public.responder_oferta(uuid, boolean, text) to authenticated;

-- Só o trecho da oferta pendente é novo aqui
create or replace function public.responder_proposta(p_proposta uuid, p_acao text, p_precos jsonb, p_desconto numeric,
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
  if p.oferta_status = 'pendente' then
    raise exception 'Este cliente fez uma oferta: responda na Mesa do Gerente.' using errcode = 'P0001';
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
