-- Testes do limite de uso da IA (migração ia_obra). Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro desfaz tudo.
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
create function pg_temp.como(u text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.pegar(u), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function pg_temp.admin() returns void language plpgsql as $$ begin execute 'reset role'; end $$;
create function pg_temp.tentar(k text, comando text) returns void language plpgsql as $$
begin
  execute comando;
  perform pg_temp.guardar(k, 'passou');
exception when others then perform pg_temp.guardar(k, sqlerrm);
end $$;
create function pg_temp.usar(k text, obra text, tipo text) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.registrar_uso_ia(%L, %L)', obra, tipo)) $$;
create function pg_temp.usos(u text) returns int language sql as $$
  select count(*)::int from public.leituras_lista where user_id = pg_temp.pegar(u)::uuid $$;

select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('estagiario', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('empreiteiro', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('cliente', '00000000-0000-0000-0000-00000000a005');
select pg_temp.guardar('fora', '00000000-0000-0000-0000-00000000a006');
select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.valor like '00000000-0000-0000-0000-00000000a%';
insert into public.obras (id, nome, created_by) values
  ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001');
insert into public.obra_membros (obra_id, user_id, papel, funcao) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a002', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'membro', 'estagiario'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a004', 'membro', 'empreiteiro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente');

-- Quem pode pedir o quê
select pg_temp.como('dono');
select pg_temp.usar('dono diario', pg_temp.pegar('O'), 'diario');
select pg_temp.usar('dono nota', pg_temp.pegar('O'), 'nota');
select pg_temp.usar('tipo errado', pg_temp.pegar('O'), 'lista');
select pg_temp.usar('tipo nulo', pg_temp.pegar('O'), null);
select pg_temp.usar('obra nula', null, 'nota');
select pg_temp.usar('obra nula diario', null, 'diario');
select pg_temp.usar('obra inexistente', '00000000-0000-0000-0000-0000000b0099', 'diario');
select pg_temp.admin();
select pg_temp.conferir('o dono dita o dia', pg_temp.pegar('dono diario') = 'passou', pg_temp.pegar('dono diario'));
select pg_temp.conferir('o dono lê a nota', pg_temp.pegar('dono nota') = 'passou', pg_temp.pegar('dono nota'));
select pg_temp.conferir('cada uso fica registrado', pg_temp.usos('dono') = 2, pg_temp.usos('dono')::text);
select pg_temp.conferir('tipo desconhecido é recusado', pg_temp.pegar('tipo errado') = 'Pedido inválido.', pg_temp.pegar('tipo errado'));
select pg_temp.conferir('tipo nulo é recusado', pg_temp.pegar('tipo nulo') = 'Pedido inválido.', pg_temp.pegar('tipo nulo'));
select pg_temp.conferir('obra nula não passa na nota', pg_temp.pegar('obra nula') like 'Só o responsável%', pg_temp.pegar('obra nula'));
select pg_temp.conferir('obra nula não passa no diário', pg_temp.pegar('obra nula diario') like 'Só quem toca%', pg_temp.pegar('obra nula diario'));
select pg_temp.conferir('obra inexistente não passa', pg_temp.pegar('obra inexistente') like 'Só quem toca%', pg_temp.pegar('obra inexistente'));

select pg_temp.como('mestre');
select pg_temp.usar('mestre diario', pg_temp.pegar('O'), 'diario');
select pg_temp.usar('mestre nota', pg_temp.pegar('O'), 'nota');
select pg_temp.como('estagiario');
select pg_temp.usar('estagiario diario', pg_temp.pegar('O'), 'diario');
select pg_temp.usar('estagiario nota', pg_temp.pegar('O'), 'nota');
select pg_temp.como('empreiteiro');
select pg_temp.usar('empreiteiro diario', pg_temp.pegar('O'), 'diario');
select pg_temp.usar('empreiteiro nota', pg_temp.pegar('O'), 'nota');
select pg_temp.como('cliente');
select pg_temp.usar('cliente diario', pg_temp.pegar('O'), 'diario');
select pg_temp.usar('cliente nota', pg_temp.pegar('O'), 'nota');
select pg_temp.como('fora');
select pg_temp.usar('fora diario', pg_temp.pegar('O'), 'diario');
select pg_temp.usar('fora nota', pg_temp.pegar('O'), 'nota');
select pg_temp.admin();
select pg_temp.conferir('o mestre dita', pg_temp.pegar('mestre diario') = 'passou', pg_temp.pegar('mestre diario'));
select pg_temp.conferir('o mestre lê a nota', pg_temp.pegar('mestre nota') = 'passou', pg_temp.pegar('mestre nota'));
select pg_temp.conferir('o estagiário dita', pg_temp.pegar('estagiario diario') = 'passou', pg_temp.pegar('estagiario diario'));
select pg_temp.conferir('o estagiário não lê nota', pg_temp.pegar('estagiario nota') like 'Só o responsável%', pg_temp.pegar('estagiario nota'));
select pg_temp.conferir('o empreiteiro dita', pg_temp.pegar('empreiteiro diario') = 'passou', pg_temp.pegar('empreiteiro diario'));
select pg_temp.conferir('o empreiteiro não lê nota', pg_temp.pegar('empreiteiro nota') like 'Só o responsável%', pg_temp.pegar('empreiteiro nota'));
select pg_temp.conferir('o cliente não dita', pg_temp.pegar('cliente diario') like 'Só quem toca%', pg_temp.pegar('cliente diario'));
select pg_temp.conferir('o cliente não lê nota', pg_temp.pegar('cliente nota') like 'Só o responsável%', pg_temp.pegar('cliente nota'));
select pg_temp.conferir('quem é de fora não dita', pg_temp.pegar('fora diario') like 'Só quem toca%', pg_temp.pegar('fora diario'));
select pg_temp.conferir('quem é de fora não lê nota', pg_temp.pegar('fora nota') like 'Só o responsável%', pg_temp.pegar('fora nota'));
select pg_temp.conferir('pedido recusado não gasta o limite', pg_temp.usos('cliente') = 0 and pg_temp.usos('fora') = 0 and pg_temp.usos('estagiario') = 1, pg_temp.usos('estagiario')::text);

-- Sem login e leitura direta
select pg_temp.como('dono');
select set_config('request.jwt.claims', '{"role": "authenticated"}', true);
select pg_temp.tentar('sem login', $$select public.registrar_uso_ia('00000000-0000-0000-0000-0000000b0001', 'diario')$$);
select pg_temp.como('dono');
select pg_temp.guardar('dono le a tabela', (select count(*)::text from public.leituras_lista));
select pg_temp.tentar('grava direto', $$insert into public.leituras_lista (user_id) values ('00000000-0000-0000-0000-00000000a001')$$);
select pg_temp.admin();
select pg_temp.conferir('sem login é recusado', pg_temp.pegar('sem login') like 'Entre na sua conta%', pg_temp.pegar('sem login'));
select pg_temp.conferir('ninguém lê os usos direto', pg_temp.pegar('dono le a tabela') = '0', pg_temp.pegar('dono le a tabela'));
select pg_temp.conferir('ninguém grava direto', pg_temp.pegar('grava direto') <> 'passou', pg_temp.pegar('grava direto'));
select pg_temp.conferir('visitante não executa', not has_function_privilege('anon', 'public.registrar_uso_ia(uuid, text)', 'execute'), null);
select pg_temp.conferir('quem entrou executa', has_function_privilege('authenticated', 'public.registrar_uso_ia(uuid, text)', 'execute'), null);

-- Limite de 30 em 24 horas, dividido com a leitura de lista. O dono já gastou 2.
insert into public.leituras_lista (user_id, criada_em)
select pg_temp.pegar('dono')::uuid, now() - interval '1 hour' from generate_series(1, 27);
insert into public.leituras_lista (user_id, criada_em)
select pg_temp.pegar('dono')::uuid, now() - interval '25 hours' from generate_series(1, 40);
select pg_temp.como('dono');
select pg_temp.tentar('lista divide o teto', 'select public.registrar_leitura_lista()');
select pg_temp.usar('passou do limite', pg_temp.pegar('O'), 'diario');
select pg_temp.usar('passou do limite nota', pg_temp.pegar('O'), 'nota');
select pg_temp.tentar('lista no limite', 'select public.registrar_leitura_lista()');
select pg_temp.admin();
select pg_temp.conferir('o uso de mais de 24 horas não conta', pg_temp.pegar('lista divide o teto') = 'passou', pg_temp.pegar('lista divide o teto'));
select pg_temp.conferir('a 31ª ajuda do dia é recusada', pg_temp.pegar('passou do limite') like 'Você já usou as 30 ajudas%', pg_temp.pegar('passou do limite'));
select pg_temp.conferir('o limite vale para a nota', pg_temp.pegar('passou do limite nota') like 'Você já usou as 30 ajudas%', pg_temp.pegar('passou do limite nota'));
select pg_temp.conferir('o limite vale para a lista', pg_temp.pegar('lista no limite') like 'Você já usou as 30 ajudas%', pg_temp.pegar('lista no limite'));
select pg_temp.como('mestre');
select pg_temp.usar('outro continua', pg_temp.pegar('O'), 'diario');
select pg_temp.admin();
select pg_temp.conferir('o limite é de cada pessoa', pg_temp.pegar('outro continua') = 'passou', pg_temp.pegar('outro continua'));
select pg_temp.conferir('excluir_conta apaga os usos', pg_get_functiondef('public.excluir_conta'::regproc) like '%leituras_lista%', null);

do $$
declare
  total int; certos int; falhas text;
begin
  select count(*), count(*) filter (where ok) into total, certos from r;
  select string_agg(teste || coalesce(' [' || detalhe || ']', ''), '; ' order by n) into falhas from r where not ok;
  raise exception 'RESULTADO: % de % ok; falhas: %', certos, total, coalesce(falhas, 'nenhuma');
end $$;
rollback;
