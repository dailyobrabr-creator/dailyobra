-- Correção da financeiro_loja: a variável parcelas tinha o nome da coluna, e o update ficava ambíguo. Toda escolha de forma
-- na cotação falhava, e o app seguia sem a forma no pedido.
create or replace function public.definir_formas_do_orcamento(p_orcamento uuid, p_formas jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare p record; v_escolha jsonb; v_forma text; v_parcelas int; v_maximo int;
begin
  if jsonb_typeof(p_formas) is distinct from 'object' then
    raise exception 'Formas de pagamento inválidas.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.orcamentos o where o.id = p_orcamento and o.construtor_id = (select auth.uid())) then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  for p in select pr.id, pr.loja_id, pr.construtor_id, l.nome, l.formas_pagamento
             from public.propostas pr join public.lojas l on l.id = pr.loja_id
            where pr.orcamento_id = p_orcamento loop
    v_escolha := p_formas -> p.loja_id::text;
    if v_escolha is null then continue; end if;
    if jsonb_typeof(v_escolha) = 'string' then
      v_forma := v_escolha #>> '{}';
      v_parcelas := 1;
    elsif jsonb_typeof(v_escolha) = 'object' and coalesce(v_escolha ->> 'parcelas', '1') ~ '^[0-9]{1,2}$' then
      v_forma := v_escolha ->> 'forma';
      v_parcelas := coalesce((v_escolha ->> 'parcelas')::int, 1);
    else
      raise exception 'Formas de pagamento inválidas.' using errcode = 'P0001';
    end if;
    if v_forma is null or not (v_forma = any(p.formas_pagamento)) then
      raise exception 'A % não recebe por essa forma.', p.nome using errcode = 'P0001';
    end if;
    if v_forma = 'duplicata' and private.duplicata_da_loja(p.loja_id, p.construtor_id) is null then
      raise exception 'A % não liberou duplicata para você.', p.nome using errcode = 'P0001';
    end if;
    v_maximo := private.maximo_de_parcelas(p.loja_id, v_forma);
    if v_parcelas < 1 or v_parcelas > v_maximo then
      raise exception 'A % parcela em até %x nessa forma.', p.nome, v_maximo using errcode = 'P0001';
    end if;
    update public.propostas
       set forma_escolhida = v_forma, parcelas = case when v_forma in ('cartao', 'boleto') then v_parcelas end
     where id = p.id;
  end loop;
end $$;
