-- Marketplace DailyObra: lojas, catálogo, ofertas, orçamentos, propostas, pedidos e carteira.
-- Só acrescenta tabelas e colunas. Escrita em orçamentos, propostas, pedidos e carteira só pelas
-- funções da migração marketplace_funcoes (nenhuma política de escrita direta aqui).
-- Reversão: drop das tabelas criadas aqui (ordem inversa), do bucket 'lojas' e das colunas novas de profiles.

-- ---------- Perfil do usuário ----------
alter table public.profiles
  add column cidade text,
  add column uf char(2) check (uf ~ '^[A-Z]{2}$'),
  add column telefone text check (telefone ~ '^\d{10,13}$'),
  add column tema text check (tema in ('sistema', 'claro', 'escuro'));

-- ---------- Lojas ----------
create table public.lojas (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(btrim(nome)) between 2 and 80),
  cnpj char(14) not null unique check (cnpj ~ '^\d{14}$'),
  descricao text check (char_length(descricao) <= 600),
  logo_path text,
  capa_path text,
  whatsapp text check (whatsapp ~ '^\d{10,13}$'),
  endereco text check (char_length(endereco) <= 200),
  cidade text not null check (char_length(btrim(cidade)) between 2 and 80),
  uf char(2) not null check (uf ~ '^[A-Z]{2}$'),
  horario text check (char_length(horario) <= 120),
  frete_fixo numeric(12, 2) not null default 0 check (frete_fixo >= 0),
  pedido_minimo numeric(12, 2) not null default 0 check (pedido_minimo >= 0),
  aberta boolean not null default true,
  status text not null default 'ativa' check (status in ('ativa', 'suspensa')),
  criada_em timestamptz not null default now(),
  atualizada_em timestamptz not null default now()
);
create index lojas_cidade_idx on public.lojas (uf, cidade);

