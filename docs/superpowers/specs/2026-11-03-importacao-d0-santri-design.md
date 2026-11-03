# Importação D+0 do Santri — design

Data: 2026-11-03 · Subprojeto 2 da Parte 2 (painel da loja dos protótipos "App da Obra").

## Objetivo

Todo dia, o dono ou o gerente exporta do Santri o relatório de estoque, sobe no DailyObra Parceiros (no computador, pelo
navegador) e, num passo só, os produtos já ligados ao catálogo ficam com o preço e a disponibilidade do dia. Produto novo
só entra depois que a loja confirma a ligação.

Decidido na conversa:

- Um arquivo por dia: o relatório **"Valor do estoque analítico"** do Santri ADM, que já traz `Disponível` e
  `Preço venda`. A lista de preço do Santri fica de fora.
- Produtos novos entram **pelo catálogo**: para cada produto do catálogo ainda sem ligação, o app sugere o item com
  estoque mais parecido do relatório; a loja liga, troca ou pula (uma ligação nova por produto do catálogo a cada
  importação; um produto do catálogo pode acumular mais de um código ligado).
- O arquivo é lido no navegador da loja. O custo nunca sai do computador: só código, nome, unidade, preço e disponível
  dos itens usados vão para o banco. O arquivo não vai para o Storage.
- Visual atual do Parceiros.

