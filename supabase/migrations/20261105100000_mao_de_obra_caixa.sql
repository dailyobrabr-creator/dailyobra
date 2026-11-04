-- Mão de obra e caixa. Diárias e contratos de empreiteiros entram na conta da obra quando são pagos: o pagamento vira um gasto em
-- obra_gastos, marcado em vinculo. Excluir esse gasto desfaz o pagamento, porque as presenças e as medições apontam para ele.
-- Valor é assunto do responsável: o mestre marca presença e lança medição em percentual, sem ver dinheiro. O empreiteiro ligado a um
-- contrato acompanha só o dele. Por isso as tabelas não abrem direto e tudo passa por funções. Só as entradas de dinheiro, que são
-- do responsável e de mais ninguém, usam política de linha.

alter table public.obra_gastos add column vinculo text check (vinculo in ('diarias', 'medicao'));

create table public.obra_diaristas (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  nome text not null check (char_length(btrim(nome)) between 1 and 120),
  funcao text check (char_length(funcao) <= 60),
  diaria numeric(10, 2) not null default 0 check (diaria >= 0),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create index obra_diaristas_obra_idx on public.obra_diaristas (obra_id);
alter table public.obra_diaristas enable row level security;

create table public.obra_presencas (
  diarista_id uuid not null references public.obra_diaristas (id) on delete cascade,
  data date not null,
  dias numeric(2, 1) not null check (dias in (0.5, 1)),
  gasto_id uuid references public.obra_gastos (id) on delete set null,
  marcado_por uuid default auth.uid() references auth.users (id) on delete set null,
  primary key (diarista_id, data)
);
create index obra_presencas_gasto_idx on public.obra_presencas (gasto_id);
alter table public.obra_presencas enable row level security;

create table public.obra_contratos (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  empreiteiro text not null check (char_length(btrim(empreiteiro)) between 1 and 120),
  usuario uuid references auth.users (id) on delete set null,
  servico text not null check (char_length(btrim(servico)) between 1 and 200),
  etapa text check (etapa ~ '^[a-z0-9_]{1,60}$'),
  valor numeric(12, 2) not null check (valor > 0),
  encerrado boolean not null default false,
  criado_em timestamptz not null default now()
);
create index obra_contratos_obra_idx on public.obra_contratos (obra_id);
alter table public.obra_contratos enable row level security;

create table public.obra_medicoes (
  id uuid primary key default gen_random_uuid(),
  contrato_id uuid not null references public.obra_contratos (id) on delete cascade,
  numero int not null,
  data date not null,
  percentual numeric(5, 2) not null check (percentual > 0 and percentual <= 100),
  valor numeric(12, 2) not null check (valor > 0),
  observacao text check (char_length(observacao) <= 500),
  aprovada boolean not null default false,
  gasto_id uuid references public.obra_gastos (id) on delete set null,
  criado_por uuid default auth.uid() references auth.users (id) on delete set null,
  criado_em timestamptz not null default now(),
  unique (contrato_id, numero)
);
create index obra_medicoes_gasto_idx on public.obra_medicoes (gasto_id);
alter table public.obra_medicoes enable row level security;

create table public.obra_entradas (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras (id) on delete cascade,
  descricao text not null check (char_length(btrim(descricao)) between 1 and 200),
  valor numeric(12, 2) not null check (valor > 0),
  data date not null,
  recebido boolean not null default false,
  criado_em timestamptz not null default now()
);
create index obra_entradas_obra_idx on public.obra_entradas (obra_id, data);
alter table public.obra_entradas enable row level security;
create policy "responsavel cuida das entradas" on public.obra_entradas for all to authenticated
  using (private.is_admin(obra_id)) with check (private.is_admin(obra_id));

-- Data de pagamento e de medição segue a mesma folga do gasto: aceita até amanhã, por causa do fuso
create function private.data_valida(d date) returns boolean
language sql stable set search_path = '' as $$
  select d is not null and d <= (now() at time zone 'America/Sao_Paulo')::date + 1;
$$;

create function public.diaristas_da_obra(p_obra uuid)
returns table (id uuid, nome text, funcao text, diaria numeric, ativo boolean)
language plpgsql stable security definer set search_path = '' as $$
declare chefe boolean := coalesce(private.is_admin(p_obra), false);
begin
  if not chefe and not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select d.id, d.nome, d.funcao, case when chefe then d.diaria end, d.ativo
      from public.obra_diaristas d
     where d.obra_id = p_obra
     order by d.ativo desc, d.nome;
end $$;

-- Quem está na obra põe a pessoa na lista; o valor da diária só o responsável define
create function public.salvar_diarista(p_obra uuid, p_id uuid, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  texto text := btrim(coalesce(d ->> 'nome', ''));
  servico text := nullif(btrim(coalesce(d ->> 'funcao', '')), '');
  v numeric := (d ->> 'diaria')::numeric;
  chefe boolean := coalesce(private.is_admin(p_obra), false);
  novo uuid;
begin
  if not chefe and not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre mexem na lista de diaristas.' using errcode = 'P0001';
  end if;
  if texto = '' then raise exception 'Diga o nome da pessoa.' using errcode = 'P0001'; end if;
  if char_length(texto) > 120 then raise exception 'Use no máximo 120 letras no nome.' using errcode = 'P0001'; end if;
  if char_length(servico) > 60 then raise exception 'Use no máximo 60 letras na função.' using errcode = 'P0001'; end if;
  if v is not null and (v < 0 or v > 99999999) then raise exception 'Valor da diária inválido.' using errcode = 'P0001'; end if;
  if p_id is null then
    insert into public.obra_diaristas (obra_id, nome, funcao, diaria)
    values (p_obra, texto, servico, case when chefe then round(coalesce(v, 0), 2) else 0 end)
    returning id into novo;
    return novo;
  end if;
  update public.obra_diaristas o
     set nome = texto, funcao = servico, ativo = coalesce((d ->> 'ativo')::boolean, o.ativo),
         diaria = case when chefe and v is not null then round(v, 2) else o.diaria end
   where o.id = p_id and o.obra_id = p_obra;
  if not found then raise exception 'Pessoa não encontrada.' using errcode = 'P0001'; end if;
  return p_id;
end $$;

create function public.presencas_da_obra(p_obra uuid)
returns table (diarista_id uuid, data date, dias numeric, pago boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select p.diarista_id, p.data, p.dias, p.gasto_id is not null
      from public.obra_presencas p
      join public.obra_diaristas d on d.id = p.diarista_id
     where d.obra_id = p_obra
     order by p.data desc;
end $$;

-- Zero dias tira a marcação
create function public.marcar_presenca(p_diarista uuid, p_data date, p_dias numeric) returns void
language plpgsql security definer set search_path = '' as $$
declare
  obra uuid;
  pago boolean;
begin
  select d.obra_id into obra from public.obra_diaristas d where d.id = p_diarista;
  if obra is null or not coalesce(private.lidera_obra(obra), false) then
    raise exception 'Pessoa não encontrada.' using errcode = 'P0001';
  end if;
  if not private.data_valida(p_data) then
    raise exception 'Não dá para marcar um dia que ainda não chegou.' using errcode = 'P0001';
  end if;
  if coalesce(p_dias, -1) not in (0, 0.5, 1) then
    raise exception 'Marque dia inteiro, meio dia ou falta.' using errcode = 'P0001';
  end if;
  select p.gasto_id is not null into pago from public.obra_presencas p where p.diarista_id = p_diarista and p.data = p_data for update;
  if coalesce(pago, false) then
    raise exception 'Este dia já foi pago. Para mudar, exclua o pagamento no dinheiro da obra.' using errcode = 'P0001';
  end if;
  if p_dias = 0 then
    delete from public.obra_presencas where diarista_id = p_diarista and data = p_data;
    return;
  end if;
  insert into public.obra_presencas (diarista_id, data, dias) values (p_diarista, p_data, p_dias)
  on conflict (diarista_id, data) do update set dias = excluded.dias, marcado_por = (select auth.uid());
end $$;

-- Paga tudo o que está em aberto de uma vez e vira um gasto só
create function public.pagar_diarias(p_obra uuid, p_data date, p_etapa text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  semana_inicio date;
  semana_fim date;
  pessoas int;
  total numeric;
  sem_valor text;
  novo uuid;
begin
  if not coalesce(private.is_admin(p_obra), false) then
    raise exception 'Só o responsável registra pagamentos.' using errcode = 'P0001';
  end if;
  if not private.data_valida(p_data) then
    raise exception 'A data do pagamento não pode estar no futuro.' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtext('diarias:' || p_obra::text));
  select min(d.nome) into sem_valor
    from public.obra_presencas p
    join public.obra_diaristas d on d.id = p.diarista_id
   where d.obra_id = p_obra and p.gasto_id is null and d.diaria = 0;
  if sem_valor is not null then
    raise exception 'Defina o valor da diária de %.', sem_valor using errcode = 'P0001';
  end if;
  select sum(p.dias * d.diaria), count(distinct d.id), min(p.data), max(p.data)
    into total, pessoas, semana_inicio, semana_fim
    from public.obra_presencas p
    join public.obra_diaristas d on d.id = p.diarista_id
   where d.obra_id = p_obra and p.gasto_id is null;
  if coalesce(total, 0) <= 0 then raise exception 'Não há diárias em aberto.' using errcode = 'P0001'; end if;
  insert into public.obra_gastos (obra_id, etapa, tipo, descricao, valor, data, vinculo)
  values (p_obra, nullif(p_etapa, ''), 'mao_de_obra',
          'Diárias de ' || to_char(semana_inicio, 'DD/MM') || ' a ' || to_char(semana_fim, 'DD/MM') || ' (' || pessoas || case when pessoas = 1 then ' pessoa)' else ' pessoas)' end,
          round(total, 2), p_data, 'diarias')
  returning id into novo;
  update public.obra_presencas p set gasto_id = novo
    from public.obra_diaristas d
   where d.id = p.diarista_id and d.obra_id = p_obra and p.gasto_id is null;
  return novo;
end $$;

create function public.contratos_da_obra(p_obra uuid)
returns table (id uuid, empreiteiro text, usuario uuid, servico text, etapa text, valor numeric, encerrado boolean)
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  f text;
begin
  select m.funcao into f from public.obra_membros m where m.obra_id = p_obra and m.user_id = uid;
  if f is null or f not in ('responsavel', 'mestre', 'empreiteiro') then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select c.id, c.empreiteiro, c.usuario, c.servico, c.etapa, case when f = 'mestre' then null else c.valor end, c.encerrado
      from public.obra_contratos c
     where c.obra_id = p_obra and (f <> 'empreiteiro' or coalesce(c.usuario = uid, false))
     order by c.encerrado, c.criado_em desc;
end $$;

create function public.medicoes_da_obra(p_obra uuid)
returns table (
  id uuid, contrato_id uuid, numero int, data date, percentual numeric, valor numeric, observacao text, aprovada boolean,
  pago boolean, pago_em date
)
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  f text;
begin
  select m.funcao into f from public.obra_membros m where m.obra_id = p_obra and m.user_id = uid;
  if f is null or f not in ('responsavel', 'mestre', 'empreiteiro') then
    raise exception 'Obra não encontrada.' using errcode = 'P0001';
  end if;
  return query
    select x.id, x.contrato_id, x.numero, x.data, x.percentual, case when f = 'mestre' then null else x.valor end, x.observacao,
           x.aprovada, x.gasto_id is not null, g.data
      from public.obra_medicoes x
      join public.obra_contratos c on c.id = x.contrato_id
      left join public.obra_gastos g on g.id = x.gasto_id
     where c.obra_id = p_obra and (f <> 'empreiteiro' or coalesce(c.usuario = uid, false))
     order by x.contrato_id, x.numero;
end $$;

create function public.salvar_contrato(p_obra uuid, p_id uuid, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  nome text := btrim(coalesce(d ->> 'empreiteiro', ''));
  texto text := btrim(coalesce(d ->> 'servico', ''));
  v numeric := (d ->> 'valor')::numeric;
  pessoa uuid := nullif(d ->> 'usuario', '')::uuid;
  medido numeric;
  novo uuid;
begin
  if not coalesce(private.is_admin(p_obra), false) then
    raise exception 'Só o responsável mexe nos contratos.' using errcode = 'P0001';
  end if;
  if nome = '' then raise exception 'Diga quem é o empreiteiro.' using errcode = 'P0001'; end if;
  if texto = '' then raise exception 'Diga qual é o serviço.' using errcode = 'P0001'; end if;
  if char_length(nome) > 120 then raise exception 'Use no máximo 120 letras no nome.' using errcode = 'P0001'; end if;
  if char_length(texto) > 200 then raise exception 'Use no máximo 200 letras no serviço.' using errcode = 'P0001'; end if;
  if v is null or v <= 0 or v > 9999999999 then raise exception 'Digite um valor maior que zero.' using errcode = 'P0001'; end if;
  if pessoa is not null and not exists (
    select 1 from public.obra_membros m where m.obra_id = p_obra and m.user_id = pessoa and m.funcao = 'empreiteiro'
  ) then
    raise exception 'Essa pessoa não é empreiteiro nesta obra.' using errcode = 'P0001';
  end if;
  if p_id is null then
    insert into public.obra_contratos (obra_id, empreiteiro, usuario, servico, etapa, valor)
    values (p_obra, nome, pessoa, texto, nullif(d ->> 'etapa', ''), round(v, 2))
    returning id into novo;
    return novo;
  end if;
  perform 1 from public.obra_contratos c where c.id = p_id and c.obra_id = p_obra for update;
  if not found then raise exception 'Contrato não encontrado.' using errcode = 'P0001'; end if;
  select coalesce(sum(m.valor), 0) into medido from public.obra_medicoes m where m.contrato_id = p_id;
  if v < medido then raise exception 'O contrato não pode ficar menor que o já medido.' using errcode = 'P0001'; end if;
  update public.obra_contratos c
     set empreiteiro = nome, usuario = pessoa, servico = texto, etapa = nullif(d ->> 'etapa', ''), valor = round(v, 2),
         encerrado = coalesce((d ->> 'encerrado')::boolean, c.encerrado)
   where c.id = p_id;
  return p_id;
end $$;

create function public.excluir_contrato(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare obra uuid;
begin
  select c.obra_id into obra from public.obra_contratos c where c.id = p_id for update;
  if obra is null or not coalesce(private.is_admin(obra), false) then
    raise exception 'Contrato não encontrado.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.obra_medicoes m where m.contrato_id = p_id) then
    raise exception 'Contrato com medição não pode ser excluído. Encerre o contrato.' using errcode = 'P0001';
  end if;
  delete from public.obra_contratos where id = p_id;
end $$;

-- O percentual é o total feito até hoje. A última medição fecha o valor exato do contrato, sem sobra de arredondamento.
-- Lançada pelo responsável já nasce aprovada; a do mestre espera a aprovação.
create function public.lancar_medicao(p_contrato uuid, p_data date, p_percentual numeric, p_observacao text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  c public.obra_contratos;
  anterior numeric;
  soma numeric;
  ultimo int;
  v numeric;
  chefe boolean;
  texto text := nullif(btrim(coalesce(p_observacao, '')), '');
  novo uuid;
begin
  select * into c from public.obra_contratos o where o.id = p_contrato for update;
  if not found or not coalesce(private.lidera_obra(c.obra_id), false) then
    raise exception 'Contrato não encontrado.' using errcode = 'P0001';
  end if;
  if c.encerrado then raise exception 'Este contrato está encerrado.' using errcode = 'P0001'; end if;
  if not private.data_valida(p_data) then
    raise exception 'A data da medição não pode estar no futuro.' using errcode = 'P0001';
  end if;
  if char_length(texto) > 500 then raise exception 'Use no máximo 500 letras.' using errcode = 'P0001'; end if;
  if exists (select 1 from public.obra_medicoes m where m.contrato_id = p_contrato and not m.aprovada) then
    raise exception 'Aprove a medição anterior antes de lançar outra.' using errcode = 'P0001';
  end if;
  select coalesce(max(m.percentual), 0), coalesce(sum(m.valor), 0), coalesce(max(m.numero), 0)
    into anterior, soma, ultimo
    from public.obra_medicoes m where m.contrato_id = p_contrato;
  if p_percentual is null or p_percentual <= anterior or p_percentual > 100 then
    raise exception 'Digite um percentual acima de % e até 100.', trim(trailing '.' from trim(trailing '0' from anterior::text)) using errcode = 'P0001';
  end if;
  v := round(c.valor * p_percentual / 100, 2) - soma;
  if v <= 0 then raise exception 'Esta medição não tem valor a pagar.' using errcode = 'P0001'; end if;
  chefe := coalesce(private.is_admin(c.obra_id), false);
  insert into public.obra_medicoes (contrato_id, numero, data, percentual, valor, observacao, aprovada)
  values (p_contrato, ultimo + 1, p_data, p_percentual, v, texto, chefe)
  returning id into novo;
  return novo;
end $$;

create function public.aprovar_medicao(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  obra uuid;
  ja boolean;
begin
  select c.obra_id, m.aprovada into obra, ja
    from public.obra_medicoes m join public.obra_contratos c on c.id = m.contrato_id
   where m.id = p_id for update of m;
  if obra is null or not coalesce(private.is_admin(obra), false) then
    raise exception 'Medição não encontrada.' using errcode = 'P0001';
  end if;
  if ja then raise exception 'Esta medição já foi aprovada.' using errcode = 'P0001'; end if;
  update public.obra_medicoes set aprovada = true where id = p_id;
end $$;

-- Só a última sai: as outras são a base do percentual seguinte
create function public.excluir_medicao(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  x public.obra_medicoes;
  obra uuid;
begin
  select m.* into x from public.obra_medicoes m where m.id = p_id for update;
  if found then select c.obra_id into obra from public.obra_contratos c where c.id = x.contrato_id; end if;
  if obra is null
     or not (coalesce(private.is_admin(obra), false)
             or (not x.aprovada and coalesce(private.lidera_obra(obra), false))) then
    raise exception 'Medição não encontrada.' using errcode = 'P0001';
  end if;
  if x.gasto_id is not null then
    raise exception 'Medição paga não pode ser excluída. Exclua o pagamento no dinheiro da obra.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.obra_medicoes m where m.contrato_id = x.contrato_id and m.numero > x.numero) then
    raise exception 'Só a última medição pode ser excluída.' using errcode = 'P0001';
  end if;
  delete from public.obra_medicoes where id = p_id;
end $$;

create function public.pagar_medicao(p_id uuid, p_data date) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  x public.obra_medicoes;
  c public.obra_contratos;
  novo uuid;
begin
  select m.* into x from public.obra_medicoes m where m.id = p_id for update;
  if found then select * into c from public.obra_contratos o where o.id = x.contrato_id; end if;
  if c.id is null or not coalesce(private.is_admin(c.obra_id), false) then
    raise exception 'Medição não encontrada.' using errcode = 'P0001';
  end if;
  if not private.data_valida(p_data) then
    raise exception 'A data do pagamento não pode estar no futuro.' using errcode = 'P0001';
  end if;
  if not x.aprovada then raise exception 'Aprove a medição antes de pagar.' using errcode = 'P0001'; end if;
  if x.gasto_id is not null then raise exception 'Esta medição já foi paga.' using errcode = 'P0001'; end if;
  insert into public.obra_gastos (obra_id, etapa, tipo, descricao, fornecedor, valor, data, vinculo)
  values (c.obra_id, c.etapa, 'mao_de_obra', left('Medição ' || x.numero || ': ' || c.servico, 200), c.empreiteiro, x.valor, p_data, 'medicao')
  returning id into novo;
  update public.obra_medicoes set gasto_id = novo where id = p_id;
  return novo;
end $$;

-- Pagamento não se edita: o valor dele é a soma das diárias ou da medição. Excluir desfaz e abre de novo.
create or replace function public.salvar_gasto(p_obra uuid, p_id uuid, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d jsonb := coalesce(p_dados, '{}'::jsonb);
  texto text := btrim(coalesce(d ->> 'descricao', ''));
  v numeric := (d ->> 'valor')::numeric;
  dia date := (d ->> 'data')::date;
  nota text := nullif(d ->> 'nota_path', '');
  atual public.obra_gastos;
  novo uuid;
begin
  if not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre lançam gastos.' using errcode = 'P0001';
  end if;
  if texto = '' then raise exception 'Diga o que foi pago.' using errcode = 'P0001'; end if;
  if char_length(texto) > 200 then raise exception 'Use no máximo 200 letras.' using errcode = 'P0001'; end if;
  if v is null or v <= 0 or v > 9999999999 then raise exception 'Digite um valor maior que zero.' using errcode = 'P0001'; end if;
  if dia is null then raise exception 'Escolha a data do gasto.' using errcode = 'P0001'; end if;
  if dia > (now() at time zone 'America/Sao_Paulo')::date + 1 then
    raise exception 'A data do gasto não pode estar no futuro.' using errcode = 'P0001';
  end if;
  if nota is not null and left(nota, 37) <> p_obra::text || '/' then
    raise exception 'Nota de outra obra.' using errcode = 'P0001';
  end if;
  if p_id is null then
    insert into public.obra_gastos (obra_id, etapa, tipo, descricao, fornecedor, valor, data, nota_path)
    values (p_obra, nullif(d ->> 'etapa', ''), coalesce(nullif(d ->> 'tipo', ''), 'material'), texto, nullif(btrim(coalesce(d ->> 'fornecedor', '')), ''), round(v, 2), dia, nota)
    returning id into novo;
    return novo;
  end if;
  select * into atual from public.obra_gastos where id = p_id and obra_id = p_obra for update;
  if not found or not private.mexe_no_gasto(atual) then
    raise exception 'Gasto não encontrado.' using errcode = 'P0001';
  end if;
  if atual.vinculo is not null then
    raise exception 'Este gasto veio de um pagamento. Para corrigir, exclua e pague de novo.' using errcode = 'P0001';
  end if;
  update public.obra_gastos
     set etapa = nullif(d ->> 'etapa', ''), tipo = coalesce(nullif(d ->> 'tipo', ''), 'material'), descricao = texto,
         fornecedor = nullif(btrim(coalesce(d ->> 'fornecedor', '')), ''), valor = round(v, 2), data = dia, nota_path = nota
   where id = p_id;
  return p_id;
end $$;

revoke execute on function public.diaristas_da_obra(uuid) from public, anon;
revoke execute on function public.salvar_diarista(uuid, uuid, jsonb) from public, anon;
revoke execute on function public.presencas_da_obra(uuid) from public, anon;
revoke execute on function public.marcar_presenca(uuid, date, numeric) from public, anon;
revoke execute on function public.pagar_diarias(uuid, date, text) from public, anon;
revoke execute on function public.contratos_da_obra(uuid) from public, anon;
revoke execute on function public.medicoes_da_obra(uuid) from public, anon;
revoke execute on function public.salvar_contrato(uuid, uuid, jsonb) from public, anon;
revoke execute on function public.excluir_contrato(uuid) from public, anon;
revoke execute on function public.lancar_medicao(uuid, date, numeric, text) from public, anon;
revoke execute on function public.aprovar_medicao(uuid) from public, anon;
revoke execute on function public.excluir_medicao(uuid) from public, anon;
revoke execute on function public.pagar_medicao(uuid, date) from public, anon;
grant execute on function public.diaristas_da_obra(uuid) to authenticated;
grant execute on function public.salvar_diarista(uuid, uuid, jsonb) to authenticated;
grant execute on function public.presencas_da_obra(uuid) to authenticated;
grant execute on function public.marcar_presenca(uuid, date, numeric) to authenticated;
grant execute on function public.pagar_diarias(uuid, date, text) to authenticated;
grant execute on function public.contratos_da_obra(uuid) to authenticated;
grant execute on function public.medicoes_da_obra(uuid) to authenticated;
grant execute on function public.salvar_contrato(uuid, uuid, jsonb) to authenticated;
grant execute on function public.excluir_contrato(uuid) to authenticated;
grant execute on function public.lancar_medicao(uuid, date, numeric, text) to authenticated;
grant execute on function public.aprovar_medicao(uuid) to authenticated;
grant execute on function public.excluir_medicao(uuid) to authenticated;
grant execute on function public.pagar_medicao(uuid, date) to authenticated;
