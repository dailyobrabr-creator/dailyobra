-- Testes da oferta do construtor e da Mesa do Gerente (migração oferta_construtor). Roda numa transação; o bloco final levanta
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
-- Roda o comando e guarda em k 'passou' ou a mensagem de erro
create function pg_temp.tentar(k text, comando text) returns void language plpgsql as $$
begin
  execute comando;
  perform pg_temp.guardar(k, 'passou');
exception when others then perform pg_temp.guardar(k, sqlerrm);
end $$;
-- Proposta de R$ 1.050 (1.000 de itens + 50 de frete) da loja A para o construtor c001
create function pg_temp.proposta(k text, status text, modo text default 'negociacao') returns void language plpgsql as $$
declare orc uuid; prop uuid; c uuid := '00000000-0000-0000-0000-00000000c001';
begin
  insert into public.orcamentos (construtor_id, modo) values (c, modo) returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, frete, total, cashback_previsto, valida_ate)
  values (orc, pg_temp.pegar('A')::uuid, c, modo, status, 1000, 50, 1050, 10, now() + interval '2 days') returning id into prop;
  insert into public.proposta_itens (proposta_id, item_id, nome, unidade, tier, quantidade, preco_anunciado)
  values (prop, (select id from public.catalogo_itens order by id offset 0 limit 1), 'Produto A', 'un', 1, 10, 50),
         (prop, (select id from public.catalogo_itens order by id offset 1 limit 1), 'Produto B', 'un', 1, 5, 100);
  perform pg_temp.guardar(k, prop::text);
end $$;
create function pg_temp.p(k text) returns public.propostas language sql as $$
  select * from public.propostas where id = pg_temp.pegar(k)::uuid $$;
create function pg_temp.oferta(k text, valor numeric, mensagem text default 'null') returns text language sql as $$
  select format('select public.fazer_oferta(%L, %s, %s)', pg_temp.pegar(k), valor, mensagem) $$;
create function pg_temp.resposta(k text, aprovar boolean, motivo text default 'null') returns text language sql as $$
  select format('select public.responder_oferta(%L, %s, %s)', pg_temp.pegar(k), aprovar, motivo) $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e002', 'gerente.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'c2@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor'),
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e002', 'gerente');

select pg_temp.proposta('p1', 'enviada');
select pg_temp.proposta('p2', 'contraproposta');
update public.proposta_itens set preco_ofertado = 40 where proposta_id = pg_temp.pegar('p2')::uuid and nome = 'Produto A';
update public.propostas set total = 950 where id = pg_temp.pegar('p2')::uuid;
select pg_temp.proposta('direto', 'enviada', 'pedido');
select pg_temp.proposta('cancelada', 'cancelada');
select pg_temp.proposta('saldo', 'enviada');
update public.propostas set saldo_aplicado = 900 where id = pg_temp.pegar('saldo')::uuid;
select private.mover('00000000-0000-0000-0000-00000000c001', 'disponivel', 'reservado', 900, 'saldo_reservado', 'Teste',
                     pg_temp.pegar('A')::uuid, null, pg_temp.pegar('saldo')::uuid);

