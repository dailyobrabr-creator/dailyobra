-- Testes da entrada do dono numa loja que já está no DailyObra (migração assumir_loja). Roda numa transação; o bloco final
-- levanta 'RESULTADO: ...' e o erro desfaz tudo.
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
-- Guarda em k o id devolvido, 'nulo', ou a mensagem de erro
create function pg_temp.assumir(k text, cnpj text, codigo text) returns void language plpgsql as $$
declare id uuid;
begin
  id := public.assumir_loja(cnpj, codigo);
  perform pg_temp.guardar(k, coalesce(id::text, 'nulo'));
exception when others then perform pg_temp.guardar(k, sqlerrm);
end $$;
create function pg_temp.tentar(k text, comando text) returns void language plpgsql as $$
begin
  execute comando;
  perform pg_temp.guardar(k, 'passou');
exception when others then perform pg_temp.guardar(k, sqlerrm);
end $$;
create function pg_temp.loja(k text, nome text, cnpj text) returns void language plpgsql as $$
declare id uuid;
begin
  insert into public.lojas (nome, cnpj, cidade, uf) values (nome, cnpj, 'Rondonópolis', 'MT') returning lojas.id into id;
  perform pg_temp.guardar(k, id::text);
end $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000a001', 'dono.real@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000a002', 'curioso@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000a003', 'outro@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000a004', 'ja.tem@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.loja('vitrine', 'Vitrine', '11222333000181');
select pg_temp.loja('outra', 'Outra sem dono', '11444777000161');
select pg_temp.loja('vencida', 'Vencida', '45723174000110');
select pg_temp.loja('forca', 'Tentativas', '19131243000197');
select pg_temp.loja('com dono', 'Com dono', '40688134000161');
insert into public.loja_membros (loja_id, user_id, papel) values
  (pg_temp.pegar('com dono')::uuid, '00000000-0000-0000-0000-00000000a004', 'dono');

select pg_temp.guardar('codigo', private.gerar_codigo_loja(pg_temp.pegar('vitrine')::uuid));
select pg_temp.guardar('codigo outra', private.gerar_codigo_loja(pg_temp.pegar('outra')::uuid));
select pg_temp.guardar('codigo vencida', private.gerar_codigo_loja(pg_temp.pegar('vencida')::uuid));
select pg_temp.guardar('codigo forca', private.gerar_codigo_loja(pg_temp.pegar('forca')::uuid));
update private.codigos_loja set expira_em = now() - interval '1 day' where loja_id = pg_temp.pegar('vencida')::uuid;
select pg_temp.tentar('gerar com dono', format('select private.gerar_codigo_loja(%L)', pg_temp.pegar('com dono')));
select pg_temp.conferir('código tem o formato combinado', pg_temp.pegar('codigo') ~ '^[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$', pg_temp.pegar('codigo'));
select pg_temp.conferir('código não fica guardado às claras',
  (select count(*) from private.codigos_loja c where encode(c.codigo_hash, 'escape') like '%' || replace(pg_temp.pegar('codigo'), '-', '') || '%') = 0);
select pg_temp.conferir('loja com dono não recebe código', pg_temp.pegar('gerar com dono') = 'Esta loja já tem equipe.', pg_temp.pegar('gerar com dono'));

