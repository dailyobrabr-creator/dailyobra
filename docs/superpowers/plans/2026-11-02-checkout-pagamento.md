# Checkout: saldo, formas de pagamento e link do cliente — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Saldo da carteira só na hora de pagar ("Eu pago"), formas de pagamento combinadas com a loja (PIX, cartão na loja, crediário com aprovação) e link do cliente com CPF/CNPJ opcional e prévia da mensagem, mantendo o visual atual.

**Architecture:** Regras no Supabase (campos novos em `pedidos` + funções `security definer`); o comum lê os campos novos; o app do construtor estende o `QuemPaga`; o Parceiros mostra a forma e responde ao prazo; a página do cliente mostra o documento mascarado com "Corrigir".

**Tech Stack:** Flutter 3.47 / Dart 3.13 (dailyobra, dailyobra_parceiro, dailyobra_comum), Supabase Postgres (MCP `apply_migration`/`execute_sql`), página estática HTML/JS testada com `node --test`.

**Spec:** `docs/superpowers/specs/2026-11-02-checkout-pagamento-design.md`

## Global Constraints

- Visual atual mantido: mesmos componentes do app (`Painel`, `CampoTexto`, `ChoiceChip`, `Aviso`), nada de tema novo.
- Erros do banco em `P0001` com estes textos exatos: `Pedido não encontrado.`, `Este pedido foi cancelado.`, `Este pedido já foi pago.`, `Escolha "Eu pago" para usar o saldo.`, `O pagamento já foi informado. Fale com a loja.`, `Você não tem saldo disponível.`, `Forma de pagamento inválida.`, `Escolha o prazo do crediário.`, `Só o dono ou o gerente responde ao prazo.`, `Não há prazo para responder.`, `CPF ou CNPJ inválido. Confira os números.`
- Funções `security definer` com `set search_path = ''`, como as do checkout bifurcado.
- Formas: `pix` | `cartao` | `crediario`; prazos: `28` | `28/35` | `28/35/42`; status do prazo: `pendente` | `aprovado` | `recusado`.
- `dailyobra_comum` não passa por `dart format`; os apps usam `dart format lib test`.
- Testes SQL rodam numa transação que termina com o bloco `raise exception 'RESULTADO: % de % ok; falhas: %'` (rodam pelo `execute_sql` e tudo é desfeito).
- Valores em reais nos testes de tela sempre por `brl.format(...)` (o formato usa espaço inquebrável).

## Review Focus

1. Saldo maior que o total do pedido (saldo R$ 1.000, pedido R$ 80): aplica só R$ 80, total vira zero, sem PIX, e o app mostra que não há nada a pagar — teste SQL na Task 1 e de tela na Task 3.
2. PIX depois de ligar/desligar o saldo: o copia e cola precisa ser buscado de novo com o total novo — teste de tela na Task 3.
3. Crediário pedido e depois "Enviar para o cliente": o link limpa o prazo e o Parceiros deixa de oferecer Aprovar/Recusar — teste SQL na Task 1.
4. Gerente tentando responder prazo de pedido cancelado: recusa com `Este pedido foi cancelado.` — teste SQL na Task 1.
5. Pedido antigo com saldo reservado na cotação (APK antigo): interruptor aparece ligado e desligar devolve esse saldo — teste SQL na Task 1.

---

### Task 1: Banco — campos, funções e testes SQL

**Files:**
- Create: `supabase/migrations/20261102230000_checkout_pagamento.sql`
- Create: `supabase/tests/checkout_pagamento_test.sql`

**Interfaces:**
- Produces (SQL): colunas `pedidos.forma_pagamento`, `prazo`, `prazo_status`, `prazo_respondido_em`; `private.saldo_no_pedido(uuid) returns numeric`; `private.mascarar_documento(text) returns text`; `public.usar_saldo(p_pedido uuid, p_usar boolean) returns numeric` (saldo usado no pedido depois da chamada); `public.escolher_pagamento(p_pedido uuid, p_forma text, p_prazo text default null) returns void`; `public.responder_prazo(p_pedido uuid, p_aprovar boolean) returns void`; `public.criar_link_pagamento(p_pedido uuid, p_nome text, p_whatsapp text, p_documento text default null) returns text`; `pedido_do_link` devolve também `documento_mascarado`.

