-- Testes do desempenho da loja (migração desempenho_loja): vendas por dia no fuso do aparelho, funil das propostas e
-- produtos mais vendidos. Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro desfaz tudo.
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
-- Proposta (com pedido quando status_pedido vem preenchido); guarda o id em v com a chave k
create function pg_temp.proposta(k text, loja uuid, total numeric, quando timestamptz, status_proposta text, status_pedido text default null)
returns void language plpgsql as $$
declare orc uuid; prop uuid;
  construtor uuid := '00000000-0000-0000-0000-00000000c001';
begin
  insert into public.orcamentos (construtor_id, modo) values (construtor, 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total, valida_ate, criada_em)
  values (orc, loja, construtor, 'pedido', status_proposta, total, total, quando + interval '7 days', quando)
  returning id into prop;
  if status_pedido is not null then
    insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status, criado_em)
    values (prop, loja, construtor, total, status_pedido, quando);
  end if;
  perform pg_temp.guardar(k, prop::text);
end $$;
-- Item n do catálogo (qualquer um) na proposta guardada em k
create function pg_temp.item(k text, n int, nome text, quantidade numeric, preco numeric, ofertado numeric default null)
returns void language plpgsql as $$
begin
  insert into public.proposta_itens (proposta_id, item_id, nome, unidade, tier, quantidade, preco_anunciado, preco_ofertado)
  values (pg_temp.pegar(k)::uuid, (select id from public.catalogo_itens order by id offset n limit 1), nome, 'un', 1, quantidade, preco, ofertado);
end $$;
create function pg_temp.desempenho(k text) returns jsonb language sql as $$ select pg_temp.pegar(k)::jsonb $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e002', 'gerente.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor'),
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e002', 'gerente');

-- p1 às 23:30 de MT já é dia seguinte em UTC. p3 foi cancelado. p6 expirou depois de a loja mandar preço; p7 expirou sem resposta
select pg_temp.proposta('p1', pg_temp.pegar('A')::uuid, 1000, '2026-10-02 23:30-04', 'aceita', 'entregue');
select pg_temp.proposta('p2', pg_temp.pegar('A')::uuid, 500, '2026-10-02 10:00-04', 'aceita', 'confirmado');
select pg_temp.proposta('p3', pg_temp.pegar('A')::uuid, 700, '2026-10-05 10:00-04', 'aceita', 'cancelado');
select pg_temp.proposta('p4', pg_temp.pegar('A')::uuid, 300, '2026-10-20 10:00-04', 'enviada');
select pg_temp.proposta('p5', pg_temp.pegar('A')::uuid, 200, '2026-10-21 10:00-04', 'recusada');
select pg_temp.proposta('p6', pg_temp.pegar('A')::uuid, 100, '2026-10-22 10:00-04', 'expirada');
select pg_temp.proposta('p7', pg_temp.pegar('A')::uuid, 100, '2026-10-23 10:00-04', 'expirada');
select pg_temp.proposta('p8', pg_temp.pegar('A')::uuid, 400, '2026-09-30 10:00-04', 'aceita', 'entregue');
select pg_temp.proposta('p9', pg_temp.pegar('B')::uuid, 900, '2026-10-10 10:00-04', 'aceita', 'entregue');

