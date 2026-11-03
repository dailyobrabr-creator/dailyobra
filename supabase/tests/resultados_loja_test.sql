-- Testes dos resultados da loja (migração resultados_loja): soma dos pedidos de um período, top construtores e quem vê.
-- Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro desfaz tudo.
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
-- Orçamento, proposta aceita e pedido (o pedido sai sem o saldo, como em aceitar a proposta)
create function pg_temp.venda(loja uuid, construtor uuid, total numeric, cashback numeric, quando timestamptz,
  status text default 'confirmado', saldo numeric default 0) returns void language plpgsql as $$
declare orc uuid; prop uuid;
begin
  insert into public.orcamentos (construtor_id, modo) values (construtor, 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total,
    cashback_previsto, saldo_aplicado, valida_ate)
  values (orc, loja, construtor, 'pedido', 'aceita', total, total, cashback, saldo, quando + interval '7 days')
  returning id into prop;
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status, criado_em)
  values (prop, loja, construtor, total - saldo, status, quando);
end $$;
create function pg_temp.top(k text, construtor text) returns jsonb language sql as $$
  select t from jsonb_array_elements(pg_temp.pegar(k)::jsonb -> 'top') t where t ->> 'construtor_id' = construtor $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000a001', 'gerente.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'c2@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c003', 'c3@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c004', 'c4@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c005', 'c5@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c006', 'c6@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c007', 'c7@teste.dailyobra', 'authenticated', 'authenticated');
update public.profiles set nome = 'Ana Souza', empresa = 'Souza Obras' where id = '00000000-0000-0000-0000-00000000c001';
update public.profiles set nome = null, empresa = null where id = '00000000-0000-0000-0000-00000000c002';
update public.profiles set nome = 'Carlos Dias' where id = '00000000-0000-0000-0000-00000000c003';
update public.profiles set nome = 'Diego Melo' where id = '00000000-0000-0000-0000-00000000c004';
update public.profiles set nome = 'Elisa Prado' where id = '00000000-0000-0000-0000-00000000c005';
update public.profiles set nome = 'Fábio Reis' where id = '00000000-0000-0000-0000-00000000c006';
update public.profiles set nome = 'Gabi Torres' where id = '00000000-0000-0000-0000-00000000c007';

-- Loja A (com gerente e vendedor) e loja B
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000a001', 'gerente'),
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor');

