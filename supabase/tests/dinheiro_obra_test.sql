-- Testes do dinheiro da obra (migração dinheiro_obra). Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro
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
create function pg_temp.gasto(k text, dados jsonb) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.salvar_gasto(%L, null, %L)', pg_temp.pegar('O'), dados)) $$;

select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');
select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('mestre2', '00000000-0000-0000-0000-00000000a007');
select pg_temp.guardar('estagiario', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('empreiteiro', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('cliente', '00000000-0000-0000-0000-00000000a005');
select pg_temp.guardar('fora', '00000000-0000-0000-0000-00000000a006');

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.chave <> 'O';
insert into public.profiles (id, nome) values ('00000000-0000-0000-0000-00000000a002', 'João Mestre')
on conflict (id) do update set nome = excluded.nome;
insert into public.obras (id, nome, created_by) values
  ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000b0002', 'Outra obra', '00000000-0000-0000-0000-00000000a006');
insert into public.obra_membros (obra_id, user_id, papel, funcao) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a002', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a007', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'membro', 'estagiario'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a004', 'membro', 'empreiteiro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente');

-- Lançar
select pg_temp.como('mestre');
select pg_temp.guardar('g mestre', (select public.salvar_gasto(pg_temp.pegar('O')::uuid, null, jsonb_build_object(
  'descricao', '  Areia  ', 'valor', 150.555, 'data', '2026-11-02', 'etapa', 'alvenaria', 'tipo', 'material', 'fornecedor', '  Depósito  ',
  'nota_path', pg_temp.pegar('O') || '/a.jpg'))::text));
select pg_temp.gasto('sem texto', '{"descricao": "  ", "valor": 10, "data": "2026-11-02"}');
select pg_temp.gasto('sem valor', '{"descricao": "x", "data": "2026-11-02"}');
select pg_temp.gasto('valor zero', '{"descricao": "x", "valor": 0, "data": "2026-11-02"}');
select pg_temp.gasto('valor negativo', '{"descricao": "x", "valor": -5, "data": "2026-11-02"}');
select pg_temp.gasto('sem data', '{"descricao": "x", "valor": 10}');
select pg_temp.gasto('futuro', jsonb_build_object('descricao', 'x', 'valor', 10, 'data', (now() + interval '9 days')::date));
select pg_temp.gasto('nota alheia', '{"descricao": "x", "valor": 10, "data": "2026-11-02", "nota_path": "00000000-0000-0000-0000-0000000b0002/a.jpg"}');
select pg_temp.gasto('tipo errado', '{"descricao": "x", "valor": 10, "data": "2026-11-02", "tipo": "festa"}');
select pg_temp.como('mestre2');
select pg_temp.guardar('g mestre2', (select public.salvar_gasto(pg_temp.pegar('O')::uuid, null, '{"descricao": "Do outro mestre", "valor": 30, "data": "2026-11-03", "tipo": "mao_de_obra"}'::jsonb)::text));
select pg_temp.como('dono');
select pg_temp.guardar('g dono', (select public.salvar_gasto(pg_temp.pegar('O')::uuid, null, '{"descricao": "Do responsável", "valor": 70, "data": "2026-11-04"}'::jsonb)::text));
select pg_temp.como('estagiario');
select pg_temp.gasto('estagiario lanca', '{"descricao": "x", "valor": 10, "data": "2026-11-02"}');
select pg_temp.como('empreiteiro');
select pg_temp.gasto('empreiteiro lanca', '{"descricao": "x", "valor": 10, "data": "2026-11-02"}');
select pg_temp.como('cliente');
select pg_temp.gasto('cliente lanca', '{"descricao": "x", "valor": 10, "data": "2026-11-02"}');
select pg_temp.como('fora');
select pg_temp.gasto('fora lanca', '{"descricao": "x", "valor": 10, "data": "2026-11-02"}');
select pg_temp.admin();
select pg_temp.conferir('gasto guarda tudo, arredonda e limpa os espaços',
  (select valor = 150.56 and descricao = 'Areia' and fornecedor = 'Depósito' and etapa = 'alvenaria' and criado_por = pg_temp.pegar('mestre')::uuid from public.obra_gastos where id = pg_temp.pegar('g mestre')::uuid));
select pg_temp.conferir('sem descrição', pg_temp.pegar('sem texto') = 'Diga o que foi pago.', pg_temp.pegar('sem texto'));
select pg_temp.conferir('sem valor, zero ou negativo',
  pg_temp.pegar('sem valor') = 'Digite um valor maior que zero.' and pg_temp.pegar('valor zero') = 'Digite um valor maior que zero.' and pg_temp.pegar('valor negativo') = 'Digite um valor maior que zero.', pg_temp.pegar('sem valor'));
select pg_temp.conferir('sem data', pg_temp.pegar('sem data') = 'Escolha a data do gasto.', pg_temp.pegar('sem data'));
select pg_temp.conferir('data no futuro', pg_temp.pegar('futuro') = 'A data do gasto não pode estar no futuro.', pg_temp.pegar('futuro'));
select pg_temp.conferir('nota de outra obra', pg_temp.pegar('nota alheia') = 'Nota de outra obra.', pg_temp.pegar('nota alheia'));
select pg_temp.conferir('tipo fora da lista', pg_temp.pegar('tipo errado') like '%obra_gastos_tipo_check%', pg_temp.pegar('tipo errado'));
select pg_temp.conferir('estagiário não lança', pg_temp.pegar('estagiario lanca') = 'Só o responsável ou o mestre lançam gastos.', pg_temp.pegar('estagiario lanca'));
select pg_temp.conferir('empreiteiro não lança', pg_temp.pegar('empreiteiro lanca') = 'Só o responsável ou o mestre lançam gastos.', pg_temp.pegar('empreiteiro lanca'));
select pg_temp.conferir('cliente não lança', pg_temp.pegar('cliente lanca') = 'Só o responsável ou o mestre lançam gastos.', pg_temp.pegar('cliente lanca'));
select pg_temp.conferir('quem é de fora não lança', pg_temp.pegar('fora lanca') = 'Só o responsável ou o mestre lançam gastos.', pg_temp.pegar('fora lanca'));

-- Pedido feito para a obra entra sozinho; cancelado e de outra obra não
do $$
declare
  loja uuid := (select id from public.lojas limit 1);
  orc uuid;
  orc2 uuid;
  orc3 uuid;
  prop uuid;
  ped uuid;
  dono uuid := '00000000-0000-0000-0000-00000000a001';
begin
  insert into public.orcamentos (construtor_id, obra_id, modo) values (dono, '00000000-0000-0000-0000-0000000b0001', 'pedido') returning id into orc;
  insert into public.orcamentos (construtor_id, obra_id, modo) values (dono, '00000000-0000-0000-0000-0000000b0001', 'pedido') returning id into orc2;
  insert into public.orcamentos (construtor_id, obra_id, modo) values (dono, null, 'pedido') returning id into orc3;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, subtotal_anunciado, total, valida_ate) values (orc, loja, dono, 'pedido', 1000, 1000, now() + interval '1 day') returning id into prop;
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total) values (prop, loja, dono, 1000) returning id into ped;
  perform pg_temp.guardar('pedido', ped::text);
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, subtotal_anunciado, total, valida_ate) values (orc2, loja, dono, 'pedido', 500, 500, now() + interval '1 day') returning id into prop;
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status) values (prop, loja, dono, 500, 'cancelado');
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, subtotal_anunciado, total, valida_ate) values (orc3, loja, dono, 'pedido', 700, 700, now() + interval '1 day') returning id into prop;
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total) values (prop, loja, dono, 700);
end $$;