select pg_temp.item('p1', 0, 'Produto A', 10, 50);
select pg_temp.item('p1', 1, 'Produto B', 5, 100, 80);
select pg_temp.item('p2', 0, 'Produto A', 2, 50);
select pg_temp.item('p2', 2, 'Produto C', 1, 300);
select pg_temp.item('p2', 3, 'Produto D', 1, 250);
select pg_temp.item('p2', 4, 'Produto E', 1, 200);
select pg_temp.item('p2', 5, 'Produto F', 1, 10);
select pg_temp.item('p3', 6, 'Produto do cancelado', 1, 9999);
select pg_temp.item('p6', 7, 'Produto da contraproposta', 1, 100, 90);
select pg_temp.item('p8', 8, 'Produto de setembro', 1, 8888);
select pg_temp.item('p9', 9, 'Produto da loja B', 1, 7777);

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('dono', public.desempenho_loja(pg_temp.pegar('A')::uuid, '2026-10-01 00:00-04', '2026-11-01 00:00-04', -240)::text);
select pg_temp.guardar('utc', public.desempenho_loja(pg_temp.pegar('A')::uuid, '2026-10-01 00:00-04', '2026-11-01 00:00-04', 0)::text);
select pg_temp.guardar('vazio', public.desempenho_loja(pg_temp.pegar('A')::uuid, '2026-01-01 00:00-04', '2026-02-01 00:00-04', -240)::text);
do $$ begin perform public.desempenho_loja(pg_temp.pegar('A')::uuid, '2026-11-01 00:00-04', '2026-10-01 00:00-04', -240); perform pg_temp.guardar('invertido', 'passou');
exception when others then perform pg_temp.guardar('invertido', sqlerrm); end $$;
do $$ begin perform public.desempenho_loja(pg_temp.pegar('A')::uuid, '2026-10-01 00:00-04', '2026-11-01 00:00-04', 5000); perform pg_temp.guardar('fuso', 'passou');
exception when others then perform pg_temp.guardar('fuso', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000e002');
select pg_temp.guardar('gerente', public.desempenho_loja(pg_temp.pegar('A')::uuid, '2026-10-01 00:00-04', '2026-11-01 00:00-04', -240)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
do $$ begin perform public.desempenho_loja(pg_temp.pegar('A')::uuid, '2026-10-01 00:00-04', '2026-11-01 00:00-04', -240); perform pg_temp.guardar('vendedor', 'passou');
exception when others then perform pg_temp.guardar('vendedor', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
do $$ begin perform public.desempenho_loja(pg_temp.pegar('A')::uuid, '2026-10-01 00:00-04', '2026-11-01 00:00-04', -240); perform pg_temp.guardar('dono_b', 'passou');
exception when others then perform pg_temp.guardar('dono_b', sqlerrm); end $$;
select pg_temp.admin();

select pg_temp.conferir('vendas somadas por dia do fuso, sem cancelado e sem outro mês',
  pg_temp.desempenho('dono') -> 'vendas_por_dia' = '[{"dia": "2026-10-02", "total": 1500, "pedidos": 2}]'::jsonb,
  pg_temp.desempenho('dono') ->> 'vendas_por_dia');
select pg_temp.conferir('o dia muda com o fuso',
  (select jsonb_agg(t ->> 'dia' order by t ->> 'dia') from jsonb_array_elements(pg_temp.desempenho('utc') -> 'vendas_por_dia') t)
  = '["2026-10-02", "2026-10-03"]'::jsonb,
  pg_temp.desempenho('utc') ->> 'vendas_por_dia');
select pg_temp.conferir('funil recebidas no mês', (pg_temp.desempenho('dono') ->> 'propostas')::int = 7, pg_temp.desempenho('dono') ->> 'propostas');
select pg_temp.conferir('funil respondidas conta contraproposta que expirou',
  (pg_temp.desempenho('dono') ->> 'respondidas')::int = 5, pg_temp.desempenho('dono') ->> 'respondidas');
select pg_temp.conferir('funil só conta pedido não cancelado',
  (pg_temp.desempenho('dono') ->> 'viraram_pedido')::int = 2, pg_temp.desempenho('dono') ->> 'viraram_pedido');
select pg_temp.conferir('cinco produtos, do maior valor ao menor',
  (select jsonb_agg(t ->> 'nome' order by ordem) from jsonb_array_elements(pg_temp.desempenho('dono') -> 'produtos') with ordinality as e(t, ordem))
  = '["Produto A", "Produto B", "Produto C", "Produto D", "Produto E"]'::jsonb,
  pg_temp.desempenho('dono') ->> 'produtos');
select pg_temp.conferir('produto soma quantidade e valor nos pedidos',
  (pg_temp.desempenho('dono') #>> '{produtos,0,quantidade}')::numeric = 12
  and (pg_temp.desempenho('dono') #>> '{produtos,0,total}')::numeric = 600
  and pg_temp.desempenho('dono') #>> '{produtos,0,unidade}' = 'un'
  and pg_temp.desempenho('dono') #>> '{produtos,0,item_id}' is not null,
  pg_temp.desempenho('dono') #>> '{produtos,0}');
select pg_temp.conferir('produto usa o preço que a loja ofertou',
  (pg_temp.desempenho('dono') #>> '{produtos,1,total}')::numeric = 400, pg_temp.desempenho('dono') #>> '{produtos,1}');
select pg_temp.conferir('mês sem nada',
  pg_temp.desempenho('vazio') = '{"vendas_por_dia": [], "propostas": 0, "respondidas": 0, "viraram_pedido": 0, "produtos": []}'::jsonb,
  pg_temp.pegar('vazio'));
select pg_temp.conferir('gerente vê', pg_temp.desempenho('gerente') = pg_temp.desempenho('dono'));
select pg_temp.conferir('vendedor recusado', pg_temp.pegar('vendedor') = 'Só o dono ou o gerente vê os resultados.', pg_temp.pegar('vendedor'));
select pg_temp.conferir('outra loja recusada', pg_temp.pegar('dono_b') = 'Só o dono ou o gerente vê os resultados.', pg_temp.pegar('dono_b'));
select pg_temp.conferir('período invertido recusado', pg_temp.pegar('invertido') = 'Período inválido.', pg_temp.pegar('invertido'));
select pg_temp.conferir('fuso absurdo recusado', pg_temp.pegar('fuso') = 'Período inválido.', pg_temp.pegar('fuso'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
