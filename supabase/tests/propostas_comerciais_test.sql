-- Testes da proposta comercial (migração propostas_comerciais). Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro
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
create function pg_temp.salvar(k text, id text, dados jsonb) returns void language sql as $$
  select pg_temp.tentar(k, format('select public.salvar_proposta_comercial(%L, %L)', id, dados)) $$;
create function pg_temp.nova(dados jsonb) returns text language sql as $$
  select public.salvar_proposta_comercial(null, dados) ->> 'id' $$;

select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('outro', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('sai', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');
select pg_temp.guardar('O2', '00000000-0000-0000-0000-0000000b0002');

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.valor like '00000000-0000-0000-0000-00000000a%';
insert into public.obras (id, nome, created_by) values
  ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000b0002', 'Obra de outro', '00000000-0000-0000-0000-00000000a002');
insert into public.obra_membros (obra_id, user_id, papel, funcao) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'membro', 'mestre');

-- Salvar
select pg_temp.como('dono');
select pg_temp.guardar('r1', (select public.salvar_proposta_comercial(null, '{"cliente": "  Dona Lia  ", "titulo": " Casa ", "contato": " 65 9 ", "cidade": " Cuiabá ", "uf": "MT", "area": 120, "padrao": "medio", "itens": [{"descricao": "Fundação", "valor": 1000.10}, {"descricao": "Alvenaria", "valor": 2000.20}], "desconto": 0.30, "mostrar_valores": false, "parcelas": [{"descricao": "Entrada", "percentual": 33.33, "dias": 0}, {"descricao": "Meio", "percentual": 33.33, "dias": 30}, {"descricao": "Fim", "percentual": 33.34, "dias": 60}], "prazo_dias": 180, "validade": "2027-01-10", "inclui": " Mão de obra "}'::jsonb)::text));
select pg_temp.guardar('p1', pg_temp.pegar('r1')::jsonb ->> 'id');
select pg_temp.guardar('r2', (select public.salvar_proposta_comercial(null, '{"cliente": "B", "titulo": "Outra"}'::jsonb)::text));
select pg_temp.guardar('p2', pg_temp.pegar('r2')::jsonb ->> 'id');
select pg_temp.salvar('sem cliente', null, '{"cliente": " ", "titulo": "x"}');
select pg_temp.salvar('sem titulo', null, '{"cliente": "x", "titulo": " "}');
select pg_temp.salvar('item vazio', null, '{"cliente": "x", "titulo": "y", "itens": [{"descricao": " ", "valor": 1}]}');
select pg_temp.salvar('item negativo', null, '{"cliente": "x", "titulo": "y", "itens": [{"descricao": "a", "valor": -1}]}');
select pg_temp.salvar('parcela errada', null, '{"cliente": "x", "titulo": "y", "parcelas": [{"descricao": "a", "percentual": 101}]}');
select pg_temp.salvar('prazo parcela', null, '{"cliente": "x", "titulo": "y", "parcelas": [{"descricao": "a", "percentual": 10, "dias": -1}]}');
select pg_temp.salvar('itens errados', null, '{"cliente": "x", "titulo": "y", "itens": "nada"}');
select pg_temp.guardar('dono ve', (select count(*)::text from public.construtor_propostas));
select pg_temp.como('outro');
select pg_temp.guardar('r outro', (select public.salvar_proposta_comercial(null, '{"cliente": "C", "titulo": "D"}'::jsonb)::text));
select pg_temp.guardar('outro ve', (select count(*)::text from public.construtor_propostas));
select pg_temp.salvar('outro muda', pg_temp.pegar('p1'), '{"cliente": "x", "titulo": "y"}');
select pg_temp.tentar('outro apaga', format('delete from public.construtor_propostas where id = %L', pg_temp.pegar('p1')));
select pg_temp.tentar('insert direto', format($q$insert into public.construtor_propostas (numero, cliente, titulo) values (99, 'x', 'y')$q$));
select pg_temp.como('dono');
select pg_temp.tentar('update direto', format($q$update public.construtor_propostas set situacao = 'aceita' where id = %L$q$, pg_temp.pegar('p2')));
select pg_temp.guardar('depois do update', (select situacao from public.construtor_propostas where id = pg_temp.pegar('p2')::uuid));
select pg_temp.admin();
select pg_temp.conferir('guarda tudo, limpo e numerado',
  (select cliente = 'Dona Lia' and titulo = 'Casa' and contato = '65 9' and cidade = 'Cuiabá' and area = 120 and desconto = 0.30 and not mostrar_valores and prazo_dias = 180 and inclui = 'Mão de obra' and numero = 1 and situacao = 'rascunho' from public.construtor_propostas where id = pg_temp.pegar('p1')::uuid));
select pg_temp.conferir('devolve o número para o PDF', (pg_temp.pegar('r1')::jsonb ->> 'numero') = '1' and (pg_temp.pegar('r2')::jsonb ->> 'numero') = '2', pg_temp.pegar('r2'));
select pg_temp.conferir('cada pessoa tem a sua numeração', (pg_temp.pegar('r outro')::jsonb ->> 'numero') = '1', pg_temp.pegar('r outro'));
select pg_temp.conferir('pede cliente e nome', pg_temp.pegar('sem cliente') = 'Diga quem é o cliente.' and pg_temp.pegar('sem titulo') = 'Diga o nome da obra ou do serviço.', pg_temp.pegar('sem cliente'));
select pg_temp.conferir('confere os itens', pg_temp.pegar('item vazio') = 'Cada item precisa de uma descrição de até 200 letras.' and pg_temp.pegar('item negativo') = 'Confira os valores dos itens.' and pg_temp.pegar('itens errados') = 'Proposta inválida.', pg_temp.pegar('item vazio'));
select pg_temp.conferir('confere as parcelas', pg_temp.pegar('parcela errada') = 'Confira os percentuais das parcelas.' and pg_temp.pegar('prazo parcela') = 'Confira os prazos das parcelas.', pg_temp.pegar('parcela errada'));
select pg_temp.conferir('cada um vê só as suas', pg_temp.pegar('dono ve') = '2' and pg_temp.pegar('outro ve') = '1', pg_temp.pegar('outro ve'));
select pg_temp.conferir('proposta de outro não muda nem sai',
  pg_temp.pegar('outro muda') = 'Proposta não encontrada.' and exists (select 1 from public.construtor_propostas where id = pg_temp.pegar('p1')::uuid), pg_temp.pegar('outro muda'));
select pg_temp.conferir('não grava por fora da função', pg_temp.pegar('insert direto') like '%row-level security%' and pg_temp.pegar('depois do update') = 'rascunho', pg_temp.pegar('insert direto'));

-- Situação e edição
select pg_temp.como('dono');
select pg_temp.salvar('muda', pg_temp.pegar('p2'), '{"cliente": "Bia", "titulo": "Outra", "situacao": "enviada"}');
select pg_temp.tentar('apaga', format('delete from public.construtor_propostas where id = %L', pg_temp.pegar('p2')));
select pg_temp.guardar('r3', (select public.salvar_proposta_comercial(null, '{"cliente": "Depois", "titulo": "Numeração"}'::jsonb)::text));
select pg_temp.admin();
select pg_temp.conferir('edita e muda a situação', pg_temp.pegar('muda') = 'passou', pg_temp.pegar('muda'));
select pg_temp.conferir('apaga a própria', pg_temp.pegar('apaga') = 'passou' and not exists (select 1 from public.construtor_propostas where id = pg_temp.pegar('p2')::uuid), pg_temp.pegar('apaga'));
select pg_temp.conferir('número segue depois de apagar a última', (pg_temp.pegar('r3')::jsonb ->> 'numero') = '2', pg_temp.pegar('r3'));

-- Virar obra
select pg_temp.como('dono');
select pg_temp.tentar('rascunho vira', format('select public.proposta_vira_obra(%L, %L, %L)', pg_temp.pegar('p1'), pg_temp.pegar('O'), '2026-12-01'));
select pg_temp.salvar('aceita', pg_temp.pegar('p1'), '{"cliente": "Dona Lia", "titulo": "Casa", "situacao": "aceita", "itens": [{"descricao": "Fundação", "valor": 1000.10}, {"descricao": "Alvenaria", "valor": 2000.20}], "desconto": 0.30, "parcelas": [{"descricao": "Entrada", "percentual": 33.33, "dias": 0}, {"descricao": "Meio", "percentual": 33.33, "dias": 30}, {"descricao": "Fim", "percentual": 33.34, "dias": 60}]}');
select pg_temp.tentar('obra alheia', format('select public.proposta_vira_obra(%L, %L, %L)', pg_temp.pegar('p1'), pg_temp.pegar('O2'), '2026-12-01'));
select pg_temp.tentar('sem data', format('select public.proposta_vira_obra(%L, %L, null)', pg_temp.pegar('p1'), pg_temp.pegar('O')));
select pg_temp.como('outro');
select pg_temp.tentar('outro vira', format('select public.proposta_vira_obra(%L, %L, %L)', pg_temp.pegar('p1'), pg_temp.pegar('O2'), '2026-12-01'));
select pg_temp.como('dono');
select pg_temp.tentar('vira', format('select public.proposta_vira_obra(%L, %L, %L)', pg_temp.pegar('p1'), pg_temp.pegar('O'), '2026-12-01'));
select pg_temp.tentar('vira de novo', format('select public.proposta_vira_obra(%L, %L, %L)', pg_temp.pegar('p1'), pg_temp.pegar('O'), '2026-12-01'));
select pg_temp.salvar('muda virada', pg_temp.pegar('p1'), '{"cliente": "x", "titulo": "y"}');
select pg_temp.admin();
select pg_temp.conferir('só proposta aceita vira obra', pg_temp.pegar('rascunho vira') = 'Marque a proposta como aceita antes de criar a obra.', pg_temp.pegar('rascunho vira'));
select pg_temp.conferir('só em obra que a pessoa administra', pg_temp.pegar('obra alheia') = 'Obra não encontrada.', pg_temp.pegar('obra alheia'));
select pg_temp.conferir('precisa da data de início', pg_temp.pegar('sem data') = 'Escolha a data de início.', pg_temp.pegar('sem data'));
select pg_temp.conferir('proposta de outro não vira', pg_temp.pegar('outro vira') = 'Proposta não encontrada.', pg_temp.pegar('outro vira'));
select pg_temp.conferir('liga a proposta à obra', pg_temp.pegar('vira') = 'passou' and (select obra_id = pg_temp.pegar('O')::uuid from public.construtor_propostas where id = pg_temp.pegar('p1')::uuid), pg_temp.pegar('vira'));
select pg_temp.conferir('parcelas entram previstas, nas datas certas',
  (select string_agg(descricao || ':' || data, ',' order by data) from public.obra_entradas where obra_id = pg_temp.pegar('O')::uuid) = 'Entrada:2026-12-01,Meio:2026-12-31,Fim:2027-01-30'
  and not exists (select 1 from public.obra_entradas where obra_id = pg_temp.pegar('O')::uuid and recebido),
  (select string_agg(descricao || ':' || data, ',' order by data) from public.obra_entradas where obra_id = pg_temp.pegar('O')::uuid));
select pg_temp.conferir('parcelas fecham o total no centavo', (select sum(valor) = 3000.00 from public.obra_entradas where obra_id = pg_temp.pegar('O')::uuid), (select sum(valor)::text from public.obra_entradas where obra_id = pg_temp.pegar('O')::uuid));
select pg_temp.conferir('não vira duas vezes', pg_temp.pegar('vira de novo') = 'Esta proposta já virou obra.' and (select count(*) = 3 from public.obra_entradas where obra_id = pg_temp.pegar('O')::uuid), pg_temp.pegar('vira de novo'));
select pg_temp.conferir('depois de virar obra não muda', pg_temp.pegar('muda virada') = 'Proposta que virou obra não muda.', pg_temp.pegar('muda virada'));

-- Excluir a conta
select pg_temp.como('sai');
select pg_temp.guardar('p sai', pg_temp.nova('{"cliente": "Cliente de quem sai", "titulo": "x"}'::jsonb));
select public.excluir_conta('EXCLUIR');
select pg_temp.admin();
select pg_temp.conferir('propostas saem junto com a conta', not exists (select 1 from public.construtor_propostas where id = pg_temp.pegar('p sai')::uuid));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
