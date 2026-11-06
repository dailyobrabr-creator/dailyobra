-- Testes do Retail Media (migração retail_media). Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro
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
create function pg_temp.d(dias int) returns date language sql as $$ select private.hoje_no_brasil() + dias $$;
-- Comando que salva um anúncio da loja guardada em v
create function pg_temp.salvar(loja text, id text, tipo text, titulo text, imagem text, item text, inicio date, fim date) returns text language sql as $$
  select format('select pg_temp.guardar(%L, public.salvar_anuncio(%L, %L, %L, %L, %L, %L, %L, %L)::text)',
                'ultimo', pg_temp.pegar(loja), id, tipo, titulo, imagem, item, inicio, fim) $$;
create function pg_temp.imagem(loja text) returns text language sql as $$ select pg_temp.pegar(loja) || '/anuncio-1.jpg' $$;

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
select pg_temp.guardar('item', (select id from public.catalogo_itens order by id limit 1));
select pg_temp.guardar('item2', (select id from public.catalogo_itens order by id offset 1 limit 1));
select pg_temp.guardar('item3', (select id from public.catalogo_itens order by id offset 2 limit 1));
insert into public.ofertas (loja_id, item_id, preco) values (pg_temp.pegar('A')::uuid, pg_temp.pegar('item'), 50);
insert into public.ofertas (loja_id, item_id, preco, pausada) values (pg_temp.pegar('A')::uuid, pg_temp.pegar('item2'), 50, true);

