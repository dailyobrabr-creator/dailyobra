-- Testes de marca, mudanças e saída do responsável (migração cliente_obra). Roda numa transação; o bloco final levanta
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
create function pg_temp.mudanca(k text, dados jsonb) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.salvar_mudanca(%L, null, %L)', pg_temp.pegar('O'), dados)) $$;
create function pg_temp.situacao(alvo text) returns text language sql as $$
  select m.situacao from public.obra_mudancas m where m.id = alvo::uuid $$;

select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');
select pg_temp.guardar('O2', '00000000-0000-0000-0000-0000000b0002');
select pg_temp.guardar('O3', '00000000-0000-0000-0000-0000000b0003');
select pg_temp.guardar('O4', '00000000-0000-0000-0000-0000000b0004');
select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('estagiario', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('empreiteiro', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('cliente', '00000000-0000-0000-0000-00000000a005');
select pg_temp.guardar('fora', '00000000-0000-0000-0000-00000000a006');
select pg_temp.guardar('sai', '00000000-0000-0000-0000-00000000a007');

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.chave not like 'O%';
insert into public.profiles (id, nome, empresa, telefone) values
  ('00000000-0000-0000-0000-00000000a001', 'Marina Duarte', 'Duarte Engenharia', '65999990000'),
  ('00000000-0000-0000-0000-00000000a005', 'Dona Lia', null, null)
on conflict (id) do update set nome = excluded.nome, empresa = excluded.empresa, telefone = excluded.telefone;
insert into public.obras (id, nome, created_by) values
  ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000b0002', 'Compartilhada', '00000000-0000-0000-0000-00000000a007'),
  ('00000000-0000-0000-0000-0000000b0003', 'Só com cliente', '00000000-0000-0000-0000-00000000a007'),
  ('00000000-0000-0000-0000-0000000b0004', 'Só dele', '00000000-0000-0000-0000-00000000a007');
insert into public.obra_membros (obra_id, user_id, papel, funcao) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a002', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'membro', 'estagiario'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a004', 'membro', 'empreiteiro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente'),
  ('00000000-0000-0000-0000-0000000b0002', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente'),
  ('00000000-0000-0000-0000-0000000b0002', '00000000-0000-0000-0000-00000000a003', 'membro', 'estagiario'),
  ('00000000-0000-0000-0000-0000000b0002', '00000000-0000-0000-0000-00000000a002', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0003', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente');

-- Marca
select pg_temp.como('cliente');
select pg_temp.guardar('marca sem preencher', (select nome from public.marca_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('dono');
insert into public.construtor_marca (user_id, nome, registro, telefone, email, logo_path)
values (pg_temp.pegar('dono')::uuid, 'Duarte Projetos', 'CREA 1234/D', '65988887777', 'contato@duarte.teste', pg_temp.pegar('dono') || '/logo.png');
select pg_temp.tentar('marca alheia', format($q$insert into public.construtor_marca (user_id, nome) values (%L, 'Falsa')$q$, pg_temp.pegar('cliente')));
select pg_temp.tentar('logo proprio', format($q$insert into storage.objects (bucket_id, name, owner_id) values ('marcas', %L, %L)$q$, pg_temp.pegar('dono') || '/logo.png', pg_temp.pegar('dono')));
select pg_temp.tentar('logo alheio', format($q$insert into storage.objects (bucket_id, name, owner_id) values ('marcas', %L, %L)$q$, pg_temp.pegar('cliente') || '/logo.png', pg_temp.pegar('dono')));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente ve marca', (select nome || '|' || registro || '|' || telefone || '|' || logo_path from public.marca_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('cliente le tabela', (select count(*)::text from public.construtor_marca));
select pg_temp.guardar('cliente le logo', (select count(*)::text from storage.objects where bucket_id = 'marcas'));
select pg_temp.como('fora');
select pg_temp.tentar('fora ve marca', format('select public.marca_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.admin();
select pg_temp.conferir('sem marca usa a empresa do perfil', pg_temp.pegar('marca sem preencher') = 'Duarte Engenharia', pg_temp.pegar('marca sem preencher'));
select pg_temp.conferir('quem está na obra vê a marca do responsável', pg_temp.pegar('cliente ve marca') = 'Duarte Projetos|CREA 1234/D|65988887777|' || pg_temp.pegar('dono') || '/logo.png', pg_temp.pegar('cliente ve marca'));
select pg_temp.conferir('marca só muda pelo dono dela', pg_temp.pegar('marca alheia') like '%row-level security%', pg_temp.pegar('marca alheia'));
select pg_temp.conferir('tabela da marca não abre para os outros', pg_temp.pegar('cliente le tabela') = '0', pg_temp.pegar('cliente le tabela'));
select pg_temp.conferir('cada um envia o próprio logo', pg_temp.pegar('logo proprio') = 'passou', pg_temp.pegar('logo proprio'));
select pg_temp.conferir('ninguém envia logo na pasta de outro', pg_temp.pegar('logo alheio') like '%row-level security%', pg_temp.pegar('logo alheio'));
select pg_temp.conferir('logo se lê para sair no PDF', pg_temp.pegar('cliente le logo') = '1', pg_temp.pegar('cliente le logo'));
select pg_temp.conferir('quem é de fora não vê a marca da obra', pg_temp.pegar('fora ve marca') = 'Obra não encontrada.', pg_temp.pegar('fora ve marca'));

-- Criar mudança
select pg_temp.como('dono');
select pg_temp.guardar('m1', (select public.salvar_mudanca(pg_temp.pegar('O')::uuid, null, '{"titulo": "  Trocar piso da sala  ", "descricao": "  Porcelanato  ", "valor": 3500.555, "dias": 5}'::jsonb)::text));
select pg_temp.guardar('m2', (select public.salvar_mudanca(pg_temp.pegar('O')::uuid, null, '{"titulo": "Tirar a churrasqueira", "valor": -1200}'::jsonb)::text));
select pg_temp.guardar('m3', (select public.salvar_mudanca(pg_temp.pegar('O')::uuid, null, '{"titulo": "Para excluir"}'::jsonb)::text));
select pg_temp.mudanca('sem titulo', '{"titulo": " "}');
select pg_temp.como('mestre');
select pg_temp.mudanca('mestre cria', '{"titulo": "x"}');
select pg_temp.como('cliente');
select pg_temp.mudanca('cliente cria', '{"titulo": "x"}');
select pg_temp.como('fora');
select pg_temp.mudanca('fora cria', '{"titulo": "x"}');
select pg_temp.admin();
select pg_temp.conferir('mudança guarda tudo, arredonda e limpa os espaços',
  (select titulo = 'Trocar piso da sala' and descricao = 'Porcelanato' and valor = 3500.56 and dias = 5 and situacao = 'pendente' from public.obra_mudancas where id = pg_temp.pegar('m1')::uuid));
select pg_temp.conferir('mudança pode reduzir o valor', (select valor = -1200 from public.obra_mudancas where id = pg_temp.pegar('m2')::uuid));
select pg_temp.conferir('mudança sem título', pg_temp.pegar('sem titulo') = 'Diga qual é a mudança.', pg_temp.pegar('sem titulo'));
select pg_temp.conferir('só o responsável pede aprovação',
  pg_temp.pegar('mestre cria') = 'Só o responsável pede a aprovação de uma mudança.' and pg_temp.pegar('cliente cria') = 'Só o responsável pede a aprovação de uma mudança.' and pg_temp.pegar('fora cria') = 'Só o responsável pede a aprovação de uma mudança.', pg_temp.pegar('mestre cria'));

-- Ver
select pg_temp.como('cliente');
select pg_temp.guardar('cliente lista', (select string_agg(titulo || ':' || coalesce(valor::text, '-'), ',' order by titulo) from public.mudancas_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('cliente tabela', (select count(*)::text from public.obra_mudancas));
select pg_temp.como('mestre');
select pg_temp.guardar('mestre lista', (select string_agg(titulo || ':' || coalesce(valor::text, '-'), ',' order by titulo) from public.mudancas_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario lista', format('select public.mudancas_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.como('empreiteiro');
select pg_temp.tentar('empreiteiro lista', format('select public.mudancas_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.como('fora');
select pg_temp.tentar('fora lista', format('select public.mudancas_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.admin();
select pg_temp.conferir('cliente vê o valor', pg_temp.pegar('cliente lista') = 'Para excluir:-,Tirar a churrasqueira:-1200.00,Trocar piso da sala:3500.56', pg_temp.pegar('cliente lista'));
select pg_temp.conferir('tabela não abre direto', pg_temp.pegar('cliente tabela') = '0', pg_temp.pegar('cliente tabela'));
select pg_temp.conferir('mestre vê a mudança sem o valor', pg_temp.pegar('mestre lista') = 'Para excluir:-,Tirar a churrasqueira:-,Trocar piso da sala:-', pg_temp.pegar('mestre lista'));
select pg_temp.conferir('estagiário e empreiteiro não veem', pg_temp.pegar('estagiario lista') = 'Obra não encontrada.' and pg_temp.pegar('empreiteiro lista') = 'Obra não encontrada.', pg_temp.pegar('estagiario lista'));
select pg_temp.conferir('quem é de fora não vê', pg_temp.pegar('fora lista') = 'Obra não encontrada.', pg_temp.pegar('fora lista'));

-- Responder
select pg_temp.como('dono');
select pg_temp.tentar('dono aprova', format('select public.responder_mudanca(%L, true)', pg_temp.pegar('m1')));
select pg_temp.tentar('altera pendente', format('select public.salvar_mudanca(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('m3'), '{"titulo": "Excluir esta", "dias": 2}'));
select pg_temp.tentar('exclui pendente', format('select public.excluir_mudanca(%L)', pg_temp.pegar('m3')));
select pg_temp.como('mestre');
select pg_temp.tentar('mestre aprova', format('select public.responder_mudanca(%L, true)', pg_temp.pegar('m1')));
select pg_temp.tentar('mestre exclui', format('select public.excluir_mudanca(%L)', pg_temp.pegar('m1')));
select pg_temp.como('fora');
select pg_temp.tentar('fora aprova', format('select public.responder_mudanca(%L, true)', pg_temp.pegar('m1')));
select pg_temp.como('cliente');
select pg_temp.tentar('aprova', format('select public.responder_mudanca(%L, true, %L)', pg_temp.pegar('m1'), '  Pode fazer  '));
select pg_temp.tentar('recusa', format('select public.responder_mudanca(%L, false, %L)', pg_temp.pegar('m2'), 'Quero manter'));
select pg_temp.tentar('responde de novo', format('select public.responder_mudanca(%L, false)', pg_temp.pegar('m1')));
select pg_temp.tentar('sem escolha', format('select public.responder_mudanca(%L, null)', pg_temp.pegar('m1')));
select pg_temp.guardar('quem respondeu', (select respondido_por from public.mudancas_da_obra(pg_temp.pegar('O')::uuid) where id = pg_temp.pegar('m1')::uuid));
select pg_temp.como('dono');
select pg_temp.tentar('altera respondida', format('select public.salvar_mudanca(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('m1'), '{"titulo": "Mudei depois"}'));
select pg_temp.tentar('exclui respondida', format('select public.excluir_mudanca(%L)', pg_temp.pegar('m1')));
select pg_temp.admin();
select pg_temp.conferir('o responsável não aprova a própria mudança', pg_temp.pegar('dono aprova') = 'Só o cliente aprova ou recusa uma mudança.', pg_temp.pegar('dono aprova'));
select pg_temp.conferir('mestre não aprova', pg_temp.pegar('mestre aprova') = 'Só o cliente aprova ou recusa uma mudança.', pg_temp.pegar('mestre aprova'));
select pg_temp.conferir('quem é de fora não aprova', pg_temp.pegar('fora aprova') = 'Mudança não encontrada.', pg_temp.pegar('fora aprova'));
select pg_temp.conferir('cliente aprova, com data e autor',
  pg_temp.pegar('aprova') = 'passou' and (select situacao = 'aprovada' and resposta = 'Pode fazer' and respondido_por = pg_temp.pegar('cliente')::uuid and respondido_em is not null from public.obra_mudancas where id = pg_temp.pegar('m1')::uuid), pg_temp.pegar('aprova'));
select pg_temp.conferir('cliente recusa', pg_temp.pegar('recusa') = 'passou' and pg_temp.situacao(pg_temp.pegar('m2')) = 'recusada', pg_temp.pegar('recusa'));
select pg_temp.conferir('resposta não se troca', pg_temp.pegar('responde de novo') = 'Esta mudança já foi respondida.' and pg_temp.situacao(pg_temp.pegar('m1')) = 'aprovada', pg_temp.pegar('responde de novo'));
select pg_temp.conferir('lista mostra quem respondeu', pg_temp.pegar('quem respondeu') = 'Dona Lia', pg_temp.pegar('quem respondeu'));
select pg_temp.conferir('pendente pode ser alterada e excluída', pg_temp.pegar('altera pendente') = 'passou' and pg_temp.pegar('exclui pendente') = 'passou' and not exists (select 1 from public.obra_mudancas where id = pg_temp.pegar('m3')::uuid), pg_temp.pegar('exclui pendente'));
select pg_temp.conferir('só o responsável exclui', pg_temp.pegar('mestre exclui') = 'Mudança não encontrada.', pg_temp.pegar('mestre exclui'));
select pg_temp.conferir('respondida não muda', pg_temp.pegar('altera respondida') = 'Mudança já respondida não pode ser alterada.', pg_temp.pegar('altera respondida'));
select pg_temp.conferir('respondida fica no histórico', pg_temp.pegar('exclui respondida') = 'Mudança já respondida fica no histórico da obra.', pg_temp.pegar('exclui respondida'));

-- Rascunho do diário
select pg_temp.como('dono');
select public.salvar_dia_obra(pg_temp.pegar('O')::uuid, '2026-11-02', '{"atividades": [{"descricao": "Fechado"}]}'::jsonb, true);
select public.salvar_dia_obra(pg_temp.pegar('O')::uuid, '2026-11-03', '{"atividades": [{"descricao": "Rascunho"}]}'::jsonb, false);
select pg_temp.guardar('dono dias', (select count(*)::text from public.rdos));
select pg_temp.como('mestre');
select pg_temp.guardar('mestre dias', (select count(*)::text from public.rdos));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente dias', (select string_agg(data::text, ',') from public.rdos));
select pg_temp.guardar('cliente itens', (select string_agg(descricao, ',') from public.rdo_atividades));
select pg_temp.admin();
select pg_temp.conferir('quem toca a obra vê o rascunho', pg_temp.pegar('dono dias') = '2' and pg_temp.pegar('mestre dias') = '2', pg_temp.pegar('mestre dias'));
select pg_temp.conferir('cliente só vê o dia finalizado', pg_temp.pegar('cliente dias') = '2026-11-02', pg_temp.pegar('cliente dias'));
select pg_temp.conferir('itens do rascunho também não aparecem para o cliente', pg_temp.pegar('cliente itens') = 'Fechado', pg_temp.pegar('cliente itens'));

-- Responsável exclui a conta
select pg_temp.como('sai');
insert into public.construtor_marca (user_id, nome, registro) values (pg_temp.pegar('sai')::uuid, 'Quem sai', 'CREA 9');
select public.excluir_conta('EXCLUIR');
select pg_temp.admin();
select pg_temp.conferir('marca sai junto com a conta', not exists (select 1 from public.construtor_marca where user_id = pg_temp.pegar('sai')::uuid));
select pg_temp.conferir('obra passa para o mestre, antes do estagiário e do cliente',
  (select funcao = 'responsavel' and papel = 'admin' from public.obra_membros where obra_id = pg_temp.pegar('O2')::uuid and user_id = pg_temp.pegar('mestre')::uuid));
select pg_temp.conferir('estagiário e cliente seguem na função deles',
  (select funcao = 'estagiario' from public.obra_membros where obra_id = pg_temp.pegar('O2')::uuid and user_id = pg_temp.pegar('estagiario')::uuid)
  and (select funcao = 'cliente' from public.obra_membros where obra_id = pg_temp.pegar('O2')::uuid and user_id = pg_temp.pegar('cliente')::uuid));
select pg_temp.conferir('obra só com cliente passa para ele', (select funcao = 'responsavel' from public.obra_membros where obra_id = pg_temp.pegar('O3')::uuid and user_id = pg_temp.pegar('cliente')::uuid));
select pg_temp.conferir('obra só dele some', not exists (select 1 from public.obras where id = pg_temp.pegar('O4')::uuid));
select pg_temp.conferir('nenhuma obra fica sem responsável',
  not exists (select 1 from public.obras o where not exists (select 1 from public.obra_membros m where m.obra_id = o.id and m.funcao = 'responsavel')));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
