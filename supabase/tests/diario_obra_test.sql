-- Testes do diário de obra (migração diario_obra). Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro
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
create function pg_temp.salvar(k text, obra text, dia date, dados jsonb, finalizar boolean default false) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.salvar_dia_obra(%L, %L, %L, %L)', obra, dia, dados, finalizar)) $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000a001', 'admin@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000a002', 'mestre@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000a003', 'cliente@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000a004', 'estranho@teste.dailyobra', 'authenticated', 'authenticated');

insert into public.obras (id, nome, created_by) values
  ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000b0002', 'Outra obra', '00000000-0000-0000-0000-00000000a004');
insert into public.obra_membros (obra_id, user_id, papel) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a001', 'admin'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a002', 'membro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'cliente'),
  ('00000000-0000-0000-0000-0000000b0002', '00000000-0000-0000-0000-00000000a004', 'admin')
on conflict (obra_id, user_id) do update set papel = excluded.papel;

select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');

-- O mestre preenche
select pg_temp.como('00000000-0000-0000-0000-00000000a002');
select pg_temp.salvar('rascunho', pg_temp.pegar('O'), '2026-11-02', $j${
  "clima_manha": "sol", "clima_tarde": "chuva", "observacoes": "  Concretagem adiada  ",
  "equipe": [{"funcao": "Pedreiro", "quantidade": 3, "empresa": "Equipe Silva"}, {"funcao": "  ", "quantidade": 1}],
  "atividades": [{"descricao": "Reboco da sala", "local": "Térreo", "percentual": 60}],
  "ocorrencias": [{"tipo": "atraso", "descricao": "Chuva à tarde"}],
  "materiais": [{"material": "Cimento", "quantidade": 10, "unidade": "saco", "fornecedor": "Operário"}],
  "equipamentos": [{"equipamento": "Betoneira", "quantidade": 1}],
  "fotos": [{"caminho": "00000000-0000-0000-0000-0000000b0001/2026-11-02/a.jpg", "legenda": "Sala"}]
}$j$::jsonb);
select pg_temp.salvar('de novo', pg_temp.pegar('O'), '2026-11-02', '{"clima_manha": "nublado", "equipe": [{"funcao": "Servente", "quantidade": 2}]}'::jsonb);
select pg_temp.tentar('direto', $q$insert into public.rdos (obra_id, data) values ('00000000-0000-0000-0000-0000000b0001', '2026-10-01')$q$);
select pg_temp.tentar('item direto', format('delete from public.rdo_efetivo where rdo_id = (select id from public.rdos where data = %L)', '2026-11-02'));
select pg_temp.guardar('equipe vista', (select count(*)::text from public.rdo_efetivo));
select pg_temp.admin();
select pg_temp.conferir('mestre salva o dia', pg_temp.pegar('rascunho') = 'passou', pg_temp.pegar('rascunho'));
select pg_temp.conferir('salvar de novo troca, não duplica',
  pg_temp.pegar('de novo') = 'passou'
  and (select count(*) from public.rdos where obra_id = pg_temp.pegar('O')::uuid and data = '2026-11-02') = 1
  and (select string_agg(funcao, ',') from public.rdo_efetivo e join public.rdos d on d.id = e.rdo_id where d.obra_id = pg_temp.pegar('O')::uuid and d.data = '2026-11-02') = 'Servente'
  and (select clima_manha from public.rdos where obra_id = pg_temp.pegar('O')::uuid) = 'nublado'
  and not exists (select 1 from public.rdo_atividades a join public.rdos d on d.id = a.rdo_id where d.obra_id = pg_temp.pegar('O')::uuid),
  pg_temp.pegar('de novo'));
select pg_temp.conferir('tabela não aceita escrita direta', pg_temp.pegar('direto') like '%row-level security%', pg_temp.pegar('direto'));
select pg_temp.conferir('item não some por fora', pg_temp.pegar('equipe vista') = '1', pg_temp.pegar('equipe vista'));

