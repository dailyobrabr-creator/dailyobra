-- Desempenho da loja num período (gráfico, funil e produtos do "Resultados do mês" no Parceiros). Mesma regra de venda de
-- resultados_loja: pedido criado no período, sem os cancelados, pelo total da proposta. O app manda o fuso do aparelho em
-- minutos para o dia do gráfico ser o dia da loja. No funil, a proposta conta como respondida pelo status ou por ter preço
-- da loja, porque a contraproposta que expira perde o status. Só dono e gerente.

create function public.desempenho_loja(p_loja uuid, p_de timestamptz, p_ate timestamptz, p_fuso_min integer) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb;
begin
  if not coalesce(private.pode_gerir_loja(p_loja), false) then
    raise exception 'Só o dono ou o gerente vê os resultados.' using errcode = 'P0001';
  end if;
  if p_de is null or p_ate is null or p_ate <= p_de or p_fuso_min is null or abs(p_fuso_min) > 840 then
    raise exception 'Período inválido.' using errcode = 'P0001';
  end if;
  with vendas as (
    select pe.proposta_id, pr.total,
           ((pe.criado_em at time zone 'UTC') + make_interval(mins => p_fuso_min))::date as dia
      from public.pedidos pe
      join public.propostas pr on pr.id = pe.proposta_id
     where pe.loja_id = p_loja and pe.status <> 'cancelado' and pe.criado_em >= p_de and pe.criado_em < p_ate
  ), por_dia as (
    select v.dia, sum(v.total) as total, count(*) as pedidos from vendas v group by v.dia
  ), recebidas as (
    select pr.id, pr.status
      from public.propostas pr
     where pr.loja_id = p_loja and pr.criada_em >= p_de and pr.criada_em < p_ate
  ), por_produto as (
    select i.item_id, min(i.nome) as nome, min(i.unidade) as unidade, sum(i.quantidade) as quantidade,
           sum(i.quantidade * coalesce(i.preco_ofertado, i.preco_anunciado)) as total
      from vendas v
      join public.proposta_itens i on i.proposta_id = v.proposta_id
     group by i.item_id
  ), melhores as (
    select * from por_produto p order by p.total desc, p.nome limit 5
  )
  select jsonb_build_object(
    'vendas_por_dia', coalesce((select jsonb_agg(jsonb_build_object('dia', d.dia, 'total', d.total, 'pedidos', d.pedidos) order by d.dia)
                                  from por_dia d), '[]'::jsonb),
    'propostas', (select count(*) from recebidas),
    'respondidas', (select count(*) from recebidas r
                     where r.status in ('contraproposta', 'aceita', 'recusada')
                        or exists (select 1 from public.proposta_itens i where i.proposta_id = r.id and i.preco_ofertado is not null)),
    'viraram_pedido', (select count(*) from recebidas r
                        join public.pedidos pe on pe.proposta_id = r.id
                       where pe.status <> 'cancelado'),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('item_id', m.item_id, 'nome', m.nome, 'unidade', m.unidade,
                            'quantidade', m.quantidade, 'total', m.total) order by m.total desc, m.nome)
                            from melhores m), '[]'::jsonb))
    into resultado;
  return resultado;
end $$;

revoke execute on function public.desempenho_loja(uuid, timestamptz, timestamptz, integer) from public, anon;
grant execute on function public.desempenho_loja(uuid, timestamptz, timestamptz, integer) to authenticated;
