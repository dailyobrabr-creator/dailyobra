-- Endereço da loja em campos (CEP, rua, número, complemento, bairro) e outras unidades em texto. Com CEP, o banco monta o
-- texto de exibição em `endereco`, que os apps já leem; loja sem CEP fica com o texto que escreveu. O horário continua
-- texto (escrito pelo editor do Parceiros) e passa a caber dias diferentes com intervalo.

alter table public.lojas
  add column cep text check (cep ~ '^\d{8}$'),
  add column logradouro text check (char_length(logradouro) <= 120),
  add column numero text check (char_length(numero) <= 20),
  add column complemento text check (char_length(complemento) <= 60),
  add column bairro text check (char_length(bairro) <= 80),
  add column outras_unidades text check (char_length(outras_unidades) <= 200);

alter table public.lojas
  drop constraint lojas_endereco_check,
  add constraint lojas_endereco_check check (char_length(endereco) <= 300),
  drop constraint lojas_horario_check,
  add constraint lojas_horario_check check (char_length(horario) <= 300);

-- "R. Fernando Corrêa da Costa, 1500, sala 2 – Vila Operária, CEP 78700-000"; com CEP, o texto do cliente não vale
create function private.montar_endereco() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.cep is not null then
    new.endereco := btrim(coalesce(new.logradouro, '')) || ', ' || btrim(coalesce(new.numero, ''))
      || coalesce(', ' || nullif(btrim(new.complemento), ''), '')
      || coalesce(' – ' || nullif(btrim(new.bairro), ''), '')
      || ', CEP ' || substr(new.cep, 1, 5) || '-' || substr(new.cep, 6, 3);
  end if;
  return new;
end $$;
create trigger lojas_endereco before insert or update on public.lojas for each row execute function private.montar_endereco();

-- criar_loja aceita os campos do endereço; o resto continua como em marketplace_funcoes
create or replace function public.criar_loja(p jsonb) returns uuid language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); id_loja uuid; cnpj text := regexp_replace(coalesce(p->>'cnpj', ''), '\D', '', 'g');
  v_cep text := nullif(regexp_replace(coalesce(p->>'cep', ''), '\D', '', 'g'), '');
begin
  if uid is null then raise exception 'Entre na sua conta para cadastrar a loja.' using errcode = 'P0001'; end if;
  if not private.cnpj_valido(cnpj) then raise exception 'CNPJ inválido. Confira os números.' using errcode = 'P0001'; end if;
  if char_length(btrim(coalesce(p->>'nome', ''))) < 2 then raise exception 'Informe o nome da loja.' using errcode = 'P0001'; end if;
  if char_length(btrim(coalesce(p->>'cidade', ''))) < 2 then raise exception 'Informe a cidade da loja.' using errcode = 'P0001'; end if;
  if coalesce(p->>'uf', '') !~ '^[A-Z]{2}$' then raise exception 'Escolha o estado da loja.' using errcode = 'P0001'; end if;
  if v_cep is not null and v_cep !~ '^\d{8}$' then raise exception 'CEP inválido.' using errcode = 'P0001'; end if;
  begin
    insert into public.lojas (nome, cnpj, descricao, whatsapp, endereco, cidade, uf, horario, frete_fixo, pedido_minimo,
                              cep, logradouro, numero, complemento, bairro, outras_unidades)
    values (btrim(p->>'nome'), cnpj, nullif(btrim(p->>'descricao'), ''), nullif(regexp_replace(coalesce(p->>'whatsapp', ''), '\D', '', 'g'), ''),
            nullif(btrim(p->>'endereco'), ''), btrim(p->>'cidade'), p->>'uf', nullif(btrim(p->>'horario'), ''),
            coalesce((p->>'frete_fixo')::numeric, 0), coalesce((p->>'pedido_minimo')::numeric, 0),
            v_cep, nullif(btrim(p->>'logradouro'), ''), nullif(btrim(p->>'numero'), ''), nullif(btrim(p->>'complemento'), ''),
            nullif(btrim(p->>'bairro'), ''), nullif(btrim(p->>'outras_unidades'), ''))
    returning id into id_loja;
  exception when unique_violation then
    raise exception 'Já existe uma loja cadastrada com este CNPJ.' using errcode = 'P0001';
  end;
  insert into public.loja_membros (loja_id, user_id, papel) values (id_loja, uid, 'dono');
  return id_loja;
end $$;