- [ ] **Step 1: Write the failing SQL test** `supabase/tests/checkout_pagamento_test.sql`, no padrão de `checkout_bifurcado_test.sql` (mesmos helpers `guardar/pegar/conferir/como/anonimo/admin`; construtor `c001`, outro `c002`, dono `d001` da loja A com `loja_pix`, vendedor `e001` da loja A, dono `f001` da loja B; saldo de teste lançado como admin em `carteira_lancamentos`, `emissor -X / disponivel +X`). Verificações, nesta ordem:
  1. `saldo liga e baixa o total`: pedido de 400 em "Eu pago", saldo 30 → `usar_saldo(true)` devolve 30; `pedidos.total = 370`; `propostas.saldo_aplicado = 30`; disponível 0; `pix_do_pedido` contém `5406370.00`.
  2. `ligar de novo não aplica duas vezes`: segundo `usar_saldo(true)` devolve 30 e o total segue 370.
  3. `desligar devolve o saldo`: `usar_saldo(false)` devolve 0; total 400; `saldo_aplicado` 0; disponível 30.
  4. `saldo maior que o pedido zera o total sem PIX`: saldo 1000, pedido de 80 → total 0; `pix_do_pedido` nulo; disponível 920.
  5. `saldo só do dono, só no Eu pago e antes do pagamento`: `c002` → `Pedido não encontrado.`; pedido sem pagador → `Escolha "Eu pago" para usar o saldo.`; depois de `confirmar_pagamento` → `Este pedido já foi pago.`
  6. `link devolve o saldo`: saldo ligado e depois `criar_link_pagamento` → total cheio de novo, disponível restaurado, `forma_pagamento = 'pix'`.
  7. `cancelar devolve o saldo do checkout`: saldo ligado e `atualizar_pedido(..., 'cancelado')` pelo construtor → disponível restaurado e `private.saldo_no_pedido` = 0.
  8. `saldo da cotação aparece ligado e desligar devolve`: `enviar_cotacao(..., p_usar_saldo => true)`, loja aceita, `pagar_eu_mesmo`; `usar_saldo(true)` devolve o mesmo valor reservado (não aplica de novo); `usar_saldo(false)` devolve tudo à conta disponível.
  9. `formas de pagamento`: `escolher_pagamento('cartao')` grava; `('boleto')` → `Forma de pagamento inválida.`; `('crediario', null)` → `Escolha o prazo do crediário.`; `('crediario', '28/35')` → `prazo = '28/35'`, `prazo_status = 'pendente'`.
  10. `prazo só o dono ou o gerente responde`: vendedor `e001` → `Só o dono ou o gerente responde ao prazo.`; dono da loja B → `Pedido não encontrado.`; dono `d001` aprova → `aprovado` com `prazo_respondido_em`; responder de novo → `Não há prazo para responder.`
  11. `prazo recusado e nova forma`: crediário → `responder_prazo(false)` → `recusado`; `escolher_pagamento('pix')` → prazo, status e resposta nulos.
  12. `crediário e depois link limpa o prazo`: crediário pendente → `criar_link_pagamento` → `prazo`, `prazo_status` nulos e `forma_pagamento = 'pix'`.
  13. `prazo de pedido cancelado`: crediário pendente, pedido cancelado → `responder_prazo` → `Este pedido foi cancelado.`
  14. `link com documento grava e a página mascara`: `criar_link_pagamento(p, 'Ana', '66999990000', '529.982.247-25')` → `pedido_documentos.documento = '52998224725'`, `documento_informado_em` preenchido; `pedido_do_link` (anon) → `documento_mascarado = '***.982.247-**'`, `situacao = 'aguardando_pagamento'`, `pix` começando com `000201` e o texto `52998224725` ausente do JSON.
  15. `link com documento inválido`: `'111.111.111-11'` → `CPF ou CNPJ inválido. Confira os números.`
  16. `CNPJ mascarado`: `private.mascarar_documento('11222333000181') = '**.222.333/0001-**'`.

