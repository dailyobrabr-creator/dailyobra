-- Resultados da loja num período (seção "Resultados do mês" do Início no Parceiros): faturamento pelo total da proposta
-- (pagar com saldo da carteira não muda o valor da venda), pedidos fechados menos os cancelados, cashback gerado e os 5
-- construtores que mais compraram. O app manda o começo e o fim do mês no fuso do aparelho. Só dono e gerente.

create index pedidos_loja_criado_idx on public.pedidos (loja_id, criado_em);

create function public.resultados_loja(p_loja uuid, p_de timestamptz, p_ate timestamptz) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb;
begin
  if not coalesce(private.pode_gerir_loja(p_loja), false) then
    raise exception 'Só o dono ou o gerente vê os resultados.' using errcode = 'P0001';
  end if;
  if p_de is null or p_ate is null or p_ate <= p_de then
    raise exception 'Período inválido.' using errcode = 'P0001';
  end if;
  with vendas as (
    select pe.construtor_id, pr.total, pr.cashback_previsto
      from public.pedidos pe
      join public.propostas pr on pr.id = pe.proposta_id
     where pe.loja_id = p_loja and pe.status <> 'cancelado' and pe.criado_em >= p_de and pe.criado_em < p_ate
  ), por_construtor as (
    select v.construtor_id, count(*) as pedidos, sum(v.total) as total,
           coalesce(pf.nome, '') as nome, coalesce(pf.empresa, '') as empresa
      from vendas v
      left join public.profiles pf on pf.id = v.construtor_id
     group by v.construtor_id, pf.nome, pf.empresa
  ), melhores as (
    select * from por_construtor order by total desc, pedidos desc, nome limit 5
  )
  select jsonb_build_object(
    'faturamento', coalesce((select sum(total) from vendas), 0),
    'pedidos', (select count(*) from vendas),
    'cashback', coalesce((select sum(cashback_previsto) from vendas), 0),
    'top', coalesce((select jsonb_agg(jsonb_build_object('construtor_id', construtor_id, 'nome', nome, 'empresa', empresa,
                       'pedidos', pedidos, 'total', total) order by total desc, pedidos desc, nome) from melhores), '[]'::jsonb))
    into resultado;
  return resultado;
end $$;

revoke execute on function public.resultados_loja(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.resultados_loja(uuid, timestamptz, timestamptz) to authenticated;
