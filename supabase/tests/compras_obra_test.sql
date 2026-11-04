-- Testes das compras da obra (migração compras_obra). Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro
-- desfaz tudo.
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
create function pg_temp.material(k text, dados jsonb) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.salvar_material(%L, null, %L)', pg_temp.pegar('O'), dados)) $$;
create function pg_temp.receber(k text, pedido text, itens jsonb, obs text default null) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.registrar_recebimento(%L, %L, %L, null, %L)', pg_temp.pegar('O'), pedido, itens, obs)) $$;

select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');
select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('estagiario', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('empreiteiro', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('cliente', '00000000-0000-0000-0000-00000000a005');
select pg_temp.guardar('fora', '00000000-0000-0000-0000-00000000a006');
select pg_temp.guardar('item', (select id from public.catalogo_itens limit 1));

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.chave not in ('O', 'item');
insert into public.obras (id, nome, created_by) values
  ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000b0002', 'Outra obra', '00000000-0000-0000-0000-00000000a006');
insert into public.obra_membros (obra_id, user_id, papel, funcao) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a002', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'membro', 'estagiario'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a004', 'membro', 'empreiteiro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente');

do $$
declare
  loja uuid := (select id from public.lojas limit 1);
  item text := pg_temp.pegar('item');
  orc uuid;
  prop uuid;
  ped uuid;
  dono uuid := '00000000-0000-0000-0000-00000000a001';
begin
  insert into public.orcamentos (construtor_id, obra_id, modo) values (dono, '00000000-0000-0000-0000-0000000b0001', 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, subtotal_anunciado, total, valida_ate) values (orc, loja, dono, 'pedido', 1000, 1000, now() + interval '1 day') returning id into prop;
  insert into public.proposta_itens (proposta_id, item_id, nome, unidade, tier, quantidade, preco_anunciado, preco_ofertado) values (prop, item, 'Cimento', 'saco', 1, 50, 20, 20);
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total) values (prop, loja, dono, 1000) returning id into ped;
  perform pg_temp.guardar('pedido', ped::text);
  insert into public.orcamentos (construtor_id, obra_id, modo) values (dono, '00000000-0000-0000-0000-0000000b0001', 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, subtotal_anunciado, total, valida_ate) values (orc, loja, dono, 'pedido', 500, 500, now() + interval '1 day') returning id into prop;
  insert into public.proposta_itens (proposta_id, item_id, nome, unidade, tier, quantidade, preco_anunciado, preco_ofertado) values (prop, item, 'Cancelado', 'saco', 1, 5, 20, 20);
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status) values (prop, loja, dono, 500, 'cancelado') returning id into ped;
  perform pg_temp.guardar('cancelado', ped::text);
  insert into public.orcamentos (construtor_id, obra_id, modo) values ('00000000-0000-0000-0000-00000000a006', '00000000-0000-0000-0000-0000000b0002', 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, subtotal_anunciado, total, valida_ate) values (orc, loja, '00000000-0000-0000-0000-00000000a006', 'pedido', 700, 700, now() + interval '1 day') returning id into prop;
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total) values (prop, loja, '00000000-0000-0000-0000-00000000a006', 700) returning id into ped;
  perform pg_temp.guardar('pedido alheio', ped::text);
end $$;

-- Lista de materiais
select pg_temp.como('mestre');
select pg_temp.tentar('monta', format('select public.salvar_materiais(%L, %L)', pg_temp.pegar('O'), jsonb_build_array(
  jsonb_build_object('etapa', 'alvenaria', 'item_id', pg_temp.pegar('item'), 'nome', ' Cimento ', 'unidade', 'saco', 'quantidade', 100, 'preco_base', 35.5),
  jsonb_build_object('etapa', 'pintura', 'item_id', null, 'nome', 'Tinta', 'unidade', 'lata', 'quantidade', 2.5))));
