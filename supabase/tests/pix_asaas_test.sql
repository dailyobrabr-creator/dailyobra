-- Regras do PIX automático pelo Asaas. Rodar inteiro: tudo fica numa transação desfeita no fim.
begin;

create temp table r (n serial, teste text, ok boolean, detalhe text) on commit drop;
create temp table v (chave text primary key, valor text) on commit drop;
grant all on r, v to authenticated, anon, service_role;
grant usage on sequence r_n_seq to authenticated, anon, service_role;

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
create function pg_temp.servidor() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  execute 'set local role service_role';
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
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c001', 'c1@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'c2@teste.dailyobra', 'authenticated', 'authenticated');

select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor');

create function pg_temp.pedido(loja uuid, total numeric, status_pedido text default 'confirmado') returns uuid language plpgsql as $$
declare orc uuid; prop uuid; ped uuid; construtor uuid := '00000000-0000-0000-0000-00000000c001';
begin
  insert into public.orcamentos (construtor_id, modo) values (construtor, 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total, valida_ate)
  values (orc, loja, construtor, 'pedido', 'aceita', total, total, now() + interval '7 days') returning id into prop;
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status, pagador, pagador_nome, documento_informado_em)
  values (prop, loja, construtor, total, status_pedido, 'proprio', 'Marcos', now()) returning id into ped;
  insert into public.pedido_documentos (pedido_id, documento) values (ped, '52998224725');
  return ped;
end $$;
select pg_temp.guardar('p1', pg_temp.pedido(pg_temp.pegar('A')::uuid, 100)::text);
select pg_temp.guardar('semcarteira', pg_temp.pedido(pg_temp.pegar('B')::uuid, 100)::text);

