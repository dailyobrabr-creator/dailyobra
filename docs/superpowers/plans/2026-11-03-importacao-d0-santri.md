# Importação D+0 do Santri — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A loja sobe todo dia o relatório "Valor do estoque analítico" do Santri no Parceiros e os produtos ligados ao catálogo ficam com o preço e a disponibilidade do dia; produto novo só entra com a ligação confirmada.

**Architecture:** O pacote comum lê o `.ods` em fluxo, reconhece o relatório do Santri e monta a atualização (função pura). O banco guarda as ligações por loja e grava ofertas e ligações numa função só. O Parceiros ganha a tela `Atualizar pelo Santri`, aberta pela tela de Produtos.

**Tech Stack:** Flutter 3.47 / Dart 3.13 (archive ^4, xml ^7), Supabase (Postgres, RLS, funções security definer).

**Spec:** `docs/superpowers/specs/2026-11-03-importacao-d0-santri-design.md`

## Global Constraints

- Só o relatório **"Valor do estoque analítico"** do Santri ADM; a lista de preço fica de fora.
- O custo nunca entra no modelo nem sai do computador; o arquivo não vai para o Storage; os relatórios reais nunca vão para o repositório.
- Código da loja só com dígitos (`65.097` → `65097`), também nas 61 ligações da Operário.
- `Conferir`: preço que muda mais de 30% sobre o preço atual da oferta ou fica em R$ 1,00 ou menos; começa desmarcado.
- Textos exatos: `Este arquivo não é o relatório "Valor do estoque analítico" do Santri.`, `Atualizar pelo Santri`, `Escolher relatório`, `Lendo o relatório…`, `Preço novo`, `Voltou ao estoque`, `Ficou sem estoque`, `Sem mudança`, `Não veio no relatório`, `Conferir`, `Produtos do catálogo para ligar`, `Ligar`, `Outro`, `Pular`, `Unidade diferente: confira se é o mesmo produto e tamanho.`, `Confirmar`, `Estoque atualizado: {n} produtos.`, `Só o dono ou o gerente atualiza o estoque.`, `Estoque atualizado pelo Santri {quando}`, `Estoque ainda não atualizado pelo Santri`.
- Banco: funções `security definer` com `set search_path = ''` e erros `P0001` em português; testes SQL numa transação que termina com `raise exception 'RESULTADO: ...'` (rodam pelo `execute_sql` e desfazem tudo).
- Nunca rodar `dart format` no `dailyobra_comum` (estilo de linha longa); os apps usam `dart format lib test`.
- O push no `main` publica o site (aprovado junto com este plano); a migração vai para o banco de produção pelo MCP.

## Review Focus

1. O Santri muda a ordem das colunas ou acrescenta colunas: o cabeçalho é achado pelos nomes, não pela posição — teste `colunas em outra ordem` (Task 2).
2. O código chega como número (`65097`) ou com ponto (`65.097`): vira a mesma ligação — teste `código como número` (Task 2) e o código só com dígitos nas ligações da Operário (Task 3).
3. Arquivo errado ou corrompido (PDF renomeado, zip quebrado): aviso claro, sem travar — testes `arquivo que não abre` (Task 1) e `arquivo errado avisa` (Task 4).
4. Dois códigos no mesmo produto e o mais barato sem estoque: vale o preço do que tem estoque — teste `regras do dia` (Task 2).
5. Confirmar duas vezes ou subir o mesmo arquivo de novo: mesmo resultado, sem ligação repetida — teste SQL `importar de novo não duplica` (Task 3).

---

### Task 0: Setup

- [ ] Branch `importacao-d0` a partir do `main`, no próprio checkout (os pacotes dependem de `../dailyobra_comum`).
- [ ] Workspace e ledger pelo `sdd-workspace` deste plano.

### Task 1: Comum — leitor de .ods e leitura sem limite

**Files:**
- Create: `dailyobra_comum/lib/src/marketplace/leitor_ods.dart`
- Modify: `dailyobra_comum/lib/src/marketplace/planilha_precos.dart:183-204` (`lerPlanilha`), `dailyobra_comum/lib/dailyobra_comum.dart` (export), `dailyobra_parceiro/lib/screens/importar_planilha_screen.dart:65` (`await`)
- Test: `dailyobra_comum/test/leitor_ods_test.dart`, `dailyobra_comum/test/planilha_precos_test.dart:120-152`