select pg_temp.material('sem nome', '{"nome": " ", "unidade": "saco", "quantidade": 1}');
select pg_temp.material('sem unidade', '{"nome": "x", "unidade": " ", "quantidade": 1}');
select pg_temp.material('sem quantidade', '{"nome": "x", "unidade": "saco"}');
select pg_temp.material('quantidade zero', '{"nome": "x", "unidade": "saco", "quantidade": 0}');
select pg_temp.guardar('m1', (select public.salvar_material(pg_temp.pegar('O')::uuid, null, '{"nome": "Areia", "unidade": "m3", "quantidade": 4, "etapa": "alvenaria"}'::jsonb)::text));
select pg_temp.tentar('altera', format('select public.salvar_material(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('m1'), '{"nome": "Areia média", "unidade": "m3", "quantidade": 6}'));
select pg_temp.guardar('mestre le', (select string_agg(nome || ':' || quantidade, ',' order by nome) from public.obra_materiais));
select pg_temp.como('estagiario');
select pg_temp.guardar('estagiario le', (select count(*)::text from public.obra_materiais));
select pg_temp.tentar('estagiario monta', format('select public.salvar_materiais(%L, %L)', pg_temp.pegar('O'), '[]'));
select pg_temp.material('estagiario adiciona', '{"nome": "x", "unidade": "saco", "quantidade": 1}');
select pg_temp.tentar('estagiario exclui', format('select public.excluir_material(%L)', pg_temp.pegar('m1')));
select pg_temp.como('empreiteiro');
select pg_temp.guardar('empreiteiro le', (select count(*)::text from public.obra_materiais));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente le', (select count(*)::text from public.obra_materiais));
select pg_temp.material('cliente adiciona', '{"nome": "x", "unidade": "saco", "quantidade": 1}');
select pg_temp.como('fora');
select pg_temp.tentar('fora exclui', format('select public.excluir_material(%L)', pg_temp.pegar('m1')));
select pg_temp.tentar('fora altera', format('select public.salvar_material(%L, %L, %L)', '00000000-0000-0000-0000-0000000b0002', pg_temp.pegar('m1'), '{"nome": "x", "unidade": "saco", "quantidade": 1}'));
select pg_temp.admin();
select pg_temp.conferir('quem lidera monta e altera a lista', pg_temp.pegar('monta') = 'passou' and pg_temp.pegar('mestre le') = 'Areia média:6.000,Cimento:100.000,Tinta:2.500', pg_temp.pegar('mestre le'));
select pg_temp.conferir('material sem nome', pg_temp.pegar('sem nome') = 'Diga qual é o material.', pg_temp.pegar('sem nome'));
select pg_temp.conferir('material sem unidade', pg_temp.pegar('sem unidade') = 'Diga a unidade do material.', pg_temp.pegar('sem unidade'));
select pg_temp.conferir('material sem quantidade', pg_temp.pegar('sem quantidade') = 'Digite uma quantidade maior que zero.' and pg_temp.pegar('quantidade zero') = 'Digite uma quantidade maior que zero.', pg_temp.pegar('sem quantidade'));
select pg_temp.conferir('estagiário lê a lista', pg_temp.pegar('estagiario le') = '3', pg_temp.pegar('estagiario le'));
select pg_temp.conferir('estagiário não mexe na lista',
  pg_temp.pegar('estagiario monta') = 'Só o responsável ou o mestre montam a lista de materiais.'
  and pg_temp.pegar('estagiario adiciona') = 'Só o responsável ou o mestre mexem na lista de materiais.'
  and pg_temp.pegar('estagiario exclui') = 'Material não encontrado.', pg_temp.pegar('estagiario monta'));
select pg_temp.conferir('empreiteiro e cliente não veem a lista', pg_temp.pegar('empreiteiro le') = '0' and pg_temp.pegar('cliente le') = '0', pg_temp.pegar('cliente le'));
select pg_temp.conferir('cliente não mexe na lista', pg_temp.pegar('cliente adiciona') = 'Só o responsável ou o mestre mexem na lista de materiais.', pg_temp.pegar('cliente adiciona'));
select pg_temp.conferir('quem é de fora não exclui', pg_temp.pegar('fora exclui') = 'Material não encontrado.', pg_temp.pegar('fora exclui'));
select pg_temp.conferir('material de uma obra não muda pela outra', pg_temp.pegar('fora altera') = 'Material não encontrado.', pg_temp.pegar('fora altera'));

-- Remontar a lista troca tudo
select pg_temp.como('dono');
select pg_temp.tentar('remonta', format('select public.salvar_materiais(%L, %L)', pg_temp.pegar('O'), '[{"nome": "Brita", "unidade": "m3", "quantidade": 3}]'));
select pg_temp.tentar('quebrada', format('select public.salvar_materiais(%L, %L)', pg_temp.pegar('O'), '[{"nome": "Sem quantidade", "unidade": "m3"}]'));
select pg_temp.tentar('nao lista', format('select public.salvar_materiais(%L, %L)', pg_temp.pegar('O'), '{"nome": "x"}'));
select pg_temp.guardar('depois', (select string_agg(nome, ',') from public.obra_materiais));
select pg_temp.admin();
select pg_temp.conferir('remontar troca a lista inteira', pg_temp.pegar('remonta') = 'passou' and pg_temp.pegar('depois') = 'Brita', pg_temp.pegar('depois'));
select pg_temp.conferir('lista com erro não apaga a que existia', pg_temp.pegar('quebrada') <> 'passou' and pg_temp.pegar('depois') = 'Brita', pg_temp.pegar('quebrada'));
select pg_temp.conferir('formato errado', pg_temp.pegar('nao lista') = 'Lista inválida.', pg_temp.pegar('nao lista'));

-- O que foi pedido
select pg_temp.como('estagiario');
select pg_temp.guardar('pedidos', (select string_agg(nome || ':' || quantidade::text, ',') from public.itens_dos_pedidos(pg_temp.pegar('O')::uuid)));
select pg_temp.como('empreiteiro');
select pg_temp.tentar('empreiteiro pedidos', format('select public.itens_dos_pedidos(%L)', pg_temp.pegar('O')));
select pg_temp.como('cliente');
select pg_temp.tentar('cliente pedidos', format('select public.itens_dos_pedidos(%L)', pg_temp.pegar('O')));
select pg_temp.como('fora');
select pg_temp.tentar('fora pedidos', format('select public.itens_dos_pedidos(%L)', pg_temp.pegar('O')));
select pg_temp.admin();
select pg_temp.conferir('pedidos da obra, sem cancelado', pg_temp.pegar('pedidos') = 'Cimento:50', pg_temp.pegar('pedidos'));
select pg_temp.conferir('quem não cuida das compras não vê os pedidos',
  pg_temp.pegar('empreiteiro pedidos') = 'Obra não encontrada.' and pg_temp.pegar('cliente pedidos') = 'Obra não encontrada.' and pg_temp.pegar('fora pedidos') = 'Obra não encontrada.', pg_temp.pegar('cliente pedidos'));
select pg_temp.conferir('lista de pedidos não traz preço',
  not exists (select 1 from pg_proc p, unnest(p.proargnames) a where p.proname = 'itens_dos_pedidos' and a ilike '%preco%'));

-- Recebimento
select pg_temp.como('estagiario');
select pg_temp.receber('recebe', pg_temp.pegar('pedido'), jsonb_build_array(jsonb_build_object('item_id', pg_temp.pegar('item'), 'nome', 'Cimento', 'unidade', 'saco', 'quantidade', 30)), '  Faltaram 20 sacos  ');
select pg_temp.receber('de fora', null, '[{"nome": "Areia", "unidade": "m3", "quantidade": 2}]');
select pg_temp.receber('sem itens', null, '[]');
select pg_temp.receber('sem nome no item', null, '[{"nome": " ", "unidade": "m3", "quantidade": 2}]');
select pg_temp.receber('quantidade errada', null, '[{"nome": "x", "unidade": "m3", "quantidade": 0}]');
select pg_temp.receber('pedido cancelado', pg_temp.pegar('cancelado'), '[{"nome": "x", "unidade": "m3", "quantidade": 1}]');
select pg_temp.receber('pedido alheio', pg_temp.pegar('pedido alheio'), '[{"nome": "x", "unidade": "m3", "quantidade": 1}]');
select pg_temp.tentar('futuro', format('select public.registrar_recebimento(%L, null, %L, %L)', pg_temp.pegar('O'), '[{"nome": "x", "unidade": "m3", "quantidade": 1}]', (now() + interval '9 days')::date));
select pg_temp.tentar('foto alheia', format('select public.registrar_recebimento(%L, null, %L, null, null, %L)', pg_temp.pegar('O'), '[{"nome": "x", "unidade": "m3", "quantidade": 1}]', '00000000-0000-0000-0000-0000000b0002/a.jpg'));
select pg_temp.guardar('rec estagiario', (select id::text from public.obra_recebimentos where nome = 'Areia'));
select pg_temp.como('empreiteiro');
select pg_temp.receber('empreiteiro recebe', null, '[{"nome": "x", "unidade": "m3", "quantidade": 1}]');
select pg_temp.guardar('empreiteiro le rec', (select count(*)::text from public.obra_recebimentos));
select pg_temp.como('cliente');
select pg_temp.receber('cliente recebe', null, '[{"nome": "x", "unidade": "m3", "quantidade": 1}]');
select pg_temp.como('fora');
select pg_temp.receber('fora recebe', null, '[{"nome": "x", "unidade": "m3", "quantidade": 1}]');
select pg_temp.guardar('fora le rec', (select count(*)::text from public.obra_recebimentos));
select pg_temp.como('mestre');
select pg_temp.receber('mestre recebe', null, '[{"nome": "Do mestre", "unidade": "m3", "quantidade": 1}]');
select pg_temp.guardar('rec mestre', (select id::text from public.obra_recebimentos where nome = 'Do mestre'));
select pg_temp.como('estagiario');
select pg_temp.tentar('exclui de outro', format('select public.excluir_recebimento(%L)', pg_temp.pegar('rec mestre')));
select pg_temp.tentar('exclui o seu', format('select public.excluir_recebimento(%L)', pg_temp.pegar('rec estagiario')));
select pg_temp.como('mestre');
select pg_temp.tentar('lider exclui', format('select public.excluir_recebimento(%L)', pg_temp.pegar('rec mestre')));
select pg_temp.admin();
select pg_temp.conferir('recebimento guarda pedido, quem e observação limpa',
  pg_temp.pegar('recebe') = 'passou' and (select pedido_id::text = pg_temp.pegar('pedido') and quantidade = 30 and observacao = 'Faltaram 20 sacos' and criado_por = pg_temp.pegar('estagiario')::uuid from public.obra_recebimentos where nome = 'Cimento'), pg_temp.pegar('recebe'));
select pg_temp.conferir('compra de fora entra sem pedido', pg_temp.pegar('de fora') = 'passou', pg_temp.pegar('de fora'));
select pg_temp.conferir('lista vazia', pg_temp.pegar('sem itens') = 'Informe pelo menos um material.', pg_temp.pegar('sem itens'));
select pg_temp.conferir('item sem nome', pg_temp.pegar('sem nome no item') = 'Informe o material e a unidade.', pg_temp.pegar('sem nome no item'));
select pg_temp.conferir('quantidade zero', pg_temp.pegar('quantidade errada') = 'Digite uma quantidade maior que zero.', pg_temp.pegar('quantidade errada'));
select pg_temp.conferir('pedido cancelado não recebe', pg_temp.pegar('pedido cancelado') = 'Pedido não encontrado nesta obra.', pg_temp.pegar('pedido cancelado'));
select pg_temp.conferir('pedido de outra obra não recebe', pg_temp.pegar('pedido alheio') = 'Pedido não encontrado nesta obra.', pg_temp.pegar('pedido alheio'));
select pg_temp.conferir('data no futuro', pg_temp.pegar('futuro') = 'A data não pode estar no futuro.', pg_temp.pegar('futuro'));
select pg_temp.conferir('foto de outra obra', pg_temp.pegar('foto alheia') = 'Foto de outra obra.', pg_temp.pegar('foto alheia'));
select pg_temp.conferir('quem não cuida das compras não registra',
  pg_temp.pegar('empreiteiro recebe') = 'Só quem cuida das compras registra o que chegou.'
  and pg_temp.pegar('cliente recebe') = 'Só quem cuida das compras registra o que chegou.'
  and pg_temp.pegar('fora recebe') = 'Só quem cuida das compras registra o que chegou.', pg_temp.pegar('cliente recebe'));
select pg_temp.conferir('quem não cuida das compras não lê', pg_temp.pegar('empreiteiro le rec') = '0' and pg_temp.pegar('fora le rec') = '0', pg_temp.pegar('empreiteiro le rec'));
select pg_temp.conferir('estagiário não exclui o de outro', pg_temp.pegar('exclui de outro') = 'Só quem registrou ou quem lidera a obra exclui.', pg_temp.pegar('exclui de outro'));
select pg_temp.conferir('cada um exclui o seu', pg_temp.pegar('exclui o seu') = 'passou', pg_temp.pegar('exclui o seu'));
select pg_temp.conferir('quem lidera exclui', pg_temp.pegar('lider exclui') = 'passou', pg_temp.pegar('lider exclui'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
