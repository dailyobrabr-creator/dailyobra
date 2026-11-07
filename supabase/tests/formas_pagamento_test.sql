-- Formas de pagamento por loja. Rodar inteiro: tudo fica numa transação desfeita no fim.
begin;

create temp table r (n serial, teste text, ok boolean, detalhe text) on commit drop;
create temp table v (chave text primary key, valor text) on commit drop;
grant all on r, v to authenticated, anon;
grant usage on sequence r_n_seq to authenticated, anon;

create function pg_temp.guardar(k text, x text) returns void language sql as $$
  insert into v values (k, x) on conflict (chave) do update set valor = excluded.valor $$;
create function pg_temp.pegar(k text) returns text language sql as $$ select valor from v where chave = k $$;
create function pg_temp.conferir(t text, condicao boolean, d text default null) returns void language sql as $$
  insert into r (teste, ok, detalhe) values (t, coalesce(condicao, false), d) $$;
create function pg_temp.como(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function pg_temp.admin() returns void language plpgsql as $$ begin execute 'reset role'; end $$;
create function pg_temp.tentar(k text, comando text) returns void language plpgsql as $$
begin
  execute comando;
  perform pg_temp.guardar(k, 'ok');
exception when others then
  perform pg_temp.guardar(k, sqlerrm);
end $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000d002', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'c2@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000d002');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);

-- O que a loja recebe
select pg_temp.admin();
select pg_temp.conferir('loja nova recebe o que o app já oferecia',
  (select formas_pagamento from public.lojas where id = pg_temp.pegar('A')::uuid) = array['pix', 'cartao', 'crediario']);
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('l1', format($x$update public.lojas set formas_pagamento = array['boleto', 'dinheiro'] where id = %L$x$, pg_temp.pegar('A')));
select pg_temp.conferir('o dono troca as formas', pg_temp.pegar('l1') = 'ok', pg_temp.pegar('l1'));
select pg_temp.tentar('l2', format($x$update public.lojas set formas_pagamento = array['cheque'] where id = %L$x$, pg_temp.pegar('A')));
select pg_temp.conferir('forma desconhecida recusada', pg_temp.pegar('l2') <> 'ok', pg_temp.pegar('l2'));
select pg_temp.tentar('l3', format($x$update public.lojas set formas_pagamento = '{}' where id = %L$x$, pg_temp.pegar('A')));
select pg_temp.conferir('loja não fica sem forma', pg_temp.pegar('l3') <> 'ok', pg_temp.pegar('l3'));
select pg_temp.como('00000000-0000-0000-0000-00000000d002');
update public.lojas set formas_pagamento = array['pix'] where id = pg_temp.pegar('A')::uuid;
select pg_temp.admin();
select pg_temp.conferir('dono de outra loja não troca',
  (select formas_pagamento from public.lojas where id = pg_temp.pegar('A')::uuid) = array['boleto', 'dinheiro']);
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.conferir('construtor vê as formas da loja',
  (select formas_pagamento from public.lojas where id = pg_temp.pegar('A')::uuid) = array['boleto', 'dinheiro']);

-- Forma escolhida na cotação
select pg_temp.admin();
create function pg_temp.proposta(loja uuid) returns uuid language plpgsql as $$
declare orc uuid; prop uuid; construtor uuid := '00000000-0000-0000-0000-00000000c001';
begin
  insert into public.orcamentos (construtor_id, modo) values (construtor, 'negociacao') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total, valida_ate)
  values (orc, loja, construtor, 'negociacao', 'enviada', 100, 100, now() + interval '2 days') returning id into prop;
  return prop;
end $$;
create function pg_temp.pedido_de(prop uuid) returns uuid language plpgsql as $$
declare ped uuid;
begin
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status, pagador, documento_informado_em)
  select p.id, p.loja_id, p.construtor_id, p.total, 'confirmado', 'proprio', now() from public.propostas p where p.id = prop
  returning id into ped;
  return ped;
end $$;
create function pg_temp.orcamento_de(prop text) returns text language sql as $$
  select orcamento_id::text from public.propostas where id = prop::uuid $$;
select pg_temp.guardar('p1', pg_temp.proposta(pg_temp.pegar('A')::uuid)::text);
select pg_temp.guardar('orc1', pg_temp.orcamento_de(pg_temp.pegar('p1')));
select pg_temp.guardar('p2', pg_temp.proposta(pg_temp.pegar('B')::uuid)::text);

select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.tentar('f1', format('select public.definir_formas_do_orcamento(%L, %L)', pg_temp.pegar('orc1'),
  jsonb_build_object(pg_temp.pegar('A'), 'boleto')));