**Interfaces:**
- Produces: `Future<List<List<String>>> lerOds(Uint8List bytes)`; `Future<List<List<String>>> lerLinhas(String nomeArquivo, Uint8List bytes)` (`.csv`, `.xlsx` ou `.ods`, sem linhas vazias, **sem** limite de linhas); `lerPlanilha` vira `Future<List<List<String>>>` = `lerLinhas` + os limites de hoje (só cabeçalho, 3.000 produtos).

- [ ] **Step 1: Write the failing tests** (`leitor_ods_test.dart`, com um `.ods` montado no teste por `Archive`/`ZipEncoder`, como o `xlsxDeTeste` de `planilha_precos_test.dart`):
  - `lê células, repetições e células cobertas`: o `content.xml` tem, numa `table:table`, as linhas `Santri ADM` · cabeçalho `Produto | Nome | Disponível` · `65.097` (texto) `| ABAFADOR<text:s/>DE RUIDOS |` célula `office:value-type="float" office:value="12"` com texto `12,000` · célula `x` com `table:number-columns-repeated="2"` seguida de `<table:covered-table-cell/>` · por fim `<table:table-row table:number-rows-repeated="1048000"><table:table-cell table:number-columns-repeated="16384"/></table:table-row>`. Esperado: `[['Santri ADM'], ['Produto', 'Nome', 'Disponível'], ['65.097', 'ABAFADOR DE RUIDOS', '12'], ['x', 'x']]` (células vazias no fim da linha saem; linhas vazias repetidas não viram linhas).
  - `lê 5.000 linhas`: `.ods` com cabeçalho e 5.000 linhas → 5.001 linhas.
  - `lê o arquivo pela extensão sem limite`: `lerLinhas('estoque.ods', ods)` lê; `lerLinhas('a.csv', ...)` com 3.001 produtos devolve 3.002 linhas; `lerLinhas('lista.pdf', Uint8List(3))` → `PlanilhaInvalida('Envie um arquivo .csv, .xlsx ou .ods.')`.
  - `arquivo que não abre`: `lerLinhas('a.ods', Uint8List.fromList([1, 2, 3]))` → `PlanilhaInvalida('Não deu para ler o arquivo. Abra no Excel, salve de novo como .xlsx ou .csv e tente outra vez.')`.
  - Em `planilha_precos_test.dart`, os testes de `lerPlanilha` passam a usar `await`, a mensagem do `.pdf` vira a nova e `lerPlanilha('tabela.ods', ods)` é aceito.
