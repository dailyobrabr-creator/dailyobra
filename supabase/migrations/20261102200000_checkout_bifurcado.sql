-- Checkout bifurcado: quem paga o pedido (o próprio construtor ou o cliente final, por link), dados para a nota
-- e PIX copia e cola (BR Code estático) com a chave da loja. Não muda proposta, pedido nem a regra do cashback.

-- ---------- Validações (puras; usadas também nas checagens de coluna) ----------
create function private.so_digitos(p text) returns text language sql immutable set search_path = '' as $$
  select regexp_replace(coalesce(p, ''), '\D', '', 'g') $$;

create function private.cpf_valido(p text) returns boolean language plpgsql immutable set search_path = '' as $$
declare d text := private.so_digitos(p); soma int; dv int; i int;
begin
  if length(d) <> 11 or d ~ '^(\d)\1{10}$' then return false; end if;
  soma := 0;
  for i in 1..9 loop soma := soma + substr(d, i, 1)::int * (11 - i); end loop;
  dv := (soma * 10) % 11; if dv = 10 then dv := 0; end if;
  if dv <> substr(d, 10, 1)::int then return false; end if;
  soma := 0;
  for i in 1..10 loop soma := soma + substr(d, i, 1)::int * (12 - i); end loop;
  dv := (soma * 10) % 11; if dv = 10 then dv := 0; end if;
  return dv = substr(d, 11, 1)::int;
end $$;

create function private.documento_valido(p text) returns boolean language sql immutable set search_path = '' as $$
  select case length(private.so_digitos(p))
    when 11 then private.cpf_valido(p) when 14 then private.cnpj_valido(p) else false end $$;

-- CPF/CNPJ só com dígitos, e-mail, celular com +55 ou chave aleatória (UUID em minúsculas)
create function private.chave_pix_valida(p text) returns boolean language sql immutable set search_path = '' as $$
  select case
    when p ~ '^\d{11}$' then private.cpf_valido(p)
    when p ~ '^\d{14}$' then private.cnpj_valido(p)
    when p ~ '^\+55\d{10,11}$' then true
    when p ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then true
    when p ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and char_length(p) <= 77 then true
    else false end $$;

revoke execute on function private.so_digitos(text), private.cpf_valido(text), private.documento_valido(text),
  private.chave_pix_valida(text) from public;
grant execute on function private.so_digitos(text), private.cpf_valido(text), private.cnpj_valido(text),
  private.documento_valido(text), private.chave_pix_valida(text) to authenticated;

-- ---------- Colunas ----------
alter table public.lojas add column chave_pix text check (chave_pix is null or private.chave_pix_valida(chave_pix));
alter table public.profiles add column documento text
  check (documento is null or (documento ~ '^(\d{11}|\d{14})$' and private.documento_valido(documento)));
alter table public.pedidos
  add column pagador text check (pagador in ('proprio', 'cliente')),
  add column pagador_nome text check (char_length(pagador_nome) <= 120),
  add column pagador_whatsapp text check (pagador_whatsapp ~ '^\d{10,13}$'),
  add column link_codigo text unique check (link_codigo ~ '^[A-Za-z0-9_-]{22}$'),
  add column documento_informado_em timestamptz,
  add column pagamento_informado_em timestamptz;

-- CPF/CNPJ de quem paga: só a loja do pedido lê; ninguém grava direto (só as funções abaixo)
create table public.pedido_documentos (
  pedido_id uuid primary key references public.pedidos (id) on delete cascade,
  documento text not null check (documento ~ '^(\d{11}|\d{14})$')
);
alter table public.pedido_documentos enable row level security;
create policy "loja ve documento do pagador" on public.pedido_documentos for select to authenticated
  using (private.membro_loja((select pe.loja_id from public.pedidos pe where pe.id = pedido_id)) is not null);
revoke all on public.pedido_documentos from anon;
revoke insert, update, delete, truncate on public.pedido_documentos from authenticated;

-- ---------- PIX copia e cola (BR Code estático do Banco Central) ----------
create function private.sem_acento(p text) returns text language sql immutable set search_path = '' as $$
  select translate(coalesce(p, ''), 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑáàâãäéèêëíìîïóòôõöúùûüçñ',
                                    'AAAAAEEEEIIIIOOOOOUUUUCNaaaaaeeeeiiiiooooouuuucn') $$;

