-- Clientes da loja: todo construtor que mandou proposta, com quantas propostas e pedidos, quanto comprou (total da proposta,
-- sem os cancelados) e o último contato. Quem tem pedido é cliente; quem só cotou é lead. A equipe inteira vê: o vendedor
-- já vê cada proposta e é quem liga para o cliente.

create function public.clientes_loja(p_loja uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb;
begin
  if private.membro_loja(p_loja) is null then
    raise exception 'Só a equipe da loja vê os clientes.' using errcode = 'P0001';
  end if;
  with por_construtor as (
    select pr.construtor_id,
           count(*) as propostas,
           count(pe.id) filter (where pe.status <> 'cancelado') as pedidos,
           coalesce(sum(pr.total) filter (where pe.id is not null and pe.status <> 'cancelado'), 0) as total,
           max(pr.criada_em) as ultimo_contato
      from public.propostas pr
      left join public.pedidos pe on pe.proposta_id = pr.id
     where pr.loja_id = p_loja
     group by pr.construtor_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'construtor_id', c.construtor_id,
           'nome', coalesce(pf.nome, ''),
           'empresa', coalesce(pf.empresa, ''),
           'telefone', coalesce(pf.telefone, ''),
           'cidade', coalesce(pf.cidade, ''),
           'uf', coalesce(pf.uf, ''),
           'propostas', c.propostas,
           'pedidos', c.pedidos,
           'total', c.total,
           'ultimo_contato', c.ultimo_contato
         ) order by c.ultimo_contato desc), '[]'::jsonb)
    into resultado
    from por_construtor c
    left join public.profiles pf on pf.id = c.construtor_id;
  return resultado;
end $$;

revoke execute on function public.clientes_loja(uuid) from public, anon;
grant execute on function public.clientes_loja(uuid) to authenticated;