Lição que vale aqui: o casamento automático numa lista inteira do ERP ligou produtos errados (lixa d'água em caixa
d'água). Nada é ligado sem a loja confirmar item por item; a atualização automática vale só para ligações confirmadas.

## 1. Leitura do relatório (pacote comum)

- `lerOds(Uint8List bytes)` lê o `content.xml` do `.ods` em fluxo, sem montar a árvore inteira (o relatório da Operário
  tem 30 MB aberto), e devolve `List<List<String>>` como `lerXlsx`: primeira tabela, células e células cobertas,
  `number-columns-repeated` e `number-rows-repeated`, valor de `office:value` quando a célula é número e o texto quando
  não é. Linhas e colunas vazias repetidas não são expandidas (o fim da planilha pode repetir milhares). `lerPlanilha`
  passa a aceitar `.ods`.
- A leitura devolve o controle à tela de tempos em tempos: a tela mostra `Lendo o relatório…` sem travar o navegador.
- `relatorioEstoqueSantri(List<List<String>> linhas) → List<LinhaEstoque>` acha o cabeçalho do Santri: primeira célula
  `Produto`, com `Disponível` e `Preço venda` (`Nome`, `Und.` e `Código de barras` são lidos se existirem). Sem esse
  cabeçalho: `Este arquivo não é o relatório "Valor do estoque analítico" do Santri.`
- `LinhaEstoque`: `codigo` (só dígitos: `65.097` → `65097`), `nome`, `unidade`, `disponivel` (`12,000` → 12;
  `-3,000` → -3) e `preco` (`27,90` → 27.9; nulo quando não há número). Linhas sem código numérico (títulos, totais) ficam
  de fora. Custo médio, totais e as outras colunas não entram no modelo.

## 2. Regras do dia (pacote comum, função pura)

`montarAtualizacao(relatorio, ligacoes, ofertas, catalogo)` monta o que a tela mostra e o que vai para o banco:

- **Produto do catálogo ligado** (um ou mais códigos): entre os códigos ligados que vieram no relatório, vale o mais
  barato com disponível maior que zero → `disponivel` com esse preço. Se nenhum tem estoque → `sem_estoque`, com o menor
  preço entre eles. Linha sem preço não conta.
- **Grupos do resumo:** `Preço novo`, `Voltou ao estoque`, `Ficou sem estoque`, `Sem mudança`, `Não veio no relatório`
  (ligado sem nenhum código no arquivo: a oferta fica como está) e `Conferir`: preço que muda mais de 30% sobre o preço
  atual da oferta ou fica em R$ 1,00 ou menos. `Conferir` começa desmarcado; o resto entra marcado.
- **Sugestões pelo catálogo:** para cada produto do catálogo sem ligação (vendido ou não pela loja), até 3 itens do
  relatório com disponível maior que zero que o `ReconhecedorDeProdutos` do comum liga a ele — os reconhecidos com
  certeza primeiro, depois os mais baratos —, com o aviso `Unidade diferente: confira se é o mesmo produto e tamanho.`
  quando a unidade do Santri não é a do catálogo.
- A promoção do Santri é ignorada (vem sem data de fim).

## 3. Banco

- Tabela `loja_produtos`: `loja_id` (→ `lojas`, apaga junto), `codigo` (texto, não vazio), `item_id` (→
  `catalogo_itens`), `nome`, `unidade`, `ligado_em` (agora); chave `(loja_id, codigo)`; índice `(loja_id, item_id)`.
  RLS: a equipe da loja lê; dono e gerente inserem, alteram e apagam.
- Coluna `lojas.estoque_atualizado_em`.
- `public.importar_estoque(p_loja uuid, p_ofertas jsonb, p_ligacoes jsonb) returns jsonb`, numa transação:
  - só dono ou gerente da loja: `Só o dono ou o gerente atualiza o estoque.`;
  - grava as ligações (`codigo`, `item_id`, `nome`, `unidade`; upsert por loja e código);
  - upsert das ofertas (`item_id`, `preco` > 0, `disponibilidade` `disponivel` ou `sem_estoque`) sem mexer em `pausada`;
    se o preço novo ficar menor ou igual a uma promoção manual, `preco_promocional` e `promo_ate` saem;
  - marca `lojas.estoque_atualizado_em = now()` e devolve `{"ofertas": n, "ligacoes": m}`.
- Migração de dados: as 61 ligações conferidas da Operário (loja pelo CNPJ `36931301000186`), com o código só com
  dígitos e o nome e a unidade do Santri.

## 4. Tela (Parceiros)

- **Produtos:** botão `Atualizar pelo Santri` ao lado de `Importar planilha`, só para dono e gerente (o vendedor não edita
  preço), e a linha `Estoque atualizado pelo Santri em {data}` (ou `Estoque ainda não atualizado pelo Santri`).
- **Tela `Atualizar pelo Santri`**, numa coluna de 760 px no computador como as outras telas abertas por cima:
  1. `Escolher relatório` (`.ods`, `.xlsx` ou `.csv`) → `Lendo o relatório…`; arquivo errado → o aviso da seção 1.
  2. **Resumo:** as contagens de cada grupo e a lista do que muda (produto do catálogo, preço antigo → novo, estoque);
     `Conferir` com as caixas desmarcadas.
  3. **Produtos do catálogo para ligar:** por produto, a sugestão (nome e unidade do Santri, preço, disponível) com
     `Ligar`, `Outro` (as outras sugestões) e `Pular`.
  4. `Confirmar` → `importar_estoque` → `Estoque atualizado: {n} produtos.`

## 5. Testes

- **Comum:** `lerOds` com um `.ods` montado no teste (colunas repetidas, célula coberta, número e texto, milhares de
  linhas vazias repetidas no fim sem virar linhas); `relatorioEstoqueSantri` (cabeçalho do Santri, `65.097` → `65097`,
  `12,000` → 12, `-3,000` → -3, linha de total fora, arquivo errado → erro); `montarAtualizacao` (mais barato com estoque,
  todos sem estoque, não veio, conferir por 30% e por R$ 1,00, sugestões com unidade diferente).
- **SQL** (desfeito no fim): só dono e gerente; outra loja não lê as ligações; ofertas e ligações gravadas juntas;
  promoção manual que sai; `estoque_atualizado_em` marcado.
- **Tela:** o fluxo completo com um arquivo de teste (resumo, conferir desmarcado, ligar e pular, confirmar manda só o
  que está marcado); vendedor não vê o botão.
- **Manual:** o relatório real da Operário de 30/10 no navegador (tempo de leitura; 11.701 linhas, 8.850 com estoque). O
  arquivo não vai para o repositório: tem o custo.

## Fora do escopo

Lista de preço do Santri, promoções do Santri, mostrar a quantidade em estoque ao construtor, envio agendado e
integração direta com o Santri.
