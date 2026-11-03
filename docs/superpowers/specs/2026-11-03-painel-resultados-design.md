# Painel de resultados — design

Data: 2026-11-03 · Subprojeto 3 da Parte 2 (painel da loja dos protótipos "App da Obra").

## Objetivo

O dono ou o gerente abre o Início do DailyObra Parceiros e vê como a loja está vendendo pelo app no mês: quanto faturou
e se está melhor que o mês anterior, quantos pedidos fechou, o ticket médio, quanto cashback gerou para os clientes e
quem mais comprou. O vendedor não vê esses valores. O visual é o de hoje: mesmos cartões, mesmas cores.

Decidido na conversa:
- Fica no **Início**, numa seção abaixo dos 4 indicadores atuais (nada muda na navegação).
- **Venda = pedido fechado**: todo pedido criado no período (a loja aceitou), menos os cancelados.
- **Só dono e gerente** veem; o banco recusa para o vendedor.
- Do mockup (`painel_web_lojista`, aba "Dashboard Estratégico & Mercado") entram os cartões de faturamento, pedidos e
  ticket, cashback e a lista de top construtores. "Propostas pendentes" já é o indicador `Propostas novas` de hoje.
  Commodities e notícias ficam de fora (combinado na Parte 2).

## 1. Regras

- **Período:** um mês do calendário no fuso do aparelho: de 1º às 0h até 1º do mês seguinte às 0h. O app manda o começo
  e o fim (instantes, `timestamptz`) para o banco, que não precisa saber o fuso.
- **Faturamento:** soma do total da proposta de cada pedido do período (produtos + frete − desconto). Pagar parte com
  saldo da carteira não muda o valor da venda (o `total` do pedido sai sem o saldo; por isso a conta usa o da proposta).
- **Pedidos fechados:** quantos pedidos do período. **Ticket médio:** faturamento ÷ pedidos (sem pedido, `—`).
- **Cashback gerado:** soma do `cashback_previsto` das propostas desses pedidos.
- **Comparação:** no mês atual, com o mesmo período do mês anterior: de 1º do mês anterior até o mesmo dia e hora de
  agora nele; se o mês anterior não tem esse dia, até o fim dele (no dia 31 de março, fevereiro inteiro). Em mês
  passado, com o mês anterior inteiro. Variação = (atual − anterior) ÷ anterior, com uma casa (`+18,4%`, `−5,2%`,
  `0,0%`). Textos: `+18,4% sobre o mesmo período de outubro` (mês atual), `+18,4% sobre outubro` (mês passado) e, sem
  venda no período anterior, `sem vendas em outubro para comparar`.
- **Top construtores:** até 5 construtores com pedido no período, pelo total (maior primeiro; empate: mais pedidos,
  depois o nome). Cada um com nome (vazio vira `Construtor`), empresa (se tiver), número de pedidos e total.

## 2. Banco

- `public.resultados_loja(p_loja uuid, p_de timestamptz, p_ate timestamptz) returns jsonb`, security definer com
  `search_path = ''`:
  - recusa quem não é dono ou gerente da loja: `Só o dono ou o gerente vê os resultados.` (P0001);
  - recusa período nulo ou com fim antes ou igual ao começo: `Período inválido.` (P0001);
  - devolve `{"faturamento": n, "pedidos": n, "cashback": n, "top": [{"construtor_id", "nome", "empresa", "pedidos",
    "total"}]}` com as regras da seção 1 (pedido de `p_de` inclusive a `p_ate` exclusive, status diferente de
    `cancelado`); nome e empresa vêm de `profiles`.
  - `execute` só para `authenticated`.
- Índice `pedidos_loja_criado_idx` em `pedidos (loja_id, criado_em)`.

## 3. App (Parceiros)

- **`ResultadosService`** (mesmo jeito dos outros serviços: `ChangeNotifier`, instância única, `definirParaTeste`):
  `carregar(DateTime mes)` chama a função duas vezes em paralelo (período e comparação) e guarda o mês, os dois
  resultados, `carregando` e `erro` (mensagem do servidor).
- **Contas puras, testadas à parte:** o período e a comparação de um mês (`agora` entra como parâmetro), a variação e o
  texto dela, e o nome do mês em português (`novembro de 2026`, lista própria: o app não inicia o `intl` com datas).
- **Início:** para dono e gerente, depois dos 4 indicadores, a seção `Resultados do mês`:
  - cabeçalho com `◀ novembro de 2026 ▶` (a seta da direita não passa do mês atual);
  - 4 cartões `Indicador` na mesma grade de 2 colunas: `Faturamento`, `Pedidos fechados`, `Ticket médio`,
    `Cashback gerado para os clientes`; o de faturamento ganha uma linha de detalhe com o texto da variação (parâmetro
    opcional novo do `Indicador`, sem mudar os cartões de hoje);
  - `Top construtores`: um item por construtor (nome, empresa, `3 pedidos`, total);
  - mês sem pedido: `Nenhum pedido em novembro ainda.`; carregando: `Esqueleto`; erro: `Aviso` com a mensagem;
  - puxar para atualizar no Início recarrega também os resultados do mês aberto.
- O vendedor continua vendo o Início de hoje, sem a seção (e o serviço nem chama o banco para ele).

## 4. Testes

- **SQL** (desfeito no fim, como os outros): soma, contagem, cashback e ticket com pedidos dentro e fora do período,
  cancelado fora, outra loja fora, total da proposta mesmo com saldo aplicado, ordem e limite de 5 do top, vendedor e
  quem não é da loja recusados, período inválido recusado.
- **Contas:** meio do mês, dia 31 com mês anterior curto, janeiro comparando com dezembro do ano anterior, mês passado
  inteiro, variação com anterior zero, positiva, negativa e igual.
- **Tela:** dono vê os 4 cartões e o top com os números do serviço; vendedor não vê a seção; voltar um mês carrega o mês
  anterior e a seta da direita volta a funcionar; mês atual sem seta para a frente; mês vazio; erro. Tema claro e
  escuro, como os outros testes do Parceiros.

## Fora do escopo

Margem (precisa do custo, que não importamos), metas, gráfico por dia, ranking de produtos, exportar para planilha ou
PDF, atualização em tempo real (recarrega ao abrir, ao trocar de mês e ao puxar), commodities e notícias.
