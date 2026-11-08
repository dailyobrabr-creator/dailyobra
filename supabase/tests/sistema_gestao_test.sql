-- Sistema de gestão da loja. Rodar inteiro: tudo fica numa transação desfeita no fim.
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
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.conferir('loja nova começa sem sistema', (select sistema_gestao is null from public.lojas where id = pg_temp.pegar('A')::uuid));

create function pg_temp.gravar(k text, valor text) returns void language sql as $$
  select pg_temp.tentar(k, format('update public.lojas set sistema_gestao = %L where id = %L', valor, pg_temp.pegar('A'))) $$;
create function pg_temp.sistema() returns text language sql security definer as $$
  select sistema_gestao from public.lojas where id = pg_temp.pegar('A')::uuid $$;

select pg_temp.gravar('g1', 'Bling');
select pg_temp.conferir('o dono grava o sistema', pg_temp.pegar('g1') = 'ok' and pg_temp.sistema() = 'Bling', pg_temp.pegar('g1'));
select pg_temp.gravar('g2', 'B');
select pg_temp.conferir('nome curto recusado', pg_temp.pegar('g2') <> 'ok' and pg_temp.sistema() = 'Bling', pg_temp.pegar('g2'));
select pg_temp.gravar('g3', ' Bling ');
select pg_temp.conferir('espaço nas pontas recusado', pg_temp.pegar('g3') <> 'ok', pg_temp.pegar('g3'));
select pg_temp.gravar('g4', repeat('x', 41));
select pg_temp.conferir('nome com mais de 40 recusado', pg_temp.pegar('g4') <> 'ok', pg_temp.pegar('g4'));
select pg_temp.gravar('g5', repeat('x', 40));
select pg_temp.conferir('nome com 40 aceito', pg_temp.pegar('g5') = 'ok', pg_temp.pegar('g5'));
select pg_temp.gravar('g6', null);
select pg_temp.conferir('o dono volta para sem sistema', pg_temp.pegar('g6') = 'ok' and pg_temp.sistema() is null, pg_temp.pegar('g6'));

select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.gravar('c1', 'Omie');
select pg_temp.conferir('quem não é da loja não muda', pg_temp.sistema() is null, pg_temp.pegar('c1'));
select pg_temp.conferir('o construtor lê o sistema sem erro',
  (select count(*) from public.lojas where id = pg_temp.pegar('A')::uuid and sistema_gestao is null) = 1);

select pg_temp.admin();
select pg_temp.conferir('quem tem produtos ligados pelo Santri está com o Santri',
  not exists (select 1 from public.lojas l where exists (select 1 from public.loja_produtos p where p.loja_id = l.id)
                and l.sistema_gestao is distinct from 'Santri'));

do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
