-- Documentos e checklists da obra. Cada documento diz quem pode ver: só quem lidera, toda a equipe ou também o cliente. Contrato não
-- deve ir para o empreiteiro e projeto deve, por isso a escolha é por documento, e o arquivo segue a mesma regra.
-- Checklist é preenchido por responsável, mestre e estagiário. Só quem lidera conclui, e concluído não muda: é o registro de que a
-- verificação foi feita. Ao concluir, cada item não conforme vira pendência da obra, para o problema não ficar só no papel.

create table public.obra_documentos (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  tipo text not null default 'outro' check (tipo in ('art', 'projeto', 'alvara', 'contrato', 'licenca', 'outro')),
  titulo text not null check (char_length(btrim(titulo)) between 1 and 160),
  numero text check (char_length(numero) <= 60),
  validade date,
  caminho text,
  nome_arquivo text check (char_length(nome_arquivo) <= 200),
  acesso text not null default 'lideres' check (acesso in ('lideres', 'equipe', 'todos')),
  criado_por uuid default auth.uid() references auth.users (id) on delete set null,
  criado_em timestamptz not null default now()
);
create index obra_documentos_obra_idx on public.obra_documentos (obra_id);
create index obra_documentos_caminho_idx on public.obra_documentos (caminho);
alter table public.obra_documentos enable row level security;

create function private.ve_documento(p_obra uuid, p_acesso text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.lidera_obra(p_obra), false)
      or (p_acesso = 'equipe' and coalesce(private.pode_editar(p_obra), false))
      or (p_acesso = 'todos' and coalesce(private.is_membro(p_obra), false));
$$;

create function private.baixa_documento(p_caminho text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.obra_documentos d where d.caminho = p_caminho and private.ve_documento(d.obra_id, d.acesso));
$$;

