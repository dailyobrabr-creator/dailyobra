-- Testes das regras do marketplace (funções da migração marketplace_funcoes).
-- Roda tudo numa transação desfeita no final: usuários, lojas e propostas de teste somem.
-- Resultado: uma linha por verificação, com ok = true quando passou.
begin;

create temp table r (n serial, teste text, ok boolean, detalhe text) on commit drop;
create temp table v (chave text primary key, valor text) on commit drop;
grant all on r, v to authenticated;
grant usage on sequence r_n_seq to authenticated;

create function pg_temp.guardar(k text, x text) returns void language sql as $$
  insert into v values (k, x) on conflict (chave) do update set valor = excluded.valor $$;
create function pg_temp.pegar(k text) returns text language sql as $$ select valor from v where chave = k $$;
create function pg_temp.conferir(t text, condicao boolean, d text default null) returns void language sql as $$
  insert into r (teste, ok, detalhe) values (t, coalesce(condicao, false), d) $$;
-- Troca o usuário "logado" da transação
create function pg_temp.como(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function pg_temp.admin() returns void language plpgsql as $$ begin execute 'reset role'; end $$;
create function pg_temp.saldo(u uuid, c text) returns numeric language sql as $$
  select coalesce(sum(valor), 0) from public.carteira_lancamentos where construtor_id = u and conta = c $$;

-- As ofertas reais do banco ficam de fora (o maior preço da economia olha todas as lojas abertas); tudo é desfeito no fim
update public.ofertas set pausada = true;

-- Usuários de teste
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000c001', 'construtor@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated');

-- Lojas: A (frete 50, mínimo 100) e B
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Maringá","uf":"PR","frete_fixo":50,"pedido_minimo":100,"whatsapp":"44999990000"}'::jsonb)::text);
insert into public.ofertas (loja_id, item_id, preco) values
  (pg_temp.pegar('A')::uuid, 'cimento-cp2-50kg', 40.00),
  (pg_temp.pegar('A')::uuid, 'tijolo-8-furos', 1.20),
  (pg_temp.pegar('A')::uuid, 'torneira-banheiro', 200.00);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
insert into public.ofertas (loja_id, item_id, preco) values (pg_temp.pegar('B')::uuid, 'cimento-cp2-50kg', 38.00);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor');

-- CNPJ inválido e repetido
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
do $$ begin
  perform public.criar_loja('{"nome":"Loja X","cnpj":"11222333000180","cidade":"Maringá","uf":"PR"}'::jsonb);
  perform pg_temp.conferir('CNPJ com dígito errado é recusado', false);
exception when others then perform pg_temp.conferir('CNPJ com dígito errado é recusado', sqlstate = 'P0001', sqlerrm); end $$;
do $$ begin
  perform public.criar_loja('{"nome":"Loja Y","cnpj":"11222333000181","cidade":"Maringá","uf":"PR"}'::jsonb);
  perform pg_temp.conferir('CNPJ já usado é recusado', false);
exception when others then perform pg_temp.conferir('CNPJ já usado é recusado', sqlstate = 'P0001', sqlerrm); end $$;

-- 2. Preço muda entre a prévia e o envio: o servidor usa o atual e avisa
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
update public.ofertas set preco = 45.00 where loja_id = pg_temp.pegar('A')::uuid and item_id = 'cimento-cp2-50kg';
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ declare res jsonb; begin
  res := public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('A'), 'quantidade', 10, 'preco_visto', 40.00)), 'negociacao', null, false, 'Entrega na obra');
  perform pg_temp.guardar('p1', res->'propostas'->0->>'id');
  perform pg_temp.conferir('preço atualizado vem do servidor e o app é avisado',
    (res->>'precos_atualizados')::boolean and (select subtotal_anunciado from public.propostas where id = (res->'propostas'->0->>'id')::uuid) = 450.00,
    res::text);
end $$;

-- 1. Loja B tenta responder proposta da loja A
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
do $$ begin
  perform public.responder_proposta(pg_temp.pegar('p1')::uuid, 'contrapropor', '[]'::jsonb, 10, null, null, 48);
  perform pg_temp.conferir('loja não responde proposta de outra loja', false);
exception when others then perform pg_temp.conferir('loja não responde proposta de outra loja', sqlstate = 'P0001', sqlerrm); end $$;

