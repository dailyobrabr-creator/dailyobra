-- Pendência sem responsável fazia a comparação dar nulo em vez de falso, e "not nulo" deixava qualquer pessoa da equipe passar.
create or replace function private.mexe_na_pendencia(p public.obra_pendencias) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.lidera_obra(p.obra_id), false)
      or coalesce(p.criada_por = (select auth.uid()), false)
      or coalesce(p.responsavel_id = (select auth.uid()), false);
$$;
