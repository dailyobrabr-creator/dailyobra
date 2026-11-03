-- Testes do checkout (migração checkout_pagamento): saldo na hora de pagar, formas de pagamento, prazo do crediário e
-- link com documento do cliente. Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro desfaz tudo.
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
create function pg_temp.anonimo() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  execute 'set local role anon';
end $$;
create function pg_temp.admin() returns void language plpgsql as $$ begin execute 'reset role'; end $$;
-- Saldo disponível do construtor c001 e um crédito de teste na carteira dele
create function pg_temp.disponivel() returns numeric language sql as $$
  select coalesce(sum(valor), 0) from public.carteira_lancamentos
   where construtor_id = '00000000-0000-0000-0000-00000000c001' and conta = 'disponivel' $$;
create function pg_temp.dar_saldo(x numeric) returns void language sql as $$
  with t as (select gen_random_uuid() as id)
  insert into public.carteira_lancamentos (transacao_id, construtor_id, conta, valor, tipo, descricao)
  select t.id, '00000000-0000-0000-0000-00000000c001', c.conta, c.valor, 'cashback_liberado', 'saldo de teste'
    from t, (values ('emissor', -x), ('disponivel', x)) as c(conta, valor) $$;
create function pg_temp.total(k text) returns numeric language sql as $$ select total from public.pedidos where id = pg_temp.pegar(k)::uuid $$;
-- Pedido direto de cimento na loja A (q sacos a R$ 40), aceito pela loja; guarda o id do pedido em k
create function pg_temp.pedido(k text, q int) returns void language plpgsql as $$
declare prop uuid;
begin
  perform pg_temp.como('00000000-0000-0000-0000-00000000c001');
  prop := (public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('A'),
           'quantidade', q, 'preco_visto', 40.00)), 'pedido', null, false, null)->'propostas'->0->>'id')::uuid;
  perform pg_temp.como('00000000-0000-0000-0000-00000000d001');
  perform public.responder_proposta(prop, 'aceitar', null, null, null, null, null);
  perform pg_temp.admin();
  perform pg_temp.guardar(k, (select id::text from public.pedidos where proposta_id = prop));
end $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000c001', 'construtor@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'outro@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated');
insert into public.profiles (id, nome) values ('00000000-0000-0000-0000-00000000c001', 'Marcos Silva')
  on conflict (id) do update set nome = excluded.nome;

-- Loja A (com chave PIX e vendedor) e loja B
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
insert into public.loja_pix (loja_id, chave) values (pg_temp.pegar('A')::uuid, '+5566999990000');
insert into public.ofertas (loja_id, item_id, preco) values (pg_temp.pegar('A')::uuid, 'cimento-cp2-50kg', 40.00);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor');

select pg_temp.pedido('pA', 10);   -- 400
select pg_temp.pedido('pA2', 2);   -- 80
select pg_temp.pedido('pA3', 3);   -- 120
select pg_temp.pedido('pA5', 6);   -- 240
select pg_temp.pedido('pA6', 7);   -- 280
select pg_temp.pedido('pA7', 8);   -- 320
select pg_temp.pedido('pA8', 9);   -- 360
select pg_temp.pedido('pA9', 11);  -- 440
select pg_temp.dar_saldo(30);

-- 1-3. Liga, liga de novo e desliga o saldo
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.pagar_eu_mesmo(pg_temp.pegar('pA')::uuid, '529.982.247-25');
select pg_temp.guardar('liga1', public.usar_saldo(pg_temp.pegar('pA')::uuid, true)::text);
select pg_temp.guardar('pix_com_saldo', public.pix_do_pedido(pg_temp.pegar('pA')::uuid));
select pg_temp.admin();
select pg_temp.conferir('saldo liga e baixa o total',
  pg_temp.pegar('liga1')::numeric = 30 and pg_temp.total('pA') = 370 and pg_temp.disponivel() = 0
  and (select saldo_aplicado from public.propostas pr join public.pedidos pe on pe.proposta_id = pr.id where pe.id = pg_temp.pegar('pA')::uuid) = 30
  and pg_temp.pegar('pix_com_saldo') like '%5406370.00%',
  concat_ws(' / ', pg_temp.pegar('liga1'), pg_temp.total('pA'), pg_temp.disponivel(), pg_temp.pegar('pix_com_saldo')));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('liga2', public.usar_saldo(pg_temp.pegar('pA')::uuid, true)::text);
