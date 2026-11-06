-- Testes do Faturamento / Caixa (migração faturamento_loja). Roda numa transação; o bloco final levanta 'RESULTADO: ...'
-- e o erro desfaz tudo.
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
-- Guarda em v a mensagem do erro, ou 'ok'
create function pg_temp.tentar(k text, comando text) returns void language plpgsql as $$
begin
  execute comando;
  perform pg_temp.guardar(k, 'ok');
exception when others then
  perform pg_temp.guardar(k, sqlerrm);
end $$;
-- Pedido da loja; guarda o id em v com a chave k
create function pg_temp.pedido(k text, loja uuid, status_pedido text, pago boolean, forma text default null, prazo_status text default null)
returns void language plpgsql as $$
declare orc uuid; prop uuid; ped uuid;
  construtor uuid := '00000000-0000-0000-0000-00000000c001';
begin
  insert into public.orcamentos (construtor_id, modo) values (construtor, 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total, valida_ate)
  values (orc, loja, construtor, 'pedido', 'aceita', 100, 100, now() + interval '7 days')
  returning id into prop;
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status, forma_pagamento, prazo, prazo_status, pagamento_confirmado_em)
  values (prop, loja, construtor, 100, status_pedido, forma, case when prazo_status is null then null else '28' end, prazo_status,
          case when pago then now() end)
  returning id into ped;
  perform pg_temp.guardar(k, ped::text);
end $$;
create function pg_temp.lancar(k text, numero text default 'V-1') returns text language sql as
  $$ select format('select public.registrar_faturamento(%L, %L)', pg_temp.pegar(k), numero) $$;
create function pg_temp.desfazer(k text) returns text language sql as
  $$ select format('select public.desfazer_faturamento(%L)', pg_temp.pegar(k)) $$;

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

select pg_temp.pedido('pago', pg_temp.pegar('A')::uuid, 'em_separacao', true, 'pix');
select pg_temp.pedido('sem pagamento', pg_temp.pegar('A')::uuid, 'confirmado', false, 'pix');
select pg_temp.pedido('prazo pendente', pg_temp.pegar('A')::uuid, 'confirmado', false, 'crediario', 'pendente');
select pg_temp.pedido('prazo recusado', pg_temp.pegar('A')::uuid, 'confirmado', false, 'crediario', 'recusado');
select pg_temp.pedido('prazo aprovado', pg_temp.pegar('A')::uuid, 'confirmado', false, 'crediario', 'aprovado');
select pg_temp.pedido('cancelado', pg_temp.pegar('A')::uuid, 'cancelado', true, 'pix');
select pg_temp.pedido('forma vazia', pg_temp.pegar('A')::uuid, 'confirmado', false);
select pg_temp.guardar('antes', (select atualizado_em::text from public.pedidos where id = pg_temp.pegar('pago')::uuid));

-- Quem pode lançar
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.tentar('vendedor', pg_temp.lancar('pago'));
select pg_temp.conferir('vendedor não lança', pg_temp.pegar('vendedor') = 'Só o dono ou o gerente da loja lançam o pedido.', pg_temp.pegar('vendedor'));
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.tentar('outra loja', pg_temp.lancar('pago'));
select pg_temp.conferir('outra loja não acha o pedido', pg_temp.pegar('outra loja') = 'Pedido não encontrado.', pg_temp.pegar('outra loja'));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.tentar('construtor', pg_temp.lancar('pago'));
select pg_temp.conferir('construtor não acha o pedido', pg_temp.pegar('construtor') = 'Pedido não encontrado.', pg_temp.pegar('construtor'));

-- O que não está pronto
select pg_temp.como('00000000-0000-0000-0000-00000000e002');
select pg_temp.tentar('r1', pg_temp.lancar('sem pagamento'));
select pg_temp.conferir('sem pagamento não lança', pg_temp.pegar('r1') = 'Confirme o pagamento ou aprove o prazo antes de lançar.', pg_temp.pegar('r1'));
select pg_temp.tentar('r2', pg_temp.lancar('prazo pendente'));
select pg_temp.conferir('prazo pendente não lança', pg_temp.pegar('r2') = 'Confirme o pagamento ou aprove o prazo antes de lançar.', pg_temp.pegar('r2'));
select pg_temp.tentar('r3', pg_temp.lancar('prazo recusado'));
select pg_temp.conferir('prazo recusado não lança', pg_temp.pegar('r3') = 'Confirme o pagamento ou aprove o prazo antes de lançar.', pg_temp.pegar('r3'));
select pg_temp.tentar('r4', pg_temp.lancar('forma vazia'));
select pg_temp.conferir('sem forma de pagamento não lança', pg_temp.pegar('r4') = 'Confirme o pagamento ou aprove o prazo antes de lançar.', pg_temp.pegar('r4'));
select pg_temp.tentar('r5', pg_temp.lancar('cancelado'));
select pg_temp.conferir('cancelado não lança', pg_temp.pegar('r5') = 'Pedido cancelado não vai para o faturamento.', pg_temp.pegar('r5'));

