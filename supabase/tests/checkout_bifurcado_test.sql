-- Testes do checkout bifurcado (migração checkout_bifurcado): link de pagamento, dados para a nota e PIX copia e cola.
-- Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro desfaz tudo (assim roda pelo execute_sql).
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

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000c001', 'construtor@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000c002', 'outro@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated');
insert into public.profiles (id, nome) values ('00000000-0000-0000-0000-00000000c001', null)
  on conflict (id) do update set nome = null;

-- Loja A (com chave PIX, nome e cidade com acento) e loja B (sem chave)
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Operário Construção e Acabamentos","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
update public.lojas set chave_pix = '+5566999990000' where id = pg_temp.pegar('A')::uuid;
insert into public.ofertas (loja_id, item_id, preco) values (pg_temp.pegar('A')::uuid, 'cimento-cp2-50kg', 40.00);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
insert into public.ofertas (loja_id, item_id, preco) values (pg_temp.pegar('B')::uuid, 'cimento-cp2-50kg', 38.00);

-- Pedidos: dois na loja A (um será cancelado) e um na B
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.enviar_cotacao(jsonb_build_array(
  jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('A'), 'quantidade', 10, 'preco_visto', 40.00),
  jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('B'), 'quantidade', 5, 'preco_visto', 38.00)),
  'pedido', null, false, null);
select public.enviar_cotacao(jsonb_build_array(
  jsonb_build_object('item_id', 'cimento-cp2-50kg', 'loja_id', pg_temp.pegar('A'), 'quantidade', 2, 'preco_visto', 40.00)),
  'pedido', null, false, null);