select pg_temp.admin();
select pg_temp.conferir('ligar de novo não aplica duas vezes', pg_temp.pegar('liga2')::numeric = 30 and pg_temp.total('pA') = 370,
  concat_ws(' / ', pg_temp.pegar('liga2'), pg_temp.total('pA')));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('desliga', public.usar_saldo(pg_temp.pegar('pA')::uuid, false)::text);
select pg_temp.admin();
select pg_temp.conferir('desligar devolve o saldo',
  pg_temp.pegar('desliga')::numeric = 0 and pg_temp.total('pA') = 400 and pg_temp.disponivel() = 30
  and (select saldo_aplicado from public.propostas pr join public.pedidos pe on pe.proposta_id = pr.id where pe.id = pg_temp.pegar('pA')::uuid) = 0,
  concat_ws(' / ', pg_temp.pegar('desliga'), pg_temp.total('pA'), pg_temp.disponivel()));

-- 4. Saldo maior que o pedido
select pg_temp.dar_saldo(970);
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.pagar_eu_mesmo(pg_temp.pegar('pA2')::uuid, '529.982.247-25');
select public.usar_saldo(pg_temp.pegar('pA2')::uuid, true);
select pg_temp.guardar('pix_zero', coalesce(public.pix_do_pedido(pg_temp.pegar('pA2')::uuid), 'nulo'));
select pg_temp.admin();
select pg_temp.conferir('saldo maior que o pedido zera o total sem PIX',
  pg_temp.total('pA2') = 0 and pg_temp.pegar('pix_zero') = 'nulo' and pg_temp.disponivel() = 920,
  concat_ws(' / ', pg_temp.total('pA2'), pg_temp.pegar('pix_zero'), pg_temp.disponivel()));