create function private.mexe_no_documento(d public.obra_documentos) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.is_admin(d.obra_id), false)
      or (coalesce(d.criado_por = (select auth.uid()), false) and coalesce(private.lidera_obra(d.obra_id), false));
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('obra-documentos', 'obra-documentos', false, 20971520, array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']);

create policy "quem lidera envia documentos" on storage.objects for insert to authenticated
  with check (bucket_id = 'obra-documentos' and private.lidera_obra(((storage.foldername(name))[1])::uuid));
create policy "quem ve o documento baixa" on storage.objects for select to authenticated
  using (bucket_id = 'obra-documentos' and (private.lidera_obra(((storage.foldername(name))[1])::uuid) or private.baixa_documento(name)));
create policy "quem lidera apaga documentos" on storage.objects for delete to authenticated
  using (bucket_id = 'obra-documentos' and private.lidera_obra(((storage.foldername(name))[1])::uuid));

create function public.documentos_da_obra(p_obra uuid)
returns table (
  id uuid, tipo text, titulo text, numero text, validade date, caminho text, nome_arquivo text, acesso text, posso_mexer boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not coalesce(private.is_membro(p_obra), false) then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select d.id, d.tipo, d.titulo, d.numero, d.validade, d.caminho, d.nome_arquivo, d.acesso, private.mexe_no_documento(d)
      from public.obra_documentos d
     where d.obra_id = p_obra and private.ve_documento(d.obra_id, d.acesso)
     order by d.validade nulls last, d.titulo;
end $$;

create function public.salvar_documento(p_obra uuid, p_id uuid, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  texto text := btrim(coalesce(d ->> 'titulo', ''));
  num text := nullif(btrim(coalesce(d ->> 'numero', '')), '');
  arquivo text := nullif(d ->> 'caminho', '');
  nome text := nullif(btrim(coalesce(d ->> 'nome_arquivo', '')), '');
  quem text := coalesce(nullif(d ->> 'acesso', ''), 'lideres');
  categoria text := coalesce(nullif(d ->> 'tipo', ''), 'outro');
  atual public.obra_documentos;
  novo uuid;
begin
  if not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre guardam documentos.' using errcode = 'P0001';
  end if;
  if texto = '' then raise exception 'Diga o nome do documento.' using errcode = 'P0001'; end if;
  if char_length(texto) > 160 then raise exception 'Use no máximo 160 letras no nome.' using errcode = 'P0001'; end if;
  if char_length(num) > 60 then raise exception 'Use no máximo 60 letras no número.' using errcode = 'P0001'; end if;
  if categoria not in ('art', 'projeto', 'alvara', 'contrato', 'licenca', 'outro') then
    raise exception 'Tipo de documento inválido.' using errcode = 'P0001';
  end if;
  if quem not in ('lideres', 'equipe', 'todos') then raise exception 'Escolha quem pode ver.' using errcode = 'P0001'; end if;
  if arquivo is not null and left(arquivo, 37) <> p_obra::text || '/' then
    raise exception 'Arquivo de outra obra.' using errcode = 'P0001';
  end if;
  if p_id is null then
    insert into public.obra_documentos (obra_id, tipo, titulo, numero, validade, caminho, nome_arquivo, acesso)
    values (p_obra, categoria, texto, num, (d ->> 'validade')::date, arquivo, left(nome, 200), quem)
    returning id into novo;
    return novo;
  end if;
  select * into atual from public.obra_documentos o where o.id = p_id and o.obra_id = p_obra for update;
  if not found or not private.mexe_no_documento(atual) then
    raise exception 'Documento não encontrado.' using errcode = 'P0001';
  end if;
  update public.obra_documentos o
     set tipo = categoria, titulo = texto, numero = num, validade = (d ->> 'validade')::date, caminho = arquivo,
         nome_arquivo = left(nome, 200), acesso = quem
   where o.id = p_id;
  return p_id;
end $$;

-- Devolve o caminho do arquivo, para o app apagar
create function public.excluir_documento(p_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare atual public.obra_documentos;
begin
  select * into atual from public.obra_documentos o where o.id = p_id for update;
  if not found or not private.mexe_no_documento(atual) then
    raise exception 'Documento não encontrado.' using errcode = 'P0001';
  end if;
  delete from public.obra_documentos where id = p_id;
  return atual.caminho;
end $$;

create function private.inspeciona(p_obra uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.obra_membros m
     where m.obra_id = p_obra and m.user_id = (select auth.uid()) and m.funcao in ('responsavel', 'mestre', 'estagiario')
  );
$$;

create table public.obra_checklists (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  modelo text not null check (modelo ~ '^[a-z0-9_]{1,60}$'),
  tipo text not null check (tipo in ('qualidade', 'seguranca')),
  titulo text not null check (char_length(btrim(titulo)) between 1 and 160),
  etapa text check (etapa ~ '^[a-z0-9_]{1,60}$'),
  local text check (char_length(local) <= 120),
  data date not null,
  observacoes text check (char_length(observacoes) <= 1000),
  concluido boolean not null default false,
  concluido_nome text,
  concluido_em timestamptz,
  criado_por uuid default auth.uid() references auth.users (id) on delete set null,
  criado_em timestamptz not null default now()
);
create index obra_checklists_obra_idx on public.obra_checklists (obra_id, data desc);
alter table public.obra_checklists enable row level security;
create policy "quem inspeciona le checklists" on public.obra_checklists for select to authenticated
  using (private.inspeciona(obra_id));

create table public.obra_checklist_itens (
  id uuid primary key default gen_random_uuid(),
  checklist_id uuid not null references public.obra_checklists (id) on delete cascade,
  ordem int not null,
  texto text not null check (char_length(btrim(texto)) between 1 and 300),
  resultado text check (resultado in ('ok', 'nao', 'na')),
  observacao text check (char_length(observacao) <= 500),
  foto_path text,
  pendencia_id uuid references public.obra_pendencias (id) on delete set null
);
create index obra_checklist_itens_lista_idx on public.obra_checklist_itens (checklist_id, ordem);
create index obra_checklist_itens_pendencia_idx on public.obra_checklist_itens (pendencia_id);
alter table public.obra_checklist_itens enable row level security;
create policy "quem inspeciona le itens" on public.obra_checklist_itens for select to authenticated
  using (exists (select 1 from public.obra_checklists c where c.id = checklist_id and private.inspeciona(c.obra_id)));

-- Troca o checklist inteiro de uma vez, para ele nunca ficar pela metade. Com p_concluir, confere as respostas e abre as pendências.
create function public.salvar_checklist(p_obra uuid, p_id uuid, p_dados jsonb, p_concluir boolean default false) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  texto text := btrim(coalesce(d ->> 'titulo', ''));
  lugar text := nullif(btrim(coalesce(d ->> 'local', '')), '');
  notas text := nullif(btrim(coalesce(d ->> 'observacoes', '')), '');
  dia date := (d ->> 'data')::date;
  itens jsonb := coalesce(d -> 'itens', '[]'::jsonb);
  item jsonb;
  resposta text;
  foto text;
  atual public.obra_checklists;
  id_lista uuid;
  i record;
  pendencia uuid;
  quem text;
begin
  if not coalesce(private.inspeciona(p_obra), false) then
    raise exception 'Só o responsável, o mestre e o estagiário preenchem checklists.' using errcode = 'P0001';
  end if;
  if coalesce(p_concluir, false) and not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre concluem o checklist.' using errcode = 'P0001';
  end if;
  if texto = '' then raise exception 'Diga o nome do checklist.' using errcode = 'P0001'; end if;
  if char_length(texto) > 160 then raise exception 'Use no máximo 160 letras no nome.' using errcode = 'P0001'; end if;
  if char_length(lugar) > 120 then raise exception 'Use no máximo 120 letras no local.' using errcode = 'P0001'; end if;
  if char_length(notas) > 1000 then raise exception 'Use no máximo 1000 letras nas observações.' using errcode = 'P0001'; end if;
  if dia is null or dia > (now() at time zone 'America/Sao_Paulo')::date + 1 then
    raise exception 'Escolha uma data até hoje.' using errcode = 'P0001';
  end if;
  if jsonb_typeof(itens) is distinct from 'array' or jsonb_array_length(itens) = 0 then
    raise exception 'O checklist precisa de pelo menos um item.' using errcode = 'P0001';
  end if;
  if jsonb_array_length(itens) > 100 then raise exception 'Use no máximo 100 itens.' using errcode = 'P0001'; end if;
  for item in select * from jsonb_array_elements(itens) loop
    resposta := nullif(item ->> 'resultado', '');
    foto := nullif(item ->> 'foto_path', '');
    if char_length(btrim(coalesce(item ->> 'texto', ''))) not between 1 and 300 then
      raise exception 'Cada item precisa de um texto de até 300 letras.' using errcode = 'P0001';
    end if;
    if char_length(item ->> 'observacao') > 500 then raise exception 'Use no máximo 500 letras na observação.' using errcode = 'P0001'; end if;
    if resposta is not null and resposta not in ('ok', 'nao', 'na') then
      raise exception 'Resposta inválida.' using errcode = 'P0001';
    end if;
    if foto is not null and left(foto, 37) <> p_obra::text || '/' then
      raise exception 'Foto de outra obra.' using errcode = 'P0001';
    end if;
    if coalesce(p_concluir, false) and resposta is null then
      raise exception 'Responda todos os itens antes de concluir.' using errcode = 'P0001';
    end if;
  end loop;

  if p_id is null then
    insert into public.obra_checklists (obra_id, modelo, tipo, titulo, etapa, local, data, observacoes)
    values (p_obra, coalesce(nullif(d ->> 'modelo', ''), 'livre'), coalesce(nullif(d ->> 'tipo', ''), 'qualidade'), texto,
            nullif(d ->> 'etapa', ''), lugar, dia, notas)
    returning id into id_lista;
  else
    select * into atual from public.obra_checklists c where c.id = p_id and c.obra_id = p_obra for update;
    if not found then raise exception 'Checklist não encontrado.' using errcode = 'P0001'; end if;
    if atual.concluido then raise exception 'Checklist concluído não muda.' using errcode = 'P0001'; end if;
    id_lista := p_id;
    update public.obra_checklists c
       set titulo = texto, etapa = nullif(d ->> 'etapa', ''), local = lugar, data = dia, observacoes = notas
     where c.id = p_id;
    delete from public.obra_checklist_itens x where x.checklist_id = p_id;
  end if;

  insert into public.obra_checklist_itens (checklist_id, ordem, texto, resultado, observacao, foto_path)
  select id_lista, n, btrim(e ->> 'texto'), nullif(e ->> 'resultado', ''), nullif(btrim(coalesce(e ->> 'observacao', '')), ''),
         nullif(e ->> 'foto_path', '')
    from jsonb_array_elements(itens) with ordinality as t (e, n);

  if coalesce(p_concluir, false) then
    for i in select x.* from public.obra_checklist_itens x where x.checklist_id = id_lista and x.resultado = 'nao' order by x.ordem loop
      insert into public.obra_pendencias (obra_id, descricao, etapa, foto_path)
      values (p_obra, left(texto || ': ' || i.texto || coalesce(' (' || i.observacao || ')', ''), 500), nullif(d ->> 'etapa', ''), i.foto_path)
      returning id into pendencia;
      update public.obra_checklist_itens x set pendencia_id = pendencia where x.id = i.id;
    end loop;
    select coalesce(nullif(btrim(p.nome), ''), 'Sem nome') into quem from public.profiles p where p.id = (select auth.uid());
    update public.obra_checklists c
       set concluido = true, concluido_nome = coalesce(quem, 'Sem nome'), concluido_em = now()
     where c.id = id_lista;
  end if;
  return id_lista;
end $$;

-- Rascunho sai por quem criou ou pelo responsável; concluído, só pelo responsável. Devolve as fotos do rascunho, para o app apagar.
-- As do concluído ficam, porque as pendências abertas por ele usam as mesmas fotos.
create function public.excluir_checklist(p_id uuid) returns text[]
language plpgsql security definer set search_path = '' as $$
declare
  atual public.obra_checklists;
  fotos text[];
begin
  select * into atual from public.obra_checklists c where c.id = p_id for update;
  if not found
     or not (coalesce(private.is_admin(atual.obra_id), false)
             or (not atual.concluido and coalesce(atual.criado_por = (select auth.uid()), false))) then
    raise exception 'Checklist não encontrado.' using errcode = 'P0001';
  end if;
  if not atual.concluido then
    select coalesce(array_agg(x.foto_path) filter (where x.foto_path is not null), '{}') into fotos
      from public.obra_checklist_itens x where x.checklist_id = p_id;
  end if;
  delete from public.obra_checklists where id = p_id;
  return coalesce(fotos, '{}');
end $$;

revoke execute on function public.documentos_da_obra(uuid) from public, anon;
revoke execute on function public.salvar_documento(uuid, uuid, jsonb) from public, anon;
revoke execute on function public.excluir_documento(uuid) from public, anon;
revoke execute on function public.salvar_checklist(uuid, uuid, jsonb, boolean) from public, anon;
revoke execute on function public.excluir_checklist(uuid) from public, anon;
grant execute on function public.documentos_da_obra(uuid) to authenticated;
grant execute on function public.salvar_documento(uuid, uuid, jsonb) to authenticated;
grant execute on function public.excluir_documento(uuid) to authenticated;
grant execute on function public.salvar_checklist(uuid, uuid, jsonb, boolean) to authenticated;
grant execute on function public.excluir_checklist(uuid) to authenticated;