-- Carteira da loja
create function pg_temp.carteira(k text, loja text, valor text) returns void language sql as $$
  select pg_temp.tentar(k, format('insert into public.loja_asaas (loja_id, carteira) values (%L, %L)', pg_temp.pegar(loja), valor)) $$;
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.carteira('c1', 'A', '7bafd95a-e783-4a62-9be1-23999af742c6');
select pg_temp.conferir('vendedor não liga', pg_temp.pegar('c1') <> 'ok', pg_temp.pegar('c1'));
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.carteira('c2', 'A', '7bafd95a-e783-4a62-9be1-23999af742c6');
select pg_temp.conferir('outra loja não liga', pg_temp.pegar('c2') <> 'ok', pg_temp.pegar('c2'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.carteira('c3', 'A', 'nao-e-carteira');
select pg_temp.conferir('recusa carteira inválida', pg_temp.pegar('c3') <> 'ok', pg_temp.pegar('c3'));
select pg_temp.carteira('c4', 'A', '7bafd95a-e783-4a62-9be1-23999af742c6');
select pg_temp.conferir('dono liga', pg_temp.pegar('c4') = 'ok', pg_temp.pegar('c4'));
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.conferir('equipe vê a carteira', (select count(*) from public.loja_asaas) = 1);
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.conferir('construtor não vê a carteira', (select count(*) from public.loja_asaas) = 0);
select pg_temp.tentar('s1', 'select count(*) from public.pedido_cobrancas');
select pg_temp.conferir('construtor não lê cobranças', pg_temp.pegar('s1') <> 'ok', pg_temp.pegar('s1'));

-- Quem chama as funções
select pg_temp.conferir('app não pede os dados', not has_function_privilege('authenticated', 'public.cobranca_para_pix(uuid, uuid, text)', 'execute'));
select pg_temp.conferir('anônimo não pede os dados', not has_function_privilege('anon', 'public.cobranca_para_pix(uuid, uuid, text)', 'execute'));
select pg_temp.conferir('app não confirma', not has_function_privilege('authenticated', 'public.confirmar_pix_asaas(text, numeric)', 'execute'));
select pg_temp.conferir('anônimo não confirma', not has_function_privilege('anon', 'public.confirmar_pix_asaas(text, numeric)', 'execute'));
select pg_temp.conferir('app não registra', not has_function_privilege('authenticated', 'public.registrar_cobranca_pix(uuid, text, numeric, text, timestamptz)', 'execute'));
select pg_temp.conferir('app não remove', not has_function_privilege('authenticated', 'public.remover_cobranca_pix(text)', 'execute'));
select pg_temp.conferir('anônimo não lê a carteira', not has_table_privilege('anon', 'public.loja_asaas', 'select'));

-- Dados para cobrar
select pg_temp.servidor();
select pg_temp.tentar('d1', format('select public.cobranca_para_pix(%L, %L, null)', pg_temp.pegar('p1'), '00000000-0000-0000-0000-00000000c002'));
select pg_temp.conferir('outro construtor não cobra', pg_temp.pegar('d1') = 'Pedido não encontrado.', pg_temp.pegar('d1'));
select pg_temp.tentar('d2', $x$select public.cobranca_para_pix(null, null, 'nao-existe')$x$);
select pg_temp.conferir('link inválido não cobra', pg_temp.pegar('d2') = 'Pedido não encontrado.', pg_temp.pegar('d2'));
select pg_temp.conferir('loja sem carteira fica no pix da chave',
  public.cobranca_para_pix(pg_temp.pegar('semcarteira')::uuid, '00000000-0000-0000-0000-00000000c001', null) is null);
select pg_temp.guardar('dados', public.cobranca_para_pix(pg_temp.pegar('p1')::uuid, '00000000-0000-0000-0000-00000000c001', null)::text);
select pg_temp.conferir('traz valor e carteira', (pg_temp.pegar('dados')::jsonb ->> 'valor')::numeric = 100
  and pg_temp.pegar('dados')::jsonb ->> 'carteira' = '7bafd95a-e783-4a62-9be1-23999af742c6', pg_temp.pegar('dados'));
select pg_temp.conferir('traz o documento', pg_temp.pegar('dados')::jsonb ->> 'documento' = '52998224725');
select pg_temp.conferir('sem cobrança aberta', pg_temp.pegar('dados')::jsonb -> 'aberta' = 'null'::jsonb, pg_temp.pegar('dados'));
select pg_temp.admin();
update public.pedidos set link_codigo = 'CODIGOdeTESTEdoLINK_01' where id = pg_temp.pegar('p1')::uuid;
select pg_temp.servidor();
select pg_temp.conferir('o link acha o pedido', public.cobranca_para_pix(null, null, 'CODIGOdeTESTEdoLINK_01') ->> 'pedido' = pg_temp.pegar('p1'));

-- Registrar
select pg_temp.conferir('registra a cobrança', public.registrar_cobranca_pix(pg_temp.pegar('p1')::uuid, 'pay_1', 100, 'pix-1', now() + interval '1 day'));
select pg_temp.conferir('segunda aberta perde', not public.registrar_cobranca_pix(pg_temp.pegar('p1')::uuid, 'pay_2', 100, 'pix-2', null));
select pg_temp.conferir('a aberta volta nos dados',
  public.cobranca_para_pix(pg_temp.pegar('p1')::uuid, '00000000-0000-0000-0000-00000000c001', null) -> 'aberta' ->> 'codigo' = 'pix-1');
select public.remover_cobranca_pix('pay_1');
select pg_temp.conferir('removida sai dos dados',
  public.cobranca_para_pix(pg_temp.pegar('p1')::uuid, '00000000-0000-0000-0000-00000000c001', null) -> 'aberta' = 'null'::jsonb);
select pg_temp.conferir('depois de remover registra outra', public.registrar_cobranca_pix(pg_temp.pegar('p1')::uuid, 'pay_3', 100, 'pix-3', null));

-- Confirmar
select pg_temp.conferir('aviso desconhecido não faz nada', public.confirmar_pix_asaas('pay_x', 100) = 'desconhecida');
select pg_temp.conferir('valor menor fica para a loja', public.confirmar_pix_asaas('pay_3', 99.99) = 'valor_menor');
select pg_temp.admin();
select pg_temp.conferir('valor menor não confirma', (select pagamento_confirmado_em from public.pedidos where id = pg_temp.pegar('p1')::uuid) is null);
select pg_temp.guardar('p2', pg_temp.pedido(pg_temp.pegar('A')::uuid, 200)::text);
update public.pedidos set forma_pagamento = 'crediario', prazo = '28', prazo_status = 'pendente' where id = pg_temp.pegar('p2')::uuid;
select pg_temp.servidor();
select public.registrar_cobranca_pix(pg_temp.pegar('p2')::uuid, 'pay_4', 200, 'pix-4', null);
select pg_temp.conferir('pix recebido confirma', public.confirmar_pix_asaas('pay_4', 200) = 'confirmado');
select pg_temp.conferir('aviso repetido não muda nada', public.confirmar_pix_asaas('pay_4', 200) = 'repetido');
select pg_temp.admin();
select pg_temp.conferir('pedido fica pago', (select pagamento_confirmado_em from public.pedidos where id = pg_temp.pegar('p2')::uuid) is not null);
select pg_temp.conferir('a forma vira pix', (select forma_pagamento = 'pix' and prazo is null and prazo_status is null from public.pedidos where id = pg_temp.pegar('p2')::uuid));
select pg_temp.conferir('fica um evento só', (select count(*) from public.pedido_eventos where pedido_id = pg_temp.pegar('p2')::uuid and para = 'pagamento_confirmado') = 1);
select pg_temp.conferir('evento sem autor', (select autor is null from public.pedido_eventos where pedido_id = pg_temp.pegar('p2')::uuid and para = 'pagamento_confirmado'));
select pg_temp.conferir('cobrança fica paga', (select situacao = 'paga' and paga_em is not null from public.pedido_cobrancas where asaas_id = 'pay_4'));

select pg_temp.guardar('p3', pg_temp.pedido(pg_temp.pegar('A')::uuid, 300)::text);
update public.pedidos set pagamento_confirmado_em = now() where id = pg_temp.pegar('p3')::uuid;
insert into public.pedido_cobrancas (pedido_id, asaas_id, valor, codigo) values (pg_temp.pegar('p3')::uuid, 'pay_5', 300, 'pix-5');
select pg_temp.guardar('p4', pg_temp.pedido(pg_temp.pegar('A')::uuid, 400, 'cancelado')::text);
insert into public.pedido_cobrancas (pedido_id, asaas_id, valor, codigo) values (pg_temp.pegar('p4')::uuid, 'pay_6', 400, 'pix-6');
select pg_temp.guardar('p5', pg_temp.pedido(pg_temp.pegar('A')::uuid, 500)::text);
insert into public.pedido_cobrancas (pedido_id, asaas_id, valor, codigo, situacao) values (pg_temp.pegar('p5')::uuid, 'pay_7', 500, 'pix-7', 'removida');
select pg_temp.servidor();
select pg_temp.conferir('loja já confirmou à mão', public.confirmar_pix_asaas('pay_5', 300) = 'ja_confirmado');
select pg_temp.conferir('pedido cancelado não volta', public.confirmar_pix_asaas('pay_6', 400) = 'pedido_cancelado');
select pg_temp.conferir('removida paga mesmo assim confirma', public.confirmar_pix_asaas('pay_7', 500) = 'confirmado');
select pg_temp.conferir('pedido pago não cobra de novo',
  public.cobranca_para_pix(pg_temp.pegar('p3')::uuid, '00000000-0000-0000-0000-00000000c001', null) is null);
select pg_temp.conferir('pedido cancelado não cobra',
  public.cobranca_para_pix(pg_temp.pegar('p4')::uuid, '00000000-0000-0000-0000-00000000c001', null) is null);
select pg_temp.admin();
select pg_temp.conferir('cancelado segue cancelado', (select status = 'cancelado' and pagamento_confirmado_em is null from public.pedidos where id = pg_temp.pegar('p4')::uuid));

-- Pedido já entregue libera o cashback
select pg_temp.guardar('p6', pg_temp.pedido(pg_temp.pegar('A')::uuid, 600, 'entregue')::text);
select private.mover('00000000-0000-0000-0000-00000000c001', 'emissor', 'pendente', 6, 'cashback_previsto', 'Teste',
  pg_temp.pegar('A')::uuid, pg_temp.pegar('p6')::uuid, null);
insert into public.pedido_cobrancas (pedido_id, asaas_id, valor, codigo) values (pg_temp.pegar('p6')::uuid, 'pay_8', 600, 'pix-8');
select pg_temp.servidor();
select pg_temp.conferir('entregue confirma', public.confirmar_pix_asaas('pay_8', 600) = 'confirmado');
select pg_temp.admin();
select pg_temp.conferir('cashback liberado', (select coalesce(sum(valor), 0) from public.carteira_lancamentos where pedido_id = pg_temp.pegar('p6')::uuid and conta = 'disponivel') = 6);

do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
