-- Testes da importação do estoque (migração importacao_estoque): ligações dos códigos da loja e importar_estoque.
-- Roda numa transação; o bloco final levanta 'RESULTADO: ...' e o erro desfaz tudo.
begin;

create temp table r (n serial, teste text, ok boolean, detalhe text) on commit drop;
create temp table v (chave text primary key, valor text) on commit drop;
grant all on r, v to authenticated, anon;
grant usage on sequence r_n_seq to authenticated, anon;

create function pg_temp.guardar(k text, x text) returns void language sql as $$
  insert into v values (k, x) on conflict (chave) do update set valor = excluded.valor $$;
create function pg_temp.pegar(k text) returns text language sql as $$ select valor from v where chave = k $$;
create function pg_temp.conferir(t text, condicao boolean, d text default null) returns void language sql as $$
  insert into r (teste, ok, detalhe) values (t, coalesce(condicao, false), d) $$;
create function pg_temp.como(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function pg_temp.admin() returns void language plpgsql as $$ begin execute 'reset role'; end $$;
create function pg_temp.oferta(k text) returns public.ofertas language sql as $$
  select * from public.ofertas where loja_id = pg_temp.pegar('A')::uuid and item_id = k $$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000d001', 'dono.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000a001', 'gerente.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000e001', 'vendedor.a@teste.dailyobra', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000f001', 'dono.b@teste.dailyobra', 'authenticated', 'authenticated');

-- Loja A (com gerente e vendedor e uma oferta de tijolo) e loja B
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('A', public.criar_loja('{"nome":"Loja A","cnpj":"11.222.333/0001-81","cidade":"Rondonópolis","uf":"MT"}'::jsonb)::text);
insert into public.ofertas (loja_id, item_id, preco) values (pg_temp.pegar('A')::uuid, 'tijolo-8-furos', 1.35);
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('B', public.criar_loja('{"nome":"Loja B","cnpj":"11444777000161","cidade":"Maringá","uf":"PR"}'::jsonb)::text);
select pg_temp.admin();
insert into public.loja_membros (loja_id, user_id, papel) values
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000a001', 'gerente'),
  (pg_temp.pegar('A')::uuid, '00000000-0000-0000-0000-00000000e001', 'vendedor');

-- 1. O dono grava ofertas e ligações de uma vez
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select pg_temp.guardar('r1', public.importar_estoque(pg_temp.pegar('A')::uuid,
  '[{"item_id":"cimento-cp2-50kg","preco":60.4,"disponibilidade":"disponivel"},{"item_id":"tijolo-8-furos","preco":1.4,"disponibilidade":"sem_estoque"}]',
  '[{"codigo":"10259","item_id":"cimento-cp2-50kg","nome":"CIMENTO ITAU","unidade":"SO"}]')::text);
select pg_temp.admin();
select pg_temp.conferir('dono importa ofertas e ligações',
  pg_temp.pegar('r1')::jsonb = '{"ofertas": 2, "ligacoes": 1}'::jsonb
  and (select preco = 60.40 and disponibilidade = 'disponivel' from pg_temp.oferta('cimento-cp2-50kg'))
  and (select preco = 1.40 and disponibilidade = 'sem_estoque' from pg_temp.oferta('tijolo-8-furos'))
  and (select item_id = 'cimento-cp2-50kg' and nome = 'CIMENTO ITAU' and unidade = 'SO' from public.loja_produtos
        where loja_id = pg_temp.pegar('A')::uuid and codigo = '10259')
  and (select estoque_atualizado_em is not null from public.lojas where id = pg_temp.pegar('A')::uuid),
  pg_temp.pegar('r1'));

-- 2. Pausa fica; promoção manual sai quando o preço novo fica menor ou igual a ela
update public.ofertas set pausada = true, preco_promocional = 55, promo_ate = current_date + 7
 where loja_id = pg_temp.pegar('A')::uuid and item_id = 'cimento-cp2-50kg';
update public.ofertas set preco_promocional = 1.30, promo_ate = current_date + 7
 where loja_id = pg_temp.pegar('A')::uuid and item_id = 'tijolo-8-furos';
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.importar_estoque(pg_temp.pegar('A')::uuid,
  '[{"item_id":"cimento-cp2-50kg","preco":61,"disponibilidade":"disponivel"},{"item_id":"tijolo-8-furos","preco":1.25,"disponibilidade":"disponivel"}]', '[]');
select pg_temp.admin();
select pg_temp.conferir('pausa fica e promoção manual sai',
  (select pausada and preco = 61 and preco_promocional = 55 and promo_ate is not null from pg_temp.oferta('cimento-cp2-50kg'))
  and (select preco = 1.25 and preco_promocional is null and promo_ate is null from pg_temp.oferta('tijolo-8-furos')));