- [ ] **Step 2: Run it against the current database (execute_sql).** Expected: falha (funções e colunas não existem).

- [ ] **Step 3: Write and apply the migration** `20261102230000_checkout_pagamento.sql` (via `apply_migration`, nome `checkout_pagamento`):
  - Colunas com `check` dos valores das Global Constraints.
  - `private.saldo_no_pedido(p_pedido)` = soma de `carteira_lancamentos.valor` com `pedido_id = p_pedido`, `conta = 'emissor'` e `tipo in ('saldo_usado', 'saldo_devolvido')`.
  - `private.mascarar_documento(p)`: 11 dígitos → `***.` + dígitos 4–6 + `.` + 7–9 + `-**`; 14 dígitos → `**.` + 3–5 + `.` + 6–8 + `/` + 9–12 + `-**`.
  - `usar_saldo`, `escolher_pagamento`, `responder_prazo` como na spec 2.1/2.2 (ligar usa `private.saldo(uid, 'disponivel')` e `private.mover(uid, 'disponivel', 'emissor', valor, 'saldo_usado', ..., loja, pedido, proposta)`; desligar move `emissor → disponivel` com `saldo_devolvido`; ambos ajustam `pedidos.total` e `propostas.saldo_aplicado`). `responder_prazo` usa `private.membro_loja` (não membro → `Pedido não encontrado.`) e `private.pode_gerir_loja`.
  - `criar_link_pagamento`: `drop function public.criar_link_pagamento(uuid, text, text)` e recria com `p_documento text default null`: devolve primeiro o saldo usado no pedido (mesmo movimento do desligar), depois as checagens atuais (inclusive total zero), valida o documento quando vier, grava `forma_pagamento = 'pix'`, limpa prazo/status/resposta, e com documento grava `pedido_documentos` e `documento_informado_em = now()`. Mesmas permissões (revoke de `public, anon`; grant a `authenticated`).
  - `pedido_do_link`: acrescenta `'documento_mascarado', (select private.mascarar_documento(d.documento) from public.pedido_documentos d where d.pedido_id = pe.id)`.
  - `atualizar_pedido`: `create or replace` com o corpo de `20261031130200_marketplace_funcoes.sql` (linhas 335–367), trocando só o cálculo do saldo devolvido no cancelamento por `usado := private.saldo_no_pedido(p_pedido);`.
  - `revoke execute ... from public` nas funções `private.*` novas; `grant execute` a `authenticated` em `usar_saldo`, `escolher_pagamento`, `responder_prazo`.

- [ ] **Step 4: Run the new test, then `checkout_bifurcado_test.sql` and `marketplace_test.sql`.** Expected: `RESULTADO: 16 de 16 ok`, `23 de 23 ok`, `48 de 48 ok`. Rode `get_advisors` (security): nada novo além dos avisos já aceitos das funções do link.

- [ ] **Step 5: Commit** — `feat(banco): saldo no checkout, formas de pagamento e prazo`.

### Task 2: Comum — forma de pagamento e prazo no pedido

**Files:**
- Modify: `dailyobra_comum/lib/src/marketplace/pagamento.dart`, `dailyobra_comum/lib/src/marketplace/propostas.dart`
- Test: `dailyobra_comum/test/pagamento_test.dart`

**Interfaces:**
- Produces: `enum FormaPagamento { pix('pix', 'PIX'), cartao('cartao', 'Cartão na loja'), crediario('crediario', 'Crediário da loja') }` com `codigo`, `rotulo` e `static FormaPagamento? fromCodigo(String?)`; `enum StatusPrazo { pendente, aprovado, recusado }` com `static StatusPrazo? fromCodigo(String?)`; `const prazosCrediario = ['28', '28/35', '28/35/42'];`; `PedidoResumo.formaPagamento`, `prazo` (`String?`), `prazoStatus`, `prazoRespondidoEm`.

