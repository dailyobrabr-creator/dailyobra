-- Diário de obra. As tabelas rdos e rdo_* já existiam, mas deixavam qualquer membro escrever, inclusive o cliente, que só
-- acompanha. Agora todos os membros leem, e gravar passa por salvar_dia_obra, que confere quem pode e troca o dia inteiro de
-- uma vez, para o diário nunca ficar pela metade. Dia finalizado não muda: só o administrador reabre.

drop policy "membros acessam rdos" on public.rdos;
create policy "membros leem rdos" on public.rdos for select to authenticated using (private.is_membro(obra_id));

do $$
declare t text;
begin
  foreach t in array array['rdo_efetivo', 'rdo_atividades', 'rdo_ocorrencias', 'rdo_materiais', 'rdo_equipamentos', 'rdo_fotos'] loop
    -- Cada gravação troca as linhas: sem esta coluna, o PDF sairia com os itens fora da ordem digitada
    execute format('alter table public.%I add column ordem int not null default 0', t);
    execute format('drop policy "membros acessam itens" on public.%I', t);
    execute format(
      'create policy "membros leem itens" on public.%I for select to authenticated using (exists (select 1 from public.rdos r where r.id = %I.rdo_id and private.is_membro(r.obra_id)))',
      t, t);
  end loop;
end $$;

drop policy "membros enviam fotos" on storage.objects;
drop policy "membros apagam fotos" on storage.objects;
create policy "quem registra envia fotos" on storage.objects for insert to authenticated
  with check (bucket_id = 'rdo-fotos' and private.pode_editar(((storage.foldername(name))[1])::uuid));
create policy "quem registra apaga fotos" on storage.objects for delete to authenticated
  using (bucket_id = 'rdo-fotos' and private.pode_editar(((storage.foldername(name))[1])::uuid));

update storage.buckets
   set file_size_limit = 5242880, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'rdo-fotos';

create function public.salvar_dia_obra(p_obra uuid, p_data date, p_dados jsonb, p_finalizar boolean default false) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  id_rdo uuid;
  situacao text;
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  foto jsonb;
  tem_algo boolean;