-- Ver
select pg_temp.como('dono');
select pg_temp.guardar('dono ve', (select string_agg(origem || ':' || valor::text, ',' order by valor) from public.lancamentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('autor', (select autor from public.lancamentos_da_obra(pg_temp.pegar('O')::uuid) where id = pg_temp.pegar('g mestre')::uuid));
select pg_temp.guardar('dono mexe', (select bool_and(posso_mexer)::text from public.lancamentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('dono tabela', (select count(*)::text from public.obra_gastos));
select pg_temp.como('mestre');
select pg_temp.guardar('mestre ve', (select string_agg(descricao, ',') from public.lancamentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('mestre tabela', (select count(*)::text from public.obra_gastos));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario ve', format('select public.lancamentos_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.guardar('estagiario tabela', (select count(*)::text from public.obra_gastos));
select pg_temp.como('empreiteiro');
select pg_temp.tentar('empreiteiro ve', format('select public.lancamentos_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.como('cliente');
select pg_temp.tentar('cliente ve', format('select public.lancamentos_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.guardar('cliente tabela', (select count(*)::text from public.obra_gastos));
select pg_temp.como('fora');
select pg_temp.tentar('fora ve', format('select public.lancamentos_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.admin();
select pg_temp.conferir('responsável vê gastos e pedidos da obra, sem cancelado nem de outra obra',
  pg_temp.pegar('dono ve') = 'gasto:30.00,gasto:70.00,gasto:150.56,pedido:1000.00', pg_temp.pegar('dono ve'));
select pg_temp.conferir('lançamento mostra quem lançou', pg_temp.pegar('autor') = 'João Mestre', pg_temp.pegar('autor'));
select pg_temp.conferir('responsável mexe em tudo', pg_temp.pegar('dono mexe') = 'true', pg_temp.pegar('dono mexe'));
select pg_temp.conferir('mestre vê só o que lançou', pg_temp.pegar('mestre ve') = 'Areia' and pg_temp.pegar('mestre tabela') = '1', pg_temp.pegar('mestre ve'));
select pg_temp.conferir('tabela do responsável traz tudo', pg_temp.pegar('dono tabela') = '3', pg_temp.pegar('dono tabela'));
select pg_temp.conferir('estagiário não vê', pg_temp.pegar('estagiario ve') = 'Obra não encontrada.' and pg_temp.pegar('estagiario tabela') = '0', pg_temp.pegar('estagiario ve'));
select pg_temp.conferir('empreiteiro não vê', pg_temp.pegar('empreiteiro ve') = 'Obra não encontrada.', pg_temp.pegar('empreiteiro ve'));
select pg_temp.conferir('cliente não vê', pg_temp.pegar('cliente ve') = 'Obra não encontrada.' and pg_temp.pegar('cliente tabela') = '0', pg_temp.pegar('cliente ve'));
select pg_temp.conferir('quem é de fora não vê', pg_temp.pegar('fora ve') = 'Obra não encontrada.', pg_temp.pegar('fora ve'));

-- Alterar e excluir
select pg_temp.como('mestre');
select pg_temp.tentar('mestre altera o seu', format('select public.salvar_gasto(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('g mestre'), jsonb_build_object('descricao', 'Areia lavada', 'valor', 200, 'data', '2026-11-02', 'nota_path', pg_temp.pegar('O') || '/a.jpg')));
select pg_temp.tentar('mestre altera o do outro', format('select public.salvar_gasto(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('g mestre2'), '{"descricao": "Mudei", "valor": 1, "data": "2026-11-02"}'));
select pg_temp.tentar('mestre exclui o do outro', format('select public.excluir_gasto(%L)', pg_temp.pegar('g mestre2')));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario exclui', format('select public.excluir_gasto(%L)', pg_temp.pegar('g mestre')));
select pg_temp.como('cliente');
select pg_temp.tentar('cliente exclui', format('select public.excluir_gasto(%L)', pg_temp.pegar('g mestre')));
select pg_temp.como('dono');
select pg_temp.tentar('dono altera o do mestre', format('select public.salvar_gasto(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('g mestre2'), '{"descricao": "Corrigido", "valor": 35, "data": "2026-11-03"}'));
select pg_temp.como('mestre');
select pg_temp.guardar('exclui', (select public.excluir_gasto(pg_temp.pegar('g mestre')::uuid)));
select pg_temp.admin();
select pg_temp.conferir('mestre altera o que lançou', pg_temp.pegar('mestre altera o seu') = 'passou', pg_temp.pegar('mestre altera o seu'));
select pg_temp.conferir('mestre não altera o de outro', pg_temp.pegar('mestre altera o do outro') = 'Gasto não encontrado.', pg_temp.pegar('mestre altera o do outro'));
select pg_temp.conferir('mestre não exclui o de outro', pg_temp.pegar('mestre exclui o do outro') = 'Gasto não encontrado.', pg_temp.pegar('mestre exclui o do outro'));
select pg_temp.conferir('estagiário e cliente não excluem', pg_temp.pegar('estagiario exclui') = 'Gasto não encontrado.' and pg_temp.pegar('cliente exclui') = 'Gasto não encontrado.', pg_temp.pegar('cliente exclui'));
select pg_temp.conferir('responsável altera qualquer um', pg_temp.pegar('dono altera o do mestre') = 'passou' and (select valor = 35 from public.obra_gastos where id = pg_temp.pegar('g mestre2')::uuid), pg_temp.pegar('dono altera o do mestre'));
select pg_temp.conferir('excluir devolve a nota para apagar', pg_temp.pegar('exclui') = pg_temp.pegar('O') || '/a.jpg', pg_temp.pegar('exclui'));

-- Quem sai da equipe perde o acesso ao que lançou
select pg_temp.como('mestre2');
select pg_temp.guardar('antes de sair', (select count(*)::text from public.lancamentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.admin();
delete from public.obra_membros where user_id = pg_temp.pegar('mestre2')::uuid;
select pg_temp.como('mestre2');
select pg_temp.tentar('depois de sair', format('select public.lancamentos_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.guardar('tabela depois de sair', (select count(*)::text from public.obra_gastos));
select pg_temp.tentar('exclui depois de sair', format('select public.excluir_gasto(%L)', pg_temp.pegar('g mestre2')));
select pg_temp.admin();
select pg_temp.conferir('quem saiu não vê mais', pg_temp.pegar('antes de sair') = '1' and pg_temp.pegar('depois de sair') = 'Obra não encontrada.' and pg_temp.pegar('tabela depois de sair') = '0', pg_temp.pegar('depois de sair'));
select pg_temp.conferir('quem saiu não mexe mais', pg_temp.pegar('exclui depois de sair') = 'Gasto não encontrado.', pg_temp.pegar('exclui depois de sair'));

-- Orçado próprio
select pg_temp.como('dono');
select pg_temp.tentar('define', format('select public.definir_orcado(%L, %L, %s)', pg_temp.pegar('O'), 'alvenaria', 5000.555));
select pg_temp.tentar('redefine', format('select public.definir_orcado(%L, %L, %s)', pg_temp.pegar('O'), 'pintura', 800));
select pg_temp.tentar('negativo', format('select public.definir_orcado(%L, %L, %s)', pg_temp.pegar('O'), 'pintura', -1));
select pg_temp.tentar('volta', format('select public.definir_orcado(%L, %L, null)', pg_temp.pegar('O'), 'pintura'));
select pg_temp.guardar('dono le orcado', (select string_agg(etapa || ':' || valor, ',') from public.obra_orcado));
select pg_temp.como('mestre');
select pg_temp.tentar('mestre define', format('select public.definir_orcado(%L, %L, 1)', pg_temp.pegar('O'), 'alvenaria'));
select pg_temp.guardar('mestre le orcado', (select count(*)::text from public.obra_orcado));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente le orcado', (select count(*)::text from public.obra_orcado));
select pg_temp.admin();
select pg_temp.conferir('responsável define, arredonda e volta para a estimativa', pg_temp.pegar('dono le orcado') = 'alvenaria:5000.56', pg_temp.pegar('dono le orcado'));
select pg_temp.conferir('orçado negativo', pg_temp.pegar('negativo') = 'O valor orçado não pode ser negativo.', pg_temp.pegar('negativo'));
select pg_temp.conferir('só o responsável define o orçado', pg_temp.pegar('mestre define') = 'Só o responsável muda o valor orçado.', pg_temp.pegar('mestre define'));
select pg_temp.conferir('orçado próprio é só do responsável', pg_temp.pegar('mestre le orcado') = '0' and pg_temp.pegar('cliente le orcado') = '0', pg_temp.pegar('mestre le orcado'));

-- Pedido na etapa
select pg_temp.como('dono');
select pg_temp.tentar('classifica', format('select public.classificar_pedido(%L, %L)', pg_temp.pegar('pedido'), 'alvenaria'));
select pg_temp.guardar('etapa do pedido', (select etapa from public.lancamentos_da_obra(pg_temp.pegar('O')::uuid) where origem = 'pedido'));
select pg_temp.tentar('tira', format('select public.classificar_pedido(%L, null)', pg_temp.pegar('pedido')));
select pg_temp.guardar('sem etapa', coalesce((select etapa from public.lancamentos_da_obra(pg_temp.pegar('O')::uuid) where origem = 'pedido'), 'nenhuma'));
select pg_temp.como('mestre');
select pg_temp.tentar('mestre classifica', format('select public.classificar_pedido(%L, %L)', pg_temp.pegar('pedido'), 'alvenaria'));
select pg_temp.como('fora');
select pg_temp.tentar('fora classifica', format('select public.classificar_pedido(%L, %L)', pg_temp.pegar('pedido'), 'alvenaria'));
select pg_temp.guardar('fora le', (select count(*)::text from public.pedido_etapas));
select pg_temp.admin();
select pg_temp.conferir('responsável coloca o pedido na etapa', pg_temp.pegar('classifica') = 'passou' and pg_temp.pegar('etapa do pedido') = 'alvenaria', pg_temp.pegar('classifica'));
select pg_temp.conferir('responsável tira o pedido da etapa', pg_temp.pegar('sem etapa') = 'nenhuma', pg_temp.pegar('sem etapa'));
select pg_temp.conferir('mestre não classifica pedido', pg_temp.pegar('mestre classifica') = 'Pedido não encontrado.', pg_temp.pegar('mestre classifica'));
select pg_temp.conferir('quem é de fora não classifica', pg_temp.pegar('fora classifica') = 'Pedido não encontrado.' and pg_temp.pegar('fora le') = '0', pg_temp.pegar('fora classifica'));

-- Foto da nota
select pg_temp.como('mestre');
select pg_temp.tentar('mestre envia nota', format($q$insert into storage.objects (bucket_id, name, owner_id) values ('obra-notas', %L, %L)$q$, pg_temp.pegar('O') || '/mestre.jpg', pg_temp.pegar('mestre')));
select pg_temp.guardar('mestre le nota', (select count(*)::text from storage.objects where bucket_id = 'obra-notas'));
select pg_temp.como('dono');
select pg_temp.tentar('dono envia nota', format($q$insert into storage.objects (bucket_id, name, owner_id) values ('obra-notas', %L, %L)$q$, pg_temp.pegar('O') || '/dono.jpg', pg_temp.pegar('dono')));
select pg_temp.guardar('dono le notas', (select count(*)::text from storage.objects where bucket_id = 'obra-notas'));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario envia nota', format($q$insert into storage.objects (bucket_id, name, owner_id) values ('obra-notas', %L, %L)$q$, pg_temp.pegar('O') || '/e.jpg', pg_temp.pegar('estagiario')));
select pg_temp.guardar('estagiario le notas', (select count(*)::text from storage.objects where bucket_id = 'obra-notas'));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente le notas', (select count(*)::text from storage.objects where bucket_id = 'obra-notas'));
select pg_temp.como('empreiteiro');
select pg_temp.guardar('empreiteiro le notas', (select count(*)::text from storage.objects where bucket_id = 'obra-notas'));
select pg_temp.admin();
select pg_temp.conferir('mestre envia e vê a nota que enviou', pg_temp.pegar('mestre envia nota') = 'passou' and pg_temp.pegar('mestre le nota') = '1', pg_temp.pegar('mestre envia nota'));
select pg_temp.conferir('responsável vê todas as notas', pg_temp.pegar('dono envia nota') = 'passou' and pg_temp.pegar('dono le notas') = '2', pg_temp.pegar('dono le notas'));
select pg_temp.conferir('estagiário não envia nem vê nota', pg_temp.pegar('estagiario envia nota') like '%row-level security%' and pg_temp.pegar('estagiario le notas') = '0', pg_temp.pegar('estagiario envia nota'));
select pg_temp.conferir('cliente e empreiteiro não veem nota', pg_temp.pegar('cliente le notas') = '0' and pg_temp.pegar('empreiteiro le notas') = '0', pg_temp.pegar('cliente le notas'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