-- Número
select pg_temp.tentar('r6', pg_temp.lancar('pago', '   '));
select pg_temp.conferir('número vazio recusado', pg_temp.pegar('r6') = 'Informe o número da venda no Santri.', pg_temp.pegar('r6'));
select pg_temp.tentar('r7', format('select public.registrar_faturamento(%L, null)', pg_temp.pegar('pago')));
select pg_temp.conferir('número nulo recusado', pg_temp.pegar('r7') = 'Informe o número da venda no Santri.', pg_temp.pegar('r7'));
select pg_temp.tentar('r8', pg_temp.lancar('pago', repeat('9', 41)));
select pg_temp.conferir('número longo recusado', pg_temp.pegar('r8') = 'O número da venda tem no máximo 40 caracteres.', pg_temp.pegar('r8'));

-- Lançar
select pg_temp.tentar('gerente', pg_temp.lancar('pago', '  V-123  '));
select pg_temp.conferir('gerente lança pedido pago', pg_temp.pegar('gerente') = 'ok', pg_temp.pegar('gerente'));
select pg_temp.admin();
select pg_temp.conferir('grava o número sem espaços', (select numero from public.pedido_faturamento where pedido_id = pg_temp.pegar('pago')::uuid) = 'V-123');
select pg_temp.conferir('grava quem lançou', (select lancado_por from public.pedido_faturamento where pedido_id = pg_temp.pegar('pago')::uuid) = '00000000-0000-0000-0000-00000000e002');
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('duas vezes', pg_temp.lancar('pago', 'V-124'));
select pg_temp.conferir('não lança duas vezes', pg_temp.pegar('duas vezes') = 'Este pedido já foi lançado.', pg_temp.pegar('duas vezes'));
select pg_temp.tentar('dono', pg_temp.lancar('prazo aprovado', 'V-200'));
select pg_temp.conferir('dono lança crediário com prazo aprovado', pg_temp.pegar('dono') = 'ok', pg_temp.pegar('dono'));

-- Quem lê
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.conferir('vendedor lê', (select count(*) from public.pedido_faturamento) = 2);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.conferir('outra loja não lê', (select count(*) from public.pedido_faturamento) = 0);
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.conferir('construtor não lê', (select count(*) from public.pedido_faturamento) = 0);

-- Direto na tabela, nem o dono
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('apagar', 'delete from public.pedido_faturamento');
select pg_temp.conferir('dono não apaga direto', pg_temp.pegar('apagar') <> 'ok', pg_temp.pegar('apagar'));
select pg_temp.tentar('inserir', format('insert into public.pedido_faturamento (pedido_id, numero) values (%L, %L)', pg_temp.pegar('sem pagamento'), 'X'));
select pg_temp.conferir('dono não insere direto', pg_temp.pegar('inserir') <> 'ok', pg_temp.pegar('inserir'));
select pg_temp.admin();
select pg_temp.conferir('nada mudou com a tentativa direta', (select count(*) from public.pedido_faturamento) >= 2);

-- Desfazer
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.tentar('d1', pg_temp.desfazer('pago'));
select pg_temp.conferir('vendedor não desfaz', pg_temp.pegar('d1') = 'Só o dono ou o gerente da loja desfazem o lançamento.', pg_temp.pegar('d1'));
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.tentar('d2', pg_temp.desfazer('pago'));
select pg_temp.conferir('outra loja não desfaz', pg_temp.pegar('d2') = 'Pedido não encontrado.', pg_temp.pegar('d2'));
select pg_temp.como('00000000-0000-0000-0000-00000000e002');
select pg_temp.tentar('d3', pg_temp.desfazer('sem pagamento'));
select pg_temp.conferir('não desfaz o que não foi lançado', pg_temp.pegar('d3') = 'Este pedido não está lançado.', pg_temp.pegar('d3'));
select pg_temp.tentar('d4', pg_temp.desfazer('pago'));
select pg_temp.conferir('gerente desfaz', pg_temp.pegar('d4') = 'ok', pg_temp.pegar('d4'));
select pg_temp.tentar('d5', pg_temp.lancar('pago', 'V-125'));
select pg_temp.conferir('depois de desfazer lança de novo', pg_temp.pegar('d5') = 'ok', pg_temp.pegar('d5'));

-- Sem sessão
select pg_temp.admin();
select pg_temp.conferir('anônimo não executa', not has_function_privilege('anon', 'public.registrar_faturamento(uuid, text)', 'execute'));
select pg_temp.conferir('anônimo não desfaz', not has_function_privilege('anon', 'public.desfazer_faturamento(uuid)', 'execute'));
select pg_temp.conferir('anônimo não lê a tabela', not has_table_privilege('anon', 'public.pedido_faturamento', 'select'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
