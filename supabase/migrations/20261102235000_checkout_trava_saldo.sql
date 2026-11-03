-- O saldo do checkout pega a trava da carteira do construtor (a mesma do enviar_cotacao) antes de ler o disponível:
-- dois pedidos ligados ao mesmo tempo não gastam o mesmo saldo.

create or replace function public.usar_saldo(p_pedido uuid, p_usar boolean) returns numeric
language plpgsql security definer set search_path = '' as $$
declare pe public.pedidos := private.pedido_do_checkout(p_pedido); usado numeric := private.saldo_no_pedido(p_pedido);
        disponivel numeric; valor numeric; loja text;
begin
  select l.nome into loja from public.lojas l where l.id = pe.loja_id;
  if p_usar then
    if usado > 0 then return usado; end if;
    perform pg_advisory_xact_lock(hashtext('carteira:' || pe.construtor_id::text));
    disponivel := private.saldo(pe.construtor_id, 'disponivel');
    if disponivel <= 0 then raise exception 'Você não tem saldo disponível.' using errcode = 'P0001'; end if;
    valor := least(disponivel, pe.total);
    if valor <= 0 then return 0; end if;
    perform private.mover(pe.construtor_id, 'disponivel', 'emissor', valor, 'saldo_usado', 'Saldo usado no pedido da ' || loja,
                          pe.loja_id, p_pedido, pe.proposta_id);
    update public.pedidos set total = total - valor where id = p_pedido;
    update public.propostas set saldo_aplicado = saldo_aplicado + valor where id = pe.proposta_id;
    return valor;
  end if;
  if usado > 0 then
    perform private.mover(pe.construtor_id, 'emissor', 'disponivel', usado, 'saldo_devolvido', 'Saldo devolvido: pedido da ' || loja,
                          pe.loja_id, p_pedido, pe.proposta_id);
    update public.pedidos set total = total + usado where id = p_pedido;
    update public.propostas set saldo_aplicado = greatest(saldo_aplicado - usado, 0) where id = pe.proposta_id;
  end if;
  return 0;
end $$;