-- 3. Contraproposta com preço acima do anunciado
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.responder_proposta(pg_temp.pegar('p1')::uuid, 'contrapropor', '[{"item_id":"cimento-cp2-50kg","preco":50}]'::jsonb, 0, null, null, 48);
  perform pg_temp.conferir('contraproposta só pode baixar preço', false);
exception when others then perform pg_temp.conferir('contraproposta só pode baixar preço', sqlstate = 'P0001', sqlerrm); end $$;

-- 4. Construtor tenta decidir contraproposta que não existe
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ begin
  perform public.decidir_contraproposta(pg_temp.pegar('p1')::uuid, true);
  perform pg_temp.conferir('não aceita contraproposta numa proposta só enviada', false);
exception when others then perform pg_temp.conferir('não aceita contraproposta numa proposta só enviada', sqlstate = 'P0001', sqlerrm); end $$;

-- Contraproposta válida e aceite pelo construtor
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
do $$ declare s text; begin
  s := public.responder_proposta(pg_temp.pegar('p1')::uuid, 'contrapropor', '[{"item_id":"cimento-cp2-50kg","preco":42}]'::jsonb, 20, 'Fecho em 42 e dou 20 de desconto', null, 24);
  perform pg_temp.conferir('vendedor faz contraproposta e o total é recalculado',
    s = 'contraproposta' and (select total from public.propostas where id = pg_temp.pegar('p1')::uuid) = 450.00, -- 420 - 20 + 50
    (select total::text from public.propostas where id = pg_temp.pegar('p1')::uuid));
end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.conferir('construtor aceita a contraproposta', public.decidir_contraproposta(pg_temp.pegar('p1')::uuid, true) = 'aceita');

-- 5. Aceitar duas vezes não cria dois pedidos
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.responder_proposta(pg_temp.pegar('p1')::uuid, 'aceitar', null, null, null, null, null);
  perform pg_temp.conferir('segunda resposta numa proposta aceita é recusada', false);
exception when others then perform pg_temp.conferir('segunda resposta numa proposta aceita é recusada', sqlstate = 'P0001', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('só um pedido para a proposta', (select count(*) from public.pedidos where proposta_id = pg_temp.pegar('p1')::uuid) = 1);

-- 6. Responder proposta cancelada ou vencida
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('p2', (public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('A'), 'quantidade', 5)), 'negociacao', null, false, null)->'propostas'->0->>'id'));
select pg_temp.conferir('construtor cancela proposta enviada', public.cancelar_proposta(pg_temp.pegar('p2')::uuid) = 'cancelada');
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.responder_proposta(pg_temp.pegar('p2')::uuid, 'aceitar', null, null, null, null, null);
  perform pg_temp.conferir('loja não aceita proposta cancelada', false);
exception when others then perform pg_temp.conferir('loja não aceita proposta cancelada', sqlstate = 'P0001', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('p3', (public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('A'), 'quantidade', 5)), 'negociacao', null, false, null)->'propostas'->0->>'id'));
select pg_temp.admin();
update public.propostas set valida_ate = now() - interval '1 minute' where id = pg_temp.pegar('p3')::uuid;
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.responder_proposta(pg_temp.pegar('p3')::uuid, 'aceitar', null, null, null, null, null);
  perform pg_temp.conferir('loja não aceita proposta vencida', false);
exception when others then perform pg_temp.conferir('loja não aceita proposta vencida', sqlstate = 'P0001', sqlerrm); end $$;
-- A tentativa recusada desfaz o próprio trabalho; a marcação fica gravada na próxima consulta das telas
select public.expirar_propostas();
select pg_temp.admin();
select pg_temp.conferir('proposta vencida fica expirada', (select status from public.propostas where id = pg_temp.pegar('p3')::uuid) = 'expirada');

