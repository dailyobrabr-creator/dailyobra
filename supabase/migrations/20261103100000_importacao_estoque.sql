-- Importação do dia pelo relatório "Valor do estoque analítico" do Santri: a loja liga os códigos dela aos produtos do
-- catálogo e importar_estoque grava ofertas e ligações juntas. O arquivo é lido no navegador; só código, nome, unidade,
-- preço e disponibilidade chegam aqui (o custo nunca sai do computador da loja).

create table public.loja_produtos (
  loja_id uuid not null references public.lojas (id) on delete cascade,
  codigo text not null check (codigo ~ '^\d+$'),
  item_id text not null references public.catalogo_itens (id),
  nome text,
  unidade text,
  ligado_em timestamptz not null default now(),
  primary key (loja_id, codigo)
);
create index loja_produtos_item_idx on public.loja_produtos (loja_id, item_id);

-- A equipe da loja lê; dono e gerente gravam
alter table public.loja_produtos enable row level security;
create policy "equipe le ligacoes" on public.loja_produtos for select to authenticated using (private.membro_loja(loja_id) is not null);
create policy "gerir ligacoes" on public.loja_produtos for insert to authenticated with check (private.pode_gerir_loja(loja_id));
create policy "alterar ligacoes" on public.loja_produtos for update to authenticated
  using (private.pode_gerir_loja(loja_id)) with check (private.pode_gerir_loja(loja_id));
create policy "remover ligacoes" on public.loja_produtos for delete to authenticated using (private.pode_gerir_loja(loja_id));

alter table public.lojas add column estoque_atualizado_em timestamptz;