-- Quem cria
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.tentar('vendedor', pg_temp.salvar('A', null, 'banner', 'Campanha', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('vendedor não cria', pg_temp.pegar('vendedor') = 'Só o dono ou o gerente da loja cuidam dos anúncios.', pg_temp.pegar('vendedor'));
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.tentar('outra', pg_temp.salvar('A', null, 'banner', 'Campanha', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('outra loja não cria', pg_temp.pegar('outra') = 'Só o dono ou o gerente da loja cuidam dos anúncios.', pg_temp.pegar('outra'));

-- Validações
select pg_temp.como('00000000-0000-0000-0000-00000000e002');
select pg_temp.tentar('t1', pg_temp.salvar('A', null, 'video', 'Campanha', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('tipo inválido', pg_temp.pegar('t1') = 'Escolha o tipo do anúncio.', pg_temp.pegar('t1'));
select pg_temp.tentar('t2', pg_temp.salvar('A', null, 'banner', ' a ', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('título curto', pg_temp.pegar('t2') = 'O título do anúncio tem de 3 a 60 caracteres.', pg_temp.pegar('t2'));
select pg_temp.tentar('t3', pg_temp.salvar('A', null, 'banner', repeat('x', 61), pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('título longo', pg_temp.pegar('t3') = 'O título do anúncio tem de 3 a 60 caracteres.', pg_temp.pegar('t3'));
select pg_temp.tentar('t4', pg_temp.salvar('A', null, 'banner', 'Campanha', pg_temp.imagem('A'), null, pg_temp.d(5), pg_temp.d(0)));
select pg_temp.conferir('datas invertidas', pg_temp.pegar('t4') = 'Confira as datas do anúncio.', pg_temp.pegar('t4'));
select pg_temp.tentar('t5', pg_temp.salvar('A', null, 'banner', 'Campanha', pg_temp.imagem('A'), null, pg_temp.d(-9), pg_temp.d(-1)));
select pg_temp.conferir('fim no passado', pg_temp.pegar('t5') = 'O fim do anúncio já passou.', pg_temp.pegar('t5'));
select pg_temp.tentar('t6', pg_temp.salvar('A', null, 'banner', 'Campanha', null, null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('banner sem imagem', pg_temp.pegar('t6') = 'Envie a imagem do banner.', pg_temp.pegar('t6'));
select pg_temp.tentar('t7', pg_temp.salvar('A', null, 'banner', 'Campanha', pg_temp.imagem('B'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('imagem de outra loja', pg_temp.pegar('t7') = 'Envie a imagem do banner.', pg_temp.pegar('t7'));
select pg_temp.tentar('t8', pg_temp.salvar('A', null, 'destaque', 'Campanha', null, pg_temp.pegar('item3'), pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('destaque sem preço', pg_temp.pegar('t8') = 'Coloque preço neste produto antes de anunciar.', pg_temp.pegar('t8'));
select pg_temp.tentar('t9', pg_temp.salvar('A', null, 'destaque', 'Campanha', null, pg_temp.pegar('item2'), pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('destaque com preço pausado', pg_temp.pegar('t9') = 'Coloque preço neste produto antes de anunciar.', pg_temp.pegar('t9'));

-- Criar
select pg_temp.tentar('c1', pg_temp.salvar('A', null, 'banner', '  Semana do piso  ', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('gerente cria banner', pg_temp.pegar('c1') = 'ok', pg_temp.pegar('c1'));
select pg_temp.guardar('banner', pg_temp.pegar('ultimo'));
select pg_temp.tentar('c2', pg_temp.salvar('A', null, 'destaque', 'Cimento', null, pg_temp.pegar('item'), pg_temp.d(-3), pg_temp.d(5)));
select pg_temp.conferir('gerente cria destaque', pg_temp.pegar('c2') = 'ok', pg_temp.pegar('c2'));
select pg_temp.guardar('destaque', pg_temp.pegar('ultimo'));
select pg_temp.conferir('tira os espaços do título', (select titulo from public.anuncios where id = pg_temp.pegar('banner')::uuid) = 'Semana do piso');

-- Limite de três ao mesmo tempo
select pg_temp.tentar('l1', pg_temp.salvar('A', null, 'banner', 'Segundo', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.tentar('l2', pg_temp.salvar('A', null, 'banner', 'Terceiro', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.guardar('terceiro', pg_temp.pegar('ultimo'));
select pg_temp.tentar('l3', pg_temp.salvar('A', null, 'banner', 'Quarto', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('quarto banner recusado', pg_temp.pegar('l3') = 'A loja pode ter até 3 anúncios deste tipo ao mesmo tempo.', pg_temp.pegar('l3'));
select pg_temp.tentar('l4', pg_temp.salvar('A', null, 'banner', 'Depois', pg_temp.imagem('A'), null, pg_temp.d(10), pg_temp.d(15)));
select pg_temp.conferir('outro período pode', pg_temp.pegar('l4') = 'ok', pg_temp.pegar('l4'));
select pg_temp.guardar('agendado', pg_temp.pegar('ultimo'));

-- Editar
select pg_temp.tentar('e1', pg_temp.salvar('A', pg_temp.pegar('banner'), 'banner', 'Semana nova', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(6)));
select pg_temp.conferir('edita sem contar a si mesmo no limite', pg_temp.pegar('e1') = 'ok', pg_temp.pegar('e1'));
select pg_temp.conferir('título alterado', (select titulo from public.anuncios where id = pg_temp.pegar('banner')::uuid) = 'Semana nova');
select pg_temp.tentar('e2', pg_temp.salvar('A', pg_temp.pegar('banner'), 'destaque', 'Semana nova', null, pg_temp.pegar('item'), pg_temp.d(0), pg_temp.d(6)));
select pg_temp.conferir('tipo não muda', pg_temp.pegar('e2') = 'O tipo do anúncio não muda depois de criado.', pg_temp.pegar('e2'));
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.tentar('e3', pg_temp.salvar('B', pg_temp.pegar('banner'), 'banner', 'Roubado', pg_temp.imagem('B'), null, pg_temp.d(0), pg_temp.d(6)));
select pg_temp.conferir('outra loja não edita', pg_temp.pegar('e3') = 'Anúncio não encontrado.', pg_temp.pegar('e3'));

-- Direto na tabela, nem o dono
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.tentar('x1', 'delete from public.anuncios');
select pg_temp.conferir('dono não apaga direto', pg_temp.pegar('x1') <> 'ok', pg_temp.pegar('x1'));
select pg_temp.tentar('x2', format('insert into public.anuncio_metricas (anuncio_id, dia, impressoes) values (%L, current_date, 999)', pg_temp.pegar('banner')));
select pg_temp.conferir('dono não inventa métrica', pg_temp.pegar('x2') <> 'ok', pg_temp.pegar('x2'));
select pg_temp.tentar('x3', format('update public.anuncios set fim = fim + 100 where id = %L', pg_temp.pegar('banner')));
select pg_temp.conferir('dono não altera direto', pg_temp.pegar('x3') <> 'ok', pg_temp.pegar('x3'));

-- Quem vê
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.conferir('construtor vê o que está no ar', (select count(*) from public.anuncios where id = pg_temp.pegar('banner')::uuid) = 1);
select pg_temp.conferir('construtor não vê o agendado', (select count(*) from public.anuncios where id = pg_temp.pegar('agendado')::uuid) = 0);
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.conferir('vendedor vê o agendado', (select count(*) from public.anuncios where id = pg_temp.pegar('agendado')::uuid) = 1);

-- Eventos
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select public.registrar_evento_anuncio(pg_temp.pegar('destaque')::uuid, 'impressao');
select public.registrar_evento_anuncio(pg_temp.pegar('destaque')::uuid, 'impressao');
select public.registrar_evento_anuncio(pg_temp.pegar('destaque')::uuid, 'clique');
select public.registrar_evento_anuncio(pg_temp.pegar('agendado')::uuid, 'impressao');
select pg_temp.tentar('ev', format('select public.registrar_evento_anuncio(%L, %L)', pg_temp.pegar('destaque'), 'venda'));
select pg_temp.conferir('evento inválido recusado', pg_temp.pegar('ev') = 'Evento inválido.', pg_temp.pegar('ev'));
select pg_temp.conferir('construtor não lê a métrica', (select count(*) from public.anuncio_metricas) = 0);
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select public.registrar_evento_anuncio(pg_temp.pegar('destaque')::uuid, 'impressao');

-- Vendas durante o anúncio: 3 dentro, cancelado e antes do período ficam de fora
select pg_temp.admin();
create function pg_temp.venda(loja uuid, item text, quantidade numeric, status_pedido text, quando timestamptz) returns void language plpgsql as $$
declare orc uuid; prop uuid; construtor uuid := '00000000-0000-0000-0000-00000000c001';
begin
  insert into public.orcamentos (construtor_id, modo) values (construtor, 'pedido') returning id into orc;
  insert into public.propostas (orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, total, valida_ate, criada_em)
  values (orc, loja, construtor, 'pedido', 'aceita', 100, 100, quando + interval '7 days', quando) returning id into prop;
  insert into public.proposta_itens (proposta_id, item_id, nome, unidade, tier, quantidade, preco_anunciado)
  values (prop, item, 'Produto', 'un', 1, quantidade, 10);
  insert into public.pedidos (proposta_id, loja_id, construtor_id, total, status, criado_em)
  values (prop, loja, construtor, 100, status_pedido, quando);
end $$;
select pg_temp.venda(pg_temp.pegar('A')::uuid, pg_temp.pegar('item'), 3, 'entregue', now() - interval '1 day');
select pg_temp.venda(pg_temp.pegar('A')::uuid, pg_temp.pegar('item'), 50, 'cancelado', now() - interval '1 day');
select pg_temp.venda(pg_temp.pegar('A')::uuid, pg_temp.pegar('item'), 70, 'entregue', now() - interval '30 days');

create function pg_temp.do_anuncio(k text, campo text) returns text language sql as $$
  select e ->> campo from jsonb_array_elements(pg_temp.pegar('lista')::jsonb) e where e ->> 'id' = pg_temp.pegar(k) $$;
-- Resultado para a loja
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.tentar('v1', format('select public.anuncios_da_loja(%L)', pg_temp.pegar('A')));
select pg_temp.conferir('vendedor não vê resultados', pg_temp.pegar('v1') = 'Só o dono ou o gerente da loja cuidam dos anúncios.', pg_temp.pegar('v1'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('lista', public.anuncios_da_loja(pg_temp.pegar('A')::uuid)::text);
select pg_temp.conferir('soma as impressões sem a equipe', pg_temp.do_anuncio('destaque', 'impressoes') = '2', pg_temp.do_anuncio('destaque', 'impressoes'));
select pg_temp.conferir('soma os cliques', pg_temp.do_anuncio('destaque', 'cliques') = '1', pg_temp.do_anuncio('destaque', 'cliques'));
select pg_temp.conferir('agendado não conta', pg_temp.do_anuncio('agendado', 'impressoes') = '0', pg_temp.do_anuncio('agendado', 'impressoes'));
select pg_temp.conferir('vendidos só no período e sem cancelado', pg_temp.do_anuncio('destaque', 'vendidos')::numeric = 3, pg_temp.do_anuncio('destaque', 'vendidos'));
select pg_temp.conferir('banner não tem vendidos', pg_temp.do_anuncio('banner', 'vendidos') is null);
select pg_temp.conferir('traz o nome do produto', pg_temp.do_anuncio('destaque', 'item_nome') is not null);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.tentar('v2', format('select public.anuncios_da_loja(%L)', pg_temp.pegar('A')));
select pg_temp.conferir('outra loja não vê resultados', pg_temp.pegar('v2') = 'Só o dono ou o gerente da loja cuidam dos anúncios.', pg_temp.pegar('v2'));

-- Pausar
select pg_temp.tentar('p1', format('select public.pausar_anuncio(%L, true)', pg_temp.pegar('banner')));
select pg_temp.conferir('outra loja não pausa', pg_temp.pegar('p1') = 'Anúncio não encontrado.', pg_temp.pegar('p1'));
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.tentar('p2', format('select public.pausar_anuncio(%L, true)', pg_temp.pegar('banner')));
select pg_temp.conferir('vendedor não pausa', pg_temp.pegar('p2') = 'Só o dono ou o gerente da loja cuidam dos anúncios.', pg_temp.pegar('p2'));
select pg_temp.como('00000000-0000-0000-0000-00000000e002');
select public.pausar_anuncio(pg_temp.pegar('banner')::uuid, true);
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.conferir('pausado some para o construtor', (select count(*) from public.anuncios where id = pg_temp.pegar('banner')::uuid) = 0);
select public.registrar_evento_anuncio(pg_temp.pegar('banner')::uuid, 'impressao');
select pg_temp.como('00000000-0000-0000-0000-00000000e002');
select pg_temp.tentar('l5', pg_temp.salvar('A', null, 'banner', 'Vaga aberta', pg_temp.imagem('A'), null, pg_temp.d(0), pg_temp.d(5)));
select pg_temp.conferir('pausado libera a vaga', pg_temp.pegar('l5') = 'ok', pg_temp.pegar('l5'));
select pg_temp.tentar('p3', format('select public.pausar_anuncio(%L, false)', pg_temp.pegar('banner')));
select pg_temp.conferir('retomar respeita o limite', pg_temp.pegar('p3') = 'A loja pode ter até 3 anúncios deste tipo ao mesmo tempo.', pg_temp.pegar('p3'));
select pg_temp.admin();
select pg_temp.conferir('pausado não conta impressão', (select count(*) from public.anuncio_metricas where anuncio_id = pg_temp.pegar('banner')::uuid) = 0);

-- Loja suspensa: só o suporte muda o status, então o teste entra como ele
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
update public.lojas set status = 'suspensa' where id = pg_temp.pegar('A')::uuid;
select pg_temp.como('00000000-0000-0000-0000-00000000c001');
select pg_temp.conferir('loja suspensa some', (select count(*) from public.anuncios where loja_id = pg_temp.pegar('A')::uuid) = 0);
select pg_temp.admin();
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
update public.lojas set status = 'ativa' where id = pg_temp.pegar('A')::uuid;

-- Excluir
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.tentar('x4', format('select public.excluir_anuncio(%L)', pg_temp.pegar('banner')));
select pg_temp.conferir('vendedor não exclui', pg_temp.pegar('x4') = 'Só o dono ou o gerente da loja cuidam dos anúncios.', pg_temp.pegar('x4'));
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.tentar('x5', format('select public.excluir_anuncio(%L)', pg_temp.pegar('banner')));
select pg_temp.conferir('outra loja não exclui', pg_temp.pegar('x5') = 'Anúncio não encontrado.', pg_temp.pegar('x5'));
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('arquivo', public.excluir_anuncio(pg_temp.pegar('banner')::uuid));
select pg_temp.conferir('devolve o arquivo do banner', pg_temp.pegar('arquivo') = pg_temp.imagem('A'), pg_temp.pegar('arquivo'));
select pg_temp.guardar('sem arquivo', coalesce(public.excluir_anuncio(pg_temp.pegar('destaque')::uuid), 'nulo'));
select pg_temp.conferir('destaque não tem arquivo', pg_temp.pegar('sem arquivo') = 'nulo', pg_temp.pegar('sem arquivo'));
select pg_temp.admin();
select pg_temp.conferir('apaga as métricas junto', (select count(*) from public.anuncio_metricas where anuncio_id = pg_temp.pegar('destaque')::uuid) = 0);

-- Sem sessão
select pg_temp.conferir('anônimo não lê anúncios', not has_table_privilege('anon', 'public.anuncios', 'select'));
select pg_temp.conferir('anônimo não conta evento', not has_function_privilege('anon', 'public.registrar_evento_anuncio(uuid, text)', 'execute'));
select pg_temp.conferir('anônimo não salva', not has_function_privilege('anon', 'public.salvar_anuncio(uuid, uuid, text, text, text, text, date, date)', 'execute'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