-- 7. Mesmo saldo em duas cotações seguidas
select pg_temp.admin();
insert into public.carteira_lancamentos (transacao_id, construtor_id, conta, valor, tipo, descricao) values
  ('00000000-0000-0000-0000-0000000000aa', '00000000-0000-0000-0000-00000000c001', 'emissor', -30, 'cashback_liberado', 'saldo de teste'),
  ('00000000-0000-0000-0000-0000000000aa', '00000000-0000-0000-0000-00000000c001', 'disponivel', 30, 'cashback_liberado', 'saldo de teste');
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('p4', (public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('A'), 'quantidade', 5)), 'negociacao', null, true, null)->'propostas'->0->>'id'));
select pg_temp.guardar('p5', (public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('A'), 'quantidade', 5)), 'negociacao', null, true, null)->'propostas'->0->>'id'));
select pg_temp.admin();
select pg_temp.conferir('saldo não é usado duas vezes',
  pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'disponivel') = 0
  and pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'reservado') = 30
  and (select saldo_aplicado from public.propostas where id = pg_temp.pegar('p5')::uuid) = 0,
  format('disp %s, res %s', pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'disponivel'), pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'reservado')));

-- 8. Recusa devolve a reserva
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.responder_proposta(pg_temp.pegar('p4')::uuid, 'recusar', null, null, null, '', null);
  perform pg_temp.conferir('recusa sem motivo é recusada', false);
exception when others then perform pg_temp.conferir('recusa sem motivo é recusada', sqlstate = 'P0001', sqlerrm); end $$;
select pg_temp.conferir('loja recusa com motivo', public.responder_proposta(pg_temp.pegar('p4')::uuid, 'recusar', null, null, null, 'Sem entrega nessa data', null) = 'recusada');
select pg_temp.admin();
select pg_temp.conferir('recusa devolve o saldo reservado',
  pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'disponivel') = 30 and pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'reservado') = 0);

-- 12. Abaixo do pedido mínimo
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ begin
  perform public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'tijolo-8-furos', 'loja_id', pg_temp.pegar('A'), 'quantidade', 10)), 'pedido', null, false, null);
  perform pg_temp.conferir('loja abaixo do pedido mínimo é recusada com o valor', false);
exception when others then perform pg_temp.conferir('loja abaixo do pedido mínimo é recusada com o valor', sqlstate = 'P0001' and sqlerrm like '%100,00%', sqlerrm); end $$;

-- 9 a 11. Cashback: pendente no aceite, só libera com entrega e pagamento, vendedor não confirma pagamento
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('p6', (public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'torneira-banheiro', 'loja_id', pg_temp.pegar('A'), 'quantidade', 5)), 'pedido', null, false, null)->'propostas'->0->>'id'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.responder_proposta(pg_temp.pegar('p6')::uuid, 'contrapropor', '[]'::jsonb, 10, null, null, 48);
  perform pg_temp.conferir('pedido direto não aceita contraproposta', false);
exception when others then perform pg_temp.conferir('pedido direto não aceita contraproposta', sqlstate = 'P0001', sqlerrm); end $$;
select pg_temp.conferir('loja confirma pedido direto', public.responder_proposta(pg_temp.pegar('p6')::uuid, 'aceitar', null, null, null, null, null) = 'aceita');
select pg_temp.admin();
select pg_temp.guardar('ped6', (select id::text from public.pedidos where proposta_id = pg_temp.pegar('p6')::uuid));
select pg_temp.conferir('cashback pendente de 5% sobre R$ 1.000 (frete fora)',
  (select coalesce(sum(valor), 0) from public.carteira_lancamentos where pedido_id = pg_temp.pegar('ped6')::uuid and conta = 'pendente') = 50.00);
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.atualizar_pedido(pg_temp.pegar('ped6')::uuid, 'em_separacao');
select public.atualizar_pedido(pg_temp.pegar('ped6')::uuid, 'saiu_entrega');
select public.atualizar_pedido(pg_temp.pegar('ped6')::uuid, 'entregue');
select pg_temp.admin();
select pg_temp.conferir('entregue sem pagamento não libera cashback', pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'disponivel') = 30);
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
do $$ begin
  perform public.confirmar_pagamento(pg_temp.pegar('ped6')::uuid);
  perform pg_temp.conferir('vendedor não confirma pagamento', false);
exception when others then perform pg_temp.conferir('vendedor não confirma pagamento', sqlstate = 'P0001', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.confirmar_pagamento(pg_temp.pegar('ped6')::uuid);
select pg_temp.admin();
select pg_temp.conferir('entrega + pagamento liberam o cashback',
  pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'disponivel') = 80
  and (select coalesce(sum(valor), 0) from public.carteira_lancamentos where pedido_id = pg_temp.pegar('ped6')::uuid and conta = 'pendente') = 0,
  format('disp %s', pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'disponivel')));