-- Grava de novo completo, para conferir cada parte
select pg_temp.como('00000000-0000-0000-0000-00000000a002');
select pg_temp.salvar('completo', pg_temp.pegar('O'), '2026-11-02', $j${
  "clima_manha": "sol", "clima_tarde": "chuva", "observacoes": "  Concretagem adiada  ",
  "equipe": [{"funcao": "Pedreiro", "quantidade": 3, "empresa": "Equipe Silva"}, {"funcao": "  ", "quantidade": 1}],
  "atividades": [{"descricao": "Reboco da sala", "local": "Térreo", "percentual": 60}],
  "ocorrencias": [{"tipo": "atraso", "descricao": "Chuva à tarde"}],
  "materiais": [{"material": "Cimento", "quantidade": 10, "unidade": "saco", "fornecedor": "Operário"}],
  "equipamentos": [{"equipamento": "Betoneira", "quantidade": 1}],
  "fotos": [{"caminho": "00000000-0000-0000-0000-0000000b0001/2026-11-02/a.jpg", "legenda": "Sala"}]
}$j$::jsonb);
select pg_temp.admin();
select pg_temp.conferir('dia guarda todas as partes e ignora linha em branco',
  pg_temp.pegar('completo') = 'passou'
  and (select observacoes from public.rdos where obra_id = pg_temp.pegar('O')::uuid) = 'Concretagem adiada'
  and (select count(*) from public.rdo_efetivo) >= 1
  and (select count(*) from public.rdo_efetivo e join public.rdos d on d.id = e.rdo_id where d.obra_id = pg_temp.pegar('O')::uuid) = 1
  and (select percentual from public.rdo_atividades a join public.rdos d on d.id = a.rdo_id where d.obra_id = pg_temp.pegar('O')::uuid) = 60
  and (select tipo from public.rdo_ocorrencias o join public.rdos d on d.id = o.rdo_id where d.obra_id = pg_temp.pegar('O')::uuid) = 'atraso'
  and (select fornecedor from public.rdo_materiais m join public.rdos d on d.id = m.rdo_id where d.obra_id = pg_temp.pegar('O')::uuid) = 'Operário'
  and (select equipamento from public.rdo_equipamentos q join public.rdos d on d.id = q.rdo_id where d.obra_id = pg_temp.pegar('O')::uuid) = 'Betoneira'
  and (select legenda from public.rdo_fotos f join public.rdos d on d.id = f.rdo_id where d.obra_id = pg_temp.pegar('O')::uuid) = 'Sala',
  pg_temp.pegar('completo'));

-- A ordem digitada volta igual
select pg_temp.como('00000000-0000-0000-0000-00000000a002');
select pg_temp.salvar('ordem', pg_temp.pegar('O'), '2026-10-30', '{"equipe": [{"funcao": "Zé"}, {"funcao": "Ana"}, {"funcao": "Bia"}]}'::jsonb);
select pg_temp.admin();
select pg_temp.conferir('itens guardam a ordem digitada',
  (select string_agg(e.funcao, ',' order by e.ordem) from public.rdo_efetivo e join public.rdos d on d.id = e.rdo_id
    where d.obra_id = pg_temp.pegar('O')::uuid and d.data = '2026-10-30') = 'Zé,Ana,Bia', pg_temp.pegar('ordem'));

-- Quem não pode
select pg_temp.como('00000000-0000-0000-0000-00000000a003');
select pg_temp.salvar('cliente', pg_temp.pegar('O'), '2026-11-03', '{"observacoes": "x"}'::jsonb);
select pg_temp.guardar('cliente lê', (select count(*)::text from public.rdos));
select pg_temp.guardar('cliente lê itens', (select count(*)::text from public.rdo_atividades));
select pg_temp.como('00000000-0000-0000-0000-00000000a004');
select pg_temp.salvar('estranho', pg_temp.pegar('O'), '2026-11-03', '{"observacoes": "x"}'::jsonb);
select pg_temp.guardar('estranho lê', (select count(*)::text from public.rdos where obra_id = '00000000-0000-0000-0000-0000000b0001'));
select pg_temp.admin();
select pg_temp.conferir('cliente não preenche', pg_temp.pegar('cliente') = 'Só quem toca a obra preenche o diário.', pg_temp.pegar('cliente'));
select pg_temp.conferir('cliente acompanha', pg_temp.pegar('cliente lê') = '2' and pg_temp.pegar('cliente lê itens') = '1', pg_temp.pegar('cliente lê'));
select pg_temp.conferir('quem é de fora não preenche', pg_temp.pegar('estranho') = 'Só quem toca a obra preenche o diário.', pg_temp.pegar('estranho'));
select pg_temp.conferir('quem é de fora não lê', pg_temp.pegar('estranho lê') = '0', pg_temp.pegar('estranho lê'));

