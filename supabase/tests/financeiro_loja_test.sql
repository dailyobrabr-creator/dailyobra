-- Financeiro da loja: parcelamento e duplicata. Rodar inteiro: tudo fica numa transação desfeita no fim.
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
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000d002', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'c2@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000d002');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor');

-- Parcelamento
select pg_temp.conferir('loja nova é à vista', (select parcelas_cartao = 1 and parcelas_boleto = 1 from public.lojas where id = pg_temp.pegar('A')::uuid));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('p1', format($x$update public.lojas set parcelas_cartao = 10, parcelas_boleto = 3,
  formas_pagamento = array['pix', 'cartao', 'boleto', 'duplicata'] where id = %L$x$, pg_temp.pegar('A')));
select pg_temp.conferir('o dono define o parcelamento e a duplicata', pg_temp.pegar('p1') = 'ok', pg_temp.pegar('p1'));
select pg_temp.tentar('p2', format('update public.lojas set parcelas_cartao = 13 where id = %L', pg_temp.pegar('A')));
select pg_temp.conferir('no máximo 12 vezes', pg_temp.pegar('p2') <> 'ok', pg_temp.pegar('p2'));
select pg_temp.tentar('p3', format('update public.lojas set parcelas_boleto = 0 where id = %L', pg_temp.pegar('A')));
select pg_temp.conferir('no mínimo à vista', pg_temp.pegar('p3') <> 'ok', pg_temp.pegar('p3'));

-- Liberar duplicata
create function pg_temp.liberar(k text, loja text, construtor text, prazo text) returns void language sql as $$
  select pg_temp.tentar(k, format('insert into public.loja_duplicatas (loja_id, construtor_id, prazo) values (%L, %L, %L)',
    pg_temp.pegar(loja), construtor, prazo)) $$;
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.liberar('d1', 'A', '00000000-0000-0000-0000-00000000c001', '28');
select pg_temp.conferir('vendedor não libera', pg_temp.pegar('d1') <> 'ok', pg_temp.pegar('d1'));
select pg_temp.como('00000000-0000-0000-0000-00000000d002');
select pg_temp.liberar('d2', 'A', '00000000-0000-0000-0000-00000000c001', '28');
select pg_temp.conferir('dono de outra loja não libera', pg_temp.pegar('d2') <> 'ok', pg_temp.pegar('d2'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.liberar('d3', 'A', '00000000-0000-0000-0000-00000000c001', '60');
select pg_temp.conferir('prazo fora da lista recusado', pg_temp.pegar('d3') <> 'ok', pg_temp.pegar('d3'));
select pg_temp.liberar('d4', 'A', '00000000-0000-0000-0000-00000000c001', '28/35');
select pg_temp.conferir('o dono libera', pg_temp.pegar('d4') = 'ok', pg_temp.pegar('d4'));
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.conferir('a equipe vê quem está liberado', (select count(*) from public.loja_duplicatas) = 1);
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.conferir('o construtor vê a dele', (select prazo from public.loja_duplicatas) = '28/35');
select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.conferir('outro construtor não vê', (select count(*) from public.loja_duplicatas) = 0);
select pg_temp.conferir('anônimo não lê', not has_table_privilege('anon', 'public.loja_duplicatas', 'select'));

-- Escolha na cotação
select pg_temp.admin();
create function pg_temp.proposta(loja uuid, construtor uuid) returns uuid language plpgsql as $$
declare orc uuid; prop uuid;
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
create function pg_temp.definir(k text, prop text, escolha jsonb) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.definir_formas_do_orcamento(%L, %L)',
    (select orcamento_id from public.propostas where id = prop::uuid),
    jsonb_build_object((select loja_id from public.propostas where id = prop::uuid), escolha))) $$;
