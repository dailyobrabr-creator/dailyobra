-- Sistema de gestão (ERP) onde a loja lança as vendas. O Faturamento usa o nome dele nos textos e só quem usa o
-- Santri tem a atualização do dia pelo relatório de estoque. Nulo: a loja não usa sistema ou ainda não escolheu.
alter table public.lojas add column sistema_gestao text
  check (sistema_gestao is null or (sistema_gestao = btrim(sistema_gestao) and char_length(sistema_gestao) between 2 and 40));

-- Quem já ligou produtos pelo relatório do Santri usa o Santri (a Operário, com 61 ligações)
update public.lojas l set sistema_gestao = 'Santri'
 where exists (select 1 from public.loja_produtos p where p.loja_id = l.id);
