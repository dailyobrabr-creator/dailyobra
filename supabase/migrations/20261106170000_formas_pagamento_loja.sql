-- Cada loja diz como recebe. O construtor escolhe a forma por loja já na cotação, e a loja vê a escolha na proposta.
-- Boleto e dinheiro são formas novas. As lojas que já existem ficam com o que o app oferecia até aqui.

alter table public.lojas
  add column formas_pagamento text[] not null default array['pix', 'cartao', 'crediario'],
  add constraint lojas_formas_pagamento_check check (
    cardinality(formas_pagamento) >= 1
    and formas_pagamento <@ array['pix', 'cartao', 'boleto', 'dinheiro', 'crediario']
  );

alter table public.pedidos drop constraint pedidos_forma_pagamento_check;
alter table public.pedidos add constraint pedidos_forma_pagamento_check
  check (forma_pagamento in ('pix', 'cartao', 'boleto', 'dinheiro', 'crediario'));

alter table public.propostas add column forma_escolhida text
  check (forma_escolhida in ('pix', 'cartao', 'boleto', 'dinheiro', 'crediario'));

-- Chamada logo depois de enviar_cotacao: p_formas é { loja_id: forma }. Loja fora do mapa fica sem forma escolhida.
create function public.definir_formas_do_orcamento(p_orcamento uuid, p_formas jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare p record; forma text;
begin
  if jsonb_typeof(p_formas) is distinct from 'object' then
    raise exception 'Formas de pagamento inválidas.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.orcamentos o where o.id = p_orcamento and o.construtor_id = (select auth.uid())) then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  for p in select pr.id, pr.loja_id, l.nome, l.formas_pagamento
             from public.propostas pr join public.lojas l on l.id = pr.loja_id
            where pr.orcamento_id = p_orcamento loop
    forma := p_formas ->> p.loja_id::text;
    if forma is null then continue; end if;
    if not (forma = any(p.formas_pagamento)) then
      raise exception 'A % não recebe por essa forma.', p.nome using errcode = 'P0001';
    end if;
    update public.propostas set forma_escolhida = forma where id = p.id;
  end loop;
end $$;
revoke all on function public.definir_formas_do_orcamento(uuid, jsonb) from public, anon;
grant execute on function public.definir_formas_do_orcamento(uuid, jsonb) to authenticated;

create or replace function public.escolher_pagamento(p_pedido uuid, p_forma text, p_prazo text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare pe public.pedidos := private.pedido_do_checkout(p_pedido); v_formas text[];
begin
  if p_forma is null or p_forma not in ('pix', 'cartao', 'boleto', 'dinheiro', 'crediario') then
    raise exception 'Forma de pagamento inválida.' using errcode = 'P0001';
  end if;
  select l.formas_pagamento into v_formas from public.lojas l where l.id = pe.loja_id;
  if not (p_forma = any(v_formas)) then raise exception 'Esta loja não recebe por essa forma.' using errcode = 'P0001'; end if;
  if p_forma = 'crediario' and (p_prazo is null or p_prazo not in ('28', '28/35', '28/35/42')) then
    raise exception 'Escolha o prazo do crediário.' using errcode = 'P0001';
  end if;
  update public.pedidos set forma_pagamento = p_forma,
    prazo = case when p_forma = 'crediario' then p_prazo end,
    prazo_status = case when p_forma = 'crediario' then 'pendente' end,
    prazo_respondido_em = null
   where id = pe.id;
end $$;

-- O pedido nasce com a forma da cotação. Crediário não vem junto porque ainda falta o construtor pedir o prazo.
create function private.forma_da_proposta() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.forma_pagamento is null then
    select p.forma_escolhida into new.forma_pagamento
      from public.propostas p where p.id = new.proposta_id and p.forma_escolhida <> 'crediario';
  end if;
  return new;
end $$;
create trigger pedidos_forma_da_proposta before insert on public.pedidos
  for each row execute function private.forma_da_proposta();