-- CRC16-CCITT-FALSE (polinômio 0x1021, inicial 0xFFFF), em hexadecimal maiúsculo
create function private.crc16(p text) returns text language plpgsql immutable set search_path = '' as $$
declare b bytea := convert_to(p, 'UTF8'); crc int := 65535; i int; j int;
begin
  for i in 0..length(b) - 1 loop
    crc := crc # (get_byte(b, i) << 8);
    for j in 1..8 loop
      if (crc & 32768) <> 0 then crc := ((crc << 1) # 4129) & 65535; else crc := (crc << 1) & 65535; end if;
    end loop;
  end loop;
  return upper(lpad(to_hex(crc), 4, '0'));
end $$;

-- Campos EMV: ID (2) + tamanho (2) + valor. Nome até 25 e cidade até 15, sem acento e em maiúsculas.
create function private.brcode(chave text, nome text, cidade text, valor numeric, txid text) returns text
language plpgsql immutable set search_path = '' as $$
declare conta text; campo text; carga text;
begin
  conta := '0014br.gov.bcb.pix01' || lpad(length(chave)::text, 2, '0') || chave;
  carga := '000201' || '26' || lpad(length(conta)::text, 2, '0') || conta || '52040000' || '5303986';
  if valor is not null then
    campo := to_char(valor, 'FM999999990.00');
    carga := carga || '54' || lpad(length(campo)::text, 2, '0') || campo;
  end if;
  campo := left(upper(private.sem_acento(nome)), 25);
  carga := carga || '5802BR' || '59' || lpad(length(campo)::text, 2, '0') || campo;
  campo := left(upper(private.sem_acento(cidade)), 15);
  carga := carga || '60' || lpad(length(campo)::text, 2, '0') || campo;
  campo := '05' || lpad(length(txid)::text, 2, '0') || txid;
  carga := carga || '62' || lpad(length(campo)::text, 2, '0') || campo || '6304';
  return carga || private.crc16(carga);
end $$;

-- PIX do pedido com o total exato e o identificador DO + 8 primeiros caracteres do id; nulo sem chave na loja
create function private.pix_copia_e_cola(p_pedido uuid) returns text language sql stable security definer set search_path = '' as $$
  select case when l.chave_pix is null then null
    else private.brcode(l.chave_pix, l.nome, l.cidade, pe.total, 'DO' || upper(left(pe.id::text, 8))) end
  from public.pedidos pe join public.lojas l on l.id = pe.loja_id where pe.id = p_pedido $$;

-- Situação do pagamento (precedência da spec): cancelado, pago, informado, aguardando_pagamento, aguardando_dados, sem_pagador
create function private.situacao_pagamento(p public.pedidos) returns text language sql stable set search_path = '' as $$
  select case
    when p.status = 'cancelado' then 'cancelado'
    when p.pagamento_confirmado_em is not null then 'pago'
    when p.pagamento_informado_em is not null then 'informado'
    when p.pagador is not null and p.documento_informado_em is not null then 'aguardando_pagamento'
    when p.pagador = 'cliente' then 'aguardando_dados'
    else 'sem_pagador' end $$;

revoke execute on function private.sem_acento(text), private.crc16(text), private.brcode(text, text, text, numeric, text),
  private.pix_copia_e_cola(uuid), private.situacao_pagamento(public.pedidos) from public;

-- ---------- Construtor ----------
create function public.pagar_eu_mesmo(p_pedido uuid, p_documento text) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); pe public.pedidos; doc text := private.so_digitos(p_documento); v_nome text;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or pe.construtor_id is distinct from uid then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then raise exception 'Este pedido já foi pago.' using errcode = 'P0001'; end if;
  if not private.documento_valido(doc) then raise exception 'CPF ou CNPJ inválido. Confira os números.' using errcode = 'P0001'; end if;
  select btrim(coalesce(p.nome, '')) into v_nome from public.profiles p where p.id = uid;
  if coalesce(v_nome, '') = '' then raise exception 'Complete seu nome no Perfil.' using errcode = 'P0001'; end if;
  update public.profiles set documento = doc where id = uid;
  update public.pedidos set pagador = 'proprio', pagador_nome = left(v_nome, 120), pagador_whatsapp = null, link_codigo = null,
    documento_informado_em = now(), pagamento_informado_em = null
   where id = p_pedido;
  insert into public.pedido_documentos (pedido_id, documento) values (p_pedido, doc)
    on conflict (pedido_id) do update set documento = excluded.documento;