select pg_temp.como('00000000-0000-0000-0000-00000000a002');
select pg_temp.assumir('errado', '11.222.333/0001-81', 'AAAA-BBBB-CCCC');
select pg_temp.assumir('cnpj trocado', '11.222.333/0001-81', pg_temp.pegar('codigo outra'));
select pg_temp.assumir('sem cnpj', '99999999000199', pg_temp.pegar('codigo'));
select pg_temp.assumir('vencido', '45723174000110', pg_temp.pegar('codigo vencida'));
select pg_temp.tentar('ler códigos', 'select * from private.codigos_loja');
select pg_temp.tentar('gerar como usuário', format('select private.gerar_codigo_loja(%L)', pg_temp.pegar('outra')));
select pg_temp.como('00000000-0000-0000-0000-00000000a004');
select pg_temp.assumir('já tem loja', '11222333000181', pg_temp.pegar('codigo'));
select pg_temp.admin();
select pg_temp.conferir('código errado não entra', pg_temp.pegar('errado') = 'nulo', pg_temp.pegar('errado'));
select pg_temp.conferir('código de outra loja não entra', pg_temp.pegar('cnpj trocado') = 'nulo', pg_temp.pegar('cnpj trocado'));
select pg_temp.conferir('CNPJ que não está no DailyObra não entra', pg_temp.pegar('sem cnpj') = 'nulo', pg_temp.pegar('sem cnpj'));
select pg_temp.conferir('erro conta como tentativa',
  (select tentativas from private.codigos_loja where loja_id = pg_temp.pegar('vitrine')::uuid) = 2);
select pg_temp.conferir('código vencido recusado', pg_temp.pegar('vencido') = 'Código vencido. Peça outro ao DailyObra.', pg_temp.pegar('vencido'));
select pg_temp.conferir('usuário não lê os códigos', pg_temp.pegar('ler códigos') like 'permission denied%', pg_temp.pegar('ler códigos'));
select pg_temp.conferir('usuário não gera código', pg_temp.pegar('gerar como usuário') like 'permission denied%', pg_temp.pegar('gerar como usuário'));
select pg_temp.conferir('conta que já é de uma loja não assume outra', pg_temp.pegar('já tem loja') = 'Esta conta já faz parte de uma loja.', pg_temp.pegar('já tem loja'));

-- Quem tem o código entra, escrito de qualquer jeito
select pg_temp.como('00000000-0000-0000-0000-00000000a001');
select pg_temp.assumir('certo', '11.222.333/0001-81', lower(replace(pg_temp.pegar('codigo'), '-', ' ')));
select pg_temp.como('00000000-0000-0000-0000-00000000a003');
select pg_temp.assumir('de novo', '11222333000181', pg_temp.pegar('codigo'));
select pg_temp.admin();
select pg_temp.conferir('quem tem o código vira dono',
  pg_temp.pegar('certo') = pg_temp.pegar('vitrine')
  and (select papel from public.loja_membros where loja_id = pg_temp.pegar('vitrine')::uuid and user_id = '00000000-0000-0000-0000-00000000a001') = 'dono',
  pg_temp.pegar('certo'));
select pg_temp.conferir('código fica marcado como usado',
  (select usado_em is not null and usado_por = '00000000-0000-0000-0000-00000000a001' from private.codigos_loja where loja_id = pg_temp.pegar('vitrine')::uuid));
select pg_temp.conferir('código não vale duas vezes', pg_temp.pegar('de novo') = 'Esta loja já tem dono. Peça um convite a ele.', pg_temp.pegar('de novo'));

-- Cinco erros bloqueiam, mesmo que o sexto esteja certo
select pg_temp.como('00000000-0000-0000-0000-00000000a002');
select pg_temp.assumir('e1', '19131243000197', 'ERRADO1');
select pg_temp.assumir('e2', '19131243000197', 'ERRADO2');
select pg_temp.assumir('e3', '19131243000197', 'ERRADO3');
select pg_temp.assumir('e4', '19131243000197', 'ERRADO4');
select pg_temp.assumir('e5', '19131243000197', 'ERRADO5');
select pg_temp.assumir('sexto', '19131243000197', pg_temp.pegar('codigo forca'));
select pg_temp.admin();
select pg_temp.conferir('muitas tentativas bloqueiam o código', pg_temp.pegar('sexto') = 'Código bloqueado depois de muitas tentativas. Peça outro ao DailyObra.', pg_temp.pegar('sexto'));
select pg_temp.conferir('bloqueado não dá a loja', not exists (select 1 from public.loja_membros where loja_id = pg_temp.pegar('forca')::uuid));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
