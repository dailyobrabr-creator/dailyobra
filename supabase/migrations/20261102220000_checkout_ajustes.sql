-- Ajustes do checkout bifurcado (pontos menores da revisão):
-- 1) A chave PIX sai de lojas (a linha inteira é lida por qualquer usuário logado) para loja_pix:
--    a equipe da loja lê; dono e gerente gravam. As funções do PIX passam a ler dali.
-- 2) pedido_do_link devolve o link do WhatsApp da loja pronto, com o 55 uma vez só.
-- 3) Pedido coberto pelo saldo DailyObra (total zero) não gera PIX nem link de pagamento.

-- ---------- Chave PIX da loja ----------
create table public.loja_pix (
  loja_id uuid primary key references public.lojas (id) on delete cascade,
  chave text not null check (private.chave_pix_valida(chave))
);
alter table public.loja_pix enable row level security;
create policy "equipe ve a chave pix" on public.loja_pix for select to authenticated
  using (private.membro_loja(loja_id) is not null);
create policy "dono e gerente gravam a chave pix" on public.loja_pix for all to authenticated
  using (private.pode_gerir_loja(loja_id)) with check (private.pode_gerir_loja(loja_id));
revoke all on public.loja_pix from anon;
revoke truncate on public.loja_pix from authenticated;

insert into public.loja_pix (loja_id, chave) select id, chave_pix from public.lojas where chave_pix is not null;
alter table public.lojas drop column chave_pix;

-- PIX do pedido; nulo sem chave na loja ou quando o saldo cobriu tudo
create or replace function private.pix_copia_e_cola(p_pedido uuid) returns text language sql stable security definer set search_path = '' as $$
  select case when lp.chave is null or pe.total <= 0 then null
    else private.brcode(lp.chave, l.nome, l.cidade, pe.total, 'DO' || upper(left(pe.id::text, 8))) end
  from public.pedidos pe join public.lojas l on l.id = pe.loja_id left join public.loja_pix lp on lp.loja_id = pe.loja_id
  where pe.id = p_pedido $$;

create or replace function public.criar_link_pagamento(p_pedido uuid, p_nome text, p_whatsapp text) returns text
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); pe public.pedidos; zap text := private.so_digitos(p_whatsapp); chave text; cod text;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or pe.construtor_id is distinct from uid then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then raise exception 'Este pedido já foi pago.' using errcode = 'P0001'; end if;
  if pe.total <= 0 then raise exception 'O saldo DailyObra cobriu este pedido. Não há nada a pagar.' using errcode = 'P0001'; end if;
  select lp.chave into chave from public.loja_pix lp where lp.loja_id = pe.loja_id;
  if chave is null then raise exception 'A loja ainda não cadastrou a chave PIX.' using errcode = 'P0001'; end if;
  if char_length(btrim(coalesce(p_nome, ''))) < 2 then raise exception 'Informe o nome do cliente.' using errcode = 'P0001'; end if;
  if zap !~ '^\d{10,13}$' then raise exception 'WhatsApp inválido. Use DDD + número.' using errcode = 'P0001'; end if;
  loop
    -- 16 bytes aleatórios em base64 URL-safe: exatamente 22 caracteres
    cod := translate(encode(decode(replace(gen_random_uuid()::text, '-', ''), 'hex'), 'base64'), '+/=', '-_');
    exit when not exists (select 1 from public.pedidos where link_codigo = cod);
  end loop;
  delete from public.pedido_documentos where pedido_id = p_pedido;
  update public.pedidos set pagador = 'cliente', pagador_nome = left(btrim(p_nome), 120), pagador_whatsapp = zap,
    link_codigo = cod, documento_informado_em = null, pagamento_informado_em = null
   where id = p_pedido;
  return cod;
end $$;

-- ---------- Página do cliente ----------
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
    'pix', case when pe.documento_informado_em is not null and sit not in ('pago', 'cancelado')
                then private.pix_copia_e_cola(pe.id) end);
end $$;