end $$;

create function public.criar_link_pagamento(p_pedido uuid, p_nome text, p_whatsapp text) returns text
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); pe public.pedidos; zap text := private.so_digitos(p_whatsapp); chave text; cod text;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or pe.construtor_id is distinct from uid then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then raise exception 'Este pedido já foi pago.' using errcode = 'P0001'; end if;
  select l.chave_pix into chave from public.lojas l where l.id = pe.loja_id;
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

create function public.pix_do_pedido(p_pedido uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
declare pe public.pedidos;
begin
  select * into pe from public.pedidos where id = p_pedido;
  if not found or (pe.construtor_id is distinct from (select auth.uid()) and private.membro_loja(pe.loja_id) is null) then
    raise exception 'Pedido não encontrado.' using errcode = 'P0001';
  end if;
  return private.pix_copia_e_cola(p_pedido);
end $$;

-- ---------- Página do cliente (pública, pelo código do link) ----------
create function public.pedido_do_link(p_codigo text) returns jsonb
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
    'loja', jsonb_build_object('nome', l.nome, 'cidade', l.cidade, 'uf', l.uf, 'whatsapp', l.whatsapp),
    'itens', v_itens, 'desconto', pr.desconto, 'frete', pr.frete, 'total', pe.total, 'situacao', sit,
    'pagador_nome', pe.pagador_nome, 'documento_informado', pe.documento_informado_em is not null,
    'pix', case when pe.documento_informado_em is not null and sit not in ('pago', 'cancelado')
                then private.pix_copia_e_cola(pe.id) end);
end $$;

create function public.dados_do_pagador(p_codigo text, p_nome text, p_documento text) returns void
language plpgsql security definer set search_path = '' as $$
declare pe public.pedidos; doc text := private.so_digitos(p_documento);
begin
  select * into pe from public.pedidos where p_codigo is not null and link_codigo = p_codigo for update;
  if not found then raise exception 'Link inválido ou substituído.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then raise exception 'Este pedido já foi pago.' using errcode = 'P0001'; end if;
  if char_length(btrim(coalesce(p_nome, ''))) < 2 then raise exception 'Informe seu nome.' using errcode = 'P0001'; end if;
  if not private.documento_valido(doc) then raise exception 'CPF ou CNPJ inválido. Confira os números.' using errcode = 'P0001'; end if;
  update public.pedidos set pagador_nome = left(btrim(p_nome), 120), documento_informado_em = now() where id = pe.id;
  insert into public.pedido_documentos (pedido_id, documento) values (pe.id, doc)
    on conflict (pedido_id) do update set documento = excluded.documento;
end $$;

create function public.avisar_pagamento(p_codigo text) returns void
language plpgsql security definer set search_path = '' as $$
declare pe public.pedidos;
begin
  select * into pe from public.pedidos where p_codigo is not null and link_codigo = p_codigo for update;
  if not found then raise exception 'Link inválido ou substituído.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then return; end if;
  if pe.documento_informado_em is null then
    raise exception 'Informe seu CPF ou CNPJ antes de avisar o pagamento.' using errcode = 'P0001';
  end if;
  -- clock_timestamp: um segundo aviso nunca troca a hora do primeiro
  update public.pedidos set pagamento_informado_em = coalesce(pagamento_informado_em, clock_timestamp()) where id = pe.id;
end $$;

revoke execute on function public.pagar_eu_mesmo(uuid, text), public.criar_link_pagamento(uuid, text, text),
  public.pix_do_pedido(uuid), public.pedido_do_link(text), public.dados_do_pagador(text, text, text),
  public.avisar_pagamento(text) from public, anon;
grant execute on function public.pagar_eu_mesmo(uuid, text), public.criar_link_pagamento(uuid, text, text),
  public.pix_do_pedido(uuid) to authenticated;
grant execute on function public.pedido_do_link(text), public.dados_do_pagador(text, text, text),
  public.avisar_pagamento(text) to anon, authenticated;