-- Construtor oferece
select pg_temp.como('00000000-0000-0000-0000-00000000c002');
select pg_temp.tentar('outro', pg_temp.oferta('p1', 840));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('alta', pg_temp.oferta('p1', 1050));
select pg_temp.tentar('frete', pg_temp.oferta('p1', 50));
select pg_temp.tentar('direto', pg_temp.oferta('direto', 840));
select pg_temp.tentar('cancelada', pg_temp.oferta('cancelada', 840));
select pg_temp.tentar('feita', pg_temp.oferta('p1', 840, '''  Fecho hoje  '''));
select pg_temp.tentar('repetida', pg_temp.oferta('p1', 830));
select pg_temp.tentar('direta na tabela', format('update public.propostas set oferta_status = ''aprovada'', total = 1 where id = %L', pg_temp.pegar('p1')));
select pg_temp.admin();
select pg_temp.conferir('outro construtor não oferece', pg_temp.pegar('outro') = 'Proposta não encontrada.', pg_temp.pegar('outro'));
select pg_temp.conferir('oferta precisa ser menor que o total', pg_temp.pegar('alta') like 'A oferta precisa ser menor que o total de R$%', pg_temp.pegar('alta'));
select pg_temp.conferir('oferta precisa cobrir o frete', pg_temp.pegar('frete') like 'A oferta precisa ser maior que o frete de R$%', pg_temp.pegar('frete'));
select pg_temp.conferir('pedido direto não aceita oferta', pg_temp.pegar('direto') = 'Pedido direto não aceita oferta.', pg_temp.pegar('direto'));
select pg_temp.conferir('proposta fechada não aceita oferta', pg_temp.pegar('cancelada') = 'Esta proposta não aceita mais oferta.', pg_temp.pegar('cancelada'));
select pg_temp.conferir('oferta guardada sem mexer na proposta',
  pg_temp.pegar('feita') = 'passou' and (pg_temp.p('p1')).status = 'enviada' and (pg_temp.p('p1')).total = 1050
  and (pg_temp.p('p1')).oferta_valor = 840 and (pg_temp.p('p1')).oferta_status = 'pendente'
  and (pg_temp.p('p1')).oferta_mensagem = 'Fecho hoje' and (pg_temp.p('p1')).oferta_em is not null,
  pg_temp.pegar('feita'));
select pg_temp.conferir('só uma oferta por vez', pg_temp.pegar('repetida') = 'Você já fez uma oferta. Aguarde a resposta da loja.', pg_temp.pegar('repetida'));
select pg_temp.conferir('tabela não aceita escrita direta', (pg_temp.p('p1')).oferta_status = 'pendente' and (pg_temp.p('p1')).total = 1050, pg_temp.pegar('direta na tabela'));

-- Quem responde
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.tentar('vendedor', pg_temp.resposta('p1', true));
select pg_temp.tentar('vendedor na tela normal', format('select public.responder_proposta(%L, ''aceitar'', null, null, null, null, null)', pg_temp.pegar('p1')));
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.tentar('dono b', pg_temp.resposta('p1', true));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('dono na tela normal', format('select public.responder_proposta(%L, ''aceitar'', null, null, null, null, null)', pg_temp.pegar('p1')));
select pg_temp.tentar('sem motivo', pg_temp.resposta('p1', false, ''' a '''));
select pg_temp.tentar('recusa', pg_temp.resposta('p1', false, '''Abaixo do que podemos'''));
select pg_temp.admin();
select pg_temp.conferir('vendedor não responde à oferta', pg_temp.pegar('vendedor') = 'Só o dono ou o gerente responde à oferta.', pg_temp.pegar('vendedor'));
select pg_temp.conferir('outra loja não responde', pg_temp.pegar('dono b') = 'Esta proposta não é da sua loja.', pg_temp.pegar('dono b'));
select pg_temp.conferir('tela normal fica bloqueada para o vendedor', pg_temp.pegar('vendedor na tela normal') = 'Este cliente fez uma oferta: responda na Mesa do Gerente.', pg_temp.pegar('vendedor na tela normal'));
select pg_temp.conferir('tela normal fica bloqueada para o dono', pg_temp.pegar('dono na tela normal') = 'Este cliente fez uma oferta: responda na Mesa do Gerente.', pg_temp.pegar('dono na tela normal'));
select pg_temp.conferir('recusar pede motivo', pg_temp.pegar('sem motivo') = 'Informe o motivo da recusa.', pg_temp.pegar('sem motivo'));
select pg_temp.conferir('recusa mantém a proposta como estava',
  pg_temp.pegar('recusa') = 'passou' and (pg_temp.p('p1')).oferta_status = 'recusada' and (pg_temp.p('p1')).oferta_motivo = 'Abaixo do que podemos'
  and (pg_temp.p('p1')).status = 'enviada' and (pg_temp.p('p1')).total = 1050
  and not exists (select 1 from public.pedidos where proposta_id = pg_temp.pegar('p1')::uuid),
  pg_temp.pegar('recusa'));

