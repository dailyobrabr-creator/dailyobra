-- Testes dos clientes da loja (migração clientes_loja): quem cotou com a loja, quem comprou, quanto e quando foi o último
-- contato. Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro desfaz tudo.
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
-- Proposta (com pedido quando status_pedido vem preenchido)
create function pg_temp.proposta(loja uuid, construtor uuid, total numeric, quando timestamptz, status_pedido text default null)
returns void language plpgsql as $$
declare orc uuid; prop uuid;
begin
  insert into public.orcamentos (construtor_id, modo) values (construtor, 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total, valida_ate, criada_em)
  values (orc, loja, construtor, 'pedido', case when status_pedido is null then 'enviada' else 'aceita' end, total, total,
          quando + interval '7 days', quando)
  returning id into prop;
  if status_pedido is not null then
    insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status, criado_em)
    values (prop, loja, construtor, total, status_pedido, quando);
  end if;
end $$;
create function pg_temp.cliente(k text, construtor text) returns jsonb language sql as $$
  select t from jsonb_array_elements(pg_temp.pegar(k)::jsonb) t where t ->> 'construtor_id' = construtor $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'c2@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c003', 'c3@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c004', 'c4@teste.dailyobra', 'authenticated', 'authenticated');
update public.profiles set nome = 'Ana Souza', empresa = 'Souza Obras', telefone = '66999990001', cidade = 'Rondonópolis', uf = 'MT'
 where id = '00000000-0000-0000-0000-00000000c001';
update public.profiles set nome = null, empresa = null, telefone = null, cidade = null, uf = null
 where id = '00000000-0000-0000-0000-00000000c002';
update public.profiles set nome = 'Carlos Dias' where id = '00000000-0000-0000-0000-00000000c003';
update public.profiles set nome = 'Diego Melo' where id = '00000000-0000-0000-0000-00000000c004';

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor');

-- c001 comprou duas vezes e tem uma proposta aberta; c002 só cotou; c003 teve o único pedido cancelado; c004 é da loja B
select pg_temp.proposta(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001', 1000, '2026-10-01 10:00-04', 'entregue');
select pg_temp.proposta(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001', 500, '2026-10-10 10:00-04', 'confirmado');
select pg_temp.proposta(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001', 300, '2026-10-20 10:00-04');
select pg_temp.proposta(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c002', 200, '2026-10-25 10:00-04');
select pg_temp.proposta(pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c003', 700, '2026-10-05 10:00-04', 'cancelado');
select pg_temp.proposta(pg_temp.pegar('B')::uuid, '00000000-0000-0000-0000-00000000c004', 900, '2026-10-30 10:00-04', 'entregue');

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('dono', public.clientes_loja(pg_temp.pegar('A')::uuid)::text);
select pg_temp.admin();
select pg_temp.conferir('lista quem cotou, do contato mais recente ao mais antigo',
  (select jsonb_agg(right(t ->> 'construtor_id', 4) order by ordem)
     from jsonb_array_elements(pg_temp.pegar('dono')::jsonb) with ordinality as e(t, ordem))
  = '["c002", "c001", "c003"]'::jsonb,
  pg_temp.pegar('dono'));
select pg_temp.conferir('cliente que comprou',
  (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'propostas')::int = 3
  and (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'pedidos')::int = 2
  and (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'total')::numeric = 1500
  and pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'nome' = 'Ana Souza'
  and pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'empresa' = 'Souza Obras'
  and pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'telefone' = '66999990001'
  and pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'cidade' = 'Rondonópolis'
  and pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'uf' = 'MT'
  and (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001') ->> 'ultimo_contato')::timestamptz = '2026-10-20 10:00-04',
  pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c001')::text);
select pg_temp.conferir('quem só cotou, sem nome no perfil',
  (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c002') ->> 'pedidos')::int = 0
  and (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c002') ->> 'total')::numeric = 0
  and pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c002') ->> 'nome' = ''
  and pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c002') ->> 'telefone' = '',
  pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c002')::text);
select pg_temp.conferir('pedido cancelado não conta como compra',
  (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c003') ->> 'pedidos')::int = 0
  and (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c003') ->> 'total')::numeric = 0
  and (pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c003') ->> 'propostas')::int = 1,
  pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c003')::text);
select pg_temp.conferir('cliente de outra loja não aparece',
  pg_temp.cliente('dono', '00000000-0000-0000-0000-00000000c004') is null);

select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.guardar('vendedor', public.clientes_loja(pg_temp.pegar('A')::uuid)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
do $$ begin perform public.clientes_loja(pg_temp.pegar('A')::uuid); perform pg_temp.guardar('dono_b', 'passou');
exception when others then perform pg_temp.guardar('dono_b', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('vendedor vê os clientes', pg_temp.pegar('vendedor')::jsonb = pg_temp.pegar('dono')::jsonb);
select pg_temp.conferir('outra loja recusada', pg_temp.pegar('dono_b') = 'Só a equipe da loja vê os clientes.', pg_temp.pegar('dono_b'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
