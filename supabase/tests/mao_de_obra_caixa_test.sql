-- Testes de diárias, contratos, medições e entradas (migração mao_de_obra_caixa). Roda numa transação; o bloco final levanta
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

select pg_temp.guardar('O', '00000000-0000-0000-0000-0000000b0001');
select pg_temp.guardar('O2', '00000000-0000-0000-0000-0000000b0002');
select pg_temp.guardar('dono', '00000000-0000-0000-0000-00000000a001');
select pg_temp.guardar('mestre', '00000000-0000-0000-0000-00000000a002');
select pg_temp.guardar('estagiario', '00000000-0000-0000-0000-00000000a003');
select pg_temp.guardar('empreiteiro', '00000000-0000-0000-0000-00000000a004');
select pg_temp.guardar('outroemp', '00000000-0000-0000-0000-00000000a008');
select pg_temp.guardar('cliente', '00000000-0000-0000-0000-00000000a005');
select pg_temp.guardar('fora', '00000000-0000-0000-0000-00000000a006');
select pg_temp.guardar('ontem', ((now() at time zone 'America/Sao_Paulo')::date - 1)::text);
select pg_temp.guardar('hoje', ((now() at time zone 'America/Sao_Paulo')::date)::text);
select pg_temp.guardar('futuro', ((now() at time zone 'America/Sao_Paulo')::date + 5)::text);

insert into auth.users (id, email, aud, role)
select v.valor::uuid, v.chave || '@teste.dailyobra', 'authenticated', 'authenticated' from v where v.valor like '00000000-0000-0000-0000-00000000a%';
insert into public.obras (id, nome, created_by) values
  ('00000000-0000-0000-0000-0000000b0001', 'Obra do teste', '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000b0002', 'Outra obra', '00000000-0000-0000-0000-00000000a006');
insert into public.obra_membros (obra_id, user_id, papel, funcao) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a002', 'membro', 'mestre'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a003', 'membro', 'estagiario'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a004', 'membro', 'empreiteiro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a008', 'membro', 'empreiteiro'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000a005', 'cliente', 'cliente');

