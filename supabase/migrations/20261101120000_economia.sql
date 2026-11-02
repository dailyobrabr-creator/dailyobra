-- Economia do mês do construtor: o envio grava o maior preço do item entre as lojas (para a parte
-- "comparando lojas") e economia_mensal soma comparando + negociando + cashback por mês.
-- Reversão: drop function public.economia_mensal(int); alter table public.proposta_itens drop column preco_maior;
-- e recriar enviar_cotacao da migração 20261031130200_marketplace_funcoes.

alter table public.proposta_itens add column preco_maior numeric(12, 2) check (preco_maior > 0);

create or replace function public.enviar_cotacao(p_itens jsonb, p_modo text, p_obra uuid, p_usar_saldo boolean, p_mensagem text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  it jsonb; loja record; o record; ci record;
  id_orc uuid; id_prop uuid;
  qtd numeric; preco numeric; maior numeric; atualizados boolean := false;
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
      -- Maior preço do item agora entre as lojas que venderiam: base da economia "comparando lojas"
      select max(private.preco_vigente(o2.preco, o2.preco_promocional, o2.promo_ate)) into maior
        from public.ofertas o2 join public.lojas l2 on l2.id = o2.loja_id
       where o2.item_id = ci.id and not o2.pausada and o2.disponibilidade <> 'sem_estoque'
         and l2.status = 'ativa' and l2.aberta;
      qtd := (it->>'quantidade')::numeric;
      insert into public.proposta_itens (proposta_id, item_id, nome, unidade, tier, quantidade, preco_anunciado, preco_maior)
      values (id_prop, ci.id, ci.nome, ci.unidade, ci.tier_cashback, qtd, preco, greatest(preco, coalesce(maior, preco)));
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

-- Últimos p_meses meses (o atual por último) do usuário logado, no horário de Brasília.
-- Pedidos cancelados não contam; meses sem pedido vêm com zero.
create function public.economia_mensal(p_meses int default 6)
returns table (mes date, comparando numeric, negociando numeric, cashback numeric, total numeric)
language sql stable security invoker set search_path = '' as $$
  with meses as (
    select (date_trunc('month', now() at time zone 'America/Sao_Paulo') - make_interval(months => g))::date as mes
      from generate_series(0, greatest(least(coalesce(p_meses, 6), 24), 1) - 1) g
  ),
  ped as (
    select pr.id as proposta_id, pr.desconto, pr.cashback_previsto,
           date_trunc('month', pe.criado_em at time zone 'America/Sao_Paulo')::date as mes
      from public.pedidos pe join public.propostas pr on pr.id = pe.proposta_id
     where pe.construtor_id = (select auth.uid()) and pe.status <> 'cancelado'
  ),
  itens as (
    select p.mes,
           sum((coalesce(i.preco_maior, i.preco_anunciado) - i.preco_anunciado) * i.quantidade) as comparando,
           sum((i.preco_anunciado - coalesce(i.preco_ofertado, i.preco_anunciado)) * i.quantidade) as negociando
      from ped p join public.proposta_itens i on i.proposta_id = p.proposta_id
     group by p.mes
  ),
  extras as (
    select p.mes, sum(p.desconto) as desconto, sum(p.cashback_previsto) as cashback from ped p group by p.mes
  )
  select m.mes,
         round(coalesce(it.comparando, 0), 2),
         round(coalesce(it.negociando, 0) + coalesce(e.desconto, 0), 2),
         round(coalesce(e.cashback, 0), 2),
         round(coalesce(it.comparando, 0) + coalesce(it.negociando, 0) + coalesce(e.desconto, 0) + coalesce(e.cashback, 0), 2)
    from meses m
    left join itens it on it.mes = m.mes
    left join extras e on e.mes = m.mes
   order by m.mes;
$$;

revoke execute on function public.economia_mensal(int) from public, anon;
grant execute on function public.economia_mensal(int) to authenticated;