select pg_temp.conferir('outro construtor não define', pg_temp.pegar('f1') = 'Orçamento não encontrado.', pg_temp.pegar('f1'));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('f2', format('select public.definir_formas_do_orcamento(%L, %L)', pg_temp.pegar('orc1'),
  jsonb_build_object(pg_temp.pegar('A'), 'pix')));
select pg_temp.conferir('forma que a loja não recebe é recusada', pg_temp.pegar('f2') = 'A Loja A não recebe por essa forma.', pg_temp.pegar('f2'));
select pg_temp.tentar('f3', format('select public.definir_formas_do_orcamento(%L, %L)', pg_temp.pegar('orc1'), '[]'));
select pg_temp.conferir('formato inválido é recusado', pg_temp.pegar('f3') = 'Formas de pagamento inválidas.', pg_temp.pegar('f3'));
select pg_temp.tentar('f4', format('select public.definir_formas_do_orcamento(%L, %L)', pg_temp.pegar('orc1'),
  jsonb_build_object(pg_temp.pegar('A'), 'boleto')));
select pg_temp.conferir('o construtor define a forma', pg_temp.pegar('f4') = 'ok', pg_temp.pegar('f4'));
select pg_temp.conferir('fica na proposta', (select forma_escolhida from public.propostas where id = pg_temp.pegar('p1')::uuid) = 'boleto');
select pg_temp.tentar('f5', format('select public.definir_formas_do_orcamento(%L, %L)', pg_temp.pegar('orc1'), '{}'));
select pg_temp.conferir('loja fora do mapa não muda nada', pg_temp.pegar('f5') = 'ok'
  and (select forma_escolhida from public.propostas where id = pg_temp.pegar('p1')::uuid) = 'boleto', pg_temp.pegar('f5'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.conferir('a loja vê a forma escolhida', (select forma_escolhida from public.propostas where id = pg_temp.pegar('p1')::uuid) = 'boleto');
select pg_temp.conferir('anônimo não define', not has_function_privilege('anon', 'public.definir_formas_do_orcamento(uuid, jsonb)', 'execute'));

-- O pedido nasce com a forma
select pg_temp.admin();
select pg_temp.guardar('ped1', pg_temp.pedido_de(pg_temp.pegar('p1')::uuid)::text);
select pg_temp.conferir('pedido herda a forma da cotação', (select forma_pagamento from public.pedidos where id = pg_temp.pegar('ped1')::uuid) = 'boleto');
update public.propostas set forma_escolhida = 'crediario' where id = pg_temp.pegar('p2')::uuid;
select pg_temp.guardar('ped2', pg_temp.pedido_de(pg_temp.pegar('p2')::uuid)::text);
select pg_temp.conferir('crediário não vem pronto, falta o prazo', (select forma_pagamento from public.pedidos where id = pg_temp.pegar('ped2')::uuid) is null);
select pg_temp.guardar('p3', pg_temp.proposta(pg_temp.pegar('B')::uuid)::text);
select pg_temp.guardar('ped3', pg_temp.pedido_de(pg_temp.pegar('p3')::uuid)::text);
select pg_temp.conferir('sem escolha o pedido fica sem forma', (select forma_pagamento from public.pedidos where id = pg_temp.pegar('ped3')::uuid) is null);

-- Pagar
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('e1', format($x$select public.escolher_pagamento(%L, 'pix')$x$, pg_temp.pegar('ped1')));
select pg_temp.conferir('não paga por forma que a loja não recebe', pg_temp.pegar('e1') = 'Esta loja não recebe por essa forma.', pg_temp.pegar('e1'));
select pg_temp.tentar('e2', format($x$select public.escolher_pagamento(%L, 'dinheiro')$x$, pg_temp.pegar('ped1')));
select pg_temp.conferir('dinheiro vale na loja que recebe', pg_temp.pegar('e2') = 'ok', pg_temp.pegar('e2'));
select pg_temp.tentar('e3', format($x$select public.escolher_pagamento(%L, 'cheque')$x$, pg_temp.pegar('ped1')));
select pg_temp.conferir('forma desconhecida segue recusada', pg_temp.pegar('e3') = 'Forma de pagamento inválida.', pg_temp.pegar('e3'));
select pg_temp.tentar('e4', format($x$select public.escolher_pagamento(%L, 'crediario', '28')$x$, pg_temp.pegar('ped2')));
select pg_temp.conferir('crediário continua pedindo prazo normalmente', pg_temp.pegar('e4') = 'ok', pg_temp.pegar('e4'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
