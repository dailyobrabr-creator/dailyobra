-- Testes do endereço do construtor e da obra (migração endereco_construtor). Roda numa transação; o bloco final levanta
-- 'RESULTADO: ...' e o erro desfaz tudo.
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
  perform pg_temp.guardar(k, 'passou');
exception when others then perform pg_temp.guardar(k, sqlerrm);
end $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000c001', 'construtor@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'outro@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000d001', 'dono@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('grava', $q$insert into public.construtor_enderecos (user_id, cep, logradouro, numero, bairro)
  values ('00000000-0000-0000-0000-00000000c001', '78720586', 'Av. João Ponce de Arruda', '4885', 'Vila Operária')$q$);
select pg_temp.tentar('atualiza', $q$insert into public.construtor_enderecos (user_id, numero) values ('00000000-0000-0000-0000-00000000c001', '10')
  on conflict (user_id) do update set numero = excluded.numero$q$);
select pg_temp.guardar('meu', (select numero from public.construtor_enderecos where user_id = '00000000-0000-0000-0000-00000000c001'));
select pg_temp.tentar('cep ruim', $q$update public.construtor_enderecos set cep = '123' where user_id = '00000000-0000-0000-0000-00000000c001'$q$);
select pg_temp.tentar('em nome de outro', $q$insert into public.construtor_enderecos (user_id, numero) values ('00000000-0000-0000-0000-00000000c002', '1')$q$);

select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.guardar('outro lê', (select count(*)::text from public.construtor_enderecos));

-- A loja que recebeu proposta lê o perfil, mas não o endereço
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.admin();
insert into public.orcamentos (id, construtor_id, modo) values ('00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-00000000c001', 'negociacao');
insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total, valida_ate)
values ('00000000-0000-0000-0000-0000000a0001', pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000c001', 'negociacao', 'enviada', 100, 100, now() + interval '2 days');
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('loja lê perfil', (select count(*)::text from public.profiles where id = '00000000-0000-0000-0000-00000000c001'));
select pg_temp.guardar('loja lê endereço', (select count(*)::text from public.construtor_enderecos));

select pg_temp.admin();
set local role anon;
select pg_temp.tentar('anônimo', 'select * from public.construtor_enderecos');
reset role;

-- A obra guarda as partes
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('obra', $q$insert into public.obras (nome, cidade, uf, created_by, cep, logradouro, numero, bairro, endereco)
  values ('Casa', 'Rondonópolis', 'MT', '00000000-0000-0000-0000-00000000c001', '78720586', 'Av. João Ponce de Arruda', '4885', 'Vila Operária', 'Av. João Ponce de Arruda, 4885 – Vila Operária, CEP 78720-586')$q$);
select pg_temp.tentar('excluir', 'select public.excluir_conta(''EXCLUIR'')');
select pg_temp.admin();

select pg_temp.conferir('construtor grava o próprio endereço', pg_temp.pegar('grava') = 'passou', pg_temp.pegar('grava'));
select pg_temp.conferir('construtor atualiza o próprio endereço', pg_temp.pegar('atualiza') = 'passou' and pg_temp.pegar('meu') = '10', pg_temp.pegar('atualiza'));
select pg_temp.conferir('CEP precisa ter 8 números', pg_temp.pegar('cep ruim') like '%check constraint%', pg_temp.pegar('cep ruim'));
select pg_temp.conferir('ninguém grava em nome de outro', pg_temp.pegar('em nome de outro') like '%row-level security%', pg_temp.pegar('em nome de outro'));
select pg_temp.conferir('outro construtor não lê', pg_temp.pegar('outro lê') = '0', pg_temp.pegar('outro lê'));
select pg_temp.conferir('loja lê o perfil e não lê o endereço', pg_temp.pegar('loja lê perfil') = '1' and pg_temp.pegar('loja lê endereço') = '0', pg_temp.pegar('loja lê endereço'));
select pg_temp.conferir('anônimo não lê', pg_temp.pegar('anônimo') like 'permission denied%', pg_temp.pegar('anônimo'));
select pg_temp.conferir('obra aceita as partes do endereço', pg_temp.pegar('obra') = 'passou', pg_temp.pegar('obra'));
select pg_temp.conferir('excluir a conta apaga o endereço',
  pg_temp.pegar('excluir') = 'passou' and not exists (select 1 from public.construtor_enderecos where user_id = '00000000-0000-0000-0000-00000000c001'), pg_temp.pegar('excluir'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