-- Pular etapa do pedido é recusado
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('p7', (public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'torneira-banheiro', 'loja_id', pg_temp.pegar('A'), 'quantidade', 1)), 'pedido', null, false, null)->'propostas'->0->>'id'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.responder_proposta(pg_temp.pegar('p7')::uuid, 'aceitar', null, null, null, null, null);
select pg_temp.admin();
select pg_temp.guardar('ped7', (select id::text from public.pedidos where proposta_id = pg_temp.pegar('p7')::uuid));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.atualizar_pedido(pg_temp.pegar('ped7')::uuid, 'entregue');
  perform pg_temp.conferir('pedido não pula de confirmado para entregue', false);
exception when others then perform pg_temp.conferir('pedido não pula de confirmado para entregue', sqlstate = 'P0001', sqlerrm); end $$;

-- 13. Cancelado pela loja em separação estorna o cashback pendente
select public.atualizar_pedido(pg_temp.pegar('ped7')::uuid, 'em_separacao');
select pg_temp.conferir('loja cancela pedido em separação', public.atualizar_pedido(pg_temp.pegar('ped7')::uuid, 'cancelado') = 'cancelado');
select pg_temp.admin();
select pg_temp.conferir('cancelamento estorna o cashback pendente',
  (select coalesce(sum(valor), 0) from public.carteira_lancamentos where pedido_id = pg_temp.pegar('ped7')::uuid and conta = 'pendente') = 0
  -- o pedido da contraproposta (R$ 400 em tier 1) continua com R$ 4,00 pendentes
  and pg_temp.saldo('00000000-0000-0000-0000-00000000c001', 'pendente') = 4.00);

-- Construtor não vê proposta de outro construtor; loja B não vê pedido da loja A
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.conferir('loja B não vê pedidos da loja A', (select count(*) from public.pedidos) = 0);
select pg_temp.conferir('loja B não vê propostas da loja A', (select count(*) from public.propostas) = 0);
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.conferir('loja A vê o construtor que mandou proposta', (select count(*) from public.profiles where id = '00000000-0000-0000-0000-00000000c001') = 1);
select pg_temp.conferir('loja A não lê a carteira do construtor', (select count(*) from public.carteira_lancamentos) = 0);

-- Partidas dobradas: cada transação soma zero
select pg_temp.admin();
select pg_temp.conferir('toda transação da carteira soma zero',
  not exists (select 1 from public.carteira_lancamentos group by transacao_id having sum(valor) <> 0));

-- Economia do mês: preço maior gravado no envio e conta por mês (p8: pedido na loja B, cimento a 38 com A a 45)
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('p8', (public.enviar_cotacao(jsonb_build_array(jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('B'), 'quantidade', 10)), 'pedido', null, false, null)->'propostas'->0->>'id'));
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select public.responder_proposta(pg_temp.pegar('p8')::uuid, 'aceitar', null, null, null, null, null);
select pg_temp.admin();
do $$ begin
  perform pg_temp.conferir('envio grava o maior preço entre as lojas',
    (select preco_maior from public.proposta_itens where proposta_id = pg_temp.pegar('p8')::uuid) = 45.00
    and (select preco_maior from public.proposta_itens where proposta_id = pg_temp.pegar('p1')::uuid) = 45.00, null);