select pg_temp.admin();
select pg_temp.guardar('propA', (select id from public.propostas where loja_id = pg_temp.pegar('A')::uuid and subtotal_anunciado = 400)::text);
select pg_temp.guardar('propA2', (select id from public.propostas where loja_id = pg_temp.pegar('A')::uuid and subtotal_anunciado = 80)::text);
select pg_temp.guardar('propB', (select id from public.propostas where loja_id = pg_temp.pegar('B')::uuid)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.responder_proposta(pg_temp.pegar('propA')::uuid, 'aceitar', null, null, null, null, null);
select public.responder_proposta(pg_temp.pegar('propA2')::uuid, 'aceitar', null, null, null, null, null);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select public.responder_proposta(pg_temp.pegar('propB')::uuid, 'aceitar', null, null, null, null, null);
select pg_temp.admin();
select pg_temp.guardar('pA', (select id from public.pedidos where proposta_id = pg_temp.pegar('propA')::uuid)::text);
select pg_temp.guardar('pA2', (select id from public.pedidos where proposta_id = pg_temp.pegar('propA2')::uuid)::text);
select pg_temp.guardar('pB', (select id from public.pedidos where proposta_id = pg_temp.pegar('propB')::uuid)::text);

-- 1-3. BR Code
select pg_temp.conferir('brcode do exemplo do BC',
  private.brcode('123e4567-e12b-12d1-a456-426655440000', 'Fulano de Tal', 'BRASILIA', null, '***')
    = '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913FULANO DE TAL6008BRASILIA62070503***6304F012',
  private.brcode('123e4567-e12b-12d1-a456-426655440000', 'Fulano de Tal', 'BRASILIA', null, '***'));
select pg_temp.conferir('brcode corta e tira acento',
  private.brcode('+5566999990000', 'Operário Construção e Acabamentos', 'Rondonópolis', 10, 'T') like '%5925OPERARIO CONSTRUCAO E ACA6012RONDONOPOLIS%',
  private.brcode('+5566999990000', 'Operário Construção e Acabamentos', 'Rondonópolis', 10, 'T'));
select pg_temp.conferir('brcode formata o valor',
  private.brcode('+5566999990000', 'X', 'Y', 1118.95, 'T') like '%54071118.95%'
  and private.brcode('+5566999990000', 'X', 'Y', 10000, 'T') like '%540810000.00%'
  and private.brcode('+5566999990000', 'X', 'Y', 0.5, 'T') like '%54040.50%');

-- 4-6. Criar o link
select pg_temp.como('00000000-0000-0000-0000-00000000c002');
do $$ begin
  perform public.criar_link_pagamento(pg_temp.pegar('pA')::uuid, 'Ana', '66999990000');
  perform pg_temp.conferir('link de quem não é dono', false);
exception when others then perform pg_temp.conferir('link de quem não é dono', sqlerrm = 'Pedido não encontrado.', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ begin
  perform public.criar_link_pagamento(pg_temp.pegar('pB')::uuid, 'Ana', '66999990000');
  perform pg_temp.conferir('link sem chave pix', false);
exception when others then perform pg_temp.conferir('link sem chave pix', sqlerrm = 'A loja ainda não cadastrou a chave PIX.', sqlerrm); end $$;
select pg_temp.guardar('cod1', public.criar_link_pagamento(pg_temp.pegar('pA')::uuid, 'Ana', '(66) 99999-0000'));
select pg_temp.admin();
select pg_temp.conferir('link criado',
  length(pg_temp.pegar('cod1')) = 22 and pg_temp.pegar('cod1') ~ '^[A-Za-z0-9_-]+$'
  and (select pagador = 'cliente' and pagador_whatsapp = '66999990000' and link_codigo = pg_temp.pegar('cod1')
         from public.pedidos where id = pg_temp.pegar('pA')::uuid));

-- 7-9. Página do cliente (anônimo)
select pg_temp.anonimo();
do $$ declare res jsonb; begin
  res := public.pedido_do_link(pg_temp.pegar('cod1'));
  perform pg_temp.conferir('página antes dos dados',
    res->>'situacao' = 'aguardando_dados' and res->'pix' = 'null'::jsonb and not (res ? 'construtor_id')
    and res->'loja'->>'nome' = 'Operário Construção e Acabamentos' and jsonb_array_length(res->'itens') = 1
    and (res->>'total')::numeric = 400, res::text);
end $$;
do $$ begin
  perform public.dados_do_pagador(pg_temp.pegar('cod1'), 'Ana Paula', '111.111.111-11');
  perform pg_temp.conferir('documento inválido', false);
exception when others then perform pg_temp.conferir('documento inválido', sqlerrm = 'CPF ou CNPJ inválido. Confira os números.', sqlerrm); end $$;
select public.dados_do_pagador(pg_temp.pegar('cod1'), 'Ana Paula', '529.982.247-25');
do $$ declare res jsonb; begin
  res := public.pedido_do_link(pg_temp.pegar('cod1'));
  perform pg_temp.guardar('pagina2', res::text);
end $$;
select pg_temp.admin();
select pg_temp.conferir('dados do cliente gravados',
  (select documento = '52998224725' from public.pedido_documentos where pedido_id = pg_temp.pegar('pA')::uuid)
  and (select documento_informado_em is not null and pagador_nome = 'Ana Paula' from public.pedidos where id = pg_temp.pegar('pA')::uuid)
  and pg_temp.pegar('pagina2')::jsonb->>'situacao' = 'aguardando_pagamento'
  and pg_temp.pegar('pagina2')::jsonb->>'pix' like '000201%'
  and position('52998224725' in pg_temp.pegar('pagina2')) = 0, pg_temp.pegar('pagina2'));

-- 10. O documento só aparece para a loja
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('docs_construtor', (select count(*) from public.pedido_documentos)::text);
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('docs_loja', (select count(*) from public.pedido_documentos)::text);
select pg_temp.admin();
select pg_temp.conferir('documento só para a loja', pg_temp.pegar('docs_construtor') = '0' and pg_temp.pegar('docs_loja') = '1',
  pg_temp.pegar('docs_construtor') || '/' || pg_temp.pegar('docs_loja'));

-- 11. "Já paguei"
select pg_temp.anonimo();
select public.avisar_pagamento(pg_temp.pegar('cod1'));
select pg_temp.admin();
select pg_temp.guardar('aviso1', (select pagamento_informado_em from public.pedidos where id = pg_temp.pegar('pA')::uuid)::text);
select pg_temp.anonimo();
select public.avisar_pagamento(pg_temp.pegar('cod1'));
do $$ begin perform pg_temp.guardar('situacao_aviso', public.pedido_do_link(pg_temp.pegar('cod1'))->>'situacao'); end $$;
select pg_temp.admin();
select pg_temp.conferir('aviso de pagamento',
  pg_temp.pegar('situacao_aviso') = 'informado'
  and (select pagamento_informado_em::text from public.pedidos where id = pg_temp.pegar('pA')::uuid) = pg_temp.pegar('aviso1'));

-- 12. Trocar o cliente invalida o link anterior
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('cod2', public.criar_link_pagamento(pg_temp.pegar('pA')::uuid, 'Beto', '66988887777'));
select pg_temp.anonimo();
do $$ begin
  perform public.pedido_do_link(pg_temp.pegar('cod1'));
  perform pg_temp.guardar('antigo', 'abriu');
exception when others then perform pg_temp.guardar('antigo', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('trocar cliente invalida o link',
  pg_temp.pegar('antigo') = 'Link inválido ou substituído.' and pg_temp.pegar('cod2') <> pg_temp.pegar('cod1')
  and not exists (select 1 from public.pedido_documentos where pedido_id = pg_temp.pegar('pA')::uuid)
  and (select documento_informado_em is null and pagamento_informado_em is null from public.pedidos where id = pg_temp.pegar('pA')::uuid),
  pg_temp.pegar('antigo'));

-- 13. Eu pago
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
do $$ begin
  perform public.pagar_eu_mesmo(pg_temp.pegar('pA')::uuid, '11.222.333/0001-81');
  perform pg_temp.guardar('sem_nome', 'passou');
exception when others then perform pg_temp.guardar('sem_nome', sqlerrm); end $$;
update public.profiles set nome = 'Marcos Silva' where id = '00000000-0000-0000-0000-00000000c001';
select public.pagar_eu_mesmo(pg_temp.pegar('pA')::uuid, '11.222.333/0001-81');
select pg_temp.admin();
select pg_temp.conferir('eu pago sem nome no perfil e depois com nome',
  pg_temp.pegar('sem_nome') = 'Complete seu nome no Perfil.'
  and (select pagador = 'proprio' and link_codigo is null and pagador_nome = 'Marcos Silva' and documento_informado_em is not null
         from public.pedidos where id = pg_temp.pegar('pA')::uuid)
  and (select documento = '11222333000181' from public.profiles where id = '00000000-0000-0000-0000-00000000c001')
  and (select documento = '11222333000181' from public.pedido_documentos where pedido_id = pg_temp.pegar('pA')::uuid),
  pg_temp.pegar('sem_nome'));

-- 14. PIX do pedido para o construtor
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('pixA', public.pix_do_pedido(pg_temp.pegar('pA')::uuid));
select pg_temp.guardar('pixB', coalesce(public.pix_do_pedido(pg_temp.pegar('pB')::uuid), 'nulo'));
select pg_temp.admin();
select pg_temp.conferir('pix do pedido',
  pg_temp.pegar('pixA') like '000201%' and pg_temp.pegar('pixA') like '%62140510DO' || upper(left(pg_temp.pegar('pA'), 8)) || '6304%'
  and pg_temp.pegar('pixB') = 'nulo', pg_temp.pegar('pixA'));

-- 15. Pagamento confirmado fecha a página
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('cod3', public.criar_link_pagamento(pg_temp.pegar('pA')::uuid, 'Ana', '66999990000'));
select pg_temp.anonimo();
select public.dados_do_pagador(pg_temp.pegar('cod3'), 'Ana Paula', '52998224725');
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.confirmar_pagamento(pg_temp.pegar('pA')::uuid);
select pg_temp.anonimo();
do $$ declare res jsonb; begin
  res := public.pedido_do_link(pg_temp.pegar('cod3'));
  begin
    perform public.dados_do_pagador(pg_temp.pegar('cod3'), 'Ana Paula', '52998224725');
    perform pg_temp.guardar('pago_erro', 'passou');
  exception when others then perform pg_temp.guardar('pago_erro', sqlerrm); end;
  perform pg_temp.conferir('pago fecha a página',
    res->>'situacao' = 'pago' and res->'pix' = 'null'::jsonb and pg_temp.pegar('pago_erro') = 'Este pedido já foi pago.', res::text);
end $$;

-- 16. Pedido cancelado fecha a página
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.guardar('cod4', public.criar_link_pagamento(pg_temp.pegar('pA2')::uuid, 'Ana', '66999990000'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.atualizar_pedido(pg_temp.pegar('pA2')::uuid, 'cancelado');
select pg_temp.anonimo();
do $$ declare res jsonb; begin
  res := public.pedido_do_link(pg_temp.pegar('cod4'));
  begin
    perform public.dados_do_pagador(pg_temp.pegar('cod4'), 'Ana Paula', '52998224725');
    perform pg_temp.guardar('cancel_erro', 'passou');
  exception when others then perform pg_temp.guardar('cancel_erro', sqlerrm); end;
  perform pg_temp.conferir('cancelado fecha a página',
    res->>'situacao' = 'cancelado' and res->'pix' = 'null'::jsonb and pg_temp.pegar('cancel_erro') = 'Este pedido foi cancelado.', res::text);
end $$;

-- 17. Chave PIX validada no banco
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin
  update public.lojas set chave_pix = '66999990000' where id = pg_temp.pegar('A')::uuid;
  perform pg_temp.guardar('chave_ruim', 'aceitou');
exception when others then perform pg_temp.guardar('chave_ruim', 'recusou'); end $$;
do $$ declare boas text[] := array['+5566999990000', '52998224725', 'loja@exemplo.com', '123e4567-e12b-12d1-a456-426655440000'];
  c text; n int := 0; begin
  foreach c in array boas loop
    begin
      update public.lojas set chave_pix = c where id = pg_temp.pegar('A')::uuid;
      n := n + 1;
    exception when others then null; end;
  end loop;
  perform pg_temp.conferir('chave pix validada', pg_temp.pegar('chave_ruim') = 'recusou' and n = 4,
    pg_temp.pegar('chave_ruim') || ', boas aceitas: ' || n);
end $$;

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
