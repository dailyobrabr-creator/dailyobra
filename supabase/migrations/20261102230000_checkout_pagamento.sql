-- Checkout: saldo da carteira na hora de pagar (só no "Eu pago"), forma de pagamento combinada com a loja (PIX, cartão
-- na loja ou crediário com aprovação do dono/gerente) e link do cliente com CPF/CNPJ opcional (a página só mostra mascarado).

alter table public.pedidos
  add column forma_pagamento text check (forma_pagamento in ('pix', 'cartao', 'crediario')),
  add column prazo text check (prazo in ('28', '28/35', '28/35/42')),
  add column prazo_status text check (prazo_status in ('pendente', 'aprovado', 'recusado')),
  add column prazo_respondido_em timestamptz;

-- Saldo da carteira usado no pedido (na cotação ou no checkout): o que está na conta emissor por causa dele
create function private.saldo_no_pedido(p_pedido uuid) returns numeric language sql stable set search_path = '' as $$
  select coalesce(sum(valor), 0) from public.carteira_lancamentos
   where pedido_id = p_pedido and conta = 'emissor' and tipo in ('saldo_usado', 'saldo_devolvido') $$;

-- CPF ***.982.247-** e CNPJ **.222.333/0001-**: a página nunca mostra o documento inteiro
create function private.mascarar_documento(p text) returns text language sql immutable set search_path = '' as $$
  select case length(p)
    when 11 then '***.' || substr(p, 4, 3) || '.' || substr(p, 7, 3) || '-**'
    when 14 then '**.' || substr(p, 3, 3) || '.' || substr(p, 6, 3) || '/' || substr(p, 9, 4) || '-**' end $$;

-- Pedido do construtor no "Eu pago", travado, ainda sem pagamento confirmado nem informado
create function private.pedido_do_checkout(p_pedido uuid) returns public.pedidos language plpgsql set search_path = '' as $$
declare pe public.pedidos;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or pe.construtor_id is distinct from (select auth.uid()) then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then raise exception 'Este pedido já foi pago.' using errcode = 'P0001'; end if;
  if pe.pagamento_informado_em is not null then raise exception 'O pagamento já foi informado. Fale com a loja.' using errcode = 'P0001'; end if;
  if pe.pagador is distinct from 'proprio' then raise exception 'Escolha "Eu pago" para usar o saldo.' using errcode = 'P0001'; end if;
  return pe;
end $$;

revoke execute on function private.saldo_no_pedido(uuid), private.mascarar_documento(text), private.pedido_do_checkout(uuid) from public;

-- Liga (aplica até o total) ou desliga (devolve) o saldo no pedido; devolve o saldo usado no pedido depois da chamada
create function public.usar_saldo(p_pedido uuid, p_usar boolean) returns numeric
language plpgsql security definer set search_path = '' as $$
declare pe public.pedidos := private.pedido_do_checkout(p_pedido); usado numeric := private.saldo_no_pedido(p_pedido);
        disponivel numeric; valor numeric; loja text;
begin
  select l.nome into loja from public.lojas l where l.id = pe.loja_id;
  if p_usar then
    if usado > 0 then return usado; end if;
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

