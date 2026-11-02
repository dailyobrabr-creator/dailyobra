-- Revisão do checkout bifurcado:
-- 1) O CPF/CNPJ do construtor sai de profiles (a política "loja ve construtor" mostra a linha inteira às lojas que
--    receberam proposta dele) e vai para uma tabela que só ele lê e grava. A loja do pedido segue lendo pedido_documentos.
-- 2) Nome e cidade do BR Code só com ASCII imprimível: º, aspas curvas do celular e travessão saem, sem espaço duplo.

-- ---------- Documento do construtor ----------
create table public.construtor_documentos (
  user_id uuid primary key references auth.users (id) on delete cascade,
  documento text not null check (documento ~ '^(\d{11}|\d{14})$' and private.documento_valido(documento))
);
alter table public.construtor_documentos enable row level security;
create policy "documento proprio" on public.construtor_documentos for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke all on public.construtor_documentos from anon;
revoke truncate on public.construtor_documentos from authenticated;

insert into public.construtor_documentos (user_id, documento)
  select id, documento from public.profiles where documento is not null;
alter table public.profiles drop column documento;

create or replace function public.pagar_eu_mesmo(p_pedido uuid, p_documento text) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); pe public.pedidos; doc text := private.so_digitos(p_documento); v_nome text;
begin
  select * into pe from public.pedidos where id = p_pedido for update;
  if not found or pe.construtor_id is distinct from uid then raise exception 'Pedido não encontrado.' using errcode = 'P0001'; end if;
  if pe.status = 'cancelado' then raise exception 'Este pedido foi cancelado.' using errcode = 'P0001'; end if;
  if pe.pagamento_confirmado_em is not null then raise exception 'Este pedido já foi pago.' using errcode = 'P0001'; end if;
  if not private.documento_valido(doc) then raise exception 'CPF ou CNPJ inválido. Confira os números.' using errcode = 'P0001'; end if;
  select btrim(coalesce(p.nome, '')) into v_nome from public.profiles p where p.id = uid;
  if coalesce(v_nome, '') = '' then raise exception 'Complete seu nome no Perfil.' using errcode = 'P0001'; end if;
  insert into public.construtor_documentos (user_id, documento) values (uid, doc)
    on conflict (user_id) do update set documento = excluded.documento;
  update public.pedidos set pagador = 'proprio', pagador_nome = left(v_nome, 120), pagador_whatsapp = null, link_codigo = null,
    documento_informado_em = now(), pagamento_informado_em = null
   where id = p_pedido;
  insert into public.pedido_documentos (pedido_id, documento) values (p_pedido, doc)
    on conflict (pedido_id) do update set documento = excluded.documento;
end $$;

-- ---------- BR Code ----------
-- Sem acento, em maiúsculas, só ASCII imprimível, espaços simples e cortado em [tamanho]
create function private.texto_pix(p text, tamanho int) returns text language sql immutable set search_path = '' as $$
  select btrim(left(btrim(regexp_replace(regexp_replace(upper(private.sem_acento(p)), '[^ -~]', '', 'g'), ' {2,}', ' ', 'g')), tamanho)) $$;
revoke execute on function private.texto_pix(text, int) from public;

create or replace function private.brcode(chave text, nome text, cidade text, valor numeric, txid text) returns text
language plpgsql immutable set search_path = '' as $$
declare conta text; campo text; carga text;
begin
  conta := '0014br.gov.bcb.pix01' || lpad(length(chave)::text, 2, '0') || chave;
  carga := '000201' || '26' || lpad(length(conta)::text, 2, '0') || conta || '52040000' || '5303986';
  if valor is not null then
    campo := to_char(valor, 'FM999999990.00');
    carga := carga || '54' || lpad(length(campo)::text, 2, '0') || campo;
  end if;
  campo := private.texto_pix(nome, 25);
  carga := carga || '5802BR' || '59' || lpad(length(campo)::text, 2, '0') || campo;
  campo := private.texto_pix(cidade, 15);
  carga := carga || '60' || lpad(length(campo)::text, 2, '0') || campo;
  campo := '05' || lpad(length(txid)::text, 2, '0') || txid;
  carga := carga || '62' || lpad(length(campo)::text, 2, '0') || campo || '6304';
  return carga || private.crc16(carga);
end $$;
