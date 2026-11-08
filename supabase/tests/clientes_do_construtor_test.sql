-- Clientes do construtor e pedido no nome do cliente. Rodar inteiro: tudo fica numa transação desfeita no fim.
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
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'c2@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);

-- Cadastro
create function pg_temp.cadastrar(k text, nome text, zap text, doc text) returns void language sql as $$
  select pg_temp.tentar(k, format('insert into public.construtor_clientes (nome, whatsapp, documento) values (%L, %L, %L)', nome, zap, doc)) $$;
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.cadastrar('k1', 'Maria Lima', '66999990000', '52998224725');
select pg_temp.conferir('o construtor cadastra o cliente', pg_temp.pegar('k1') = 'ok', pg_temp.pegar('k1'));
select pg_temp.guardar('maria', (select id::text from public.construtor_clientes where documento = '52998224725'));
select pg_temp.conferir('o cliente é do construtor', (select construtor_id = '00000000-0000-0000-0000-00000000c001' from public.construtor_clientes));
select pg_temp.cadastrar('k2', 'Outra', '66999990000', '11111111111');
select pg_temp.conferir('documento inválido recusado', pg_temp.pegar('k2') <> 'ok', pg_temp.pegar('k2'));
select pg_temp.cadastrar('k3', 'Outra', '6699', '11222333000181');
select pg_temp.conferir('WhatsApp inválido recusado', pg_temp.pegar('k3') <> 'ok', pg_temp.pegar('k3'));
select pg_temp.cadastrar('k4', 'Maria de novo', '66999990000', '52998224725');
select pg_temp.conferir('mesmo documento não repete', pg_temp.pegar('k4') <> 'ok', pg_temp.pegar('k4'));
select pg_temp.cadastrar('k5', 'M', '66999990000', '11222333000181');
select pg_temp.conferir('nome curto recusado', pg_temp.pegar('k5') <> 'ok', pg_temp.pegar('k5'));
select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.conferir('outro construtor não vê', (select count(*) from public.construtor_clientes) = 0);
select pg_temp.cadastrar('k6', 'Maria Lima', '66999990000', '52998224725');
select pg_temp.conferir('outro construtor cadastra o mesmo cliente para si', pg_temp.pegar('k6') = 'ok', pg_temp.pegar('k6'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.conferir('a loja não lê os clientes', (select count(*) from public.construtor_clientes) = 0);
select pg_temp.conferir('anônimo não lê', not has_table_privilege('anon', 'public.construtor_clientes', 'select'));

-- Quem paga o orçamento
select pg_temp.admin();
create function pg_temp.proposta(construtor uuid) returns uuid language plpgsql as $$
declare orc uuid; prop uuid;
begin
  insert into public.orcamentos (construtor_id, modo) values (construtor, 'negociacao') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total, valida_ate)
  values (orc, pg_temp.pegar('A')::uuid, construtor, 'negociacao', 'enviada', 100, 100, now() + interval '2 days') returning id into prop;
  return prop;
end $$;
create function pg_temp.pedido_de(prop uuid) returns uuid language plpgsql as $$
declare ped uuid;
begin
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status)
  select p.id, p.loja_id, p.construtor_id, p.total, 'confirmado' from public.propostas p where p.id = prop
  returning id into ped;
  return ped;
end $$;
create function pg_temp.orcamento_de(prop text) returns text language sql as $$
  select orcamento_id::text from public.propostas where id = prop::uuid $$;
select pg_temp.guardar('p1', pg_temp.proposta('00000000-0000-0000-0000-00000000c001')::text);
select pg_temp.guardar('p2', pg_temp.proposta('00000000-0000-0000-0000-00000000c001')::text);
update public.propostas set forma_escolhida = 'boleto', parcelas = 3 where id = pg_temp.pegar('p1')::uuid;

select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.tentar('q1', format('select public.definir_pagador_do_orcamento(%L, null)', pg_temp.orcamento_de(pg_temp.pegar('p1'))));
select pg_temp.conferir('outro construtor não escolhe', pg_temp.pegar('q1') = 'Orçamento não encontrado.', pg_temp.pegar('q1'));
select pg_temp.guardar('dele', (select id::text from public.construtor_clientes));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('q2', format('select public.definir_pagador_do_orcamento(%L, %L)', pg_temp.orcamento_de(pg_temp.pegar('p1')), pg_temp.pegar('dele')));
select pg_temp.conferir('cliente de outro construtor é recusado', pg_temp.pegar('q2') = 'Cliente não encontrado.', pg_temp.pegar('q2'));
select pg_temp.tentar('q3', format('select public.definir_pagador_do_orcamento(%L, %L)', pg_temp.orcamento_de(pg_temp.pegar('p1')), pg_temp.pegar('maria')));
select pg_temp.conferir('o construtor escolhe o cliente', pg_temp.pegar('q3') = 'ok'
  and (select cliente_id::text from public.propostas where id = pg_temp.pegar('p1')::uuid) = pg_temp.pegar('maria'), pg_temp.pegar('q3'));
select pg_temp.conferir('anônimo não escolhe', not has_function_privilege('anon', 'public.definir_pagador_do_orcamento(uuid, uuid)', 'execute'));

-- O pedido nasce no nome do cliente
select pg_temp.admin();
select pg_temp.guardar('ped1', pg_temp.pedido_de(pg_temp.pegar('p1')::uuid)::text);
select pg_temp.conferir('pedido no nome do cliente',
  (select pagador = 'cliente' and pagador_nome = 'Maria Lima' and pagador_whatsapp = '66999990000' and documento_informado_em is not null
     from public.pedidos where id = pg_temp.pegar('ped1')::uuid));
select pg_temp.conferir('link pronto para enviar', (select link_codigo ~ '^[A-Za-z0-9_-]{22}$' from public.pedidos where id = pg_temp.pegar('ped1')::uuid));
select pg_temp.conferir('o cliente paga por PIX, sem parcelas',
  (select forma_pagamento = 'pix' and parcelas is null from public.pedidos where id = pg_temp.pegar('ped1')::uuid));
select pg_temp.conferir('o documento vai para a nota',
  (select documento from public.pedido_documentos where pedido_id = pg_temp.pegar('ped1')::uuid) = '52998224725');
select pg_temp.conferir('a página do link já mostra a nota no nome dele',
  public.pedido_do_link((select link_codigo from public.pedidos where id = pg_temp.pegar('ped1')::uuid)) ->> 'documento_mascarado' is not null);
select pg_temp.guardar('ped2', pg_temp.pedido_de(pg_temp.pegar('p2')::uuid)::text);
select pg_temp.conferir('sem cliente o construtor escolhe depois',
  (select pagador is null and link_codigo is null from public.pedidos where id = pg_temp.pegar('ped2')::uuid));

-- Excluir a conta apaga os clientes
select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.tentar('x1', $x$select public.excluir_conta('EXCLUIR')$x$);
select pg_temp.admin();
select pg_temp.conferir('excluir a conta apaga os clientes', pg_temp.pegar('x1') = 'ok'
  and not exists (select 1 from public.construtor_clientes where construtor_id = '00000000-0000-0000-0000-00000000c002'), pg_temp.pegar('x1'));

do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