create function public.escolher_pagamento(p_pedido uuid, p_forma text, p_prazo text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare pe public.pedidos := private.pedido_do_checkout(p_pedido);
begin
  if p_forma is null or p_forma not in ('pix', 'cartao', 'crediario') then raise exception 'Forma de pagamento inválida.' using errcode = 'P0001'; end if;
  if p_forma = 'crediario' and (p_prazo is null or p_prazo not in ('28', '28/35', '28/35/42')) then
    raise exception 'Escolha o prazo do crediário.' using errcode = 'P0001';
  end if;
  update public.pedidos set forma_pagamento = p_forma,
    prazo = case when p_forma = 'crediario' then p_prazo end,
    prazo_status = case when p_forma = 'crediario' then 'pendente' end,
    prazo_respondido_em = null
   where id = pe.id;
end $$;

create function public.responder_prazo(p_pedido uuid, p_aprovar boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare pe public.pedidos;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or private.membro_loja(pe.loja_id) is null then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if not coalesce(private.pode_gerir_loja(pe.loja_id), false) then
    raise exception 'Só o dono ou o gerente responde ao prazo.' using errcode = 'P0001';
  end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.prazo_status is distinct from 'pendente' then raise exception 'Não há prazo para responder.' using errcode = 'P0001'; end if;
  update public.pedidos set prazo_status = case when p_aprovar then 'aprovado' else 'recusado' end, prazo_respondido_em = now()
   where id = p_pedido;
end $$;

revoke execute on function public.usar_saldo(uuid, boolean), public.escolher_pagamento(uuid, text, text),
  public.responder_prazo(uuid, boolean) from public, anon;
grant execute on function public.usar_saldo(uuid, boolean), public.escolher_pagamento(uuid, text, text),
  public.responder_prazo(uuid, boolean) to authenticated;

-- ---------- Link do cliente: documento opcional; devolve o saldo do construtor (o cliente paga o total) ----------
drop function public.criar_link_pagamento(uuid, text, text);
create function public.criar_link_pagamento(p_pedido uuid, p_nome text, p_whatsapp text, p_documento text default null) returns text
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); pe public.pedidos; zap text := private.so_digitos(p_whatsapp);
        doc text := nullif(private.so_digitos(p_documento), ''); chave text; cod text; usado numeric; loja text;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or pe.construtor_id is distinct from uid then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then raise exception 'Este pedido já foi pago.' using errcode = 'P0001'; end if;
  select lp.chave into chave from public.loja_pix lp where lp.loja_id = pe.loja_id;
  if chave is null then raise exception 'A loja ainda não cadastrou a chave PIX.' using errcode = 'P0001'; end if;
  if char_length(btrim(coalesce(p_nome, ''))) < 2 then raise exception 'Informe o nome do cliente.' using errcode = 'P0001'; end if;
  if zap !~ '^\d{10,13}$' then raise exception 'WhatsApp inválido. Use DDD + número.' using errcode = 'P0001'; end if;
  if doc is not null and not private.documento_valido(doc) then
    raise exception 'CPF ou CNPJ inválido. Confira os números.' using errcode = 'P0001';
  end if;
  usado := private.saldo_no_pedido(p_pedido);
  if usado > 0 then
    select l.nome into loja from public.lojas l where l.id = pe.loja_id;
    perform private.mover(pe.construtor_id, 'emissor', 'disponivel', usado, 'saldo_devolvido',
                          'Saldo devolvido: pedido da ' || loja || ' enviado ao cliente', pe.loja_id, p_pedido, pe.proposta_id);
    update public.pedidos set total = total + usado where id = p_pedido returning * into pe;
    update public.propostas set saldo_aplicado = greatest(saldo_aplicado - usado, 0) where id = pe.proposta_id;
  end if;
  if pe.total <= 0 then raise exception 'O saldo DailyObra cobriu este pedido. Não há nada a pagar.' using errcode = 'P0001'; end if;
  loop
    -- 16 bytes aleatórios em base64 URL-safe: exatamente 22 caracteres
    cod := translate(encode(decode(replace(gen_random_uuid()::text, '-', ''), 'hex'), 'base64'), '+/=', '-_');
    exit when not exists (select 1 from public.pedidos where link_codigo = cod);
  end loop;
  delete from public.pedido_documentos where pedido_id = p_pedido;
  update public.pedidos set pagador = 'cliente', pagador_nome = left(btrim(p_nome), 120), pagador_whatsapp = zap, link_codigo = cod,
    documento_informado_em = case when doc is not null then now() end, pagamento_informado_em = null,
    forma_pagamento = 'pix', prazo = null, prazo_status = null, prazo_respondido_em = null
   where id = p_pedido;
  if doc is not null then insert into public.pedido_documentos (pedido_id, documento) values (p_pedido, doc); end if;
  return cod;
end $$;

revoke execute on function public.criar_link_pagamento(uuid, text, text, text) from public, anon;
grant execute on function public.criar_link_pagamento(uuid, text, text, text) to authenticated;

-- ---------- Página do cliente: documento mascarado ----------
create or replace function public.pedido_do_link(p_codigo text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare pe public.pedidos; pr public.propostas; l public.lojas; sit text; v_itens jsonb;
begin
  select * into pe from public.pedidos where p_codigo is not null and link_codigo = p_codigo;
  if not found then raise exception 'Link inválido ou substituído.' using errcode = 'P0001'; end if;
  select * into pr from public.propostas where id = pe.proposta_id;
  select * into l from public.lojas where id = pe.loja_id;
  sit := private.situacao_pagamento(pe);
  select coalesce(jsonb_agg(jsonb_build_object(
      'nome', i.nome, 'quantidade', i.quantidade, 'unidade', i.unidade,
      'preco', coalesce(i.preco_ofertado, i.preco_anunciado),
      'total', round(coalesce(i.preco_ofertado, i.preco_anunciado) * i.quantidade, 2)) order by i.nome), '[]'::jsonb)
    into v_itens from public.proposta_itens i where i.proposta_id = pe.proposta_id;
  return jsonb_build_object(
    'loja', jsonb_build_object('nome', l.nome, 'cidade', l.cidade, 'uf', l.uf, 'whatsapp', l.whatsapp,
      -- DDD + número (10 ou 11 dígitos) ganha o 55; quem salvou com 55 fica como está
      'whatsapp_link', case when l.whatsapp is not null
        then 'https://wa.me/' || case when length(l.whatsapp) in (10, 11) then '55' else '' end || l.whatsapp end),
    'itens', v_itens, 'desconto', pr.desconto, 'frete', pr.frete, 'total', pe.total, 'situacao', sit,
    'pagador_nome', pe.pagador_nome, 'documento_informado', pe.documento_informado_em is not null,
    'documento_mascarado', (select private.mascarar_documento(d.documento) from public.pedido_documentos d where d.pedido_id = pe.id),
    'pix', case when pe.documento_informado_em is not null and sit not in ('pago', 'cancelado')
                then private.pix_copia_e_cola(pe.id) end);
end $$;

-- ---------- Cancelamento devolve todo o saldo usado no pedido (da cotação ou do checkout) ----------
create or replace function public.atualizar_pedido(p_pedido uuid, p_status text) returns text
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
    usado := private.saldo_no_pedido(p_pedido);
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
