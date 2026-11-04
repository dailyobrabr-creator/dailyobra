-- Testes de documentos e checklists (migração documentos_checklists). Roda numa transação; o bloco final levanta 'RESULTADO: ...'
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
create function pg_temp.lista(titulo text, resultados text[]) returns jsonb language sql as $$
  select jsonb_build_object('titulo', titulo, 'tipo', 'seguranca', 'modelo', 'seguranca_geral', 'etapa', 'alvenaria', 'data', pg_temp.pegar('hoje'),
    'itens', (select jsonb_agg(jsonb_build_object('texto', 'Item ' || n, 'resultado', resultados[n], 'observacao', case when resultados[n] = 'nao' then 'Falta guarda-corpo' end)) from generate_subscripts(resultados, 1) n)) $$;

select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');
select pg_temp.guardar('O2', '00000000-0000-0000-0000-0000000b0002');
select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('estagiario', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('empreiteiro', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('cliente', '00000000-0000-0000-0000-00000000a005');
select pg_temp.guardar('fora', '00000000-0000-0000-0000-00000000a006');
select pg_temp.guardar('hoje', ((now() at time zone 'America/Sao_Paulo')::date)::text);
select pg_temp.guardar('futuro', ((now() at time zone 'America/Sao_Paulo')::date + 5)::text);

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.valor like '00000000-0000-0000-0000-00000000a%';
insert into public.profiles (id, nome) values ('00000000-0000-0000-0000-00000000a002', 'Seu Jorge')
on conflict (id) do update set nome = excluded.nome;
insert into public.obras (id, nome, created_by) values
  ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000b0002', 'Outra obra', '00000000-0000-0000-0000-00000000a006');
insert into public.obra_membros (obra_id, user_id, papel, funcao) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a002', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'membro', 'estagiario'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a004', 'membro', 'empreiteiro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente');

-- Documentos
select pg_temp.como('dono');
select pg_temp.guardar('d contrato', (select public.salvar_documento(pg_temp.pegar('O')::uuid, null, jsonb_build_object('tipo', 'contrato', 'titulo', '  Contrato do cliente  ', 'numero', ' 12/26 ', 'validade', '2027-01-10', 'caminho', pg_temp.pegar('O') || '/contrato.pdf', 'nome_arquivo', 'contrato.pdf'))::text));
select pg_temp.guardar('d projeto', (select public.salvar_documento(pg_temp.pegar('O')::uuid, null, jsonb_build_object('tipo', 'projeto', 'titulo', 'Projeto elétrico', 'caminho', pg_temp.pegar('O') || '/eletrico.pdf', 'acesso', 'equipe'))::text));
select pg_temp.guardar('d alvara', (select public.salvar_documento(pg_temp.pegar('O')::uuid, null, jsonb_build_object('tipo', 'alvara', 'titulo', 'Alvará', 'caminho', pg_temp.pegar('O') || '/alvara.pdf', 'acesso', 'todos'))::text));
select pg_temp.tentar('sem titulo', format('select public.salvar_documento(%L, null, %L)', pg_temp.pegar('O'), '{"titulo": " "}'));
select pg_temp.tentar('tipo errado', format('select public.salvar_documento(%L, null, %L)', pg_temp.pegar('O'), '{"titulo": "x", "tipo": "foto"}'));
select pg_temp.tentar('acesso errado', format('select public.salvar_documento(%L, null, %L)', pg_temp.pegar('O'), '{"titulo": "x", "acesso": "publico"}'));
select pg_temp.tentar('arquivo alheio', format('select public.salvar_documento(%L, null, %L)', pg_temp.pegar('O'), json_build_object('titulo', 'x', 'caminho', pg_temp.pegar('O2') || '/x.pdf')));
select pg_temp.tentar('envia dono', format($q$insert into storage.objects (bucket_id, name, owner_id) values ('obra-documentos', %L, %L)$q$, pg_temp.pegar('O') || '/contrato.pdf', pg_temp.pegar('dono')));
select pg_temp.guardar('dono ve', (select count(*)::text from public.documentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('mestre');
select pg_temp.guardar('d mestre', (select public.salvar_documento(pg_temp.pegar('O')::uuid, null, '{"titulo": "Do mestre"}'::jsonb)::text));
select pg_temp.tentar('mestre edita o dele', format('select public.salvar_documento(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('d mestre'), '{"titulo": "Trocado"}'));
select pg_temp.tentar('mestre edita alheio', format('select public.salvar_documento(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('d contrato'), '{"titulo": "Trocado"}'));
select pg_temp.tentar('mestre exclui alheio', format('select public.excluir_documento(%L)', pg_temp.pegar('d contrato')));
select pg_temp.guardar('mestre ve', (select count(*)::text from public.documentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('mestre mexe', (select string_agg(titulo, ',' order by titulo) from public.documentos_da_obra(pg_temp.pegar('O')::uuid) where posso_mexer));
select pg_temp.guardar('tabela documentos', (select count(*)::text from public.obra_documentos));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario salva', format('select public.salvar_documento(%L, null, %L)', pg_temp.pegar('O'), '{"titulo": "x"}'));
select pg_temp.guardar('estagiario ve', (select string_agg(titulo, ',' order by titulo) from public.documentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.tentar('estagiario envia', format($q$insert into storage.objects (bucket_id, name, owner_id) values ('obra-documentos', %L, %L)$q$, pg_temp.pegar('O') || '/x.pdf', pg_temp.pegar('estagiario')));
select pg_temp.guardar('estagiario baixa contrato', (select count(*)::text from storage.objects where bucket_id = 'obra-documentos' and name = pg_temp.pegar('O') || '/contrato.pdf'));
select pg_temp.como('empreiteiro');
select pg_temp.guardar('empreiteiro ve', (select string_agg(titulo, ',' order by titulo) from public.documentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente ve', (select string_agg(titulo, ',' order by titulo) from public.documentos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('fora');
select pg_temp.tentar('fora ve', format('select public.documentos_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.tentar('fora de outra obra', format('select public.salvar_documento(%L, %L, %L)', pg_temp.pegar('O2'), pg_temp.pegar('d contrato'), '{"titulo": "Roubado"}'));
select pg_temp.tentar('fora envia', format($q$insert into storage.objects (bucket_id, name, owner_id) values ('obra-documentos', %L, %L)$q$, pg_temp.pegar('O') || '/y.pdf', pg_temp.pegar('fora')));
select pg_temp.admin();
insert into storage.objects (bucket_id, name, owner_id) values ('obra-documentos', pg_temp.pegar('O') || '/alvara.pdf', pg_temp.pegar('dono'));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente baixa', (select string_agg(split_part(name, '/', 2), ',' order by name) from storage.objects where bucket_id = 'obra-documentos'));
select pg_temp.como('fora');
select pg_temp.guardar('fora baixa', (select count(*)::text from storage.objects where bucket_id = 'obra-documentos'));
select pg_temp.como('mestre');
select pg_temp.guardar('mestre baixa', (select count(*)::text from storage.objects where bucket_id = 'obra-documentos'));
select pg_temp.tentar('mestre exclui o dele', format('select public.excluir_documento(%L)', pg_temp.pegar('d mestre')));
select pg_temp.como('dono');
select pg_temp.guardar('caminho excluido', (select public.excluir_documento(pg_temp.pegar('d projeto')::uuid)));
select pg_temp.admin();
select pg_temp.conferir('documento guarda tudo, limpo', (select titulo = 'Contrato do cliente' and numero = '12/26' and validade = '2027-01-10' and acesso = 'lideres' from public.obra_documentos where id = pg_temp.pegar('d contrato')::uuid));
select pg_temp.conferir('documento precisa de nome', pg_temp.pegar('sem titulo') = 'Diga o nome do documento.', pg_temp.pegar('sem titulo'));
select pg_temp.conferir('tipo e acesso só da lista', pg_temp.pegar('tipo errado') = 'Tipo de documento inválido.' and pg_temp.pegar('acesso errado') = 'Escolha quem pode ver.', pg_temp.pegar('tipo errado'));
select pg_temp.conferir('arquivo de outra obra recusado', pg_temp.pegar('arquivo alheio') = 'Arquivo de outra obra.', pg_temp.pegar('arquivo alheio'));
select pg_temp.conferir('responsável envia e vê tudo', pg_temp.pegar('envia dono') = 'passou' and pg_temp.pegar('dono ve') = '3', pg_temp.pegar('dono ve'));
select pg_temp.conferir('mestre guarda e edita o dele', pg_temp.pegar('mestre edita o dele') = 'passou' and pg_temp.pegar('mestre ve') = '4' and pg_temp.pegar('mestre mexe') = 'Trocado', pg_temp.pegar('mestre mexe'));
select pg_temp.conferir('mestre não mexe no do responsável', pg_temp.pegar('mestre edita alheio') = 'Documento não encontrado.' and pg_temp.pegar('mestre exclui alheio') = 'Documento não encontrado.', pg_temp.pegar('mestre edita alheio'));
select pg_temp.conferir('tabela não abre direto', pg_temp.pegar('tabela documentos') = '0', pg_temp.pegar('tabela documentos'));
select pg_temp.conferir('estagiário não guarda documento', pg_temp.pegar('estagiario salva') = 'Só o responsável ou o mestre guardam documentos.' and pg_temp.pegar('estagiario envia') like '%row-level security%', pg_temp.pegar('estagiario salva'));
select pg_temp.conferir('equipe vê o da equipe, não o de quem lidera', pg_temp.pegar('estagiario ve') = 'Alvará,Projeto elétrico' and pg_temp.pegar('empreiteiro ve') = 'Alvará,Projeto elétrico', pg_temp.pegar('empreiteiro ve'));
select pg_temp.conferir('cliente vê só o liberado para ele', pg_temp.pegar('cliente ve') = 'Alvará', pg_temp.pegar('cliente ve'));
select pg_temp.conferir('quem é de fora não vê', pg_temp.pegar('fora ve') = 'Obra não encontrada.', pg_temp.pegar('fora ve'));
select pg_temp.conferir('documento de outra obra não muda pela obra dele', pg_temp.pegar('fora de outra obra') = 'Documento não encontrado.', pg_temp.pegar('fora de outra obra'));
select pg_temp.conferir('quem é de fora não envia', pg_temp.pegar('fora envia') like '%row-level security%', pg_temp.pegar('fora envia'));
select pg_temp.conferir('arquivo segue a regra do documento',
  pg_temp.pegar('cliente baixa') = 'alvara.pdf' and pg_temp.pegar('estagiario baixa contrato') = '0' and pg_temp.pegar('fora baixa') = '0' and pg_temp.pegar('mestre baixa') = '2', pg_temp.pegar('cliente baixa'));
select pg_temp.conferir('excluir devolve o arquivo', pg_temp.pegar('caminho excluido') = pg_temp.pegar('O') || '/eletrico.pdf' and pg_temp.pegar('mestre exclui o dele') = 'passou', pg_temp.pegar('caminho excluido'));

-- Checklists
select pg_temp.como('estagiario');
select pg_temp.guardar('l1', (select public.salvar_checklist(pg_temp.pegar('O')::uuid, null, pg_temp.lista('  Segurança  ', array['ok', null, 'nao', 'na']))::text));
select pg_temp.tentar('estagiario conclui', format('select public.salvar_checklist(%L, %L, %L, true)', pg_temp.pegar('O'), pg_temp.pegar('l1'), pg_temp.lista('x', array['ok'])));
select pg_temp.guardar('estagiario le', (select count(*)::text from public.obra_checklists));
select pg_temp.guardar('estagiario le itens', (select count(*)::text from public.obra_checklist_itens));
select pg_temp.como('empreiteiro');
select pg_temp.tentar('empreiteiro salva', format('select public.salvar_checklist(%L, null, %L)', pg_temp.pegar('O'), pg_temp.lista('x', array['ok'])));
select pg_temp.guardar('empreiteiro le', (select count(*)::text from public.obra_checklists));
select pg_temp.como('cliente');
select pg_temp.tentar('cliente salva', format('select public.salvar_checklist(%L, null, %L)', pg_temp.pegar('O'), pg_temp.lista('x', array['ok'])));
select pg_temp.guardar('cliente le', (select count(*)::text from public.obra_checklists));
select pg_temp.como('fora');
select pg_temp.tentar('fora salva', format('select public.salvar_checklist(%L, null, %L)', pg_temp.pegar('O'), pg_temp.lista('x', array['ok'])));
select pg_temp.tentar('fora muda de outra obra', format('select public.salvar_checklist(%L, %L, %L)', pg_temp.pegar('O2'), pg_temp.pegar('l1'), pg_temp.lista('x', array['ok'])));
select pg_temp.como('mestre');
select pg_temp.tentar('sem nome', format('select public.salvar_checklist(%L, null, %L)', pg_temp.pegar('O'), pg_temp.lista(' ', array['ok'])));
select pg_temp.tentar('sem itens', format('select public.salvar_checklist(%L, null, %L)', pg_temp.pegar('O'), json_build_object('titulo', 'x', 'data', pg_temp.pegar('hoje'), 'itens', json_build_array())));
select pg_temp.tentar('futuro', format('select public.salvar_checklist(%L, null, %L)', pg_temp.pegar('O'), json_build_object('titulo', 'x', 'data', pg_temp.pegar('futuro'), 'itens', json_build_array(json_build_object('texto', 'a')))));
select pg_temp.tentar('resposta errada', format('select public.salvar_checklist(%L, null, %L)', pg_temp.pegar('O'), pg_temp.lista('x', array['talvez'])));
select pg_temp.tentar('foto alheia', format('select public.salvar_checklist(%L, null, %L)', pg_temp.pegar('O'), json_build_object('titulo', 'x', 'data', pg_temp.pegar('hoje'), 'itens', json_build_array(json_build_object('texto', 'a', 'foto_path', pg_temp.pegar('O2') || '/f.jpg')))));
select pg_temp.tentar('falta responder', format('select public.salvar_checklist(%L, %L, %L, true)', pg_temp.pegar('O'), pg_temp.pegar('l1'), pg_temp.lista('Segurança', array['ok', null])));
select pg_temp.tentar('conclui', format('select public.salvar_checklist(%L, %L, %L, true)', pg_temp.pegar('O'), pg_temp.pegar('l1'), pg_temp.lista('Segurança', array['ok', 'nao', 'nao', 'na'])));
select pg_temp.tentar('muda concluido', format('select public.salvar_checklist(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('l1'), pg_temp.lista('Mudei', array['ok'])));
select pg_temp.tentar('mestre exclui concluido', format('select public.excluir_checklist(%L)', pg_temp.pegar('l1')));
select pg_temp.guardar('pendencias vistas', (select count(*)::text from public.pendencias_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('l mestre', (select public.salvar_checklist(pg_temp.pegar('O')::uuid, null, pg_temp.lista('Rascunho do mestre', array['ok']))::text));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario exclui alheio', format('select public.excluir_checklist(%L)', pg_temp.pegar('l mestre')));
select pg_temp.guardar('l estagiario', (select public.salvar_checklist(pg_temp.pegar('O')::uuid, null, jsonb_build_object('titulo', 'Com foto', 'data', pg_temp.pegar('hoje'), 'itens', jsonb_build_array(jsonb_build_object('texto', 'a', 'foto_path', pg_temp.pegar('O') || '/f.jpg'))))::text));
select pg_temp.guardar('fotos do rascunho', (select array_to_string(public.excluir_checklist(pg_temp.pegar('l estagiario')::uuid), ',')));
select pg_temp.como('dono');
select pg_temp.tentar('dono exclui rascunho', format('select public.excluir_checklist(%L)', pg_temp.pegar('l mestre')));
select pg_temp.tentar('dono exclui concluido', format('select public.excluir_checklist(%L)', pg_temp.pegar('l1')));
select pg_temp.admin();
select pg_temp.conferir('estagiário preenche, não conclui', pg_temp.pegar('estagiario conclui') = 'Só o responsável ou o mestre concluem o checklist.' and pg_temp.pegar('estagiario le') = '1' and pg_temp.pegar('estagiario le itens') = '4', pg_temp.pegar('estagiario conclui'));
select pg_temp.conferir('empreiteiro e cliente não entram',
  pg_temp.pegar('empreiteiro salva') = 'Só o responsável, o mestre e o estagiário preenchem checklists.' and pg_temp.pegar('cliente salva') = 'Só o responsável, o mestre e o estagiário preenchem checklists.' and pg_temp.pegar('empreiteiro le') = '0' and pg_temp.pegar('cliente le') = '0', pg_temp.pegar('empreiteiro salva'));
select pg_temp.conferir('quem é de fora não entra', pg_temp.pegar('fora salva') = 'Só o responsável, o mestre e o estagiário preenchem checklists.', pg_temp.pegar('fora salva'));
select pg_temp.conferir('checklist de outra obra não muda pela obra dele', pg_temp.pegar('fora muda de outra obra') = 'Checklist não encontrado.', pg_temp.pegar('fora muda de outra obra'));
select pg_temp.conferir('checklist precisa de nome e itens', pg_temp.pegar('sem nome') = 'Diga o nome do checklist.' and pg_temp.pegar('sem itens') = 'O checklist precisa de pelo menos um item.', pg_temp.pegar('sem itens'));
select pg_temp.conferir('data futura recusada', pg_temp.pegar('futuro') = 'Escolha uma data até hoje.', pg_temp.pegar('futuro'));
select pg_temp.conferir('resposta só da lista', pg_temp.pegar('resposta errada') = 'Resposta inválida.', pg_temp.pegar('resposta errada'));
select pg_temp.conferir('foto de outra obra recusada', pg_temp.pegar('foto alheia') = 'Foto de outra obra.', pg_temp.pegar('foto alheia'));
select pg_temp.conferir('não conclui com item sem resposta', pg_temp.pegar('falta responder') = 'Responda todos os itens antes de concluir.', pg_temp.pegar('falta responder'));
select pg_temp.conferir('concluir não mudou o que sumiu: tudo passou', pg_temp.pegar('conclui') = 'passou', pg_temp.pegar('conclui'));
select pg_temp.conferir('cada item não conforme vira uma pendência', pg_temp.pegar('pendencias vistas') = '2', pg_temp.pegar('pendencias vistas'));
select pg_temp.conferir('pendência explica o que aconteceu',
  exists (select 1 from public.obra_pendencias where obra_id = pg_temp.pegar('O')::uuid and descricao = 'Segurança: Item 2 (Falta guarda-corpo)' and etapa = 'alvenaria' and situacao = 'aberta'));
select pg_temp.conferir('concluído não muda', pg_temp.pegar('muda concluido') = 'Checklist concluído não muda.', pg_temp.pegar('muda concluido'));
select pg_temp.conferir('só o responsável exclui concluído', pg_temp.pegar('mestre exclui concluido') = 'Checklist não encontrado.' and pg_temp.pegar('dono exclui concluido') = 'passou', pg_temp.pegar('mestre exclui concluido'));
select pg_temp.conferir('rascunho de outro não sai', pg_temp.pegar('estagiario exclui alheio') = 'Checklist não encontrado.', pg_temp.pegar('estagiario exclui alheio'));
select pg_temp.conferir('quem criou tira o rascunho e recebe as fotos', pg_temp.pegar('fotos do rascunho') = pg_temp.pegar('O') || '/f.jpg', pg_temp.pegar('fotos do rascunho'));
select pg_temp.conferir('responsável tira rascunho de qualquer um', pg_temp.pegar('dono exclui rascunho') = 'passou', pg_temp.pegar('dono exclui rascunho'));
select pg_temp.conferir('excluir o checklist não apaga as pendências', (select count(*) = 2 from public.obra_pendencias where obra_id = pg_temp.pegar('O')::uuid));

-- Quem concluiu fica registrado
select pg_temp.como('mestre');
select pg_temp.guardar('l2', (select public.salvar_checklist(pg_temp.pegar('O')::uuid, null, pg_temp.lista('Com nome', array['ok']), true)::text));
select pg_temp.admin();
select pg_temp.conferir('nome de quem concluiu fica guardado', (select concluido and concluido_nome = 'Seu Jorge' and concluido_em is not null from public.obra_checklists where id = pg_temp.pegar('l2')::uuid));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
