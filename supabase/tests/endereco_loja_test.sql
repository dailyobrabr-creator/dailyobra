-- Testes do endereço em campos (migração endereco_loja): texto montado pelo banco, loja antiga sem CEP, criar_loja com os
-- campos novos e o horário maior. Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro desfaz tudo.
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
create function pg_temp.endereco(k text) returns text language sql as $$
  select endereco from public.lojas where id = pg_temp.pegar(k)::uuid $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000d002', 'dono.c@teste.dailyobra', 'authenticated', 'authenticated');

-- 1. criar_loja com o endereço em campos
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT",
  "cep":"78700-000","logradouro":"R. Fernando Corrêa da Costa","numero":"1500","complemento":"sala 2","bairro":"Vila Operária",
  "outras_unidades":"Sagrada Família e Médici"}'::jsonb)::text);
select pg_temp.admin();
select pg_temp.conferir('criar_loja monta o endereço',
  (select endereco = 'R. Fernando Corrêa da Costa, 1500, sala 2 – Vila Operária, CEP 78700-000' and cep = '78700000'
     and outras_unidades = 'Sagrada Família e Médici' from public.lojas where id = pg_temp.pegar('A')::uuid),
  pg_temp.endereco('A'));

-- 2 e 3. O dono apaga complemento e bairro; texto mandado pelo cliente não vale com CEP
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
update public.lojas set complemento = null, bairro = null where id = pg_temp.pegar('A')::uuid;
select pg_temp.admin();
select pg_temp.conferir('sem complemento e bairro',
  pg_temp.endereco('A') = 'R. Fernando Corrêa da Costa, 1500, CEP 78700-000', pg_temp.endereco('A'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
update public.lojas set endereco = 'qualquer' where id = pg_temp.pegar('A')::uuid;
select pg_temp.admin();
select pg_temp.conferir('cliente não troca o texto montado',
  pg_temp.endereco('A') = 'R. Fernando Corrêa da Costa, 1500, CEP 78700-000', pg_temp.endereco('A'));

-- 4. Loja sem CEP fica com o texto que escreveu
select pg_temp.como('00000000-0000-0000-0000-00000000d002');
select pg_temp.guardar('C', public.criar_loja('{"nome":"Loja C","cnpj":"11444777000161","cidade":"Rondonópolis","uf":"MT",
  "endereco":"Lojas Vila Operária (matriz)"}'::jsonb)::text);
select pg_temp.admin();
select pg_temp.guardar('c_antes', pg_temp.endereco('C'));
select pg_temp.como('00000000-0000-0000-0000-00000000d002');
update public.lojas set endereco = 'Lojas Vila Operária e Médici' where id = pg_temp.pegar('C')::uuid;
select pg_temp.admin();
select pg_temp.conferir('loja sem CEP mantém o texto',
  pg_temp.pegar('c_antes') = 'Lojas Vila Operária (matriz)' and pg_temp.endereco('C') = 'Lojas Vila Operária e Médici'
  and (select cep is null from public.lojas where id = pg_temp.pegar('C')::uuid),
  concat_ws(' / ', pg_temp.pegar('c_antes'), pg_temp.endereco('C')));

-- 5. CEP com menos de 8 números
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.criar_loja('{"nome":"Loja D","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT","cep":"7870"}'::jsonb);
  perform pg_temp.guardar('cep', 'passou');
exception when others then perform pg_temp.guardar('cep', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('CEP inválido', pg_temp.pegar('cep') = 'CEP inválido.', pg_temp.pegar('cep'));

-- 6. Horário até 300 caracteres
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
update public.lojas set horario = repeat('a', 300) where id = pg_temp.pegar('A')::uuid;
do $$ begin
  update public.lojas set horario = repeat('a', 301) where id = pg_temp.pegar('A')::uuid;
  perform pg_temp.guardar('h301', 'passou');
exception when others then perform pg_temp.guardar('h301', 'recusou'); end $$;
select pg_temp.admin();
select pg_temp.conferir('horário até 300',
  (select char_length(horario) = 300 from public.lojas where id = pg_temp.pegar('A')::uuid) and pg_temp.pegar('h301') = 'recusou',
  pg_temp.pegar('h301'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