begin
  if not coalesce(private.pode_editar(p_obra), false) then
    raise exception 'Só quem toca a obra preenche o diário.' using errcode = 'P0001';
  end if;
  if p_data is null then raise exception 'Escolha o dia.' using errcode = 'P0001'; end if;
  -- Um dia de folga cobre a diferença de fuso entre o aparelho e o banco
  if p_data > (now() at time zone 'utc')::date + 1 then
    raise exception 'Não dá para preencher um dia que ainda não chegou.' using errcode = 'P0001';
  end if;
  select status into situacao from public.rdos where obra_id = p_obra and data = p_data for update;
  if situacao is not null and situacao <> 'rascunho' then
    raise exception 'Este dia já foi finalizado. Reabra para alterar.' using errcode = 'P0001';
  end if;
  if jsonb_array_length(coalesce(d -> 'fotos', '[]'::jsonb)) > 10 then
    raise exception 'Cada dia aceita até 10 fotos.' using errcode = 'P0001';
  end if;
  for foto in select * from jsonb_array_elements(coalesce(d -> 'fotos', '[]'::jsonb)) loop
    if left(coalesce(foto ->> 'caminho', ''), 37) <> p_obra::text || '/' then
      raise exception 'Foto de outra obra.' using errcode = 'P0001';
    end if;
  end loop;

  tem_algo := jsonb_array_length(coalesce(d -> 'equipe', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'atividades', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'ocorrencias', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'materiais', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'equipamentos', '[]'::jsonb)) > 0
    or jsonb_array_length(coalesce(d -> 'fotos', '[]'::jsonb)) > 0
    or btrim(coalesce(d ->> 'observacoes', '')) <> '';
  if p_finalizar and not tem_algo then
    raise exception 'Preencha alguma coisa antes de finalizar o dia.' using errcode = 'P0001';
  end if;

  insert into public.rdos (obra_id, data, clima_manha, clima_tarde, observacoes, status)
  values (p_obra, p_data, nullif(d ->> 'clima_manha', ''), nullif(d ->> 'clima_tarde', ''), nullif(btrim(coalesce(d ->> 'observacoes', '')), ''),
          case when p_finalizar then 'finalizado' else 'rascunho' end)
  on conflict (obra_id, data) do update
    set clima_manha = excluded.clima_manha, clima_tarde = excluded.clima_tarde, observacoes = excluded.observacoes,
        status = excluded.status, updated_at = now()
  returning id into id_rdo;

  delete from public.rdo_efetivo where rdo_id = id_rdo;
  delete from public.rdo_atividades where rdo_id = id_rdo;
  delete from public.rdo_ocorrencias where rdo_id = id_rdo;
  delete from public.rdo_materiais where rdo_id = id_rdo;
  delete from public.rdo_equipamentos where rdo_id = id_rdo;
  delete from public.rdo_fotos where rdo_id = id_rdo;

  insert into public.rdo_efetivo (rdo_id, funcao, quantidade, empresa, ordem)
  select id_rdo, btrim(e ->> 'funcao'), coalesce((e ->> 'quantidade')::int, 1), nullif(btrim(coalesce(e ->> 'empresa', '')), ''), n
    from jsonb_array_elements(coalesce(d -> 'equipe', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'funcao', '')) <> '';
  insert into public.rdo_atividades (rdo_id, descricao, local, percentual, ordem)
  select id_rdo, btrim(e ->> 'descricao'), nullif(btrim(coalesce(e ->> 'local', '')), ''), (e ->> 'percentual')::int, n
    from jsonb_array_elements(coalesce(d -> 'atividades', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'descricao', '')) <> '';
  insert into public.rdo_ocorrencias (rdo_id, tipo, descricao, ordem)
  select id_rdo, coalesce(nullif(e ->> 'tipo', ''), 'geral'), btrim(e ->> 'descricao'), n
    from jsonb_array_elements(coalesce(d -> 'ocorrencias', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'descricao', '')) <> '';
  insert into public.rdo_materiais (rdo_id, material, quantidade, unidade, fornecedor, ordem)
  select id_rdo, btrim(e ->> 'material'), (e ->> 'quantidade')::numeric, nullif(btrim(coalesce(e ->> 'unidade', '')), ''), nullif(btrim(coalesce(e ->> 'fornecedor', '')), ''), n
    from jsonb_array_elements(coalesce(d -> 'materiais', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'material', '')) <> '';
  insert into public.rdo_equipamentos (rdo_id, equipamento, quantidade, ordem)
  select id_rdo, btrim(e ->> 'equipamento'), coalesce((e ->> 'quantidade')::int, 1), n
    from jsonb_array_elements(coalesce(d -> 'equipamentos', '[]'::jsonb)) with ordinality as t(e, n) where btrim(coalesce(e ->> 'equipamento', '')) <> '';
  insert into public.rdo_fotos (rdo_id, storage_path, legenda, ordem)
  select id_rdo, e ->> 'caminho', nullif(btrim(coalesce(e ->> 'legenda', '')), ''), n
    from jsonb_array_elements(coalesce(d -> 'fotos', '[]'::jsonb)) with ordinality as t(e, n);

  return id_rdo;
end $$;

create function public.reabrir_dia_obra(p_rdo uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.rdos;
begin
  select * into r from public.rdos where id = p_rdo for update;
  if not found or not coalesce(private.is_membro(r.obra_id), false) then
    raise exception 'Dia não encontrado.' using errcode = 'P0001';
  end if;
  if not coalesce(private.is_admin(r.obra_id), false) then
    raise exception 'Só o administrador da obra reabre um dia.' using errcode = 'P0001';
  end if;
  update public.rdos set status = 'rascunho', updated_at = now() where id = p_rdo;
end $$;

revoke execute on function public.salvar_dia_obra(uuid, date, jsonb, boolean) from public, anon;
revoke execute on function public.reabrir_dia_obra(uuid) from public, anon;
grant execute on function public.salvar_dia_obra(uuid, date, jsonb, boolean) to authenticated;
grant execute on function public.reabrir_dia_obra(uuid) to authenticated;