- [ ] **Step 2: Run** `cd dailyobra_comum; flutter test test/leitor_ods_test.dart test/planilha_precos_test.dart` — Expected: FAIL (`lerOds` e `lerLinhas` não existem).
- [ ] **Step 3: Implement** `lerOds` com `ZipDecoder` e `parseEvents` (`package:xml/xml_events.dart`) sobre o `content.xml`: só a primeira `table:table`; texto dos `text:p` (vários juntados com espaço; `text:s` com `text:c` vira espaços, `text:tab` e `text:line-break` viram espaço); `office:value` quando `office:value-type` é `float`, `currency` ou `percentage`; colunas vazias repetidas só viram células quando há célula preenchida depois delas na mesma linha; linha vazia é descartada (com ou sem repetição); repetição de valor preenchido limitada a 1.024; a cada 500 linhas, `await Future<void>.delayed(Duration.zero)`; sem `content.xml` → `FormatException`. `lerLinhas` escolhe pela extensão e troca qualquer falha de leitura de `.xlsx`/`.ods` pela mensagem de "não deu para ler". O Parceiros passa a dar `await` no `lerPlanilha`.
- [ ] **Step 4: Run** `cd dailyobra_comum; flutter analyze; flutter test` e `cd dailyobra_parceiro; flutter analyze; flutter test` — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(comum): leitor de .ods e leitura sem limite de linhas`.

### Task 2: Comum — relatório do Santri e regras do dia

**Files:**
- Create: `dailyobra_comum/lib/src/marketplace/estoque_santri.dart`
- Modify: `dailyobra_comum/lib/dailyobra_comum.dart` (export)
- Test: `dailyobra_comum/test/estoque_santri_test.dart`

**Interfaces:**
- Consumes: `lerPreco`, `PlanilhaInvalida`, `ReconhecedorDeProdutos(catalogo).reconhecer(nome)` → `LinhaSmartList(tipo: TipoLinha, item, candidatos)`, `unidadeCanonica`, `Oferta`, `Disponibilidade`.
- Produces:
  - `class LinhaEstoque { const LinhaEstoque({required String codigo, required String nome, String? unidade, required double disponivel, double? preco}); }`
  - `List<LinhaEstoque> relatorioEstoqueSantri(List<List<String>> linhas)` — lança `PlanilhaInvalida('Este arquivo não é o relatório "Valor do estoque analítico" do Santri.')`.
  - `class LigacaoProduto { const LigacaoProduto({required String codigo, required String itemId, String? nome, String? unidade}); factory LigacaoProduto.fromJson(Map<String, dynamic> j); Map<String, dynamic> toJson(); }` (chaves `codigo`, `item_id`, `nome`, `unidade`).
  - `enum GrupoMudanca { conferir, ficouSemEstoque, voltouAoEstoque, precoNovo, semMudanca }` — um grupo por produto, nesta ordem de precedência; rótulos `Conferir`, `Ficou sem estoque`, `Voltou ao estoque`, `Preço novo`, `Sem mudança`.
  - `class MudancaOferta { ItemCatalogo item; double? precoAntigo; double precoNovo; Disponibilidade? disponibilidadeAntiga; Disponibilidade disponibilidadeNova; GrupoMudanca grupo; }`
  - `class OpcaoLigacao { LinhaEstoque linha; bool certeza; bool unidadeDiferente; }` e `class SugestaoLigacao { ItemCatalogo item; List<OpcaoLigacao> opcoes; }` (até 3 opções).
  - `class AtualizacaoEstoque { List<MudancaOferta> mudancas; List<ItemCatalogo> naoVieram; List<SugestaoLigacao> sugestoes; int semPreco; }`
  - `AtualizacaoEstoque montarAtualizacao(List<LinhaEstoque> relatorio, List<LigacaoProduto> ligacoes, Map<String, Oferta> ofertas, List<ItemCatalogo> catalogo)` (`ofertas` por `itemId`, como `OfertasService.minhas`).

- [ ] **Step 1: Write the failing tests** (catálogo com os mesmos `cimento`, `tijolo`, `ferro516` e `ferro38` de `planilha_precos_test.dart`):
  - `lê o relatório do Santri`: linhas `['Santri ADM 1.1.5.9 R1']`, `['Valor de Estoque - Analítico']`, o cabeçalho real (`Produto, Nome, Marca, Código original, Código de barras, Volume, Volume litros, Volume total, Volume lt. total, Peso total, Disponível, Und., Custo médio, Preço venda, Total custo, Total venda, Diferença`), `65.097 · ABAFADOR DE RUIDOS TIPO CONCHA · … · 12,000 · UN · 8,0512 · 27,90 · …`, `10.259 · CIMENTO CP II · … · -3,000 · SO · 30,10 · 60,40 · …` e uma linha `Total geral` → duas linhas: `(65097, ABAFADOR DE RUIDOS TIPO CONCHA, UN, 12, 27.9)` e `(10259, CIMENTO CP II, SO, -3, 60.4)`.
  - `colunas em outra ordem`: cabeçalho `Produto | Preço venda | Und. | Disponível | Nome` → os mesmos valores.
  - `código como número`: código `65097` (como vem de `office:value`) → `65097`; `1.234` → `1234`.
  - `arquivo errado`: cabeçalho sem `Preço venda` → `PlanilhaInvalida` com o texto exato.
  - `regras do dia`: ligações `cimento ← 10259 e 99999`, `tijolo ← 61879`, `ferro516 ← 70000`; ofertas `cimento 60,00 disponível`, `tijolo 1,35 sem estoque`, `ferro516 52,00 disponível`; relatório `10259 CIMENTO CP II ITAU disp 0 preço 58,00`, `99999 CIMENTO CP II 50KG VOTORAN disp 5 preço 62,00`, `61879 TIJOLO 8 FUROS UN disp 1000 preço 1,40`, `55555 VERGALHAO CA-50 3/8 BARRA 12M BR disp 20 preço 39,00`, `44444 MANGUEIRA DE JARDIM 20M disp 3 preço 30,00`, `33333 CIMENTO CP II 50KG CAUE CX disp 0 preço 40,00`. Esperado: cimento `62,00 disponível, Preço novo` (o de 58,00 está sem estoque); tijolo `1,40 disponível, Voltou ao estoque`; `naoVieram == [ferro516]`; `sugestoes` tem `ferro38` com a primeira opção `55555`; nenhuma sugestão da mangueira nem do cimento sem estoque; nenhuma sugestão para cimento, tijolo ou ferro516 (já ligados).
  - `conferir`: oferta `18,88` e relatório `30,00` → `Conferir`; relatório `0,99` → `Conferir`; oferta `60,00` e relatório `61,00` → `Preço novo`.
  - `ficou sem estoque e sem preço`: ligado com oferta disponível e todos os códigos com `disp 0` → `Ficou sem estoque` com o menor preço deles; linha ligada sem preço → `semPreco == 1` e fica de fora.
  - `sugestão com unidade diferente`: `CIMENTO CP II 50KG VOTORAN CX disp 2 preço 45,00` sem ligação de cimento → opção de `cimento` com `unidadeDiferente == true`; `TIJOLO 8 FUROS UN` → `unidadeDiferente == false`; com duas opções reconhecidas com certeza, a mais barata vem primeiro.
- [ ] **Step 2: Run** `cd dailyobra_comum; flutter test test/estoque_santri_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**: cabeçalho = primeira linha cuja primeira célula é `Produto` e que tem `Disponível` e `Preço venda` (`Nome` e `Und.`/`Und` opcionais); código: tira espaços e pontos e só fica se sobrarem dígitos; disponível: com vírgula, tira os pontos e troca a vírgula; sem vírgula, lê como está (aceita sinal); preço por `lerPreco`. Regras e sugestões como a spec, seção 2: sugestão = linhas com disponível > 0 e preço > 0 que o reconhecedor liga ao produto (`reconhecido` → `certeza: true` para o `item`; `escolher` → `certeza: false` para cada candidato), por produto do catálogo sem ligação, ordenadas por certeza e depois preço; `unidadeDiferente` quando `unidadeCanonica` do Santri difere da do catálogo.
- [ ] **Step 4: Run** `cd dailyobra_comum; flutter analyze; flutter test` — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(comum): relatório de estoque do Santri e regras do dia`.

### Task 3: Banco — ligações, importar_estoque e as 61 da Operário

**Files:**
- Create: `supabase/migrations/20261103100000_importacao_estoque.sql`, `supabase/tests/importacao_estoque_test.sql`

**Interfaces:**
- Produces: tabela `public.loja_produtos (loja_id uuid → lojas on delete cascade, codigo text not null check (codigo ~ '^\d+$'), item_id text → catalogo_itens, nome text, unidade text, ligado_em timestamptz default now(), primary key (loja_id, codigo))` com índice `(loja_id, item_id)`; coluna `public.lojas.estoque_atualizado_em timestamptz`; `public.importar_estoque(p_loja uuid, p_ofertas jsonb, p_ligacoes jsonb) returns jsonb` → `{"ofertas": n, "ligacoes": m}` (`p_ofertas`: `[{item_id, preco, disponibilidade}]`; `p_ligacoes`: `[{codigo, item_id, nome, unidade}]`).

- [ ] **Step 1: Write the failing SQL test** (padrão de `supabase/tests/checkout_pagamento_test.sql`: usuários de teste, loja A com dono, gerente e vendedor, loja B), verificações:
  - `dono importa ofertas e ligações`: duas ofertas (uma nova, uma existente) e uma ligação → retorno `{"ofertas": 2, "ligacoes": 1}`, preço e disponibilidade gravados, ligação em `loja_produtos`, `estoque_atualizado_em` preenchido.
  - `pausa fica e promoção manual sai`: oferta pausada continua pausada; oferta com promoção 40,00 e preço novo 39,00 fica sem `preco_promocional`/`promo_ate`; com preço novo 45,00 a promoção fica.
  - `só dono ou gerente`: gerente importa; vendedor e dono da loja B recebem `Só o dono ou o gerente atualiza o estoque.`
  - `ligações só para a equipe`: vendedor da loja A lê as ligações e não insere direto; dono da loja B lê zero.
  - `valores inválidos`: preço 0 → `Preço inválido.`; disponibilidade `sob_consulta` → `Disponibilidade inválida.`
  - `importar de novo não duplica`: a mesma chamada duas vezes deixa uma ligação e o mesmo preço.
  - `ligações da Operário`: a loja do CNPJ `36931301000186` tem 61 ligações, todas com código só de dígitos.
- [ ] **Step 2: Run** o teste pelo `execute_sql` — Expected: falha (a tabela e a função não existem).
- [ ] **Step 3: Implement** a migração: tabela, índice, RLS (`select` para `private.membro_loja(loja_id) is not null`; `insert`/`update`/`delete` para `private.pode_gerir_loja(loja_id)`), a coluna, a função (checa `pode_gerir_loja`; valida cada oferta; upsert de `loja_produtos` por `(loja_id, codigo)`; upsert de `ofertas` só com `preco` e `disponibilidade`, limpando `preco_promocional` e `promo_ate` quando o preço novo é menor ou igual à promoção; marca `estoque_atualizado_em = now()`), `revoke` de `public, anon` e `grant` para `authenticated`, e o insert das 61 ligações da Operário gerado de `scratchpad/operario_dados/operario_ofertas.json` (`codigo` sem pontos, `item`, `produto` como nome, `und` como unidade), achando a loja pelo CNPJ e com `on conflict do nothing`. Aplicar com `apply_migration` (nome `importacao_estoque`).
- [ ] **Step 4: Run** o teste de novo e os testes SQL `checkout_pagamento_test`, `checkout_bifurcado_test` e `marketplace_test` — Expected: tudo `ok`.
- [ ] **Step 5: Commit** — `feat(banco): ligações dos códigos da loja e importação do estoque`.

### Task 4: Parceiros — tela Atualizar pelo Santri

**Files:**
- Create: `dailyobra_parceiro/lib/screens/atualizar_estoque_screen.dart`
- Modify: `dailyobra_parceiro/lib/services/ofertas_service.dart`
- Test: `dailyobra_parceiro/test/atualizar_estoque_test.dart`

**Interfaces:**
- Consumes: `lerLinhas` (Task 1); `relatorioEstoqueSantri`, `montarAtualizacao`, `LigacaoProduto` e os tipos da Task 2; `importar_estoque` (Task 3); `ArquivoPlanilha` e `ColunaCentral`.
- Produces: `OfertasService.carregarLigacoes() → Future<List<LigacaoProduto>>`; `OfertasService.importarEstoque({required List<Oferta> ofertas, required List<LigacaoProduto> ligacoes}) → Future<int>` (chama `importar_estoque`, recarrega as ofertas e o `LojaService`, devolve o número de ofertas); em teste, `definirParaTeste(..., List<LigacaoProduto> ligacoes = const [])` e `@visibleForTesting importacoesDeTeste` (lista de `(List<Oferta>, List<LigacaoProduto>)`) sem chamar o banco. `AtualizarEstoqueScreen({Key? key, Future<ArquivoPlanilha?> Function()? escolher})`.

- [ ] **Step 1: Write the failing tests** (claro e escuro; arquivo `.csv` com o cabeçalho do Santri, lido pelo `lerLinhas`; catálogo, ofertas e ligações pelo `OfertasService.definirParaTeste`):
  - `resumo do relatório`: depois de `Escolher relatório`, aparecem os grupos com as contagens (`Preço novo` 1, `Voltou ao estoque` 1, `Não veio no relatório` 1, `Conferir` 1) e a caixa do item em `Conferir` está desmarcada.
  - `confirmar manda só o marcado`: `Confirmar` → `importacoesDeTeste.single` tem as ofertas de `Preço novo` e `Voltou ao estoque` e não tem a de `Conferir`; marcando `Conferir` antes, ela vai junto; depois aparece `Estoque atualizado: {n} produtos.`
  - `ligar e pular sugestões`: em `Produtos do catálogo para ligar`, `Ligar` na sugestão de um produto e `Pular` na de outro → a ligação e a oferta do primeiro vão no `Confirmar`; nada do segundo; `Outro` troca para a segunda opção antes de ligar.
  - `unidade diferente avisa`: sugestão com unidade diferente mostra `Unidade diferente: confira se é o mesmo produto e tamanho.`
  - `arquivo errado avisa`: `.csv` sem `Preço venda` → `Este arquivo não é o relatório "Valor do estoque analítico" do Santri.`
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/atualizar_estoque_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** a tela, numa `ColunaCentral` dentro do `Scaffold` (título `Atualizar pelo Santri`): começo com o texto `Exporte do Santri o relatório "Valor do estoque analítico" e escolha o arquivo aqui. Só preço e estoque saem do seu computador; o custo fica nele.` e `Escolher relatório` (`.ods`, `.xlsx`, `.csv`; mesmo seletor da importação de planilha); `Lendo o relatório…` enquanto lê; resumo com a contagem de cada grupo, a lista do que muda (produto, preço antigo → novo, disponibilidade) e caixas só em `Conferir`; `Produtos do catálogo para ligar` com a opção atual de cada sugestão (nome e unidade do Santri, preço em `brl`, `Disponível: ${formatarQuantidade(n)}`), `Ligar` / `Outro` / `Pular` e o aviso de unidade; `Confirmar` manda as mudanças (menos `Sem mudança` e as de `Conferir` desmarcadas) mais as ligações novas e as ofertas delas (disponível > 0 → `disponivel`). Falhas de leitura e do servidor aparecem como aviso na tela.
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` no Parceiros — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(parceiros): tela Atualizar pelo Santri`.

### Task 5: Parceiros — entrada em Produtos

**Files:**
- Modify: `dailyobra_parceiro/lib/services/loja_service.dart:23-38,110-112,135-141` (`DadosLoja.estoqueAtualizadoEm`, coluna `estoque_atualizado_em`), `dailyobra_parceiro/lib/screens/produtos_screen.dart:34-48` e o topo da lista
- Test: `dailyobra_parceiro/test/painel_test.dart`

**Interfaces:**
- Consumes: `AtualizarEstoqueScreen` (Task 4).
- Produces: `DadosLoja.estoqueAtualizadoEm` (`DateTime?`, de `estoque_atualizado_em`).

- [ ] **Step 1: Write the failing tests** (claro e escuro):
  - `produtos mostra atualizar pelo santri para quem gere`: dono com `estoqueAtualizadoEm` hoje às 07:30 → botão com tooltip `Atualizar pelo Santri` e o texto `Estoque atualizado pelo Santri às 07:30`; sem data → `Estoque ainda não atualizado pelo Santri`; tocar no botão abre `AtualizarEstoqueScreen`.
  - `vendedor não vê atualizar pelo santri`: nem o botão nem a linha.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/painel_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**: `IconButton` (`Icons.inventory_2_outlined`, tooltip `Atualizar pelo Santri`) ao lado do de `Importar planilha`, só com `meuPapel.gere`; no topo da lista, para quem gere, `Estoque atualizado pelo Santri ${quando(d)}` ou `Estoque ainda não atualizado pelo Santri`; `DadosLoja` lê `estoque_atualizado_em`.
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` no Parceiros — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(parceiros): atualizar pelo Santri a partir de Produtos`.

### Task 6: Relatório real, publicação e APK

- [ ] **Step 1: Relatório real** — teste local, **sem commit**, em `dailyobra_comum/test/` que lê `C:\Users\luizh\Downloads\Valor do estoque analítico - 30-10-2026.ods` com `lerLinhas` e `relatorioEstoqueSantri`, roda com `flutter test --platform chrome` (com `CHROME_EXECUTABLE` apontando para o Edge se não houver Chrome) e imprime o tempo. Expected: 11.701 linhas e 8.850 com disponível > 0, em até 20 s. Apagar o teste depois. Se passar de 20 s, ruling: trocar o `parseEvents` por um leitor próprio das etiquetas.
- [ ] **Step 2: README** — na seção do Parceiros: `Atualizar pelo Santri` (o relatório, o resumo, o `Conferir`, as ligações pelo catálogo e que o custo não sai do computador). Commit — `docs: atualizar pelo Santri`.
- [ ] **Step 3: Suítes** — `flutter analyze` e `flutter test` nos três pacotes, `node --test dailyobra/test/pagina_pagar_test.mjs` e os quatro testes SQL. Expected: tudo verde.
- [ ] **Step 4: Publicar** — `main` avança para o branch (fast-forward), `git push origin main`, workflow `Site no GitHub Pages` com `success` e `/dailyobra/parceiros/` respondendo 200.
- [ ] **Step 5: APK** — `cd D:\dev\dailyobra_app\dailyobra_parceiro; flutter build apk --release` pelo terminal e cópia para `apk\DailyObraParceiros.apk` (o app do construtor não muda).