-- Novembro de 2026 na loja A (c006 bem no começo do período) e o que fica de fora
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001', 1000, 20, '2026-11-02 10:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001', 500, 10, '2026-11-15 10:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c002', 800, 16, '2026-11-03 10:00-04', saldo => 100);
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c003', 300, 0, '2026-11-04 10:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c007', 100, 0, '2026-11-05 10:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c007', 100, 0, '2026-11-06 10:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c004', 200, 0, '2026-11-07 10:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c005', 100, 0, '2026-11-08 10:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c006', 50, 0, '2026-11-01 00:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001', 9999, 0, '2026-11-09 10:00-04', 'cancelado');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001', 400, 0, '2026-10-20 10:00-04');
select pg_temp.venda(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c003', 700, 0, '2026-12-01 00:00-04');
select pg_temp.venda(pg_temp.pegar('B')::uuid, '00000000-0000-0000-0000-00000000c001', 600, 0, '2026-11-10 10:00-04');

-- 1 a 4. O dono vê novembro
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('nov', public.resultados_loja(pg_temp.pegar('A')::uuid, '2026-11-01 00:00-04', '2026-12-01 00:00-04')::text);
select pg_temp.admin();
select pg_temp.conferir('dono vê novembro',
  (pg_temp.pegar('nov')::jsonb ->> 'faturamento')::numeric = 3150 and (pg_temp.pegar('nov')::jsonb ->> 'pedidos')::int = 9
  and (pg_temp.pegar('nov')::jsonb ->> 'cashback')::numeric = 46,
  pg_temp.pegar('nov'));
select pg_temp.conferir('top tem 5, pelo total, empate por pedidos',
  (select jsonb_agg(jsonb_build_array(right(t ->> 'construtor_id', 4), (t ->> 'total')::numeric, (t ->> 'pedidos')::int) order by ordem)
     from jsonb_array_elements(pg_temp.pegar('nov')::jsonb -> 'top') with ordinality as e(t, ordem))
  = '[["c001", 1500, 2], ["c002", 800, 1], ["c003", 300, 1], ["c007", 200, 2], ["c004", 200, 1]]'::jsonb,
  pg_temp.pegar('nov')::jsonb ->> 'top');
select pg_temp.conferir('total da proposta mesmo com saldo',
  (pg_temp.top('nov', '00000000-0000-0000-0000-00000000c002') ->> 'total')::numeric = 800);
select pg_temp.conferir('construtor sem nome',
  pg_temp.top('nov', '00000000-0000-0000-0000-00000000c002') ->> 'nome' = ''
  and pg_temp.top('nov', '00000000-0000-0000-0000-00000000c002') ->> 'empresa' = ''
  and pg_temp.top('nov', '00000000-0000-0000-0000-00000000c001') ->> 'nome' = 'Ana Souza'
  and pg_temp.top('nov', '00000000-0000-0000-0000-00000000c001') ->> 'empresa' = 'Souza Obras',
  concat_ws(' / ', pg_temp.top('nov', '00000000-0000-0000-0000-00000000c002')::text, pg_temp.top('nov', '00000000-0000-0000-0000-00000000c001')::text));

-- 5 a 7. Gerente vê; vendedor e outra loja não
select pg_temp.como('00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('gerente', public.resultados_loja(pg_temp.pegar('A')::uuid, '2026-11-01 00:00-04', '2026-12-01 00:00-04')::text);
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
do $$ begin perform public.resultados_loja(pg_temp.pegar('A')::uuid, '2026-11-01 00:00-04', '2026-12-01 00:00-04');
  perform pg_temp.guardar('vendedor', 'passou');
exception when others then perform pg_temp.guardar('vendedor', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
do $$ begin perform public.resultados_loja(pg_temp.pegar('A')::uuid, '2026-11-01 00:00-04', '2026-12-01 00:00-04');
  perform pg_temp.guardar('dono_b', 'passou');
exception when others then perform pg_temp.guardar('dono_b', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('gerente vê o mesmo', pg_temp.pegar('gerente')::jsonb = pg_temp.pegar('nov')::jsonb, pg_temp.pegar('gerente'));
select pg_temp.conferir('vendedor recusado', pg_temp.pegar('vendedor') = 'Só o dono ou o gerente vê os resultados.', pg_temp.pegar('vendedor'));
select pg_temp.conferir('outra loja recusada', pg_temp.pegar('dono_b') = 'Só o dono ou o gerente vê os resultados.', pg_temp.pegar('dono_b'));

-- 8 e 9. Período inválido e mês sem venda
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin perform public.resultados_loja(pg_temp.pegar('A')::uuid, '2026-11-01 00:00-04', '2026-11-01 00:00-04');
  perform pg_temp.guardar('periodo', 'passou');
exception when others then perform pg_temp.guardar('periodo', sqlerrm); end $$;
select pg_temp.guardar('vazio', public.resultados_loja(pg_temp.pegar('A')::uuid, '2025-10-01 00:00-04', '2025-11-01 00:00-04')::text);
select pg_temp.admin();
select pg_temp.conferir('período inválido', pg_temp.pegar('periodo') = 'Período inválido.', pg_temp.pegar('periodo'));
select pg_temp.conferir('mês sem venda',
  pg_temp.pegar('vazio')::jsonb = '{"faturamento": 0, "pedidos": 0, "cashback": 0, "top": []}'::jsonb, pg_temp.pegar('vazio'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