-- Nova oferta e aprovação
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('nova', pg_temp.oferta('p1', 840));
select pg_temp.admin();
select pg_temp.conferir('depois da recusa pode oferecer de novo',
  pg_temp.pegar('nova') = 'passou' and (pg_temp.p('p1')).oferta_status = 'pendente' and (pg_temp.p('p1')).oferta_motivo is null, pg_temp.pegar('nova'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('aprova', pg_temp.resposta('p1', true));
select pg_temp.tentar('de novo', pg_temp.resposta('p1', true));
select pg_temp.admin();
select pg_temp.conferir('aprovar fecha pelo valor da oferta',
  pg_temp.pegar('aprova') = 'passou' and (pg_temp.p('p1')).status = 'aceita' and (pg_temp.p('p1')).oferta_status = 'aprovada'
  and (pg_temp.p('p1')).total = 840 and (pg_temp.p('p1')).desconto = 210,
  pg_temp.pegar('aprova'));
select pg_temp.conferir('aprovar cria o pedido',
  (select count(*) = 1 and min(total) = 840 and min(status) = 'confirmado' from public.pedidos where proposta_id = pg_temp.pegar('p1')::uuid));
select pg_temp.conferir('cashback acompanha o desconto',
  (pg_temp.p('p1')).cashback_previsto = round(1000 * private.percentual_tier(1::smallint) * 790 / 1000, 2),
  (pg_temp.p('p1')).cashback_previsto::text);
select pg_temp.conferir('oferta respondida não volta', pg_temp.pegar('de novo') = 'Esta oferta não está mais aguardando resposta.', pg_temp.pegar('de novo'));
select pg_temp.conferir('histórico da oferta',
  (select count(*) from public.proposta_eventos where proposta_id = pg_temp.pegar('p1')::uuid and valores ? 'oferta') = 4
  and exists (select 1 from public.proposta_eventos where proposta_id = pg_temp.pegar('p1')::uuid and justificativa = 'Abaixo do que podemos'));

-- Sobre contraproposta, pelo gerente
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('sobre contraproposta', pg_temp.oferta('p2', 800));
select pg_temp.como('00000000-0000-0000-0000-00000000e002');
select pg_temp.tentar('gerente', pg_temp.resposta('p2', true));
select pg_temp.admin();
select pg_temp.conferir('oferta sobre a contraproposta usa os preços dela',
  pg_temp.pegar('sobre contraproposta') = 'passou' and pg_temp.pegar('gerente') = 'passou'
  and (pg_temp.p('p2')).status = 'aceita' and (pg_temp.p('p2')).total = 800 and (pg_temp.p('p2')).desconto = 150,
  pg_temp.pegar('gerente'));

-- Saldo reservado maior que a oferta
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('oferta saldo', pg_temp.oferta('saldo', 600));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('aprova saldo', pg_temp.resposta('saldo', true));
select pg_temp.admin();
select pg_temp.conferir('saldo reservado acima da oferta volta para a carteira',
  pg_temp.pegar('aprova saldo') = 'passou' and (pg_temp.p('saldo')).saldo_aplicado = 600
  and (select total from public.pedidos where proposta_id = pg_temp.pegar('saldo')::uuid) = 0
  and (select coalesce(sum(valor), 0) from public.carteira_lancamentos where proposta_id = pg_temp.pegar('saldo')::uuid and conta = 'disponivel') = -600
  and (select coalesce(sum(valor), 0) from public.carteira_lancamentos where proposta_id = pg_temp.pegar('saldo')::uuid and conta = 'reservado') = 0,
  pg_temp.pegar('aprova saldo'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
