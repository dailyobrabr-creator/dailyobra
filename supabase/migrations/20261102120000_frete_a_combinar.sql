-- Loja que ainda não informou o frete: o app mostra "Frete a combinar" em vez de "Frete grátis".
-- Quando a loja salva frete ou pedido mínimo (app Parceiros), o frete dela passa a valer.

alter table public.lojas add column frete_a_combinar boolean not null default false;

create or replace function public.lojas_frete_definido()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Só desliga quando a própria atualização não está mexendo na marcação
  if new.frete_a_combinar is not distinct from old.frete_a_combinar then
    new.frete_a_combinar := false;
  end if;
  return new;
end
$$;

-- "of frete_fixo, pedido_minimo" dispara quando a coluna está no SET, mesmo com o mesmo valor
-- (a loja que confirma frete zero também sai do "a combinar"); trocar logo ou capa não dispara
create trigger lojas_frete_definido
  before update of frete_fixo, pedido_minimo on public.lojas
  for each row execute function public.lojas_frete_definido();

revoke all on function public.lojas_frete_definido() from public, anon, authenticated;
