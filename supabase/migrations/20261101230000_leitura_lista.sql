-- Leitura de lista por arquivo (PDF ou foto): registro de cada leitura para o limite diário.
-- A função ler-lista chama registrar_leitura_lista() antes de mandar o arquivo para a IA.

create table public.leituras_lista (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  criada_em timestamptz not null default now()
);
create index leituras_lista_usuario_data on public.leituras_lista (user_id, criada_em desc);

-- Sem políticas: ninguém lê nem grava direto, só pela função abaixo
alter table public.leituras_lista enable row level security;

create or replace function public.registrar_leitura_lista()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
begin
  if v_usuario is null then
    raise exception 'Entre na sua conta para ler arquivos.' using errcode = 'P0001';
  end if;
  -- Uma leitura por vez por usuário, para o limite valer mesmo com envios simultâneos
  perform pg_advisory_xact_lock(hashtext('leitura_lista:' || v_usuario::text));
  if (select count(*) from public.leituras_lista
      where user_id = v_usuario and criada_em > now() - interval '24 hours') >= 30 then
    raise exception 'Você já usou as 30 leituras de arquivo das últimas 24 horas. Cole o texto da lista ou tente mais tarde.'
      using errcode = 'P0001';
  end if;
  insert into public.leituras_lista (user_id) values (v_usuario);
end
$$;

revoke all on function public.registrar_leitura_lista() from public, anon;
grant execute on function public.registrar_leitura_lista() to authenticated;