- [ ] **Step 1: Write the failing tests:** `PedidoResumo.fromJson lê forma e prazo` (`{'forma_pagamento': 'crediario', 'prazo': '28/35', 'prazo_status': 'pendente'}` → `FormaPagamento.crediario`, `'28/35'`, `StatusPrazo.pendente`; sem os campos → nulos) e `rótulos das formas` (`FormaPagamento.cartao.rotulo == 'Cartão na loja'`, `fromCodigo('boleto') == null`).
- [ ] **Step 2: Run** `cd dailyobra_comum; flutter test test/pagamento_test.dart` — Expected: FAIL (nomes não definidos).
- [ ] **Step 3: Implement** os enums, a lista de prazos e os campos/`fromJson` do `PedidoResumo` (mesmo padrão de `pagador`).
- [ ] **Step 4: Run** `flutter analyze` e `flutter test` no comum — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(comum): forma de pagamento e prazo no pedido`.

### Task 3: App — "Eu pago" com titular, saldo, formas e total

**Files:**
- Modify: `dailyobra/lib/screens/quem_paga.dart`, `dailyobra/lib/screens/pedido_screen.dart`, `dailyobra/lib/services/negociacao_service.dart`
- Test: `dailyobra/test/quem_paga_test.dart`

**Interfaces:**
- Consumes: Task 2 (`FormaPagamento`, `StatusPrazo`, `prazosCrediario`, campos do `PedidoResumo`); Task 1 (`usar_saldo`, `escolher_pagamento`).
- Produces: `NegociacaoService.usarSaldo(String pedidoId, bool usar)` e `escolherPagamento(String pedidoId, FormaPagamento forma, {String? prazo})` via `_acao`; colunas novas no `select` de `pedidos`. `QuemPaga` ganha `required String nomeTitular`, `required double saldoDisponivel`, `required double saldoNoPedido`, `required Future<void> Function(bool usar) usarSaldo`, `required Future<void> Function(FormaPagamento forma, String? prazo) escolherPagamento`.

- [ ] **Step 1: Write the failing widget tests** (claro e escuro; `montar` ganha os parâmetros novos e registra as chamadas em `Chamadas`):
  - `eu pago mostra o titular da nota`: pedido "Eu pago" confirmado, `nomeTitular: 'Marcos Silva'`, documento `52998224725` → `Nota no nome de Marcos Silva`, `529.982.247-25` e `Alterar`; tocar em `Alterar` mostra o campo `documento` de novo.
  - `interruptor do saldo`: `saldoDisponivel: 30` → `Usar saldo da carteira (${brl.format(30)})`; tocar chama `usarSaldo(true)`; com `saldoNoPedido: 30` aparece `Abate ${brl.format(30)} neste pedido.` e tocar chama `usarSaldo(false)`; sem saldo nenhum, o interruptor não aparece.
  - `formas de pagamento`: `Cartão na loja` chama `escolherPagamento(cartao, null)` e mostra `Pague na maquininha da loja na entrega ou retirada.`; `Crediário da loja` mostra `28 dias`, `28/35 dias`, `28/35/42 dias`; escolher `28/35 dias` e tocar `Pedir prazo` chama `escolherPagamento(crediario, '28/35')`.
  - `estados do prazo`: pedido com crediário `pendente`, `aprovado` (`28/35/42`) e `recusado` → `Aguardando a loja aprovar o prazo.`, `Prazo aprovado: 28/35/42 dias.`, `A loja recusou o prazo. Escolha PIX ou cartão.`
  - `total a pagar e PIX novo quando o total muda`: `Total a pagar` com `brl.format(450)`; montar de novo a mesma chave com total 420 → a função `pix` foi chamada duas vezes e aparece `brl.format(420)`.
  - `saldo cobriu o pedido`: total 0 com `saldoNoPedido: 80` → `O saldo DailyObra cobriu este pedido. Não há nada a pagar.` e nenhuma forma de pagamento.
- [ ] **Step 2: Run** `cd dailyobra; flutter test test/quem_paga_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** no `QuemPaga`, no visual atual: depois do documento confirmado, o cartão do titular (com `formatarDocumento` e `Alterar`), o interruptor do saldo, os `ChoiceChip` das formas (sem forma gravada, PIX vem marcado sem chamar o banco), os chips de prazo com `Pedir prazo`, os textos do prazo e a linha `Total a pagar` (loja sem chave PIX: PIX marcado continua mostrando `Combine o pagamento com a loja.`, como hoje). `didUpdateWidget` busca o PIX de novo quando `total` muda (sem mexer na escolha). `PedidoScreen` passa `PerfilService.instance.nome`, `CarteiraService.instance.disponivel`, `p.saldoAplicado` e as duas ações do serviço, e passa a ouvir também `CarteiraService` e `PerfilService`.
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` no app — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(app): saldo e formas de pagamento no Eu pago`.