-- 5. Quem pode e quando
select pg_temp.como('00000000-0000-0000-0000-00000000c002');
do $$ begin perform public.usar_saldo(pg_temp.pegar('pA')::uuid, true); perform pg_temp.guardar('e_outro', 'passou');
exception when others then perform pg_temp.guardar('e_outro', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ begin perform public.usar_saldo(pg_temp.pegar('pA9')::uuid, true); perform pg_temp.guardar('e_sem_pagador', 'passou');
exception when others then perform pg_temp.guardar('e_sem_pagador', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.confirmar_pagamento(pg_temp.pegar('pA2')::uuid);
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ begin perform public.usar_saldo(pg_temp.pegar('pA2')::uuid, false); perform pg_temp.guardar('e_pago', 'passou');
exception when others then perform pg_temp.guardar('e_pago', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('saldo só do dono, só no Eu pago e antes do pagamento',
  pg_temp.pegar('e_outro') = 'Pedido não encontrado.' and pg_temp.pegar('e_sem_pagador') = 'Escolha "Eu pago" para usar o saldo.'
  and pg_temp.pegar('e_pago') = 'Este pedido já foi pago.',
  concat_ws(' / ', pg_temp.pegar('e_outro'), pg_temp.pegar('e_sem_pagador'), pg_temp.pegar('e_pago')));

-- 6. O link para o cliente devolve o saldo
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.usar_saldo(pg_temp.pegar('pA')::uuid, true);
select public.criar_link_pagamento(pg_temp.pegar('pA')::uuid, 'Ana', '66999990000');
select pg_temp.admin();
select pg_temp.conferir('link devolve o saldo',
  pg_temp.total('pA') = 400 and pg_temp.disponivel() = 920 and private.saldo_no_pedido(pg_temp.pegar('pA')::uuid) = 0
  and (select forma_pagamento = 'pix' from public.pedidos where id = pg_temp.pegar('pA')::uuid),
  concat_ws(' / ', pg_temp.total('pA'), pg_temp.disponivel()));

-- 7. Cancelar devolve o saldo usado no checkout
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.pagar_eu_mesmo(pg_temp.pegar('pA3')::uuid, '529.982.247-25');
select public.usar_saldo(pg_temp.pegar('pA3')::uuid, true);
select public.atualizar_pedido(pg_temp.pegar('pA3')::uuid, 'cancelado');
select pg_temp.admin();
select pg_temp.conferir('cancelar devolve o saldo do checkout',
  pg_temp.disponivel() = 920 and private.saldo_no_pedido(pg_temp.pegar('pA3')::uuid) = 0, pg_temp.disponivel()::text);

-- 9. Formas de pagamento
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.pagar_eu_mesmo(pg_temp.pegar('pA5')::uuid, '529.982.247-25');
select public.escolher_pagamento(pg_temp.pegar('pA5')::uuid, 'cartao');
select pg_temp.guardar('forma_cartao', (select forma_pagamento from public.pedidos where id = pg_temp.pegar('pA5')::uuid));
do $$ begin perform public.escolher_pagamento(pg_temp.pegar('pA5')::uuid, 'boleto'); perform pg_temp.guardar('e_boleto', 'passou');
exception when others then perform pg_temp.guardar('e_boleto', sqlerrm); end $$;
do $$ begin perform public.escolher_pagamento(pg_temp.pegar('pA5')::uuid, 'crediario', null); perform pg_temp.guardar('e_prazo', 'passou');
exception when others then perform pg_temp.guardar('e_prazo', sqlerrm); end $$;
select public.escolher_pagamento(pg_temp.pegar('pA5')::uuid, 'crediario', '28/35');
select pg_temp.admin();
select pg_temp.conferir('formas de pagamento',
  pg_temp.pegar('forma_cartao') = 'cartao' and pg_temp.pegar('e_boleto') = 'Forma de pagamento inválida.'
  and pg_temp.pegar('e_prazo') = 'Escolha o prazo do crediário.'
  and (select forma_pagamento = 'crediario' and prazo = '28/35' and prazo_status = 'pendente' from public.pedidos where id = pg_temp.pegar('pA5')::uuid),
  concat_ws(' / ', pg_temp.pegar('forma_cartao'), pg_temp.pegar('e_boleto'), pg_temp.pegar('e_prazo')));

-- 10. Só o dono ou o gerente responde ao prazo
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
do $$ begin perform public.responder_prazo(pg_temp.pegar('pA5')::uuid, true); perform pg_temp.guardar('e_vendedor', 'passou');
exception when others then perform pg_temp.guardar('e_vendedor', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
do $$ begin perform public.responder_prazo(pg_temp.pegar('pA5')::uuid, true); perform pg_temp.guardar('e_outra_loja', 'passou');
exception when others then perform pg_temp.guardar('e_outra_loja', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.responder_prazo(pg_temp.pegar('pA5')::uuid, true);
do $$ begin perform public.responder_prazo(pg_temp.pegar('pA5')::uuid, true); perform pg_temp.guardar('e_de_novo', 'passou');
exception when others then perform pg_temp.guardar('e_de_novo', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('prazo só o dono ou o gerente responde',
  pg_temp.pegar('e_vendedor') = 'Só o dono ou o gerente responde ao prazo.' and pg_temp.pegar('e_outra_loja') = 'Pedido não encontrado.'
  and pg_temp.pegar('e_de_novo') = 'Não há prazo para responder.'
  and (select prazo_status = 'aprovado' and prazo_respondido_em is not null from public.pedidos where id = pg_temp.pegar('pA5')::uuid),
  concat_ws(' / ', pg_temp.pegar('e_vendedor'), pg_temp.pegar('e_outra_loja'), pg_temp.pegar('e_de_novo')));

-- 11. Prazo recusado e nova forma
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.pagar_eu_mesmo(pg_temp.pegar('pA6')::uuid, '529.982.247-25');
select public.escolher_pagamento(pg_temp.pegar('pA6')::uuid, 'crediario', '28');
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.responder_prazo(pg_temp.pegar('pA6')::uuid, false);
select pg_temp.admin();
select pg_temp.guardar('recusado', (select prazo_status from public.pedidos where id = pg_temp.pegar('pA6')::uuid));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.escolher_pagamento(pg_temp.pegar('pA6')::uuid, 'pix');
select pg_temp.admin();
select pg_temp.conferir('prazo recusado e nova forma',
  pg_temp.pegar('recusado') = 'recusado'
  and (select forma_pagamento = 'pix' and prazo is null and prazo_status is null and prazo_respondido_em is null
         from public.pedidos where id = pg_temp.pegar('pA6')::uuid),
  pg_temp.pegar('recusado'));

-- 12. Crediário e depois link para o cliente
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.pagar_eu_mesmo(pg_temp.pegar('pA7')::uuid, '529.982.247-25');
select public.escolher_pagamento(pg_temp.pegar('pA7')::uuid, 'crediario', '28/35/42');
select public.criar_link_pagamento(pg_temp.pegar('pA7')::uuid, 'Ana', '66999990000');
select pg_temp.admin();
select pg_temp.conferir('crediário e depois link limpa o prazo',
  (select pagador = 'cliente' and forma_pagamento = 'pix' and prazo is null and prazo_status is null
     from public.pedidos where id = pg_temp.pegar('pA7')::uuid));

-- 13. Prazo de pedido cancelado
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.pagar_eu_mesmo(pg_temp.pegar('pA8')::uuid, '529.982.247-25');
select public.escolher_pagamento(pg_temp.pegar('pA8')::uuid, 'crediario', '28');
select public.atualizar_pedido(pg_temp.pegar('pA8')::uuid, 'cancelado');
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin perform public.responder_prazo(pg_temp.pegar('pA8')::uuid, true); perform pg_temp.guardar('e_cancelado', 'passou');
exception when others then perform pg_temp.guardar('e_cancelado', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('prazo de pedido cancelado', pg_temp.pegar('e_cancelado') = 'Este pedido foi cancelado.', pg_temp.pegar('e_cancelado'));

-- 14-15. Link com o documento do cliente
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('cod9', public.criar_link_pagamento(pg_temp.pegar('pA9')::uuid, 'Ana', '66999990000', '529.982.247-25'));
select pg_temp.anonimo();
do $$ begin perform pg_temp.guardar('pagina9', public.pedido_do_link(pg_temp.pegar('cod9'))::text); end $$;
select pg_temp.admin();
select pg_temp.conferir('link com documento grava e a página mascara',
  (select documento = '52998224725' from public.pedido_documentos where pedido_id = pg_temp.pegar('pA9')::uuid)
  and (select documento_informado_em is not null from public.pedidos where id = pg_temp.pegar('pA9')::uuid)
  and pg_temp.pegar('pagina9')::jsonb->>'documento_mascarado' = '***.982.247-**'
  and pg_temp.pegar('pagina9')::jsonb->>'situacao' = 'aguardando_pagamento'
  and pg_temp.pegar('pagina9')::jsonb->>'pix' like '000201%'
  and position('52998224725' in pg_temp.pegar('pagina9')) = 0,
  pg_temp.pegar('pagina9'));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ begin perform public.criar_link_pagamento(pg_temp.pegar('pA9')::uuid, 'Ana', '66999990000', '111.111.111-11');
  perform pg_temp.guardar('e_doc', 'passou');
exception when others then perform pg_temp.guardar('e_doc', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('link com documento inválido', pg_temp.pegar('e_doc') = 'CPF ou CNPJ inválido. Confira os números.', pg_temp.pegar('e_doc'));

-- 16. CNPJ mascarado
select pg_temp.conferir('CNPJ mascarado', private.mascarar_documento('11222333000181') = '**.222.333/0001-**',
  private.mascarar_documento('11222333000181'));

-- 8. Saldo reservado na cotação (APK antigo): aparece ligado e desligar devolve (por último: mexe na carteira)
select pg_temp.guardar('antes', pg_temp.disponivel()::text);
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('prop4', public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'cimento-cp2-50kg',
  'loja_id', pg_temp.pegar('A'), 'quantidade', 5, 'preco_visto', 40.00)), 'pedido', null, true, null)->'propostas'->0->>'id');
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.responder_proposta(pg_temp.pegar('prop4')::uuid, 'aceitar', null, null, null, null, null);
select pg_temp.admin();
select pg_temp.guardar('pA4', (select id::text from public.pedidos where proposta_id = pg_temp.pegar('prop4')::uuid));
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.pagar_eu_mesmo(pg_temp.pegar('pA4')::uuid, '529.982.247-25');
select pg_temp.guardar('legado_liga', public.usar_saldo(pg_temp.pegar('pA4')::uuid, true)::text);
select pg_temp.guardar('legado_total_ligado', pg_temp.total('pA4')::text);
select public.usar_saldo(pg_temp.pegar('pA4')::uuid, false);
select pg_temp.admin();
select pg_temp.conferir('saldo da cotação aparece ligado e desligar devolve',
  pg_temp.pegar('legado_liga')::numeric = 200 and pg_temp.pegar('legado_total_ligado')::numeric = 0
  and pg_temp.total('pA4') = 200 and pg_temp.disponivel() = pg_temp.pegar('antes')::numeric,
  concat_ws(' / ', pg_temp.pegar('legado_liga'), pg_temp.pegar('legado_total_ligado'), pg_temp.total('pA4'), pg_temp.disponivel(), pg_temp.pegar('antes')));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