create table public.loja_membros (
  loja_id uuid not null references public.lojas (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  papel text not null check (papel in ('dono', 'gerente', 'vendedor')),
  criado_em timestamptz not null default now(),
  primary key (loja_id, user_id)
);
create index loja_membros_user_idx on public.loja_membros (user_id);

-- Papel do usuário logado na loja (null = não é da loja)
create function private.membro_loja(p_loja uuid) returns text
language sql stable security definer set search_path = '' as $$
  select m.papel from public.loja_membros m where m.loja_id = p_loja and m.user_id = (select auth.uid());
$$;

-- Dono ou gerente: mexe em preços, perfil e imagens
create function private.pode_gerir_loja(p_loja uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.membro_loja(p_loja) in ('dono', 'gerente'), false);
$$;

-- ---------- Catálogo DailyObra (a loja não altera) ----------
create table public.catalogo_categorias (
  id text primary key check (id ~ '^[a-z0-9-]{2,40}$'),
  nome text not null,
  ordem int not null
);

create table public.catalogo_itens (
  id text primary key check (id ~ '^[a-z0-9-]{2,60}$'),
  nome text not null check (char_length(btrim(nome)) between 2 and 120),
  unidade text not null check (char_length(unidade) between 1 and 20),
  categoria_id text not null references public.catalogo_categorias (id),
  tier_cashback smallint not null check (tier_cashback between 1 and 4),
  sinonimos text[] not null default '{}',
  ean text check (ean ~ '^\d{8,14}$'),
  ncm text check (ncm ~ '^\d{8}$'),
  imagem_path text,
  ativo boolean not null default true
);
create index catalogo_itens_categoria_idx on public.catalogo_itens (categoria_id);

-- Liga cada material das planilhas Projetos Calculos ao produto do catálogo (null = não é produto de loja)
create table public.catalogo_planilha (
  nome text not null,
  unidade text not null,
  item_id text references public.catalogo_itens (id),
  primary key (nome, unidade)
);
create index catalogo_planilha_item_idx on public.catalogo_planilha (item_id);

create table public.cashback_tiers (
  tier smallint primary key check (tier between 1 and 4),
  percentual numeric(5, 4) not null check (percentual >= 0 and percentual < 0.5),
  vigente_desde date not null default current_date
);

-- ---------- Ofertas (preço de cada loja para cada produto) ----------
create table public.ofertas (
  loja_id uuid not null references public.lojas (id) on delete cascade,
  item_id text not null references public.catalogo_itens (id),
  preco numeric(12, 2) not null check (preco > 0),
  preco_promocional numeric(12, 2) check (preco_promocional > 0),
  promo_ate date,
  disponibilidade text not null default 'disponivel' check (disponibilidade in ('disponivel', 'sob_consulta', 'sem_estoque')),
  pausada boolean not null default false,
  atualizada_em timestamptz not null default now(),
  primary key (loja_id, item_id),
  check (preco_promocional is null or preco_promocional < preco),
  check (preco_promocional is null or promo_ate is not null)
);
create index ofertas_item_idx on public.ofertas (item_id);

-- ---------- Orçamentos, propostas e pedidos ----------
create table public.orcamentos (
  id uuid primary key default gen_random_uuid(),
  construtor_id uuid not null references auth.users (id) on delete cascade,
  obra_id uuid references public.obras (id) on delete set null,
  modo text not null check (modo in ('negociacao', 'pedido')),
  mensagem text check (char_length(mensagem) <= 500),
  criado_em timestamptz not null default now()
);
create index orcamentos_construtor_idx on public.orcamentos (construtor_id, criado_em desc);
create index orcamentos_obra_idx on public.orcamentos (obra_id);

create table public.propostas (
  id uuid primary key default gen_random_uuid(),
  orcamento_id uuid not null references public.orcamentos (id) on delete cascade,
  loja_id uuid not null references public.lojas (id),
  construtor_id uuid not null references auth.users (id) on delete cascade,
  modo text not null check (modo in ('negociacao', 'pedido')),
  status text not null default 'enviada'
    check (status in ('enviada', 'contraproposta', 'aceita', 'recusada', 'cancelada', 'expirada')),
  subtotal_anunciado numeric(12, 2) not null check (subtotal_anunciado >= 0),
  desconto numeric(12, 2) not null default 0 check (desconto >= 0),
  frete numeric(12, 2) not null default 0 check (frete >= 0),
  total numeric(12, 2) not null check (total >= 0),
  cashback_previsto numeric(12, 2) not null default 0 check (cashback_previsto >= 0),
  saldo_aplicado numeric(12, 2) not null default 0 check (saldo_aplicado >= 0),
  mensagem_construtor text check (char_length(mensagem_construtor) <= 500),
  mensagem_loja text check (char_length(mensagem_loja) <= 500),
  motivo_recusa text check (char_length(motivo_recusa) <= 300),
  valida_ate timestamptz not null,
  criada_em timestamptz not null default now(),
  atualizada_em timestamptz not null default now()
);
create index propostas_loja_idx on public.propostas (loja_id, status, valida_ate);
create index propostas_construtor_idx on public.propostas (construtor_id, criada_em desc);
create index propostas_orcamento_idx on public.propostas (orcamento_id);

create table public.proposta_itens (
  id bigint generated always as identity primary key,
  proposta_id uuid not null references public.propostas (id) on delete cascade,
  item_id text not null references public.catalogo_itens (id),
  nome text not null,
  unidade text not null,
  tier smallint not null check (tier between 1 and 4),
  quantidade numeric(12, 3) not null check (quantidade > 0),
  preco_anunciado numeric(12, 2) not null check (preco_anunciado > 0),
  preco_ofertado numeric(12, 2) check (preco_ofertado > 0)
);
create index proposta_itens_proposta_idx on public.proposta_itens (proposta_id);
create index proposta_itens_item_idx on public.proposta_itens (item_id);

create table public.proposta_eventos (
  id bigint generated always as identity primary key,
  proposta_id uuid not null references public.propostas (id) on delete cascade,
  de text,
  para text not null,
  autor uuid references auth.users (id) on delete set null,
  papel text,
  valores jsonb,
  justificativa text,
  criado_em timestamptz not null default now()
);
create index proposta_eventos_proposta_idx on public.proposta_eventos (proposta_id, criado_em);
create index proposta_eventos_autor_idx on public.proposta_eventos (autor);

create table public.pedidos (
  id uuid primary key default gen_random_uuid(),
  proposta_id uuid not null unique references public.propostas (id) on delete cascade,
  loja_id uuid not null references public.lojas (id),
  construtor_id uuid not null references auth.users (id) on delete cascade,
  total numeric(12, 2) not null check (total >= 0),
  status text not null default 'confirmado'
    check (status in ('confirmado', 'em_separacao', 'saiu_entrega', 'entregue', 'cancelado')),
  pagamento_confirmado_em timestamptz,
  entregue_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index pedidos_loja_idx on public.pedidos (loja_id, status);
create index pedidos_construtor_idx on public.pedidos (construtor_id, criado_em desc);

create table public.pedido_eventos (
  id bigint generated always as identity primary key,
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  de text,
  para text not null,
  autor uuid references auth.users (id) on delete set null,
  criado_em timestamptz not null default now()
);
create index pedido_eventos_pedido_idx on public.pedido_eventos (pedido_id, criado_em);
create index pedido_eventos_autor_idx on public.pedido_eventos (autor);

-- ---------- Carteira: extrato imutável em partidas dobradas ----------
-- Cada transação tem linhas que somam zero entre as contas; 'emissor' é a contrapartida do DailyObra.
create table public.carteira_lancamentos (
  id bigint generated always as identity primary key,
  transacao_id uuid not null,
  construtor_id uuid not null references auth.users (id) on delete cascade,
  conta text not null check (conta in ('pendente', 'disponivel', 'reservado', 'emissor')),
  valor numeric(12, 2) not null check (valor <> 0),
  tipo text not null check (tipo in ('cashback_previsto', 'cashback_liberado', 'cashback_estornado', 'saldo_reservado', 'saldo_usado', 'saldo_devolvido')),
  descricao text not null,
  tier smallint,
  loja_id uuid references public.lojas (id) on delete set null,
  pedido_id uuid references public.pedidos (id) on delete set null,
  proposta_id uuid references public.propostas (id) on delete set null,
  criado_em timestamptz not null default now()
);
create index carteira_construtor_idx on public.carteira_lancamentos (construtor_id, criado_em desc);
create index carteira_transacao_idx on public.carteira_lancamentos (transacao_id);
create index carteira_loja_idx on public.carteira_lancamentos (loja_id);
create index carteira_pedido_idx on public.carteira_lancamentos (pedido_id);
create index carteira_proposta_idx on public.carteira_lancamentos (proposta_id);

-- ---------- Datas de atualização ----------
create function private.tocar_atualizada_em() returns trigger language plpgsql set search_path = '' as $$
begin new.atualizada_em := now(); return new; end $$;
create function private.tocar_atualizado_em() returns trigger language plpgsql set search_path = '' as $$
begin new.atualizado_em := now(); return new; end $$;
create trigger lojas_atualizada before update on public.lojas for each row execute function private.tocar_atualizada_em();
create trigger ofertas_atualizada before update on public.ofertas for each row execute function private.tocar_atualizada_em();
create trigger propostas_atualizada before update on public.propostas for each row execute function private.tocar_atualizada_em();
create trigger pedidos_atualizado before update on public.pedidos for each row execute function private.tocar_atualizado_em();

-- Status e CNPJ da loja só mudam pelo administrador (fora do app)
create function private.proteger_loja() returns trigger language plpgsql set search_path = '' as $$
begin
  if (select auth.role()) in ('authenticated', 'anon')
     and (new.status is distinct from old.status or new.cnpj is distinct from old.cnpj) then
    raise exception 'Status e CNPJ da loja só podem ser alterados pelo suporte DailyObra.' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger lojas_protegidas before update on public.lojas for each row execute function private.proteger_loja();

-- ---------- RLS ----------
alter table public.lojas enable row level security;
alter table public.loja_membros enable row level security;
alter table public.catalogo_categorias enable row level security;
alter table public.catalogo_itens enable row level security;
alter table public.catalogo_planilha enable row level security;
alter table public.cashback_tiers enable row level security;
alter table public.ofertas enable row level security;
alter table public.orcamentos enable row level security;
alter table public.propostas enable row level security;
alter table public.proposta_itens enable row level security;
alter table public.proposta_eventos enable row level security;
alter table public.pedidos enable row level security;
alter table public.pedido_eventos enable row level security;
alter table public.carteira_lancamentos enable row level security;

create policy "ver catalogo" on public.catalogo_categorias for select to authenticated using (true);
create policy "ver catalogo" on public.catalogo_itens for select to authenticated using (true);
create policy "ver catalogo" on public.catalogo_planilha for select to authenticated using (true);
create policy "ver tiers" on public.cashback_tiers for select to authenticated using (true);

create policy "ver lojas" on public.lojas for select to authenticated
  using (status = 'ativa' or private.membro_loja(id) is not null);
create policy "editar propria loja" on public.lojas for update to authenticated
  using (private.pode_gerir_loja(id)) with check (private.pode_gerir_loja(id));

create policy "ver membros" on public.loja_membros for select to authenticated
  using (user_id = (select auth.uid()) or private.membro_loja(loja_id) is not null);
create policy "dono remove membro" on public.loja_membros for delete to authenticated
  using (private.membro_loja(loja_id) = 'dono' and user_id <> (select auth.uid()));

create policy "ver ofertas" on public.ofertas for select to authenticated
  using (
    private.membro_loja(loja_id) is not null
    or (not pausada and exists (select 1 from public.lojas l where l.id = loja_id and l.status = 'ativa'))
  );
create policy "gerir ofertas" on public.ofertas for insert to authenticated with check (private.pode_gerir_loja(loja_id));
create policy "alterar ofertas" on public.ofertas for update to authenticated
  using (private.pode_gerir_loja(loja_id)) with check (private.pode_gerir_loja(loja_id));
create policy "remover ofertas" on public.ofertas for delete to authenticated using (private.pode_gerir_loja(loja_id));

create policy "ver meus orcamentos" on public.orcamentos for select to authenticated using (construtor_id = (select auth.uid()));

create policy "ver propostas" on public.propostas for select to authenticated
  using (construtor_id = (select auth.uid()) or private.membro_loja(loja_id) is not null);
create policy "ver itens" on public.proposta_itens for select to authenticated
  using (exists (select 1 from public.propostas p where p.id = proposta_id
                 and (p.construtor_id = (select auth.uid()) or private.membro_loja(p.loja_id) is not null)));
create policy "ver eventos" on public.proposta_eventos for select to authenticated
  using (exists (select 1 from public.propostas p where p.id = proposta_id
                 and (p.construtor_id = (select auth.uid()) or private.membro_loja(p.loja_id) is not null)));

create policy "ver pedidos" on public.pedidos for select to authenticated
  using (construtor_id = (select auth.uid()) or private.membro_loja(loja_id) is not null);
create policy "ver eventos" on public.pedido_eventos for select to authenticated
  using (exists (select 1 from public.pedidos p where p.id = pedido_id
                 and (p.construtor_id = (select auth.uid()) or private.membro_loja(p.loja_id) is not null)));

create policy "ver minha carteira" on public.carteira_lancamentos for select to authenticated
  using (construtor_id = (select auth.uid()));

-- A loja vê nome, empresa e telefone de quem mandou proposta para ela
create policy "loja ve construtor" on public.profiles for select to authenticated
  using (exists (select 1 from public.propostas p where p.construtor_id = profiles.id
                 and private.membro_loja(p.loja_id) is not null));

-- Defesa extra: nem com política errada no futuro o app escreve nestas tabelas
revoke insert, update, delete, truncate on public.orcamentos, public.propostas, public.proposta_itens,
  public.proposta_eventos, public.pedidos, public.pedido_eventos, public.carteira_lancamentos,
  public.catalogo_categorias, public.catalogo_itens, public.catalogo_planilha, public.cashback_tiers
  from anon, authenticated;
revoke insert, truncate on public.lojas, public.loja_membros from anon, authenticated;

revoke execute on function private.membro_loja(uuid), private.pode_gerir_loja(uuid),
  private.tocar_atualizada_em(), private.tocar_atualizado_em(), private.proteger_loja() from public;
grant execute on function private.membro_loja(uuid), private.pode_gerir_loja(uuid) to authenticated;

-- ---------- Fotos das lojas (logo e capa) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lojas', 'lojas', true, 2097152, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

-- Primeira pasta do caminho é o id da loja: lojas/<loja_id>/logo.jpg
create function private.loja_da_pasta(p_nome text) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  return (storage.foldername(p_nome))[1]::uuid;
exception when others then
  return null;
end $$;
revoke execute on function private.loja_da_pasta(text) from public;
grant execute on function private.loja_da_pasta(text) to authenticated;

create policy "loja envia imagens" on storage.objects for insert to authenticated
  with check (bucket_id = 'lojas' and private.pode_gerir_loja(private.loja_da_pasta(name)));
create policy "loja troca imagens" on storage.objects for update to authenticated
  using (bucket_id = 'lojas' and private.pode_gerir_loja(private.loja_da_pasta(name)))
  with check (bucket_id = 'lojas' and private.pode_gerir_loja(private.loja_da_pasta(name)));
create policy "loja apaga imagens" on storage.objects for delete to authenticated
  using (bucket_id = 'lojas' and private.pode_gerir_loja(private.loja_da_pasta(name)));

-- ---------- Tempo real ----------
alter publication supabase_realtime add table public.propostas, public.pedidos;
