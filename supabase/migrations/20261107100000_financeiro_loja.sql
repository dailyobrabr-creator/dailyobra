-- Financeiro da loja: parcelamento no cartão e no boleto, e duplicata. A duplicata depende da análise de crédito da loja,
-- então ela libera cliente a cliente, com o prazo. O construtor escolhe as parcelas na cotação e o pedido nasce com elas.

alter table public.lojas
  add column parcelas_cartao smallint not null default 1 check (parcelas_cartao between 1 and 12),
  add column parcelas_boleto smallint not null default 1 check (parcelas_boleto between 1 and 12),
  drop constraint lojas_formas_pagamento_check,
  add constraint lojas_formas_pagamento_check check (
    cardinality(formas_pagamento) >= 1
    and formas_pagamento <@ array['pix', 'cartao', 'boleto', 'duplicata', 'dinheiro', 'crediario']
  );

alter table public.pedidos
  drop constraint pedidos_forma_pagamento_check,
  add constraint pedidos_forma_pagamento_check
    check (forma_pagamento in ('pix', 'cartao', 'boleto', 'duplicata', 'dinheiro', 'crediario')),
  add column parcelas smallint check (parcelas between 1 and 12);

alter table public.propostas
  drop constraint propostas_forma_escolhida_check,
  add constraint propostas_forma_escolhida_check
    check (forma_escolhida in ('pix', 'cartao', 'boleto', 'duplicata', 'dinheiro', 'crediario')),
  add column parcelas smallint check (parcelas between 1 and 12);

-- Quem a loja liberou para pagar com duplicata, e em que prazo
create table public.loja_duplicatas (
  loja_id uuid not null references public.lojas (id) on delete cascade,
  construtor_id uuid not null references auth.users (id) on delete cascade,
  prazo text not null check (prazo in ('28', '28/35', '28/35/42')),
  liberada_em timestamptz not null default now(),
  liberada_por uuid default auth.uid() references auth.users (id) on delete set null,
  primary key (loja_id, construtor_id)
);
alter table public.loja_duplicatas enable row level security;
create policy "equipe ve as duplicatas" on public.loja_duplicatas for select to authenticated
  using (private.membro_loja(loja_id) is not null);
create policy "construtor ve as suas duplicatas" on public.loja_duplicatas for select to authenticated
  using (construtor_id = (select auth.uid()));
create policy "dono e gerente liberam duplicata" on public.loja_duplicatas for all to authenticated
  using (coalesce(private.pode_gerir_loja(loja_id), false)) with check (coalesce(private.pode_gerir_loja(loja_id), false));
revoke all on public.loja_duplicatas from anon;
revoke truncate on public.loja_duplicatas from authenticated;

create function private.duplicata_da_loja(p_loja uuid, p_construtor uuid) returns text
language sql stable security definer set search_path = '' as $$
  select d.prazo from public.loja_duplicatas d where d.loja_id = p_loja and d.construtor_id = p_construtor;
$$;

create function private.maximo_de_parcelas(p_loja uuid, p_forma text) returns int
language sql stable security definer set search_path = '' as $$
  select case p_forma when 'cartao' then l.parcelas_cartao when 'boleto' then l.parcelas_boleto else 1 end
    from public.lojas l where l.id = p_loja;
$$;

