-- Etapa 10: limite de uso da IA na obra (diário por voz e nota por foto).
-- Cada uso custa dinheiro, então a função ia-obra chama registrar_uso_ia antes de falar com a IA. O uso entra em leituras_lista: a
-- tabela já some em excluir_conta, e as três ajudas dividem o mesmo teto de 30 em 24 horas por pessoa.

create function public.registrar_uso_ia(p_obra uuid, p_tipo text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_usuario uuid := auth.uid();
begin
  if v_usuario is null then
    raise exception 'Entre na sua conta para usar a IA.' using errcode = 'P0001';
  end if;
  if p_tipo is null or p_tipo not in ('diario', 'nota') then
    raise exception 'Pedido inválido.' using errcode = 'P0001';
  end if;
  if p_tipo = 'diario' and not coalesce(private.pode_editar(p_obra), false) then
    raise exception 'Só quem toca a obra preenche o diário.' using errcode = 'P0001';
  end if;
  if p_tipo = 'nota' and not coalesce(private.lidera_obra(p_obra), false) then
    raise exception 'Só o responsável ou o mestre lançam gastos.' using errcode = 'P0001';
  end if;
  -- A mesma trava da leitura de lista: o limite vale mesmo com pedidos simultâneos
  perform pg_advisory_xact_lock(hashtext('leitura_lista:' || v_usuario::text));
  if (select count(*) from public.leituras_lista
      where user_id = v_usuario and criada_em > now() - interval '24 hours') >= 30 then
    raise exception 'Você já usou as 30 ajudas da IA das últimas 24 horas. Preencha à mão ou tente mais tarde.' using errcode = 'P0001';
  end if;
  insert into public.leituras_lista (user_id) values (v_usuario);
end
$$;

revoke all on function public.registrar_uso_ia(uuid, text) from public, anon;
grant execute on function public.registrar_uso_ia(uuid, text) to authenticated;

-- A leitura de lista divide o teto com o diário e as notas, então a mensagem deixa de falar só de arquivos
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
    raise exception 'Você já usou as 30 ajudas da IA das últimas 24 horas. Cole o texto da lista ou tente mais tarde.'
      using errcode = 'P0001';
  end if;
  insert into public.leituras_lista (user_id) values (v_usuario);
end
$$;
