-- Testes da equipe da obra (migração equipe_obra). Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro
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
  perform pg_temp.guardar(k, 'passou');
exception when others then perform pg_temp.guardar(k, sqlerrm);
end $$;
create function pg_temp.funcao(u text) returns text language sql as $$
  select m.funcao || '/' || m.papel from public.obra_membros m where m.obra_id = pg_temp.pegar('O')::uuid and m.user_id = u::uuid $$;

select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');
select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('estagiario', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('empreiteiro', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('cliente', '00000000-0000-0000-0000-00000000a005');
select pg_temp.guardar('fora', '00000000-0000-0000-0000-00000000a006');

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.chave <> 'O';
insert into public.profiles (id, nome) values
  ('00000000-0000-0000-0000-00000000a001', 'Marina Duarte'),
  ('00000000-0000-0000-0000-00000000a002', 'João Mestre')
on conflict (id) do update set nome = excluded.nome;

insert into public.obras (id, nome, created_by) values ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001');
select pg_temp.conferir('quem cria a obra vira responsável', pg_temp.funcao(pg_temp.pegar('dono')) = 'responsavel/admin', pg_temp.funcao(pg_temp.pegar('dono')));

-- Convites
select pg_temp.como(pg_temp.pegar('dono')::uuid);
select pg_temp.guardar('c mestre', (select codigo from public.criar_convite(pg_temp.pegar('O')::uuid, 'mestre')));
select pg_temp.guardar('c estagiario', (select codigo from public.criar_convite(pg_temp.pegar('O')::uuid, 'estagiario')));
select pg_temp.guardar('c empreiteiro', (select codigo from public.criar_convite(pg_temp.pegar('O')::uuid, 'empreiteiro')));
select pg_temp.guardar('c cliente', (select codigo from public.criar_convite(pg_temp.pegar('O')::uuid, 'cliente')));
select pg_temp.guardar('c vence', (select codigo from public.criar_convite(pg_temp.pegar('O')::uuid, 'cliente')));
select pg_temp.guardar('id cancela', (select id::text from public.criar_convite(pg_temp.pegar('O')::uuid, 'cliente')));
select pg_temp.tentar('funcao invalida', format('select public.criar_convite(%L, %L)', pg_temp.pegar('O'), 'responsavel'));
select pg_temp.tentar('limite', format('select public.criar_convite(%L, %L) from generate_series(1, 25)', pg_temp.pegar('O'), 'cliente'));
select pg_temp.guardar('convites vistos', (select count(*)::text from public.obra_convites));
select pg_temp.admin();
select pg_temp.conferir('código tem 5 + 5 letras', pg_temp.pegar('c mestre') ~ '^[0-9A-F]{5}-[0-9A-F]{5}$', pg_temp.pegar('c mestre'));
select pg_temp.conferir('convite só para as funções da equipe', pg_temp.pegar('funcao invalida') = 'Escolha a função da pessoa.', pg_temp.pegar('funcao invalida'));
select pg_temp.conferir('limite de convites abertos', pg_temp.pegar('limite') = 'Esta obra tem muitos convites abertos. Cancele os que não vai usar.', pg_temp.pegar('limite'));
select pg_temp.conferir('responsável vê os convites', pg_temp.pegar('convites vistos') = '6', pg_temp.pegar('convites vistos'));

-- Aceitar
select pg_temp.como(pg_temp.pegar('mestre')::uuid);
select pg_temp.guardar('previa', (select obra_nome || '|' || funcao || '|' || convidado_por || '|' || ja_participa from public.ver_convite(lower(pg_temp.pegar('c mestre')))));
select pg_temp.tentar('aceita mestre', format('select public.aceitar_convite(%L)', lower(replace(pg_temp.pegar('c mestre'), '-', ''))));
select pg_temp.guardar('previa depois', (select ja_participa::text from public.ver_convite(pg_temp.pegar('c mestre'))));
select pg_temp.tentar('aceita de novo', format('select public.aceitar_convite(%L)', pg_temp.pegar('c mestre')));
select pg_temp.guardar('mestre ve convites', (select count(*)::text from public.obra_convites));
select pg_temp.tentar('mestre convida', format('select public.criar_convite(%L, %L)', pg_temp.pegar('O'), 'cliente'));
select pg_temp.como(pg_temp.pegar('estagiario')::uuid);
select pg_temp.tentar('aceita estagiario', format('select public.aceitar_convite(%L)', pg_temp.pegar('c estagiario')));
select pg_temp.tentar('codigo usado', format('select public.aceitar_convite(%L)', pg_temp.pegar('c mestre')));
select pg_temp.como(pg_temp.pegar('empreiteiro')::uuid);
select pg_temp.tentar('aceita empreiteiro', format('select public.aceitar_convite(%L)', pg_temp.pegar('c empreiteiro')));
select pg_temp.como(pg_temp.pegar('cliente')::uuid);
select pg_temp.tentar('aceita cliente', format('select public.aceitar_convite(%L)', pg_temp.pegar('c cliente')));
select pg_temp.como(pg_temp.pegar('fora')::uuid);
select pg_temp.tentar('codigo errado', format('select public.aceitar_convite(%L)', 'ABCDE-12345'));
select pg_temp.tentar('codigo curto', format('select public.ver_convite(%L)', 'ABC'));
select pg_temp.guardar('fora ve convites', (select count(*)::text from public.obra_convites));
select pg_temp.admin();
update public.obra_convites set expira_em = now() - interval '1 minute' where codigo = pg_temp.pegar('c vence');
select pg_temp.como(pg_temp.pegar('fora')::uuid);
select pg_temp.tentar('codigo vencido', format('select public.aceitar_convite(%L)', pg_temp.pegar('c vence')));
select pg_temp.admin();
select pg_temp.conferir('prévia mostra obra, função e quem convidou', pg_temp.pegar('previa') = 'Obra do teste|mestre|Marina Duarte|false', pg_temp.pegar('previa'));
select pg_temp.conferir('código vale com minúscula e sem traço', pg_temp.pegar('aceita mestre') = 'passou' and pg_temp.funcao(pg_temp.pegar('mestre')) = 'mestre/membro', pg_temp.pegar('aceita mestre'));
select pg_temp.conferir('prévia sabe quem já está na obra', pg_temp.pegar('previa depois') = 'true', pg_temp.pegar('previa depois'));
select pg_temp.conferir('quem usou pode abrir o link de novo', pg_temp.pegar('aceita de novo') = 'passou', pg_temp.pegar('aceita de novo'));
select pg_temp.conferir('código vale uma vez só', pg_temp.pegar('codigo usado') = 'Este convite já foi usado. Peça um novo.', pg_temp.pegar('codigo usado'));
select pg_temp.conferir('cada convite dá a sua função',
  pg_temp.funcao(pg_temp.pegar('estagiario')) = 'estagiario/membro' and pg_temp.funcao(pg_temp.pegar('empreiteiro')) = 'empreiteiro/membro' and pg_temp.funcao(pg_temp.pegar('cliente')) = 'cliente/cliente');
select pg_temp.conferir('código errado', pg_temp.pegar('codigo errado') = 'Código não encontrado. Confira e tente de novo.', pg_temp.pegar('codigo errado'));
select pg_temp.conferir('código incompleto', pg_temp.pegar('codigo curto') = 'Código não encontrado. Confira e tente de novo.', pg_temp.pegar('codigo curto'));
select pg_temp.conferir('código vencido', pg_temp.pegar('codigo vencido') = 'Este convite venceu. Peça um novo.', pg_temp.pegar('codigo vencido'));
select pg_temp.conferir('quem não é responsável não convida', pg_temp.pegar('mestre convida') = 'Só o responsável pela obra convida pessoas.', pg_temp.pegar('mestre convida'));
select pg_temp.conferir('convites só para o responsável', pg_temp.pegar('mestre ve convites') = '0' and pg_temp.pegar('fora ve convites') = '0', pg_temp.pegar('mestre ve convites'));

-- Quem pode fazer o quê
select pg_temp.como(pg_temp.pegar('estagiario')::uuid);
select pg_temp.tentar('estagiario rascunho', format('select public.salvar_dia_obra(%L, %L, %L)', pg_temp.pegar('O'), '2026-11-02', '{"observacoes": "x"}'));
select pg_temp.tentar('estagiario finaliza', format('select public.salvar_dia_obra(%L, %L, %L, %L)', pg_temp.pegar('O'), '2026-11-02', '{"observacoes": "x"}', true));
select pg_temp.tentar('estagiario etapa', format($q$insert into public.obra_etapas (obra_id, etapa, status) values (%L, 'fundacao', 'iniciada')$q$, pg_temp.pegar('O')));
select pg_temp.como(pg_temp.pegar('empreiteiro')::uuid);
select pg_temp.tentar('empreiteiro rascunho', format('select public.salvar_dia_obra(%L, %L, %L)', pg_temp.pegar('O'), '2026-11-01', '{"observacoes": "x"}'));
select pg_temp.tentar('empreiteiro finaliza', format('select public.salvar_dia_obra(%L, %L, %L, %L)', pg_temp.pegar('O'), '2026-11-01', '{"observacoes": "x"}', true));
select pg_temp.como(pg_temp.pegar('cliente')::uuid);
select pg_temp.tentar('cliente rascunho', format('select public.salvar_dia_obra(%L, %L, %L)', pg_temp.pegar('O'), '2026-11-03', '{"observacoes": "x"}'));
select pg_temp.tentar('cliente etapa', format($q$insert into public.obra_etapas (obra_id, etapa, status) values (%L, 'fundacao', 'iniciada')$q$, pg_temp.pegar('O')));
select pg_temp.como(pg_temp.pegar('mestre')::uuid);
select pg_temp.tentar('mestre finaliza', format('select public.salvar_dia_obra(%L, %L, %L, %L)', pg_temp.pegar('O'), '2026-11-02', '{"observacoes": "x"}', true));
select pg_temp.tentar('mestre etapa', format($q$insert into public.obra_etapas (obra_id, etapa, status) values (%L, 'fundacao', 'iniciada')$q$, pg_temp.pegar('O')));
select pg_temp.admin();
select pg_temp.conferir('estagiário preenche rascunho', pg_temp.pegar('estagiario rascunho') = 'passou', pg_temp.pegar('estagiario rascunho'));
select pg_temp.conferir('estagiário não finaliza', pg_temp.pegar('estagiario finaliza') = 'Só o responsável ou o mestre finalizam o dia.', pg_temp.pegar('estagiario finaliza'));
select pg_temp.conferir('estagiário não muda etapa', pg_temp.pegar('estagiario etapa') like '%row-level security%', pg_temp.pegar('estagiario etapa'));
select pg_temp.conferir('empreiteiro preenche rascunho', pg_temp.pegar('empreiteiro rascunho') = 'passou', pg_temp.pegar('empreiteiro rascunho'));
select pg_temp.conferir('empreiteiro não finaliza', pg_temp.pegar('empreiteiro finaliza') = 'Só o responsável ou o mestre finalizam o dia.', pg_temp.pegar('empreiteiro finaliza'));
select pg_temp.conferir('cliente continua sem preencher', pg_temp.pegar('cliente rascunho') = 'Só quem toca a obra preenche o diário.', pg_temp.pegar('cliente rascunho'));
select pg_temp.conferir('cliente não muda etapa', pg_temp.pegar('cliente etapa') like '%row-level security%', pg_temp.pegar('cliente etapa'));
select pg_temp.conferir('mestre finaliza e muda etapa', pg_temp.pegar('mestre finaliza') = 'passou' and pg_temp.pegar('mestre etapa') = 'passou', pg_temp.pegar('mestre etapa'));

-- Ver e cuidar da equipe
select pg_temp.como(pg_temp.pegar('cliente')::uuid);
select pg_temp.guardar('lista', (select string_agg(nome || ':' || funcao || ':' || eu, ',') from public.equipe_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.tentar('cliente muda funcao', format('select public.mudar_funcao_membro(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('mestre'), 'cliente'));
select pg_temp.tentar('cliente remove', format('select public.remover_membro(%L, %L)', pg_temp.pegar('O'), pg_temp.pegar('mestre')));
select pg_temp.como(pg_temp.pegar('fora')::uuid);
select pg_temp.tentar('fora ve equipe', format('select public.equipe_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.como(pg_temp.pegar('dono')::uuid);
select pg_temp.tentar('muda funcao', format('select public.mudar_funcao_membro(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('estagiario'), 'cliente'));
select pg_temp.tentar('funcao ruim', format('select public.mudar_funcao_membro(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('mestre'), 'responsavel'));
select pg_temp.tentar('muda dono', format('select public.mudar_funcao_membro(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('dono'), 'mestre'));
select pg_temp.tentar('muda de fora', format('select public.mudar_funcao_membro(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('fora'), 'mestre'));
select pg_temp.tentar('dono sai', format('select public.remover_membro(%L, %L)', pg_temp.pegar('O'), pg_temp.pegar('dono')));
select pg_temp.tentar('remove', format('select public.remover_membro(%L, %L)', pg_temp.pegar('O'), pg_temp.pegar('empreiteiro')));
select pg_temp.tentar('direto', format($q$insert into public.obra_membros (obra_id, user_id, papel, funcao) values (%L, %L, 'membro', 'mestre')$q$, pg_temp.pegar('O'), pg_temp.pegar('fora')));
update public.obra_membros set papel = 'admin', funcao = 'responsavel' where user_id = pg_temp.pegar('mestre')::uuid;
select pg_temp.tentar('cancela', format('select public.cancelar_convite(%L)', pg_temp.pegar('id cancela')));
select pg_temp.como(pg_temp.pegar('fora')::uuid);
select pg_temp.tentar('fora cancela', format('select public.cancelar_convite(%L)', pg_temp.pegar('id cancela')));
select pg_temp.como(pg_temp.pegar('cliente')::uuid);
select pg_temp.tentar('sai', format('select public.remover_membro(%L, %L)', pg_temp.pegar('O'), pg_temp.pegar('cliente')));
select pg_temp.admin();
select pg_temp.conferir('equipe na ordem das funções e com nome de quem não preencheu',
  pg_temp.pegar('lista') = 'Marina Duarte:responsavel:false,João Mestre:mestre:false,Sem nome:estagiario:false,Sem nome:empreiteiro:false,Sem nome:cliente:true', pg_temp.pegar('lista'));
select pg_temp.conferir('quem é de fora não vê a equipe', pg_temp.pegar('fora ve equipe') = 'Obra não encontrada.', pg_temp.pegar('fora ve equipe'));
select pg_temp.conferir('só o responsável muda função', pg_temp.pegar('cliente muda funcao') = 'Só o responsável pela obra muda a função de alguém.', pg_temp.pegar('cliente muda funcao'));
select pg_temp.conferir('só o responsável remove', pg_temp.pegar('cliente remove') = 'Só o responsável pela obra remove pessoas.', pg_temp.pegar('cliente remove'));
select pg_temp.conferir('função muda junto com o papel', pg_temp.pegar('muda funcao') = 'passou' and pg_temp.funcao(pg_temp.pegar('estagiario')) = 'cliente/cliente', pg_temp.pegar('muda funcao'));
select pg_temp.conferir('não vira responsável por função', pg_temp.pegar('funcao ruim') = 'Escolha a função da pessoa.', pg_temp.pegar('funcao ruim'));
select pg_temp.conferir('responsável não muda de função', pg_temp.pegar('muda dono') = 'Esta pessoa não pode ter a função alterada.' and pg_temp.funcao(pg_temp.pegar('dono')) = 'responsavel/admin', pg_temp.pegar('muda dono'));
select pg_temp.conferir('não muda quem não está na obra', pg_temp.pegar('muda de fora') = 'Esta pessoa não pode ter a função alterada.', pg_temp.pegar('muda de fora'));
select pg_temp.conferir('responsável não sai', pg_temp.pegar('dono sai') = 'O responsável não pode sair da obra.', pg_temp.pegar('dono sai'));
select pg_temp.conferir('responsável remove', pg_temp.pegar('remove') = 'passou' and pg_temp.funcao(pg_temp.pegar('empreiteiro')) is null, pg_temp.pegar('remove'));
select pg_temp.conferir('cada um pode sair', pg_temp.pegar('sai') = 'passou' and pg_temp.funcao(pg_temp.pegar('cliente')) is null, pg_temp.pegar('sai'));
select pg_temp.conferir('nem o responsável escreve direto na equipe', pg_temp.pegar('direto') like '%row-level security%' and pg_temp.funcao(pg_temp.pegar('mestre')) = 'mestre/membro', pg_temp.pegar('direto'));
select pg_temp.conferir('convite cancelado some', pg_temp.pegar('cancela') = 'passou' and not exists (select 1 from public.obra_convites where id = pg_temp.pegar('id cancela')::uuid), pg_temp.pegar('cancela'));
select pg_temp.conferir('quem é de fora não cancela', pg_temp.pegar('fora cancela') = 'Convite não encontrado.', pg_temp.pegar('fora cancela'));
select pg_temp.conferir('obras antigas ganharam função',
  not exists (select 1 from public.obra_membros m where m.papel <> case m.funcao when 'responsavel' then 'admin' when 'cliente' then 'cliente' else 'membro' end));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