-- Regras do dia
select pg_temp.como('00000000-0000-0000-0000-00000000a002');
select pg_temp.salvar('futuro', pg_temp.pegar('O'), (now() + interval '5 days')::date, '{"observacoes": "x"}'::jsonb);
select pg_temp.salvar('foto alheia', pg_temp.pegar('O'), '2026-11-01', '{"fotos": [{"caminho": "00000000-0000-0000-0000-0000000b0002/x.jpg"}]}'::jsonb);
select pg_temp.salvar('muitas fotos', pg_temp.pegar('O'), '2026-11-01', jsonb_build_object('fotos',
  (select jsonb_agg(jsonb_build_object('caminho', pg_temp.pegar('O') || '/' || n || '.jpg')) from generate_series(1, 11) n)));
select pg_temp.salvar('clima errado', pg_temp.pegar('O'), '2026-11-01', '{"clima_manha": "neve"}'::jsonb);
select pg_temp.salvar('vazio', pg_temp.pegar('O'), '2026-11-01', '{"clima_manha": "sol"}'::jsonb, true);
select pg_temp.salvar('finaliza', pg_temp.pegar('O'), '2026-11-02', '{"observacoes": "Dia fechado"}'::jsonb, true);
select pg_temp.salvar('depois de finalizado', pg_temp.pegar('O'), '2026-11-02', '{"observacoes": "Mudei"}'::jsonb);
select pg_temp.tentar('mestre reabre', format('select public.reabrir_dia_obra(%L)', (select id from public.rdos where data = '2026-11-02')));
select pg_temp.como('00000000-0000-0000-0000-00000000a004');
select pg_temp.tentar('de fora reabre', format('select public.reabrir_dia_obra(%L)', (select id from public.rdos r where r.obra_id = '00000000-0000-0000-0000-0000000b0001' limit 1)));
select pg_temp.admin();
select pg_temp.guardar('id dia', (select id::text from public.rdos where obra_id = pg_temp.pegar('O')::uuid and data = '2026-11-02'));
select pg_temp.como('00000000-0000-0000-0000-00000000a001');
select pg_temp.tentar('admin reabre', format('select public.reabrir_dia_obra(%L)', pg_temp.pegar('id dia')));
select pg_temp.salvar('reaberto', pg_temp.pegar('O'), '2026-11-02', '{"observacoes": "Corrigido"}'::jsonb);
select pg_temp.admin();
select pg_temp.conferir('dia futuro recusado', pg_temp.pegar('futuro') = 'Não dá para preencher um dia que ainda não chegou.', pg_temp.pegar('futuro'));
select pg_temp.conferir('foto de outra obra recusada', pg_temp.pegar('foto alheia') = 'Foto de outra obra.', pg_temp.pegar('foto alheia'));
select pg_temp.conferir('no máximo 10 fotos', pg_temp.pegar('muitas fotos') = 'Cada dia aceita até 10 fotos.', pg_temp.pegar('muitas fotos'));
select pg_temp.conferir('clima fora da lista recusado', pg_temp.pegar('clima errado') like '%rdos_clima_manha_check%', pg_temp.pegar('clima errado'));
select pg_temp.conferir('não finaliza dia vazio', pg_temp.pegar('vazio') = 'Preencha alguma coisa antes de finalizar o dia.', pg_temp.pegar('vazio'));
select pg_temp.conferir('dia finalizado não muda', pg_temp.pegar('finaliza') = 'passou' and pg_temp.pegar('depois de finalizado') = 'Este dia já foi finalizado. Reabra para alterar.', pg_temp.pegar('depois de finalizado'));
select pg_temp.conferir('só o administrador reabre', pg_temp.pegar('mestre reabre') = 'Só o administrador da obra reabre um dia.', pg_temp.pegar('mestre reabre'));
select pg_temp.conferir('quem é de fora não acha o dia', pg_temp.pegar('de fora reabre') = 'Dia não encontrado.', pg_temp.pegar('de fora reabre'));
select pg_temp.conferir('reaberto volta a aceitar mudança',
  pg_temp.pegar('admin reabre') = 'passou' and pg_temp.pegar('reaberto') = 'passou'
  and (select status = 'rascunho' and observacoes = 'Corrigido' from public.rdos where id = pg_temp.pegar('id dia')::uuid), pg_temp.pegar('reaberto'));
select pg_temp.conferir('fotos: cliente não envia nem apaga',
  (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname in ('quem registra envia fotos', 'quem registra apaga fotos')) = 2
  and not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname in ('membros enviam fotos', 'membros apagam fotos')));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