-- 3. Só o dono ou o gerente da loja
select pg_temp.como('00000000-0000-0000-0000-00000000a001');
do $$ begin perform public.importar_estoque(pg_temp.pegar('A')::uuid, '[]', '[]'); perform pg_temp.guardar('gerente', 'passou');
exception when others then perform pg_temp.guardar('gerente', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
do $$ begin perform public.importar_estoque(pg_temp.pegar('A')::uuid, '[]', '[]'); perform pg_temp.guardar('vendedor', 'passou');
exception when others then perform pg_temp.guardar('vendedor', sqlerrm); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
do $$ begin perform public.importar_estoque(pg_temp.pegar('A')::uuid, '[]', '[]'); perform pg_temp.guardar('dono_b', 'passou');
exception when others then perform pg_temp.guardar('dono_b', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('só dono ou gerente',
  pg_temp.pegar('gerente') = 'passou' and pg_temp.pegar('vendedor') = 'Só o dono ou o gerente atualiza o estoque.'
  and pg_temp.pegar('dono_b') = 'Só o dono ou o gerente atualiza o estoque.',
  concat_ws(' / ', pg_temp.pegar('gerente'), pg_temp.pegar('vendedor'), pg_temp.pegar('dono_b')));

-- 4. As ligações ficam com a equipe da loja: o vendedor lê mas não grava; outra loja não lê
select pg_temp.como('00000000-0000-0000-0000-00000000e001');
select pg_temp.guardar('le_vendedor', (select count(*) from public.loja_produtos where loja_id = pg_temp.pegar('A')::uuid)::text);
do $$ begin insert into public.loja_produtos (loja_id, codigo, item_id) values (pg_temp.pegar('A')::uuid, '1', 'tijolo-8-furos');
  perform pg_temp.guardar('insere_vendedor', 'passou');
exception when others then perform pg_temp.guardar('insere_vendedor', 'recusou'); end $$;
select pg_temp.como('00000000-0000-0000-0000-00000000f001');
select pg_temp.guardar('le_b', (select count(*) from public.loja_produtos where loja_id = pg_temp.pegar('A')::uuid)::text);
select pg_temp.admin();
select pg_temp.conferir('ligações só para a equipe',
  pg_temp.pegar('le_vendedor') = '1' and pg_temp.pegar('insere_vendedor') = 'recusou' and pg_temp.pegar('le_b') = '0',
  concat_ws(' / ', pg_temp.pegar('le_vendedor'), pg_temp.pegar('insere_vendedor'), pg_temp.pegar('le_b')));

-- 5. Valores inválidos
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
do $$ begin perform public.importar_estoque(pg_temp.pegar('A')::uuid, '[{"item_id":"tijolo-8-furos","preco":0,"disponibilidade":"disponivel"}]', '[]');
  perform pg_temp.guardar('e_preco', 'passou');
exception when others then perform pg_temp.guardar('e_preco', sqlerrm); end $$;
do $$ begin perform public.importar_estoque(pg_temp.pegar('A')::uuid, '[{"item_id":"tijolo-8-furos","preco":2,"disponibilidade":"sob_consulta"}]', '[]');
  perform pg_temp.guardar('e_disp', 'passou');
exception when others then perform pg_temp.guardar('e_disp', sqlerrm); end $$;
do $$ begin perform public.importar_estoque(pg_temp.pegar('A')::uuid, '[{"item_id":"nao-existe","preco":2,"disponibilidade":"disponivel"}]', '[]');
  perform pg_temp.guardar('e_item', 'passou');
exception when others then perform pg_temp.guardar('e_item', sqlerrm); end $$;
select pg_temp.admin();
select pg_temp.conferir('valores inválidos',
  pg_temp.pegar('e_preco') = 'Preço inválido.' and pg_temp.pegar('e_disp') = 'Disponibilidade inválida.'
  and pg_temp.pegar('e_item') = 'Produto do catálogo não encontrado.',
  concat_ws(' / ', pg_temp.pegar('e_preco'), pg_temp.pegar('e_disp'), pg_temp.pegar('e_item')));

-- 6. Importar de novo dá o mesmo resultado
select pg_temp.como('00000000-0000-0000-0000-00000000d001');
select public.importar_estoque(pg_temp.pegar('A')::uuid, '[{"item_id":"cimento-cp2-50kg","preco":62,"disponibilidade":"disponivel"}]',
  '[{"codigo":"10259","item_id":"cimento-cp2-50kg","nome":"CIMENTO ITAU","unidade":"SO"}]');
select public.importar_estoque(pg_temp.pegar('A')::uuid, '[{"item_id":"cimento-cp2-50kg","preco":62,"disponibilidade":"disponivel"}]',
  '[{"codigo":"10259","item_id":"cimento-cp2-50kg","nome":"CIMENTO ITAU","unidade":"SO"}]');
select pg_temp.admin();
select pg_temp.conferir('importar de novo não duplica',
  (select count(*) = 1 from public.loja_produtos where loja_id = pg_temp.pegar('A')::uuid and codigo = '10259')
  and (select preco = 62 from pg_temp.oferta('cimento-cp2-50kg')));

-- 7. As 61 ligações conferidas da Operário, com o código só com dígitos
select pg_temp.conferir('ligações da Operário',
  (select count(*) = 61 and bool_and(lp.codigo ~ '^\d+$') from public.loja_produtos lp join public.lojas l on l.id = lp.loja_id
    where l.cnpj = '36931301000186'),
  (select count(*)::text from public.loja_produtos lp join public.lojas l on l.id = lp.loja_id where l.cnpj = '36931301000186'));

select pg_temp.admin();
do $$ declare total int; ok int; falhas text; begin
  select count(*), count(*) filter (where r.ok), coalesce(string_agg(r.teste || ' [' || coalesce(r.detalhe, '') || ']', '; ') filter (where not r.ok), '')
    into total, ok, falhas from r;
  raise exception 'RESULTADO: % de % ok; falhas: %', ok, total, falhas;
end $$;
rollback;