exception when others then perform pg_temp.conferir('envio grava o maior preço entre as lojas', false, sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ declare e record; n int; begin
  select count(*) into n from public.economia_mensal(6);
  select * into e from public.economia_mensal(6) order by mes desc limit 1;
  -- p8: comparando (45 - 38) x 10; p1: negociando (45 - 42) x 10 + 20; cashback 4,00 (p1) + 50,00 (p6) + 3,80 (p8); p7 cancelado fica fora
  perform pg_temp.conferir('economia do mês soma comparando, negociando e cashback (sem o cancelado)',
    n = 6 and e.comparando = 70.00 and e.negociando = 50.00 and e.cashback = 57.80 and e.total = 177.80,
    format('n=%s comp=%s neg=%s cash=%s total=%s', n, e.comparando, e.negociando, e.cashback, e.total));
  perform pg_temp.conferir('meses sem pedido valem zero',
    (select count(*) from public.economia_mensal(6) where total = 0 and comparando = 0 and negociando = 0 and cashback = 0) = 5, null);
exception when others then
  perform pg_temp.conferir('economia do mês soma comparando, negociando e cashback (sem o cancelado)', false, sqlerrm);
  perform pg_temp.conferir('meses sem pedido valem zero', false, sqlerrm);
end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform pg_temp.conferir('economia de outro construtor não aparece',
    (select count(*) from public.economia_mensal(6)) = 6 and (select coalesce(sum(total), 0) from public.economia_mensal(6)) = 0, null);
exception when others then perform pg_temp.conferir('economia de outro construtor não aparece', false, sqlerrm); end $$;
select pg_temp.admin();

-- Equipe: só o dono convida, e só quem já tem conta
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
do $$ begin
  perform public.convidar_membro(pg_temp.pegar('A')::uuid, 'dono.b@teste.dailyobra', 'vendedor');
  perform pg_temp.conferir('vendedor não convida para a equipe', false);
exception when others then perform pg_temp.conferir('vendedor não convida para a equipe', sqlstate = 'P0001', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.convidar_membro(pg_temp.pegar('A')::uuid, 'ninguem@teste.dailyobra', 'vendedor');
  perform pg_temp.conferir('convite para e-mail sem conta é recusado', false);
exception when others then perform pg_temp.conferir('convite para e-mail sem conta é recusado', sqlstate = 'P0001' and sqlerrm like 'Não encontramos%', sqlerrm); end $$;
select pg_temp.conferir('dono convida quem tem conta', public.convidar_membro(pg_temp.pegar('A')::uuid, 'DONO.B@teste.dailyobra', 'gerente') = 'gerente');
select pg_temp.admin();
select pg_temp.conferir('convidado entra com o papel escolhido',
  (select papel from public.loja_membros where loja_id = pg_temp.pegar('A')::uuid and user_id = '00000000-0000-0000-0000-00000000f001') = 'gerente');
-- Visitante sem login não chama as funções
do $$ begin
  execute 'set local role anon';
  perform public.enviar_cotacao('[]'::jsonb, 'pedido', null, false, null);
  execute 'reset role';
  perform pg_temp.conferir('visitante sem login não envia cotação', false);
exception when others then
  execute 'reset role';
  perform pg_temp.conferir('visitante sem login não envia cotação', sqlstate in ('42501', 'P0001'), sqlerrm);
end $$;

-- Leitura de lista por arquivo: 30 por dia por construtor
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ declare i int; begin
  for i in 1..30 loop perform public.registrar_leitura_lista(); end loop;
  perform pg_temp.conferir('30 leituras de arquivo no dia passam', true);
exception when others then perform pg_temp.conferir('30 leituras de arquivo no dia passam', false, sqlerrm); end $$;
do $$ begin
  perform public.registrar_leitura_lista();
  perform pg_temp.conferir('a 31ª leitura do dia é recusada', false);
exception when others then perform pg_temp.conferir('a 31ª leitura do dia é recusada', sqlstate = 'P0001', sqlerrm); end $$;
select pg_temp.conferir('construtor não lê as leituras de ninguém', (select count(*) from public.leituras_lista) = 0);
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  perform public.registrar_leitura_lista();
  perform pg_temp.conferir('o limite de um não afeta outra pessoa', true);
exception when others then perform pg_temp.conferir('o limite de um não afeta outra pessoa', false, sqlerrm); end $$;

-- Frete a combinar: sai quando a loja salva frete ou pedido mínimo, não quando troca a logo
select pg_temp.admin();
update public.lojas set frete_a_combinar = true where id = pg_temp.pegar('A')::uuid;
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
update public.lojas set logo_path = 'a/logo.png' where id = pg_temp.pegar('A')::uuid;
select pg_temp.conferir('trocar a logo mantém o frete a combinar',
  (select frete_a_combinar from public.lojas where id = pg_temp.pegar('A')::uuid));
update public.lojas set frete_fixo = 50, pedido_minimo = 100 where id = pg_temp.pegar('A')::uuid;
select pg_temp.conferir('salvar o frete pelo app tira o a combinar',
  not (select frete_a_combinar from public.lojas where id = pg_temp.pegar('A')::uuid));

select pg_temp.admin();
select n, ok, teste, detalhe from r order by n;
rollback;
