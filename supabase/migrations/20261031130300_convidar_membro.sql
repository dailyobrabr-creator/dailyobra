-- Equipe da loja: o dono convida por e-mail quem já tem conta no DailyObra (gerente ou vendedor).
-- Reconvidar muda o papel. O dono não pode se rebaixar por aqui.
-- Reversão: drop function public.convidar_membro(uuid, text, text);

create function public.convidar_membro(p_loja uuid, p_email text, p_papel text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  alvo uuid;
begin
  if uid is null then raise exception 'Entre na sua conta para convidar.' using errcode = 'P0001'; end if;
  if private.membro_loja(p_loja) is distinct from 'dono' then
    raise exception 'Só o dono da loja convida pessoas para a equipe.' using errcode = 'P0001';
  end if;
  if p_papel not in ('gerente', 'vendedor') then
    raise exception 'Escolha gerente ou vendedor.' using errcode = 'P0001';
  end if;
  select u.id into alvo from auth.users u where lower(u.email) = lower(btrim(coalesce(p_email, '')));
  if alvo is null then
    raise exception 'Não encontramos uma conta com este e-mail. Peça para a pessoa criar a conta no app primeiro.'
      using errcode = 'P0001';
  end if;
  if alvo = uid then raise exception 'Você já é o dono desta loja.' using errcode = 'P0001'; end if;
  insert into public.loja_membros (loja_id, user_id, papel) values (p_loja, alvo, p_papel)
  on conflict (loja_id, user_id) do update set papel = excluded.papel
  where public.loja_membros.papel <> 'dono';
  return p_papel;
end $$;

revoke execute on function public.convidar_membro(uuid, text, text) from public, anon;
grant execute on function public.convidar_membro(uuid, text, text) to authenticated;