### Task 4: App — link do cliente com documento e prévia; cotação sem saldo

**Files:**
- Modify: `dailyobra/lib/screens/quem_paga.dart`, `dailyobra/lib/services/negociacao_service.dart`, `dailyobra/lib/screens/pedido_screen.dart`, `dailyobra/lib/screens/orcamentos_screen.dart`
- Test: `dailyobra/test/quem_paga_test.dart`, `dailyobra/test/orcamentos_test.dart`

**Interfaces:**
- Consumes: Task 1 (`criar_link_pagamento` com `p_documento`).
- Produces: `NegociacaoService.criarLink(String pedidoId, {required String nome, required String whatsapp, String? documento})`; `QuemPaga.criarLink` passa a ser `Future<String> Function(String nome, String whatsapp, String? documento)`.

- [ ] **Step 1: Write the failing tests:**
  - `link com documento do cliente` (quem_paga_test): campo `cliente-documento` (`CPF ou CNPJ do cliente (opcional)`); `111.111.111-11` → `CPF ou CNPJ inválido. Confira os números.` e nenhum link; `529.982.247-25` → `criarLink('Ana', '66999990000', '52998224725')`; vazio → documento `null`.
  - `prévia da mensagem`: com nome `Ana`, o cartão `Mensagem que vai no WhatsApp` mostra exatamente `mensagemDoLink(nome: 'Ana', loja: 'Casa do Construtor', total: 450, link: linkDePagamento('…'))`.
  - `cotação não oferece o saldo da carteira` (orcamentos_test): com `CarteiraService.instance.definirParaTeste(disponivel: 50)`, a revisão da cotação não tem `Usar saldo da carteira` e o envio vai com `usarSaldo: false`.
- [ ] **Step 2: Run** os dois arquivos — Expected: FAIL.
- [ ] **Step 3: Implement** o campo opcional e a prévia (atualiza ao digitar o nome; código do link aparece como `…` até o envio), o parâmetro `documento` até o `rpc` (`p_documento`, só quando não vazio), e tire de `orcamentos_screen.dart` o `_usarSaldo` e o `SwitchListTile`, mandando sempre `usarSaldo: false`.
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` no app — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(app): documento do cliente e prévia no link; saldo sai da cotação`.

### Task 5: Parceiros — forma de pagamento e prazo

**Files:**
- Modify: `dailyobra_parceiro/lib/services/propostas_loja_service.dart`, `dailyobra_parceiro/lib/screens/pedido_loja_screen.dart`, `dailyobra_parceiro/lib/screens/componentes.dart`
- Test: `dailyobra_parceiro/test/painel_test.dart`

