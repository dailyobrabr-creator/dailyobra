-- Testes do cronograma e das pendências (migração cronograma_pendencias). Roda numa transação; o bloco final levanta
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
create function pg_temp.etapa(c text) returns public.obra_etapas language sql as $$
  select * from public.obra_etapas e where e.obra_id = pg_temp.pegar('O')::uuid and e.etapa = c $$;
create function pg_temp.marcar(status text) returns void language sql as $$
  insert into public.obra_etapas (obra_id, etapa, status) values (pg_temp.pegar('O')::uuid, 'alvenaria', status)
  on conflict (obra_id, etapa) do update set status = excluded.status $$;
create function pg_temp.salvar_cron(k text, json text) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.salvar_cronograma(%L, %L)', pg_temp.pegar('O'), json)) $$;

select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');
select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('estagiario', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('empreiteiro', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('cliente', '00000000-0000-0000-0000-00000000a005');
select pg_temp.guardar('fora', '00000000-0000-0000-0000-00000000a006');
select pg_temp.guardar('hoje', (now() at time zone 'America/Sao_Paulo')::date::text);

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.chave not in ('O', 'hoje');
insert into public.profiles (id, nome) values ('00000000-0000-0000-0000-00000000a002', 'João Mestre')
on conflict (id) do update set nome = excluded.nome;
insert into public.obras (id, nome, created_by) values ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001');
insert into public.obra_membros (obra_id, user_id, papel, funcao) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a002', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'membro', 'estagiario'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a004', 'membro', 'empreiteiro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente');

-- Datas reais nascem da situação
select pg_temp.como('mestre');
select pg_temp.marcar('iniciada');
select pg_temp.admin();
select pg_temp.conferir('marcar iniciada anota o dia', (pg_temp.etapa('alvenaria')).inicio_real::text = pg_temp.pegar('hoje') and (pg_temp.etapa('alvenaria')).fim_real is null);
update public.obra_etapas set inicio_real = '2026-10-01' where etapa = 'alvenaria' and obra_id = pg_temp.pegar('O')::uuid;
select pg_temp.como('mestre');
select pg_temp.marcar('concluida');
select pg_temp.admin();
select pg_temp.conferir('concluir mantém o início e anota o fim', (pg_temp.etapa('alvenaria')).inicio_real = '2026-10-01' and (pg_temp.etapa('alvenaria')).fim_real::text = pg_temp.pegar('hoje'));
select pg_temp.como('mestre');
select pg_temp.marcar('concluida');
select pg_temp.admin();
update public.obra_etapas set fim_real = '2026-10-20' where etapa = 'alvenaria' and obra_id = pg_temp.pegar('O')::uuid;
select pg_temp.como('mestre');
select pg_temp.marcar('concluida');
select pg_temp.admin();
select pg_temp.conferir('repetir a mesma situação não mexe nas datas', (pg_temp.etapa('alvenaria')).fim_real = '2026-10-20');
select pg_temp.como('mestre');
select pg_temp.marcar('bloqueada');
select pg_temp.admin();
select pg_temp.conferir('etapa reaberta perde o fim e mantém o início', (pg_temp.etapa('alvenaria')).fim_real is null and (pg_temp.etapa('alvenaria')).inicio_real = '2026-10-01');
select pg_temp.como('mestre');
select pg_temp.marcar('prevista');
select pg_temp.admin();
select pg_temp.conferir('voltar para prevista limpa as datas reais', (pg_temp.etapa('alvenaria')).inicio_real is null);
select pg_temp.como('mestre');
select pg_temp.marcar('concluida');
select pg_temp.admin();
select pg_temp.conferir('concluir direto preenche início e fim', (pg_temp.etapa('alvenaria')).inicio_real::text = pg_temp.pegar('hoje') and (pg_temp.etapa('alvenaria')).fim_real::text = pg_temp.pegar('hoje'));
select pg_temp.conferir('a história da etapa continua sendo gravada', (select count(*) from public.obra_etapas_historico h where h.obra_id = pg_temp.pegar('O')::uuid) = 5);

-- Cronograma
select pg_temp.como('mestre');
select pg_temp.salvar_cron('mestre salva', '[{"etapa": "fundacao", "inicio_previsto": "2026-11-01", "fim_previsto": "2026-11-20"}, {"etapa": "alvenaria", "inicio_previsto": "2026-11-21", "fim_previsto": "2026-12-10"}]');
select pg_temp.admin();
select pg_temp.conferir('quem lidera grava as datas', pg_temp.pegar('mestre salva') = 'passou' and (pg_temp.etapa('fundacao')).fim_previsto = '2026-11-20' and (pg_temp.etapa('fundacao')).status = 'prevista', pg_temp.pegar('mestre salva'));
select pg_temp.conferir('datas previstas não apagam as reais', (pg_temp.etapa('alvenaria')).inicio_real::text = pg_temp.pegar('hoje') and (pg_temp.etapa('alvenaria')).status = 'concluida');
select pg_temp.como('dono');
select pg_temp.salvar_cron('acerta real', '[{"etapa": "alvenaria", "inicio_previsto": "2026-11-21", "fim_previsto": "2026-12-10", "inicio_real": "2026-10-02", "fim_real": "2026-10-09"}]');
select pg_temp.salvar_cron('fim antes', '[{"etapa": "pintura", "inicio_previsto": "2026-11-21", "fim_previsto": "2026-11-20"}]');
select pg_temp.salvar_cron('real antes', '[{"etapa": "pintura", "inicio_real": "2026-10-21", "fim_real": "2026-10-20"}]');
select pg_temp.salvar_cron('real futuro', format('[{"etapa": "pintura", "inicio_real": "%s"}]', (now() + interval '9 days')::date));
select pg_temp.salvar_cron('nao lista', '{"etapa": "pintura"}');
select pg_temp.como('estagiario');
select pg_temp.salvar_cron('estagiario salva', '[{"etapa": "pintura", "inicio_previsto": "2026-11-21"}]');
select pg_temp.como('cliente');
select pg_temp.salvar_cron('cliente salva', '[{"etapa": "pintura", "inicio_previsto": "2026-11-21"}]');
select pg_temp.guardar('cliente ve datas', (select count(*)::text from public.obra_etapas where fim_previsto is not null));
select pg_temp.como('fora');
select pg_temp.salvar_cron('fora salva', '[{"etapa": "pintura", "inicio_previsto": "2026-11-21"}]');
select pg_temp.admin();
select pg_temp.conferir('acerta a data real', pg_temp.pegar('acerta real') = 'passou' and (pg_temp.etapa('alvenaria')).fim_real = '2026-10-09', pg_temp.pegar('acerta real'));
select pg_temp.conferir('fim previsto antes do início', pg_temp.pegar('fim antes') = 'O fim previsto não pode vir antes do início.', pg_temp.pegar('fim antes'));
select pg_temp.conferir('fim real antes do início', pg_temp.pegar('real antes') = 'O fim real não pode vir antes do início.', pg_temp.pegar('real antes'));
select pg_temp.conferir('data real no futuro', pg_temp.pegar('real futuro') = 'A data real não pode estar no futuro.', pg_temp.pegar('real futuro'));
select pg_temp.conferir('formato errado', pg_temp.pegar('nao lista') = 'Cronograma inválido.', pg_temp.pegar('nao lista'));
select pg_temp.conferir('estagiário não mexe no cronograma', pg_temp.pegar('estagiario salva') = 'Só o responsável ou o mestre mexem no cronograma.', pg_temp.pegar('estagiario salva'));
select pg_temp.conferir('cliente não mexe no cronograma', pg_temp.pegar('cliente salva') = 'Só o responsável ou o mestre mexem no cronograma.', pg_temp.pegar('cliente salva'));
select pg_temp.conferir('quem é de fora não mexe no cronograma', pg_temp.pegar('fora salva') = 'Só o responsável ou o mestre mexem no cronograma.', pg_temp.pegar('fora salva'));
select pg_temp.conferir('cliente acompanha o cronograma', pg_temp.pegar('cliente ve datas') = '2', pg_temp.pegar('cliente ve datas'));

-- Pendências
select pg_temp.como('estagiario');
select pg_temp.guardar('p1', (select public.salvar_pendencia(pg_temp.pegar('O')::uuid, null, jsonb_build_object(
  'descricao', '  Trinca na parede  ', 'etapa', 'alvenaria', 'responsavel_id', pg_temp.pegar('mestre'), 'prazo', '2026-11-20',
  'foto_path', pg_temp.pegar('O') || '/2026-11-04/a.jpg'))::text));
select pg_temp.guardar('p2', (select public.salvar_pendencia(pg_temp.pegar('O')::uuid, null, '{"descricao": "Sem responsável"}'::jsonb)::text));
select pg_temp.guardar('lista', (select string_agg(descricao || '|' || coalesce(responsavel_nome, '-') || '|' || coalesce(prazo::text, '-') || '|' || posso_mexer, ';') from public.pendencias_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.tentar('vazia', format('select public.salvar_pendencia(%L, null, %L)', pg_temp.pegar('O'), '{"descricao": "   "}'));
select pg_temp.tentar('longa', format('select public.salvar_pendencia(%L, null, %L)', pg_temp.pegar('O'), jsonb_build_object('descricao', repeat('x', 501))));
select pg_temp.tentar('resp cliente', format('select public.salvar_pendencia(%L, null, %L)', pg_temp.pegar('O'), jsonb_build_object('descricao', 'x', 'responsavel_id', pg_temp.pegar('cliente'))));
select pg_temp.tentar('resp fora', format('select public.salvar_pendencia(%L, null, %L)', pg_temp.pegar('O'), jsonb_build_object('descricao', 'x', 'responsavel_id', pg_temp.pegar('fora'))));
select pg_temp.tentar('foto alheia', format('select public.salvar_pendencia(%L, null, %L)', pg_temp.pegar('O'), '{"descricao": "x", "foto_path": "00000000-0000-0000-0000-0000000b0002/a.jpg"}'));
select pg_temp.como('empreiteiro');
select pg_temp.guardar('lista empreiteiro', (select string_agg(posso_mexer::text, ',' order by descricao) from public.pendencias_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.tentar('outro altera', format('select public.salvar_pendencia(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('p1'), '{"descricao": "Mudei"}'));
select pg_temp.tentar('outro resolve', format('select public.resolver_pendencia(%L, true)', pg_temp.pegar('p1')));
select pg_temp.tentar('outro exclui', format('select public.excluir_pendencia(%L)', pg_temp.pegar('p1')));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente le', (select count(*)::text from public.obra_pendencias));
select pg_temp.tentar('cliente lista', format('select public.pendencias_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.tentar('cliente cria', format('select public.salvar_pendencia(%L, null, %L)', pg_temp.pegar('O'), '{"descricao": "x"}'));
select pg_temp.tentar('cliente resolve', format('select public.resolver_pendencia(%L, true)', pg_temp.pegar('p1')));
select pg_temp.como('fora');
select pg_temp.guardar('fora le', (select count(*)::text from public.obra_pendencias));
select pg_temp.tentar('fora resolve', format('select public.resolver_pendencia(%L, true)', pg_temp.pegar('p1')));
select pg_temp.como('mestre');
select pg_temp.tentar('designado resolve', format('select public.resolver_pendencia(%L, true)', pg_temp.pegar('p1')));
select pg_temp.admin();
select pg_temp.conferir('resolver registra quem e quando',
  pg_temp.pegar('designado resolve') = 'passou'
  and (select situacao = 'resolvida' and resolvida_por = pg_temp.pegar('mestre')::uuid and resolvida_em is not null from public.obra_pendencias where id = pg_temp.pegar('p1')::uuid), pg_temp.pegar('designado resolve'));
select pg_temp.como('estagiario');
select pg_temp.tentar('criador reabre', format('select public.resolver_pendencia(%L, false)', pg_temp.pegar('p1')));
select pg_temp.tentar('criador altera', format('select public.salvar_pendencia(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('p1'), jsonb_build_object('descricao', 'Trinca maior', 'foto_path', pg_temp.pegar('O') || '/2026-11-04/a.jpg')));
select pg_temp.guardar('exclui', (select public.excluir_pendencia(pg_temp.pegar('p1')::uuid)));
select pg_temp.admin();
select pg_temp.conferir('prévia na lista: nome, prazo e quem mexe', pg_temp.pegar('lista') = 'Trinca na parede|João Mestre|2026-11-20|true;Sem responsável|-|-|true', pg_temp.pegar('lista'));
select pg_temp.conferir('quem não tem relação só vê', pg_temp.pegar('lista empreiteiro') = 'false,false', pg_temp.pegar('lista empreiteiro'));
select pg_temp.conferir('descrição vazia', pg_temp.pegar('vazia') = 'Descreva a pendência.', pg_temp.pegar('vazia'));
select pg_temp.conferir('descrição longa', pg_temp.pegar('longa') = 'Use no máximo 500 letras.', pg_temp.pegar('longa'));
select pg_temp.conferir('cliente não é responsável', pg_temp.pegar('resp cliente') = 'O responsável precisa estar na equipe da obra.', pg_temp.pegar('resp cliente'));
select pg_temp.conferir('quem é de fora não é responsável', pg_temp.pegar('resp fora') = 'O responsável precisa estar na equipe da obra.', pg_temp.pegar('resp fora'));
select pg_temp.conferir('foto de outra obra', pg_temp.pegar('foto alheia') = 'Foto de outra obra.', pg_temp.pegar('foto alheia'));
select pg_temp.conferir('outro não altera', pg_temp.pegar('outro altera') = 'Só quem criou, quem vai resolver ou quem lidera a obra altera esta pendência.', pg_temp.pegar('outro altera'));
select pg_temp.conferir('outro não resolve', pg_temp.pegar('outro resolve') = 'Só quem criou, quem vai resolver ou quem lidera a obra altera esta pendência.', pg_temp.pegar('outro resolve'));
select pg_temp.conferir('outro não exclui', pg_temp.pegar('outro exclui') = 'Só quem criou ou quem lidera a obra exclui uma pendência.', pg_temp.pegar('outro exclui'));
select pg_temp.conferir('cliente não vê pendências', pg_temp.pegar('cliente le') = '0' and pg_temp.pegar('cliente lista') = 'Obra não encontrada.', pg_temp.pegar('cliente lista'));
select pg_temp.conferir('cliente não cria nem resolve', pg_temp.pegar('cliente cria') = 'Só quem toca a obra registra pendências.' and pg_temp.pegar('cliente resolve') = 'Pendência não encontrada.', pg_temp.pegar('cliente resolve'));
select pg_temp.conferir('quem é de fora não vê nem resolve', pg_temp.pegar('fora le') = '0' and pg_temp.pegar('fora resolve') = 'Pendência não encontrada.', pg_temp.pegar('fora resolve'));
select pg_temp.conferir('criador reabre e altera', pg_temp.pegar('criador reabre') = 'passou' and pg_temp.pegar('criador altera') = 'passou', pg_temp.pegar('criador altera'));
select pg_temp.conferir('excluir devolve a foto para apagar', pg_temp.pegar('exclui') = pg_temp.pegar('O') || '/2026-11-04/a.jpg', pg_temp.pegar('exclui'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