-- p_formas é { loja_id: forma } (apps antigos) ou { loja_id: { forma, parcelas } }
create or replace function public.definir_formas_do_orcamento(p_orcamento uuid, p_formas jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare p record; escolha jsonb; forma text; parcelas int; maximo int;
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
    escolha := p_formas -> p.loja_id::text;
    if escolha is null then continue; end if;
    if jsonb_typeof(escolha) = 'string' then
      forma := escolha #>> '{}';
      parcelas := 1;
    elsif jsonb_typeof(escolha) = 'object' and coalesce(escolha ->> 'parcelas', '1') ~ '^[0-9]{1,2}$' then
      forma := escolha ->> 'forma';
      parcelas := coalesce((escolha ->> 'parcelas')::int, 1);
    else
      raise exception 'Formas de pagamento inválidas.' using errcode = 'P0001';
    end if;
    if forma is null or not (forma = any(p.formas_pagamento)) then
      raise exception 'A % não recebe por essa forma.', p.nome using errcode = 'P0001';
    end if;
    if forma = 'duplicata' and private.duplicata_da_loja(p.loja_id, p.construtor_id) is null then
      raise exception 'A % não liberou duplicata para você.', p.nome using errcode = 'P0001';
    end if;
    maximo := private.maximo_de_parcelas(p.loja_id, forma);
    if parcelas < 1 or parcelas > maximo then
      raise exception 'A % parcela em até %x nessa forma.', p.nome, maximo using errcode = 'P0001';
    end if;
    update public.propostas
       set forma_escolhida = forma, parcelas = case when forma in ('cartao', 'boleto') then parcelas end
     where id = p.id;
  end loop;
end $$;

drop function public.escolher_pagamento(uuid, text, text);
create function public.escolher_pagamento(p_pedido uuid, p_forma text, p_prazo text default null, p_parcelas int default null)
returns void language plpgsql security definer set search_path = '' as $$
declare pe public.pedidos := private.pedido_do_checkout(p_pedido); v_formas text[]; v_prazo text; maximo int;
begin
  if p_forma is null or p_forma not in ('pix', 'cartao', 'boleto', 'duplicata', 'dinheiro', 'crediario') then
    raise exception 'Forma de pagamento inválida.' using errcode = 'P0001';
  end if;
  select l.formas_pagamento into v_formas from public.lojas l where l.id = pe.loja_id;
  if not (p_forma = any(v_formas)) then raise exception 'Esta loja não recebe por essa forma.' using errcode = 'P0001'; end if;
  maximo := private.maximo_de_parcelas(pe.loja_id, p_forma);
  if coalesce(p_parcelas, 1) < 1 or coalesce(p_parcelas, 1) > maximo then
    raise exception 'Esta loja parcela em até %x nessa forma.', maximo using errcode = 'P0001';
  end if;
  if p_forma = 'duplicata' then
    v_prazo := private.duplicata_da_loja(pe.loja_id, pe.construtor_id);
    if v_prazo is null then raise exception 'A loja ainda não liberou duplicata para você.' using errcode = 'P0001'; end if;
    update public.pedidos set forma_pagamento = 'duplicata', prazo = v_prazo, prazo_status = 'aprovado',
      prazo_respondido_em = now(), parcelas = null
     where id = pe.id;
    return;
  end if;
  if p_forma = 'crediario' and (p_prazo is null or p_prazo not in ('28', '28/35', '28/35/42')) then
    raise exception 'Escolha o prazo do crediário.' using errcode = 'P0001';
  end if;
  update public.pedidos set forma_pagamento = p_forma,
    prazo = case when p_forma = 'crediario' then p_prazo end,
    prazo_status = case when p_forma = 'crediario' then 'pendente' end,
    prazo_respondido_em = null,
    parcelas = case when p_forma in ('cartao', 'boleto') then coalesce(p_parcelas, 1) end
   where id = pe.id;
end $$;
revoke all on function public.escolher_pagamento(uuid, text, text, int) from public, anon;
grant execute on function public.escolher_pagamento(uuid, text, text, int) to authenticated;

-- O pedido nasce com a forma e as parcelas da cotação. Duplicata já vem com o prazo liberado pela loja; crediário não vem
-- porque ainda falta o construtor pedir o prazo.
create or replace function private.forma_da_proposta() returns trigger
language plpgsql set search_path = '' as $$
declare v_forma text; v_parcelas int;
begin
  if new.forma_pagamento is null then
    select p.forma_escolhida, p.parcelas into v_forma, v_parcelas from public.propostas p where p.id = new.proposta_id;
    if v_forma is not null and v_forma <> 'crediario' then
      if v_forma = 'duplicata' then
        new.prazo := private.duplicata_da_loja(new.loja_id, new.construtor_id);
        if new.prazo is not null then
          new.forma_pagamento := 'duplicata';
          new.prazo_status := 'aprovado';
          new.prazo_respondido_em := now();
        end if;
      else
        new.forma_pagamento := v_forma;
        new.parcelas := v_parcelas;
      end if;
    end if;
  end if;
  return new;
end $$;

-- Pronto para lançar: pagamento confirmado, crediário com o prazo aprovado ou duplicata liberada.
create or replace function public.registrar_faturamento(p_pedido uuid, p_numero text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pe record;
  numero text := btrim(coalesce(p_numero, ''));
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or private.membro_loja(pe.loja_id) is null then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;
  if not coalesce(private.pode_gerir_loja(pe.loja_id), false) then
    raise exception 'Só o dono ou o gerente da loja lançam o pedido.' using errcode = 'P0001';
  end if;
  if pe.status = 'cancelado' then
    raise exception 'Pedido cancelado não vai para o faturamento.' using errcode = 'P0001';
  end if;
  if pe.pagamento_confirmado_em is null
     and not coalesce(pe.forma_pagamento in ('crediario', 'duplicata') and pe.prazo_status = 'aprovado', false) then
    raise exception 'Confirme o pagamento ou aprove o prazo antes de lançar.' using errcode = 'P0001';
  end if;
  if numero = '' then
    raise exception 'Informe o número da venda no Santri.' using errcode = 'P0001';
  end if;
  if char_length(numero) > 40 then
    raise exception 'O número da venda tem no máximo 40 caracteres.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.pedido_faturamento f where f.pedido_id = p_pedido) then
    raise exception 'Este pedido já foi lançado.' using errcode = 'P0001';
  end if;
  insert into public.pedido_faturamento (pedido_id, numero, lancado_por)
  values (p_pedido, numero, (select auth.uid()));
  -- Atualiza o pedido para os outros painéis abertos receberem a mudança em tempo real
  update public.pedidos set atualizado_em = now() where id = p_pedido;
end $$;