**Interfaces:**
- Consumes: Task 1 (`responder_prazo`), Task 2 (campos e enums).
- Produces: `PropostasLojaService.responderPrazo(String pedidoId, bool aprovar)` via `_pedidoRpc`; em modo de teste registra em `@visibleForTesting final prazosDeTeste = <(String, bool)>[]` e não chama o banco; colunas novas em `pedidos(...)` do `_colunas`.

- [ ] **Step 1: Write the failing tests** (claro e escuro):
  - `pedido mostra a forma de pagamento`: cartão → `Cartão na loja`; crediário aprovado `28/35` → `Crediário: 28/35 dias` e `Prazo aprovado.`
  - `gerente aprova ou recusa o prazo`: crediário pendente, papel dono → `Aprovar prazo` registra `('ped1', true)`; `Recusar` registra `('ped1', false)`.
  - `vendedor não responde ao prazo`: papel vendedor → sem os botões e com `Aguardando o gerente aprovar o prazo.`
  - `lista mostra prazo para aprovar`: na aba de pedidos, o selo `Prazo para aprovar`.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/painel_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** o serviço, o painel Pagamento (forma, botões só para `meuPapel.gere`, textos de resposta) e `seloParaLoja` (prazo pendente → `('Prazo para aprovar', TomSelo.aviso)` antes do selo do status).
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(parceiros): forma de pagamento e resposta ao prazo`.

### Task 6: Página do cliente — documento mascarado e "Corrigir"

**Files:**
- Modify: `dailyobra/web/pagar/index.html`
- Test: `dailyobra/test/pagina_pagar_test.mjs`

**Interfaces:**
- Consumes: Task 1 (`documento_mascarado` em `pedido_do_link`).
- Produces: `tela(p, corrigindo = false)` (com `corrigindo` e situação em aberto → `'formulario'`); `pagamento(p)` mostra `Nota no CPF/CNPJ {documento_mascarado}` e o link `Corrigir` (`id="corrigir"`) quando houver documento.

- [ ] **Step 1: Write the failing Node tests:** `pagamento mostra o documento mascarado e Corrigir` (`pagamento(pedido({documento_mascarado: '***.982.247-**', pix: '000201'}))` contém `Nota no CPF/CNPJ ***.982.247-**` e `id="corrigir"`); `sem documento mascarado não há Corrigir`; `Corrigir volta ao formulário` (`tela(pedido({situacao: 'aguardando_pagamento', documento_informado: true, pix: '000201'}), true) === 'formulario'`).
- [ ] **Step 2: Run** `node --test dailyobra/test/pagina_pagar_test.mjs` — Expected: FAIL.
- [ ] **Step 3: Implement** a linha com o documento (com `escapar`), o estado `corrigindo` (o clique em `Corrigir` mostra o formulário com o nome atual; depois de `dados_do_pagador`, volta a `false` e recarrega).
- [ ] **Step 4: Run** o teste de novo — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(pagina): documento mascarado e corrigir dados da nota`.

### Task 7: README, publicação e APKs

**Files:**
- Modify: `README.md` (seção "Pagamento pelo cliente (link PIX)": saldo só no "Eu pago", formas de pagamento e prazo, documento opcional do cliente; `checkout_pagamento_test.sql` em "Verificar")

- [ ] **Step 1: Run all suites:** `flutter analyze` e `flutter test` nos três pacotes, `node --test dailyobra/test/pagina_pagar_test.mjs` e os três testes SQL — Expected: tudo verde.
- [ ] **Step 2: Commit the README** — `docs: formas de pagamento e saldo no checkout`.
- [ ] **Step 3: Merge and push** — merge do branch no `main` e `git push origin main` (aprovado junto com o plano); esperar o workflow "Site no GitHub Pages" terminar com `success` e conferir que `/pagar/?c=invalido` abre `Link inválido`.
- [ ] **Step 4: Rebuild the APKs** pelo terminal (`cd D:\dev\dailyobra_app\<app>; flutter build apk --release` nos dois) e copiar para `apk\DailyObra.apk` e `apk\DailyObraParceiros.apk`.