select pg_temp.guardar('pr1', pg_temp.proposta(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001')::text);
select pg_temp.guardar('pr2', pg_temp.proposta(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c002')::text);

select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.definir('e1', pg_temp.pegar('pr1'), '{"forma": "cartao", "parcelas": 11}');
select pg_temp.conferir('acima do limite do cartão é recusado', pg_temp.pegar('e1') = 'A Loja A parcela em até 10x nessa forma.', pg_temp.pegar('e1'));
select pg_temp.definir('e2', pg_temp.pegar('pr1'), '{"forma": "pix", "parcelas": 2}');
select pg_temp.conferir('PIX não parcela', pg_temp.pegar('e2') = 'A Loja A parcela em até 1x nessa forma.', pg_temp.pegar('e2'));
select pg_temp.definir('e3', pg_temp.pegar('pr1'), '{"forma": "cartao", "parcelas": "x"}');
select pg_temp.conferir('parcelas inválidas são recusadas', pg_temp.pegar('e3') = 'Formas de pagamento inválidas.', pg_temp.pegar('e3'));
select pg_temp.definir('e4', pg_temp.pegar('pr1'), '{"forma": "cartao", "parcelas": 6}');
select pg_temp.conferir('cartão em 6x', pg_temp.pegar('e4') = 'ok'
  and (select forma_escolhida = 'cartao' and parcelas = 6 from public.propostas where id = pg_temp.pegar('pr1')::uuid), pg_temp.pegar('e4'));
select pg_temp.definir('e5', pg_temp.pegar('pr1'), '"boleto"');
select pg_temp.conferir('app antigo manda só a forma, à vista', pg_temp.pegar('e5') = 'ok'
  and (select forma_escolhida = 'boleto' and parcelas = 1 from public.propostas where id = pg_temp.pegar('pr1')::uuid), pg_temp.pegar('e5'));
select pg_temp.definir('e6', pg_temp.pegar('pr1'), '{"forma": "duplicata"}');
select pg_temp.conferir('duplicata liberada vale', pg_temp.pegar('e6') = 'ok', pg_temp.pegar('e6'));
select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.definir('e7', pg_temp.pegar('pr2'), '{"forma": "duplicata"}');
select pg_temp.conferir('duplicata sem liberação é recusada', pg_temp.pegar('e7') = 'A Loja A não liberou duplicata para você.', pg_temp.pegar('e7'));
select pg_temp.definir('e8', pg_temp.pegar('pr2'), '{"forma": "boleto", "parcelas": 3}');

-- O pedido nasce com a escolha
select pg_temp.admin();
select pg_temp.guardar('ped1', pg_temp.pedido_de(pg_temp.pegar('pr1')::uuid)::text);
select pg_temp.conferir('duplicata nasce aprovada com o prazo da loja',
  (select forma_pagamento = 'duplicata' and prazo = '28/35' and prazo_status = 'aprovado' and parcelas is null
     from public.pedidos where id = pg_temp.pegar('ped1')::uuid));
select pg_temp.guardar('ped2', pg_temp.pedido_de(pg_temp.pegar('pr2')::uuid)::text);
select pg_temp.conferir('boleto nasce com as parcelas',
  (select forma_pagamento = 'boleto' and parcelas = 3 and prazo is null from public.pedidos where id = pg_temp.pegar('ped2')::uuid));

-- Pagar
select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.tentar('q1', format($x$select public.escolher_pagamento(%L, 'cartao', null, 4)$x$, pg_temp.pegar('ped2')));
select pg_temp.conferir('troca para cartão em 4x', pg_temp.pegar('q1') = 'ok'
  and (select forma_pagamento = 'cartao' and parcelas = 4 from public.pedidos where id = pg_temp.pegar('ped2')::uuid), pg_temp.pegar('q1'));
select pg_temp.tentar('q2', format($x$select public.escolher_pagamento(%L, 'boleto', null, 4)$x$, pg_temp.pegar('ped2')));
select pg_temp.conferir('boleto acima do limite é recusado', pg_temp.pegar('q2') = 'Esta loja parcela em até 3x nessa forma.', pg_temp.pegar('q2'));
select pg_temp.tentar('q3', format($x$select public.escolher_pagamento(%L, 'duplicata')$x$, pg_temp.pegar('ped2')));
select pg_temp.conferir('duplicata sem liberação no pagamento', pg_temp.pegar('q3') = 'A loja ainda não liberou duplicata para você.', pg_temp.pegar('q3'));
select pg_temp.tentar('q4', format($x$select public.escolher_pagamento(%L, 'pix')$x$, pg_temp.pegar('ped2')));
select pg_temp.conferir('PIX zera as parcelas', pg_temp.pegar('q4') = 'ok'
  and (select parcelas is null from public.pedidos where id = pg_temp.pegar('ped2')::uuid), pg_temp.pegar('q4'));
select pg_temp.conferir('chamada antiga com três dados segue valendo', has_function_privilege('authenticated', 'public.escolher_pagamento(uuid, text, text, integer)', 'execute'));
select pg_temp.conferir('anônimo não escolhe', not has_function_privilege('anon', 'public.escolher_pagamento(uuid, text, text, integer)', 'execute'));

-- Faturamento
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('f1', format($x$select public.registrar_faturamento(%L, 'V-1')$x$, pg_temp.pegar('ped1')));
select pg_temp.conferir('duplicata liberada já pode ser lançada', pg_temp.pegar('f1') = 'ok', pg_temp.pegar('f1'));
select pg_temp.tentar('f2', format($x$select public.registrar_faturamento(%L, 'V-2')$x$, pg_temp.pegar('ped2')));
select pg_temp.conferir('PIX sem pagamento ainda não', pg_temp.pegar('f2') = 'Confirme o pagamento ou aprove o prazo antes de lançar.', pg_temp.pegar('f2'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