-- Diaristas
select pg_temp.como('dono');
select pg_temp.guardar('ze', (select public.salvar_diarista(pg_temp.pegar('O')::uuid, null, '{"nome": "  Zé  ", "funcao": " Pedreiro ", "diaria": 200.555}'::jsonb)::text));
select pg_temp.como('mestre');
select pg_temp.guardar('ana', (select public.salvar_diarista(pg_temp.pegar('O')::uuid, null, '{"nome": "Ana", "diaria": 999}'::jsonb)::text));
select pg_temp.tentar('mestre muda valor', format('select public.salvar_diarista(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('ze'), '{"nome": "Zé Maria", "diaria": 1}'));
select pg_temp.guardar('mestre le valor', (select string_agg(coalesce(diaria::text, '-'), ',') from public.diaristas_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('tabela diaristas', (select count(*)::text from public.obra_diaristas));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario le', format('select public.diaristas_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.tentar('estagiario salva', format('select public.salvar_diarista(%L, null, %L)', pg_temp.pegar('O'), '{"nome": "x"}'));
select pg_temp.como('cliente');
select pg_temp.tentar('cliente le', format('select public.diaristas_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.como('fora');
select pg_temp.tentar('fora salva', format('select public.salvar_diarista(%L, null, %L)', pg_temp.pegar('O'), '{"nome": "x"}'));
select pg_temp.tentar('fora de outra obra', format('select public.salvar_diarista(%L, %L, %L)', pg_temp.pegar('O2'), pg_temp.pegar('ze'), '{"nome": "Roubado", "diaria": 1}'));
select pg_temp.como('dono');
select pg_temp.tentar('sem nome', format('select public.salvar_diarista(%L, null, %L)', pg_temp.pegar('O'), '{"nome": " "}'));
select pg_temp.tentar('valor negativo', format('select public.salvar_diarista(%L, null, %L)', pg_temp.pegar('O'), '{"nome": "x", "diaria": -1}'));
select pg_temp.admin();
select pg_temp.conferir('responsável define nome, função e valor',
  (select nome = 'Zé Maria' and funcao is null and diaria = 200.56 from public.obra_diaristas where id = pg_temp.pegar('ze')::uuid));
select pg_temp.conferir('mestre põe na lista, sem definir valor', (select diaria = 0 from public.obra_diaristas where id = pg_temp.pegar('ana')::uuid));
select pg_temp.conferir('mestre não troca o valor', pg_temp.pegar('mestre muda valor') = 'passou' and (select diaria = 200.56 from public.obra_diaristas where id = pg_temp.pegar('ze')::uuid), pg_temp.pegar('mestre muda valor'));
select pg_temp.conferir('mestre lê sem o valor', pg_temp.pegar('mestre le valor') = '-,-', pg_temp.pegar('mestre le valor'));
select pg_temp.conferir('tabela não abre direto', pg_temp.pegar('tabela diaristas') = '0', pg_temp.pegar('tabela diaristas'));
select pg_temp.conferir('estagiário e cliente não entram', pg_temp.pegar('estagiario le') = 'Obra não encontrada.' and pg_temp.pegar('cliente le') = 'Obra não encontrada.' and pg_temp.pegar('estagiario salva') = 'Só o responsável ou o mestre mexem na lista de diaristas.', pg_temp.pegar('estagiario le'));
select pg_temp.conferir('quem é de fora não entra', pg_temp.pegar('fora salva') = 'Só o responsável ou o mestre mexem na lista de diaristas.', pg_temp.pegar('fora salva'));
select pg_temp.conferir('pessoa de outra obra não muda pela obra dele', pg_temp.pegar('fora de outra obra') = 'Pessoa não encontrada.', pg_temp.pegar('fora de outra obra'));
select pg_temp.conferir('nome é obrigatório', pg_temp.pegar('sem nome') = 'Diga o nome da pessoa.', pg_temp.pegar('sem nome'));
select pg_temp.conferir('diária não é negativa', pg_temp.pegar('valor negativo') = 'Valor da diária inválido.', pg_temp.pegar('valor negativo'));

-- Presenças
select pg_temp.como('mestre');
select pg_temp.tentar('marca ze', format('select public.marcar_presenca(%L, %L, 1)', pg_temp.pegar('ze'), pg_temp.pegar('ontem')));
select pg_temp.tentar('marca ana', format('select public.marcar_presenca(%L, %L, 0.5)', pg_temp.pegar('ana'), pg_temp.pegar('ontem')));
select pg_temp.tentar('marca de novo', format('select public.marcar_presenca(%L, %L, 0.5)', pg_temp.pegar('ze'), pg_temp.pegar('hoje')));
select pg_temp.tentar('muda', format('select public.marcar_presenca(%L, %L, 1)', pg_temp.pegar('ze'), pg_temp.pegar('hoje')));
select pg_temp.tentar('marca futuro', format('select public.marcar_presenca(%L, %L, 1)', pg_temp.pegar('ze'), pg_temp.pegar('futuro')));
select pg_temp.tentar('dias errados', format('select public.marcar_presenca(%L, %L, 2)', pg_temp.pegar('ze'), pg_temp.pegar('hoje')));
select pg_temp.tentar('tira', format('select public.marcar_presenca(%L, %L, 0)', pg_temp.pegar('ana'), pg_temp.pegar('hoje')));
select pg_temp.guardar('mestre presencas', (select count(*)::text from public.presencas_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario marca', format('select public.marcar_presenca(%L, %L, 1)', pg_temp.pegar('ze'), pg_temp.pegar('hoje')));
select pg_temp.tentar('estagiario presencas', format('select public.presencas_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.como('fora');
select pg_temp.tentar('fora marca', format('select public.marcar_presenca(%L, %L, 1)', pg_temp.pegar('ze'), pg_temp.pegar('hoje')));
select pg_temp.admin();
select pg_temp.conferir('mestre marca e corrige', pg_temp.pegar('marca ze') = 'passou' and pg_temp.pegar('muda') = 'passou' and pg_temp.pegar('mestre presencas') = '3', pg_temp.pegar('mestre presencas'));
select pg_temp.conferir('dia futuro recusado', pg_temp.pegar('marca futuro') = 'Não dá para marcar um dia que ainda não chegou.', pg_temp.pegar('marca futuro'));
select pg_temp.conferir('só dia inteiro ou meio dia', pg_temp.pegar('dias errados') = 'Marque dia inteiro, meio dia ou falta.', pg_temp.pegar('dias errados'));
select pg_temp.conferir('estagiário não marca', pg_temp.pegar('estagiario marca') = 'Pessoa não encontrada.' and pg_temp.pegar('estagiario presencas') = 'Obra não encontrada.', pg_temp.pegar('estagiario marca'));
select pg_temp.conferir('quem é de fora não marca', pg_temp.pegar('fora marca') = 'Pessoa não encontrada.', pg_temp.pegar('fora marca'));

-- Pagar diárias
select pg_temp.como('mestre');
select pg_temp.tentar('mestre paga', format('select public.pagar_diarias(%L, %L)', pg_temp.pegar('O'), pg_temp.pegar('hoje')));
select pg_temp.como('dono');
select pg_temp.tentar('sem valor', format('select public.pagar_diarias(%L, %L)', pg_temp.pegar('O'), pg_temp.pegar('hoje')));
select pg_temp.tentar('define ana', format('select public.salvar_diarista(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('ana'), '{"nome": "Ana", "diaria": 100}'));
select pg_temp.tentar('paga futuro', format('select public.pagar_diarias(%L, %L)', pg_temp.pegar('O'), pg_temp.pegar('futuro')));
select pg_temp.guardar('g diarias', (select public.pagar_diarias(pg_temp.pegar('O')::uuid, pg_temp.pegar('hoje')::date, 'alvenaria')::text));
select pg_temp.tentar('paga de novo', format('select public.pagar_diarias(%L, %L)', pg_temp.pegar('O'), pg_temp.pegar('hoje')));
select pg_temp.tentar('muda pago', format('select public.marcar_presenca(%L, %L, 0)', pg_temp.pegar('ze'), pg_temp.pegar('ontem')));
select pg_temp.tentar('edita pagamento', format('select public.salvar_gasto(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('g diarias'), json_build_object('descricao', 'x', 'valor', 1, 'data', pg_temp.pegar('hoje'))));
select pg_temp.admin();
select pg_temp.conferir('mestre não paga', pg_temp.pegar('mestre paga') = 'Só o responsável registra pagamentos.', pg_temp.pegar('mestre paga'));
select pg_temp.conferir('pede o valor que falta', pg_temp.pegar('sem valor') = 'Defina o valor da diária de Ana.', pg_temp.pegar('sem valor'));
select pg_temp.conferir('pagamento não fica no futuro', pg_temp.pegar('paga futuro') = 'A data do pagamento não pode estar no futuro.', pg_temp.pegar('paga futuro'));
select pg_temp.conferir('pagamento soma as diárias e entra na conta',
  (select valor = 451.12 and tipo = 'mao_de_obra' and vinculo = 'diarias' and etapa = 'alvenaria' and descricao like '%(2 pessoas)' from public.obra_gastos where id = pg_temp.pegar('g diarias')::uuid), (select valor::text from public.obra_gastos where id = pg_temp.pegar('g diarias')::uuid));
select pg_temp.conferir('nada fica em aberto', not exists (select 1 from public.obra_presencas p join public.obra_diaristas d on d.id = p.diarista_id where d.obra_id = pg_temp.pegar('O')::uuid and p.gasto_id is null));
select pg_temp.conferir('não paga duas vezes', pg_temp.pegar('paga de novo') = 'Não há diárias em aberto.', pg_temp.pegar('paga de novo'));
select pg_temp.conferir('dia pago não muda', pg_temp.pegar('muda pago') = 'Este dia já foi pago. Para mudar, exclua o pagamento no dinheiro da obra.', pg_temp.pegar('muda pago'));
select pg_temp.conferir('pagamento não se edita', pg_temp.pegar('edita pagamento') = 'Este gasto veio de um pagamento. Para corrigir, exclua e pague de novo.', pg_temp.pegar('edita pagamento'));
select pg_temp.como('dono');
select pg_temp.tentar('desfaz', format('select public.excluir_gasto(%L)', pg_temp.pegar('g diarias')));
select pg_temp.guardar('reabertos', (select count(*)::text from public.presencas_da_obra(pg_temp.pegar('O')::uuid) where not pago));
select pg_temp.admin();
select pg_temp.conferir('excluir o pagamento reabre as diárias', pg_temp.pegar('desfaz') = 'passou' and pg_temp.pegar('reabertos') = '3', pg_temp.pegar('reabertos'));

-- Contratos
select pg_temp.como('dono');
select pg_temp.guardar('c1', (select public.salvar_contrato(pg_temp.pegar('O')::uuid, null, json_build_object('empreiteiro', ' João Reboco ', 'servico', ' Reboco ', 'etapa', 'alvenaria', 'valor', 10000.005, 'usuario', pg_temp.pegar('empreiteiro'))::jsonb)::text));
select pg_temp.guardar('c2', (select public.salvar_contrato(pg_temp.pegar('O')::uuid, null, '{"empreiteiro": "Sem acesso", "servico": "Pintura", "valor": 3333}'::jsonb)::text));
select pg_temp.tentar('sem empreiteiro', format('select public.salvar_contrato(%L, null, %L)', pg_temp.pegar('O'), '{"servico": "x", "valor": 1}'));
select pg_temp.tentar('sem servico', format('select public.salvar_contrato(%L, null, %L)', pg_temp.pegar('O'), '{"empreiteiro": "x", "valor": 1}'));
select pg_temp.tentar('sem valor contrato', format('select public.salvar_contrato(%L, null, %L)', pg_temp.pegar('O'), '{"empreiteiro": "x", "servico": "y", "valor": 0}'));
select pg_temp.tentar('usuario errado', format('select public.salvar_contrato(%L, null, %L)', pg_temp.pegar('O'), json_build_object('empreiteiro', 'x', 'servico', 'y', 'valor', 1, 'usuario', pg_temp.pegar('cliente'))));
select pg_temp.como('mestre');
select pg_temp.tentar('mestre contrato', format('select public.salvar_contrato(%L, null, %L)', pg_temp.pegar('O'), '{"empreiteiro": "x", "servico": "y", "valor": 1}'));
select pg_temp.tentar('mestre exclui contrato', format('select public.excluir_contrato(%L)', pg_temp.pegar('c2')));
select pg_temp.guardar('mestre contratos', (select string_agg(coalesce(valor::text, '-'), ',') from public.contratos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.guardar('tabela contratos', (select count(*)::text from public.obra_contratos));
select pg_temp.como('empreiteiro');
select pg_temp.guardar('emp contratos', (select string_agg(servico || ':' || valor::text, ',') from public.contratos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('outroemp');
select pg_temp.guardar('outro contratos', (select count(*)::text from public.contratos_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('estagiario');
select pg_temp.tentar('estagiario contratos', format('select public.contratos_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.como('cliente');
select pg_temp.tentar('cliente contratos', format('select public.contratos_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.tentar('cliente medicoes', format('select public.medicoes_da_obra(%L)', pg_temp.pegar('O')));
select pg_temp.admin();
select pg_temp.conferir('contrato guarda tudo', (select empreiteiro = 'João Reboco' and servico = 'Reboco' and valor = 10000.01 and usuario = pg_temp.pegar('empreiteiro')::uuid from public.obra_contratos where id = pg_temp.pegar('c1')::uuid));
select pg_temp.conferir('contrato pede empreiteiro, serviço e valor',
  pg_temp.pegar('sem empreiteiro') = 'Diga quem é o empreiteiro.' and pg_temp.pegar('sem servico') = 'Diga qual é o serviço.' and pg_temp.pegar('sem valor contrato') = 'Digite um valor maior que zero.', pg_temp.pegar('sem empreiteiro'));
select pg_temp.conferir('só liga a empreiteiro da obra', pg_temp.pegar('usuario errado') = 'Essa pessoa não é empreiteiro nesta obra.', pg_temp.pegar('usuario errado'));
select pg_temp.conferir('só o responsável mexe em contrato', pg_temp.pegar('mestre contrato') = 'Só o responsável mexe nos contratos.' and pg_temp.pegar('mestre exclui contrato') = 'Contrato não encontrado.', pg_temp.pegar('mestre contrato'));
select pg_temp.conferir('mestre vê contratos sem valor', pg_temp.pegar('mestre contratos') = '-,-', pg_temp.pegar('mestre contratos'));
select pg_temp.conferir('tabela de contratos não abre direto', pg_temp.pegar('tabela contratos') = '0', pg_temp.pegar('tabela contratos'));
select pg_temp.conferir('empreiteiro vê só o contrato dele, com valor', pg_temp.pegar('emp contratos') = 'Reboco:10000.01' and pg_temp.pegar('outro contratos') = '0', pg_temp.pegar('emp contratos'));
select pg_temp.conferir('estagiário e cliente não veem contratos',
  pg_temp.pegar('estagiario contratos') = 'Obra não encontrada.' and pg_temp.pegar('cliente contratos') = 'Obra não encontrada.' and pg_temp.pegar('cliente medicoes') = 'Obra não encontrada.', pg_temp.pegar('cliente contratos'));

-- Medições
select pg_temp.como('mestre');
select pg_temp.guardar('m1', (select public.lancar_medicao(pg_temp.pegar('c1')::uuid, pg_temp.pegar('ontem')::date, 33.33, '  Primeira  ')::text));
select pg_temp.tentar('duas pendentes', format('select public.lancar_medicao(%L, %L, 50)', pg_temp.pegar('c1'), pg_temp.pegar('hoje')));
select pg_temp.tentar('mestre aprova', format('select public.aprovar_medicao(%L)', pg_temp.pegar('m1')));
select pg_temp.tentar('mestre paga medicao', format('select public.pagar_medicao(%L, %L)', pg_temp.pegar('m1'), pg_temp.pegar('hoje')));
select pg_temp.guardar('mestre medicoes', (select string_agg(numero || ':' || percentual || ':' || coalesce(valor::text, '-'), ',') from public.medicoes_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('empreiteiro');
select pg_temp.tentar('emp lanca', format('select public.lancar_medicao(%L, %L, 50)', pg_temp.pegar('c1'), pg_temp.pegar('hoje')));
select pg_temp.guardar('emp medicoes', (select string_agg(valor::text, ',') from public.medicoes_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('outroemp');
select pg_temp.guardar('outro medicoes', (select count(*)::text from public.medicoes_da_obra(pg_temp.pegar('O')::uuid)));
select pg_temp.como('dono');
select pg_temp.tentar('paga sem aprovar', format('select public.pagar_medicao(%L, %L)', pg_temp.pegar('m1'), pg_temp.pegar('hoje')));
select pg_temp.tentar('aprova', format('select public.aprovar_medicao(%L)', pg_temp.pegar('m1')));
select pg_temp.tentar('aprova de novo', format('select public.aprovar_medicao(%L)', pg_temp.pegar('m1')));
select pg_temp.tentar('menor', format('select public.lancar_medicao(%L, %L, 33)', pg_temp.pegar('c1'), pg_temp.pegar('hoje')));
select pg_temp.tentar('demais', format('select public.lancar_medicao(%L, %L, 101)', pg_temp.pegar('c1'), pg_temp.pegar('hoje')));
select pg_temp.tentar('medicao futura', format('select public.lancar_medicao(%L, %L, 50)', pg_temp.pegar('c1'), pg_temp.pegar('futuro')));
select pg_temp.tentar('reduz contrato', format('select public.salvar_contrato(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('c1'), '{"empreiteiro": "J", "servico": "R", "valor": 100}'));
select pg_temp.tentar('exclui com medicao', format('select public.excluir_contrato(%L)', pg_temp.pegar('c1')));
select pg_temp.guardar('g med', (select public.pagar_medicao(pg_temp.pegar('m1')::uuid, pg_temp.pegar('hoje')::date)::text));
select pg_temp.tentar('paga medicao de novo', format('select public.pagar_medicao(%L, %L)', pg_temp.pegar('m1'), pg_temp.pegar('hoje')));
select pg_temp.tentar('exclui paga', format('select public.excluir_medicao(%L)', pg_temp.pegar('m1')));
select pg_temp.guardar('m2', (select public.lancar_medicao(pg_temp.pegar('c1')::uuid, pg_temp.pegar('hoje')::date, 66.66)::text));
select pg_temp.guardar('m3', (select public.lancar_medicao(pg_temp.pegar('c1')::uuid, pg_temp.pegar('hoje')::date, 100)::text));
select pg_temp.tentar('exclui do meio', format('select public.excluir_medicao(%L)', pg_temp.pegar('m2')));
select pg_temp.tentar('passa de 100', format('select public.lancar_medicao(%L, %L, 100)', pg_temp.pegar('c1'), pg_temp.pegar('hoje')));
select pg_temp.tentar('exclui a ultima', format('select public.excluir_medicao(%L)', pg_temp.pegar('m3')));
select pg_temp.tentar('encerra', format('select public.salvar_contrato(%L, %L, %L)', pg_temp.pegar('O'), pg_temp.pegar('c2'), '{"empreiteiro": "Sem acesso", "servico": "Pintura", "valor": 3333, "encerrado": true}'));
select pg_temp.tentar('mede encerrado', format('select public.lancar_medicao(%L, %L, 10)', pg_temp.pegar('c2'), pg_temp.pegar('hoje')));
select pg_temp.como('mestre');
select pg_temp.guardar('m4', (select public.lancar_medicao(pg_temp.pegar('c1')::uuid, pg_temp.pegar('hoje')::date, 100)::text));
select pg_temp.tentar('mestre exclui pendente', format('select public.excluir_medicao(%L)', pg_temp.pegar('m4')));
select pg_temp.tentar('mestre exclui aprovada', format('select public.excluir_medicao(%L)', pg_temp.pegar('m2')));
select pg_temp.admin();
select pg_temp.conferir('medição vira valor pelo percentual', (select valor = 3333.00 and numero = 1 and observacao = 'Primeira' from public.obra_medicoes where id = pg_temp.pegar('m1')::uuid), (select valor::text from public.obra_medicoes where id = pg_temp.pegar('m1')::uuid));
select pg_temp.conferir('medição do mestre espera aprovação', pg_temp.pegar('paga sem aprovar') = 'Aprove a medição antes de pagar.', pg_temp.pegar('paga sem aprovar'));
select pg_temp.conferir('medição do responsável nasce aprovada', (select aprovada from public.obra_medicoes where id = pg_temp.pegar('m2')::uuid));
select pg_temp.conferir('uma pendente por vez', pg_temp.pegar('duas pendentes') = 'Aprove a medição anterior antes de lançar outra.', pg_temp.pegar('duas pendentes'));
select pg_temp.conferir('mestre não aprova nem paga', pg_temp.pegar('mestre aprova') = 'Medição não encontrada.' and pg_temp.pegar('mestre paga medicao') = 'Medição não encontrada.', pg_temp.pegar('mestre aprova'));
select pg_temp.conferir('mestre vê a medição sem valor', pg_temp.pegar('mestre medicoes') = '1:33.33:-', pg_temp.pegar('mestre medicoes'));
select pg_temp.conferir('empreiteiro não lança e vê o valor da dele', pg_temp.pegar('emp lanca') = 'Contrato não encontrado.' and pg_temp.pegar('emp medicoes') = '3333.00' and pg_temp.pegar('outro medicoes') = '0', pg_temp.pegar('emp medicoes'));
select pg_temp.conferir('aprovar uma vez só', pg_temp.pegar('aprova') = 'passou' and pg_temp.pegar('aprova de novo') = 'Esta medição já foi aprovada.', pg_temp.pegar('aprova de novo'));
select pg_temp.conferir('percentual só sobe, até 100',
  pg_temp.pegar('menor') = 'Digite um percentual acima de 33.33 e até 100.' and pg_temp.pegar('demais') = 'Digite um percentual acima de 33.33 e até 100.', pg_temp.pegar('menor'));
select pg_temp.conferir('medição não fica no futuro', pg_temp.pegar('medicao futura') = 'A data da medição não pode estar no futuro.', pg_temp.pegar('medicao futura'));
select pg_temp.conferir('contrato não fica menor que o medido', pg_temp.pegar('reduz contrato') = 'O contrato não pode ficar menor que o já medido.', pg_temp.pegar('reduz contrato'));
select pg_temp.conferir('contrato com medição não se exclui', pg_temp.pegar('exclui com medicao') = 'Contrato com medição não pode ser excluído. Encerre o contrato.', pg_temp.pegar('exclui com medicao'));
select pg_temp.conferir('pagar medição entra na conta com a etapa do contrato',
  (select valor = 3333.00 and tipo = 'mao_de_obra' and vinculo = 'medicao' and etapa = 'alvenaria' and fornecedor = 'João Reboco' and descricao = 'Medição 1: Reboco' from public.obra_gastos where id = pg_temp.pegar('g med')::uuid));
select pg_temp.conferir('não paga a medição duas vezes', pg_temp.pegar('paga medicao de novo') = 'Esta medição já foi paga.', pg_temp.pegar('paga medicao de novo'));
select pg_temp.conferir('medição paga não se exclui', pg_temp.pegar('exclui paga') = 'Medição paga não pode ser excluída. Exclua o pagamento no dinheiro da obra.', pg_temp.pegar('exclui paga'));
select pg_temp.conferir('só a última sai', pg_temp.pegar('exclui do meio') = 'Só a última medição pode ser excluída.' and pg_temp.pegar('exclui a ultima') = 'passou', pg_temp.pegar('exclui do meio'));
select pg_temp.conferir('não passa de 100%', pg_temp.pegar('passa de 100') = 'Digite um percentual acima de 100 e até 100.', pg_temp.pegar('passa de 100'));
select pg_temp.conferir('contrato encerrado não mede', pg_temp.pegar('encerra') = 'passou' and pg_temp.pegar('mede encerrado') = 'Este contrato está encerrado.', pg_temp.pegar('mede encerrado'));
select pg_temp.conferir('mestre tira a medição pendente, não a aprovada', pg_temp.pegar('mestre exclui pendente') = 'passou' and pg_temp.pegar('mestre exclui aprovada') = 'Medição não encontrada.', pg_temp.pegar('mestre exclui aprovada'));
select pg_temp.como('dono');
select pg_temp.guardar('m5', (select public.lancar_medicao(pg_temp.pegar('c1')::uuid, pg_temp.pegar('hoje')::date, 100)::text));
select pg_temp.tentar('desfaz medicao', format('select public.excluir_gasto(%L)', pg_temp.pegar('g med')));
select pg_temp.guardar('m1 paga', (select pago::text from public.medicoes_da_obra(pg_temp.pegar('O')::uuid) where id = pg_temp.pegar('m1')::uuid));
select pg_temp.admin();
select pg_temp.conferir('a medição de 100% fecha o contrato no centavo', (select sum(valor) = 10000.01 from public.obra_medicoes where contrato_id = pg_temp.pegar('c1')::uuid), (select sum(valor)::text from public.obra_medicoes where contrato_id = pg_temp.pegar('c1')::uuid));
select pg_temp.conferir('excluir o pagamento volta a medição para a pagar', pg_temp.pegar('desfaz medicao') = 'passou' and pg_temp.pegar('m1 paga') = 'false', pg_temp.pegar('m1 paga'));

-- Entradas
select pg_temp.como('dono');
select pg_temp.tentar('entrada', format($q$insert into public.obra_entradas (obra_id, descricao, valor, data, recebido) values (%L, 'Sinal', 5000, %L, true)$q$, pg_temp.pegar('O'), pg_temp.pegar('hoje')));
select pg_temp.tentar('entrada zero', format($q$insert into public.obra_entradas (obra_id, descricao, valor, data) values (%L, 'Sinal', 0, %L)$q$, pg_temp.pegar('O'), pg_temp.pegar('hoje')));
select pg_temp.tentar('entrada alheia', format($q$insert into public.obra_entradas (obra_id, descricao, valor, data) values (%L, 'x', 1, %L)$q$, pg_temp.pegar('O2'), pg_temp.pegar('hoje')));
select pg_temp.como('mestre');
select pg_temp.guardar('mestre entradas', (select count(*)::text from public.obra_entradas));
select pg_temp.tentar('mestre entrada', format($q$insert into public.obra_entradas (obra_id, descricao, valor, data) values (%L, 'x', 1, %L)$q$, pg_temp.pegar('O'), pg_temp.pegar('hoje')));
select pg_temp.como('cliente');
select pg_temp.guardar('cliente entradas', (select count(*)::text from public.obra_entradas));
select pg_temp.como('dono');
select pg_temp.guardar('dono entradas', (select count(*)::text from public.obra_entradas));
select pg_temp.admin();
select pg_temp.conferir('responsável lança entradas', pg_temp.pegar('entrada') = 'passou' and pg_temp.pegar('dono entradas') = '1', pg_temp.pegar('entrada'));
select pg_temp.conferir('entrada precisa de valor', pg_temp.pegar('entrada zero') like '%obra_entradas_valor_check%', pg_temp.pegar('entrada zero'));
select pg_temp.conferir('entrada em obra alheia recusada', pg_temp.pegar('entrada alheia') like '%row-level security%', pg_temp.pegar('entrada alheia'));
select pg_temp.conferir('mestre e cliente não veem entradas', pg_temp.pegar('mestre entradas') = '0' and pg_temp.pegar('cliente entradas') = '0' and pg_temp.pegar('mestre entrada') like '%row-level security%', pg_temp.pegar('mestre entrada'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