-- Ligações (upsert por loja e código) e ofertas (só preço e disponibilidade; a pausa fica; a promoção manual sai quando o
-- preço novo fica menor ou igual a ela), numa transação. Devolve quantas ofertas e ligações gravou.
create function public.importar_estoque(p_loja uuid, p_ofertas jsonb, p_ligacoes jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare g jsonb; o jsonb; preco numeric; disp text; n_ofertas int := 0; n_ligacoes int := 0;
begin
  if not coalesce(private.pode_gerir_loja(p_loja), false) then
    raise exception 'Só o dono ou o gerente atualiza o estoque.' using errcode = 'P0001';
  end if;
  for g in select * from jsonb_array_elements(coalesce(p_ligacoes, '[]'::jsonb)) loop
    if not exists (select 1 from public.catalogo_itens where id = g->>'item_id') then
      raise exception 'Produto do catálogo não encontrado.' using errcode = 'P0001';
    end if;
    insert into public.loja_produtos (loja_id, codigo, item_id, nome, unidade)
    values (p_loja, g->>'codigo', g->>'item_id', left(g->>'nome', 200), left(g->>'unidade', 20))
    on conflict (loja_id, codigo) do update set item_id = excluded.item_id, nome = excluded.nome, unidade = excluded.unidade;
    n_ligacoes := n_ligacoes + 1;
  end loop;
  for o in select * from jsonb_array_elements(coalesce(p_ofertas, '[]'::jsonb)) loop
    preco := round((o->>'preco')::numeric, 2);
    disp := o->>'disponibilidade';
    if preco is null or preco <= 0 then raise exception 'Preço inválido.' using errcode = 'P0001'; end if;
    if disp is null or disp not in ('disponivel', 'sem_estoque') then raise exception 'Disponibilidade inválida.' using errcode = 'P0001'; end if;
    if not exists (select 1 from public.catalogo_itens where id = o->>'item_id') then
      raise exception 'Produto do catálogo não encontrado.' using errcode = 'P0001';
    end if;
    insert into public.ofertas (loja_id, item_id, preco, disponibilidade)
    values (p_loja, o->>'item_id', preco, disp)
    on conflict (loja_id, item_id) do update set preco = excluded.preco, disponibilidade = excluded.disponibilidade,
      preco_promocional = case when public.ofertas.preco_promocional >= excluded.preco then null else public.ofertas.preco_promocional end,
      promo_ate = case when public.ofertas.preco_promocional >= excluded.preco then null else public.ofertas.promo_ate end;
    n_ofertas := n_ofertas + 1;
  end loop;
  update public.lojas set estoque_atualizado_em = now() where id = p_loja;
  return jsonb_build_object('ofertas', n_ofertas, 'ligacoes', n_ligacoes);
end $$;

revoke execute on function public.importar_estoque(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.importar_estoque(uuid, jsonb, jsonb) to authenticated;

-- As 61 ligações conferidas item a item para a Operário (Santri, 30/10/2026): o estoque do dia já atualiza esses produtos
insert into public.loja_produtos (loja_id, codigo, item_id, nome, unidade)
select l.id, v.codigo, v.item_id, v.nome, v.unidade
  from public.lojas l
 cross join (values
    ('10259', 'cimento-cp2-50kg', 'CIMENTO ITAU CP II F32/Z32 50KG TODAS AS OBRAS', 'SO'),
    ('61879', 'cal-hidratada-20kg', 'CAL HIDRATADA CH III 20KG', 'UN'),
    ('61937', 'argamassa-ac1-20kg', 'ARGAMASSA ACI CINZA 20KG', 'SO'),
    ('64060', 'argamassa-ac3-20kg', 'ARGAMASSA ACIII CINZA 20KG', 'SO'),
    ('10373', 'vergalhao-5mm', 'FERRO CA-60 5MMX12MT 3/16 (1,85 KG APROX)', 'BR'),
    ('10379', 'vergalhao-8mm', 'FERRO CA-50 8MMX12MT 5/16 (4,74 KG APROX)', 'BR'),
    ('10381', 'vergalhao-10mm', 'FERRO CA-50 10MMX12MT 3/8 (7,404 KG APROX)', 'BR'),
    ('19455', 'coluna-7x14-8mm', 'COLUNA ACO ARM 8MM 7X14 5/16" 6MTS EST. (BRANCA)', 'BR'),
    ('55714', 'trelica-tr8', 'TRELICA TR8 5,8X3,4X3,8 6M (LARANJA)', 'BR'),
    ('10191', 'arame-recozido-18', 'ARAME RECOZIDO N 18 1KG (107336 1,24)', 'RL'),
    ('24359', 'canaleta-ceramica', 'CANALETA RONDONOPOLIS 9X19X19CM PEQUENA', 'UN'),
    ('36178', 'pintura-asfaltica-18l', 'PINTURA ASFALTICA ACQUA 18LT', 'BD'),
    ('48967', 'impermeabilizante-polimerico', 'IMPERMEABILIZANTE TECPLUS LASTIC 18KG', 'CX'),
    ('62321', 'impermeabilizante-acrilico-18l', 'MANTA LIQUIDA CIAFLEX 18KG', 'BD'),
    ('17529', 'registro-gaveta-3-4', 'REGISTRO GAVETA BASE 3/4" 4509.202', 'UN'),
    ('67163', 'registro-pressao-3-4', 'REGISTRO PRESSAO SOLD 25MM FACILITA', 'UN'),
    ('51014', 'tubo-agua-fria-25mm', 'TUBO SOLD DN 25MM', 'BR'),
    ('67026', 'tubo-esgoto-100mm', 'TUBO ESG DN 100MM 6M', 'BR'),
    ('67236', 'adesivo-pvc-175g', 'ADESIVO PLASTICO PVC 175G', 'UN'),
    ('51367', 'caixa-sifonada-150', 'CAIXA SIFONADA 15X15CM 7 ENT GRELHA QUAD BCA', 'UN'),
    ('60840', 'caixa-gordura', 'CAIXA DE GORDURA 41X41X40CM 42L PTA', 'UN'),
    ('64884', 'caixa-passagem-esgoto', 'CAIXA PASSAGEM INSPECAO ESGOTO 277X277X210 PTO', 'PC'),
    ('66573', 'torneira-boia-3-4', 'TORNEIRA BOIA CX D''AGUA 1/2X3/4''''', 'UN'),
    ('57722', 'adaptador-flange-25mm', 'ADAPTADOR SOLD CX D''AGUA FLANGE 25MMX3/4"', 'UN'),
    ('32864', 'cabo-triplex-10mm', 'CABO TRIPLEX 2X1X10+10MM', 'MT'),
    ('48218', 'cabo-flexivel-2-5mm', 'CABO FLEX 2,5MM 450/750V AMARELO', 'MT'),
    ('48216', 'cabo-flexivel-4mm', 'CABO FLEX 4,0MM 450/750V VERDE', 'MT'),
    ('48202', 'cabo-flexivel-6mm', 'CABO FLEX 6,0MM 450/750V AZUL', 'MT'),
    ('63937', 'cabo-flexivel-10mm', 'CABO FLEX 10MM 450/750V VERDE', 'MT'),
    ('52234', 'disjuntor-din', 'DISJUNTOR MONOPOLAR DIN 63A CURVA C SHB', 'UN'),
    ('66416', 'fita-isolante-20m', 'FITA ISOLANTE 18MMX20M PRETA', 'UN'),
    ('63465', 'quadro-distribuicao-12', 'QUADRO DISTRIBUICAO BCO EMB 12 DISJUNTORES', 'UN'),
    ('65158', 'tomada-2p-t-10a', 'CONJUNTO CLICK 1TOM 2P+T 10A BCO', 'UN'),
    ('65151', 'interruptor-simples', 'CONJUNTO CLICK 1INT SIMP BCO', 'UN'),
    ('45043', 'lampada-led-9w', 'LAMP LED 9W BR6500K PERA', 'UN'),
    ('17667', 'soquete-e27', 'SOQUETE E27 PTO C/ RABICHO', 'UN'),
    ('64844', 'caixa-luz-4x2', 'CAIXA DE LUZ 4X2 EMB PTA', 'UN'),
    ('64509', 'haste-aterramento', 'HASTE ATERRAMENTO BX CAM 5/8 12,00MMX2,40M', 'UN'),
    ('61519', 'luminaria-led-embutir', 'PAINEL LED PTO EMB QUAD 18W BR6500K 22X22 POP', 'UN'),
    ('39609', 'revestimento-ceramico', 'PISO 50X50 5123 MARMORIZADO GRAY BR C2,54M', 'M2'),
    ('40774', 'porcelanato-retificado', 'PORC 71X71 RT ALVORADA SOFT CHIARO AC C1,51M', 'M2'),
    ('24144', 'espacador-piso', 'ESPACADOR PISO TOI 5MM LR (1224)', 'PT'),
    ('54100', 'nivelador-piso', 'ESPACADOR DE NIVELAMENTO ECO 1,0MM 50UN', 'PT'),
    ('58614', 'cunha-niveladora', 'CUNHA NIVELAMENTO SLIM 50UN', 'SO'),
    ('54475', 'espelho-banheiro', 'ESPELHO VIOLETA 45X60CM', 'UN'),
    ('14311', 'massa-corrida-pva', 'MASSA CORRIDA PVA BRANCA 3,6L 6KG', 'GL'),
    ('49958', 'selador-acrilico-18l', 'SELADOR ACRILICO PLUS BRANCO 18KG', 'BD'),
    ('55348', 'fita-crepe-48mm', 'FITA CREPE USO GERAL 48MMX50M', 'UN'),
    ('54038', 'lixa-massa-150', 'LIXA MASSA G150', 'UN'),
    ('59917', 'bacia-caixa-acoplada', 'COMBO BACIA COM CAIXA ACOPLADA LIRIO BCO', 'PC'),
    ('66913', 'torneira-banheiro', 'TORNEIRA LAV MESA ABS 1/2" BCO/PTO', 'UN'),
    ('18383', 'torneira-cozinha', 'TORNEIRA COZ PAR 18CM 3/4" BCO/PTO', 'UN'),
    ('51032', 'chuveiro-eletrico', 'DUCHA MULT HYDRA GORDUCHA 3T BCA 127V 5400W', 'UN'),
    ('63645', 'kit-acessorios-banheiro', 'KIT ACESS BANH TWISTER CRO 5PC', 'UN'),
    ('47871', 'pia-cozinha-inox', 'PIA INOX 1C 150X53 FURO 3.1/2" S VALV', 'UN'),
    ('50427', 'linha-nylon-pedreiro', 'LINHA P/ PEDREIRO NOVE54 LISA 100M', 'UN'),
    ('66349', 'carrinho-de-mao', 'CARRINHO MAO GALVANIZADA 55L', 'UN'),
    ('57936', 'colher-pedreiro', 'COLHER PEDREIRO 06'''' CB MADEIRA', 'UN'),
    ('67035', 'nivel-bolha', 'NIVEL DE ALUMINIO 16"', 'UN'),
    ('41164', 'trena-5m', 'TRENA TOI EMBORRACHADA 5MX19MM', 'UN'),
    ('66071', 'pa-de-bico', 'PA AJUNTADEIRA DE BICO CB MAD 120CM', 'PC')
  ) as v(codigo, item_id, nome, unidade)
 where l.cnpj = '36931301000186'
on conflict (loja_id, codigo) do nothing;
