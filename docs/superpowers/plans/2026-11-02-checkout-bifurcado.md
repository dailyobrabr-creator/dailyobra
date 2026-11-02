# Checkout bifurcado Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No pedido aceito, o construtor escolhe "Eu pago" (nota no CPF/CNPJ dele, PIX da loja no app) ou "Enviar para o cliente" (link pelo WhatsApp para uma página leve onde o dono da obra informa o documento e paga por PIX direto à loja).

**Architecture:** Regras e dados no Supabase (colunas novas, tabela `pedido_documentos` só para a loja, funções `security definer`, BR Code gerado no banco). O app do construtor e o Parceiros chamam as funções; a página do cliente é um HTML estático em `dailyobra/web/pagar/` que chama as funções públicas pelo REST com a chave publicável.

**Tech Stack:** Postgres/Supabase (MCP `apply_migration`, `execute_sql`), Flutter 3.47/Dart 3.13 (`dailyobra_comum`, `dailyobra`, `dailyobra_parceiro`), `url_launcher` (novo no app do construtor), HTML + JS puro com `qrcode-generator` 1.4.4 guardado no repositório.

**Spec:** `docs/superpowers/specs/2026-11-02-checkout-bifurcado-design.md`

## Global Constraints

- Projeto Supabase `wlqtwaiqtwxmmndlunvh`; migração nova em `supabase/migrations/20261102200000_checkout_bifurcado.sql`, aplicada com `apply_migration` (nome `checkout_bifurcado`).
- Funções `security definer`, `set search_path = ''`, erros `raise exception '…' using errcode = 'P0001'` em português.
- Não muda `confirmar_pagamento`, `atualizar_pedido`, `responder_proposta` nem a regra do cashback (libera pago e entregue).
- Funções públicas (`anon`) só: `pedido_do_link`, `dados_do_pagador`, `avisar_pagamento`. Nenhuma devolve dados do construtor nem o documento.
- Link: `https://dailyobrabr-creator.github.io/dailyobra/pagar/?c={codigo}`; código aleatório de 22 caracteres URL-safe.
- Mensagem do WhatsApp, exata: `Olá, {nome}! Preparei os materiais da sua obra na {loja}: total {total}. Para pagar direto à loja por PIX e receber a nota no seu nome, abra: {link}` (`total` em `brl`).
- BR Code conforme a seção 5 da spec (59 até 25, 60 até 15, sem acento, maiúsculas; 62/05 = `DO` + 8 primeiros caracteres do id do pedido em maiúsculas; CRC16-CCITT-FALSE).
- Nunca rodar `dart format` em `dailyobra_comum` (estilo de linha longa); nos apps, `dart format lib test`.
- Testes de tela nos temas claro e escuro, como os atuais. Commits terminam com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Nenhuma chave secreta no repositório; a página usa só `SupabaseConfig.url` e `SupabaseConfig.publishableKey`.

## Review Focus

1. Loja com acento e nome longo (`Operário Construção e Acabamentos`, `Rondonópolis`): o BR Code sai sem acento e cortado em 25/15 — teste SQL em Task 1.
2. Totais como `1118.95`, `10000` e `0.5`: o campo 54 sai `1118.95`, `10000.00`, `0.50` — teste SQL em Task 1.
3. WhatsApp digitado com máscara ou com `+55` (`(66) 99999-0000`, `+55 66 99999-0000`): vira `5566999990000` no `wa.me`, sem `5555` — teste em Task 2.
4. Link antigo depois de "Trocar cliente", de pagamento confirmado ou de cancelamento: a página não mostra PIX e diz o porquê — testes SQL em Task 1 e conferência da página em Task 6.
5. CPF/CNPJ com pontuação (`529.982.247-25`, `11.222.333/0001-81`) aceito e gravado só com dígitos; repetidos (`111.111.111-11`) recusados — testes em Task 1 e Task 2.

---

### Task 1: Banco — colunas, funções, BR Code e testes SQL

**Files:**
- Create: `supabase/migrations/20261102200000_checkout_bifurcado.sql`
- Create: `supabase/tests/checkout_bifurcado_test.sql`

**Interfaces:**
- Produces (RPC):
  - `pagar_eu_mesmo(p_pedido uuid, p_documento text) returns void` — construtor do pedido.
  - `criar_link_pagamento(p_pedido uuid, p_nome text, p_whatsapp text) returns text` — devolve o código.
  - `pix_do_pedido(p_pedido uuid) returns text` — construtor do pedido ou membro da loja; `null` quando a loja não tem chave PIX. (Expõe o BR Code que a spec chama de interno, para o "Eu pago" e para reabrir a tela.)
  - `pedido_do_link(p_codigo text) returns jsonb` — `{loja:{nome,cidade,uf,whatsapp}, itens:[{nome,quantidade,unidade,preco,total}], desconto, frete, total, situacao, pagador_nome, documento_informado, pix}`; `pix` só quando `documento_informado` e a situação não é `pago`/`cancelado`.
  - `dados_do_pagador(p_codigo text, p_nome text, p_documento text) returns void`
  - `avisar_pagamento(p_codigo text) returns void`
- Produces (colunas): `lojas.chave_pix`, `profiles.documento`, `pedidos.pagador | pagador_nome | pagador_whatsapp | link_codigo | documento_informado_em | pagamento_informado_em`, tabela `pedido_documentos(pedido_id, documento)`.
- `situacao` (texto): `cancelado`, `pago`, `informado`, `aguardando_pagamento`, `aguardando_dados`, `sem_pagador` (ordem da spec, seção 3).

- [ ] **Step 1: Write the failing SQL test** `supabase/tests/checkout_bifurcado_test.sql` no padrão de `marketplace_test.sql` (begin; tabelas `r`/`v`; `pg_temp.conferir`, `pg_temp.como`, `pg_temp.admin`; usuários de teste; obra → orçamento → proposta → pedido inseridos como admin; loja A com `chave_pix = '+5566999990000'`, nome `Operário Construção e Acabamentos`, cidade `Rondonópolis`; loja B sem chave). Final em bloco `do` que faz `raise exception 'RESULTADO: % de % ok; falhas: %'` (assim tudo é desfeito pelo `execute_sql`). Verificações, com estes nomes:
  - `brcode do exemplo do BC` — para chave `123e4567-e12b-12d1-a456-426655440000`, nome `Fulano de Tal`, cidade `BRASILIA`, sem valor e txid `***`, o montador (`private.brcode(chave, nome, cidade, valor numeric, txid text)`) devolve `00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913FULANO DE TAL6008BRASILIA62070503***` + `6304` + CRC conferido no Step 2.
  - `brcode corta e tira acento` — loja A: campo 59 = `OPERARIO CONSTRUCAO E ACA`, campo 60 = `RONDONOPOLIS`.
  - `brcode formata o valor` — 1118.95 → `54071118.95`; 10000 → `540810000.00`; 0.5 → `54040.50`.
  - `link de quem não é dono` — outro construtor → erro `Pedido não encontrado.`
  - `link sem chave pix` — pedido da loja B → erro `A loja ainda não cadastrou a chave PIX.`
  - `link criado` — código com 22 caracteres; `pedidos.pagador = 'cliente'`; `pagador_whatsapp = '66999990000'` ao enviar `(66) 99999-0000`.
  - `página antes dos dados` — como `anon`: `situacao = 'aguardando_dados'`, `pix` nulo, JSON sem chave `construtor_id` nem documento.
  - `documento inválido` — `111.111.111-11` → erro `CPF ou CNPJ inválido. Confira os números.`
  - `dados do cliente gravados` — `529.982.247-25` → `pedido_documentos.documento = '52998224725'`; `documento_informado_em` preenchido; página com `situacao = 'aguardando_pagamento'` e `pix` começando por `000201`.
  - `documento só para a loja` — construtor vê 0 linhas em `pedido_documentos`; dono da loja A vê 1.
  - `aviso de pagamento` — `situacao = 'informado'`; chamar de novo não muda `pagamento_informado_em`.
  - `trocar cliente invalida o link` — novo `criar_link_pagamento`; código antigo → erro `Link inválido ou substituído.`; `pedido_documentos` sem linha; `documento_informado_em` nulo.
  - `eu pago sem nome no perfil` → erro `Complete seu nome no Perfil.`; com nome → `pagador = 'proprio'`, `link_codigo` nulo, `profiles.documento = '11222333000181'` (enviado `11.222.333/0001-81`).
  - `pix do pedido` — construtor recebe texto começando por `000201`; pedido da loja B → nulo.
  - `pago fecha a página` — após `confirmar_pagamento` (dono da loja A), `situacao = 'pago'`, `pix` nulo e `dados_do_pagador` → erro `Este pedido já foi pago.`
  - `chave pix validada` — `update lojas set chave_pix = '66999990000'` (11 dígitos, CPF inválido) falha; `'+5566999990000'`, `'52998224725'`, `'loja@exemplo.com'`, `'123e4567-e12b-12d1-a456-426655440000'` passam.

- [ ] **Step 2: Confirm the CRC of the BC example independently**

Run: `python -I -c "d=b'00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913FULANO DE TAL6008BRASILIA62070503***6304'; c=0xFFFF
for b in d:
  c^=b<<8
  for _ in range(8): c=((c<<1)^0x1021 if c&0x8000 else c<<1)&0xFFFF
print('%04X'%c)"`
Expected: 4 dígitos hexadecimais; usar esse valor no teste `brcode do exemplo do BC`.

- [ ] **Step 3: Run the test to verify it fails** — `execute_sql` com o conteúdo do arquivo.
Expected: erro na primeira chamada a uma função inexistente (`private.brcode` ou `criar_link_pagamento does not exist`).

- [ ] **Step 4: Write the migration** com: `private.cpf_valido(text)`, `private.documento_valido(text)` (11 dígitos → CPF, 14 → `private.cnpj_valido`), `private.so_digitos(text)`, `private.chave_pix_valida(text)` (CPF/CNPJ válidos só com dígitos, e-mail, `+55` + 10 ou 11 dígitos, UUID minúsculo), `private.sem_acento(text)` (`translate` de ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ e minúsculas), `private.crc16(text)`, `private.brcode(chave text, nome text, cidade text, valor numeric, txid text)`, `private.situacao_pagamento(public.pedidos)`; colunas e checks da Interfaces; `pedido_documentos` com RLS `for select to authenticated using (private.membro_loja((select loja_id from public.pedidos where id = pedido_id)) is not null)`; as seis funções públicas; `grant execute` de `pedido_do_link`, `dados_do_pagador`, `avisar_pagamento` para `anon, authenticated` e das demais só para `authenticated`; `revoke all on pedido_documentos from anon`. O código do link: `translate(encode(gen_random_bytes(17), 'base64'), '+/=', '-_')` cortado em 22.

- [ ] **Step 5: Apply the migration** — `apply_migration` (nome `checkout_bifurcado`) com o mesmo conteúdo do arquivo.
Expected: sucesso; `get_advisors` (security) sem alerta novo para as funções e a tabela criadas.

- [ ] **Step 6: Run the test to verify it passes** — `execute_sql` com o arquivo de teste.
Expected: erro `RESULTADO: N de N ok; falhas: ` com N ≥ 16 (um `conferir` por verificação acima, podendo dividir em mais) e lista de falhas vazia. Rodar também `supabase/tests/marketplace_test.sql` (com o mesmo final em bloco `do`) e esperar todos ok — nada antigo quebrou.

- [ ] **Step 7: Commit**
```bash
git add supabase/migrations/20261102200000_checkout_bifurcado.sql supabase/tests/checkout_bifurcado_test.sql
git commit -m "feat(banco): checkout bifurcado (link de pagamento, dados para a nota e PIX copia e cola)"
```

### Task 2: Comum — modelos, link e validações

**Files:**
- Create: `dailyobra_comum/lib/src/marketplace/pagamento.dart` (exportar em `lib/dailyobra_comum.dart`)
- Modify: `dailyobra_comum/lib/src/marketplace/propostas.dart` (`PedidoResumo`)
- Modify: `dailyobra_comum/lib/src/marketplace/modelos.dart` (`Loja.chavePix`)
- Test: `dailyobra_comum/test/pagamento_test.dart`

**Interfaces:**
- Consumes: colunas da Task 1.
- Produces:
  - `enum Pagador { proprio, cliente }` com `static Pagador? fromCodigo(String?)`.
  - `enum SituacaoPagamento { semPagador, aguardandoDados, aguardandoPagamento, informado, pago, cancelado }`.
  - `PedidoResumo` ganha `pagador`, `pagadorNome`, `pagadorWhatsapp`, `linkCodigo`, `documentoInformadoEm`, `pagamentoInformadoEm` e `SituacaoPagamento get situacaoPagamento` (mesma precedência da spec).
  - `Loja.chavePix` (`String?`, de `chave_pix`).
  - `String linkDePagamento(String codigo)`, `String mensagemDoLink({required String nome, required String loja, required double total, required String link})`, `Uri linkWhatsApp(String whatsapp, String mensagem)`, `String somenteDigitos(String)`, `bool documentoValido(String)`, `String? chavePixInvalida(String)` (`null` quando ok; senão `'Chave PIX inválida. Use CPF, CNPJ, e-mail, celular com +55 ou chave aleatória.'`).

- [ ] **Step 1: Write the failing tests** em `test/pagamento_test.dart`:
  - `PedidoResumo.fromJson lê o pagador` — JSON com `pagador: 'cliente'`, `pagador_nome: 'Ana'`, `link_codigo: 'abc'`, `documento_informado_em: null` → `situacaoPagamento == SituacaoPagamento.aguardandoDados`; com `documento_informado_em` → `aguardandoPagamento`; com `pagamento_informado_em` → `informado`; com `pagamento_confirmado_em` → `pago`; `status: 'cancelado'` → `cancelado`; sem pagador → `semPagador`.
  - `link e mensagem` — `linkDePagamento('xyz') == 'https://dailyobrabr-creator.github.io/dailyobra/pagar/?c=xyz'`; `mensagemDoLink(nome: 'Ana', loja: 'Taipa', total: 1234.5, link: 'L')` == `'Olá, Ana! Preparei os materiais da sua obra na Taipa: total R\$ 1.234,50. Para pagar direto à loja por PIX e receber a nota no seu nome, abra: L'` (comparar com `brl.format`).
  - `whatsapp com máscara ou +55` — `linkWhatsApp('(66) 99999-0000', 'oi').toString()` e `linkWhatsApp('+55 66 99999-0000', 'oi').toString()` ambos == `'https://wa.me/5566999990000?text=oi'`.
  - `documentos` — `documentoValido('529.982.247-25')`, `documentoValido('11.222.333/0001-81')` verdadeiros; `'111.111.111-11'`, `'123'` falsos.
  - `chave pix` — `null` para `'+5566999990000'`, `'52998224725'`, `'loja@exemplo.com'`, `'123e4567-e12b-12d1-a456-426655440000'`; mensagem para `'66999990000'` e `'loja@'`.
  - `Loja.fromJson lê a chave pix` — `chave_pix: '+5566999990000'` → `chavePix` igual.

- [ ] **Step 2: Run** `cd dailyobra_comum; flutter test test/pagamento_test.dart` — Expected: FAIL (símbolos inexistentes).
- [ ] **Step 3: Implement** os símbolos da Interfaces (validação de CPF/CNPJ com os mesmos dígitos verificadores do banco; `linkWhatsApp` acrescenta `55` só quando restam 10 ou 11 dígitos).
- [ ] **Step 4: Run** `flutter test` em `dailyobra_comum` — Expected: todos passam (os 157 antigos + os novos); `flutter analyze` sem avisos.
- [ ] **Step 5: Commit** — `feat(comum): pagador, situação do pagamento, link e validações`.

### Task 3: App do construtor — "Quem paga este pedido?" e CPF/CNPJ no perfil

**Files:**
- Create: `dailyobra/lib/screens/quem_paga.dart`
- Modify: `dailyobra/lib/screens/pedido_screen.dart` (inserir `QuemPaga` antes do resumo de pagamento, enquanto `situacaoPagamento` não for `pago`/`cancelado`)
- Modify: `dailyobra/lib/services/negociacao_service.dart` (colunas de `pedidos(...)` e três métodos)
- Modify: `dailyobra/lib/services/perfil_service.dart`, `dailyobra/lib/screens/perfil_screen.dart` (campo CPF ou CNPJ)
- Modify: `dailyobra/pubspec.yaml` (`url_launcher` com versão em circunflexo)
- Test: `dailyobra/test/quem_paga_test.dart`

**Interfaces:**
- Consumes: RPCs da Task 1; `PedidoResumo`, `SituacaoPagamento`, `linkDePagamento`, `mensagemDoLink`, `linkWhatsApp`, `documentoValido` da Task 2.
- Produces:
  - `NegociacaoService`: `Future<String?> pixDoPedido(String pedidoId)`, `Future<void> pagarEuMesmo(String pedidoId, String documento)`, `Future<String> criarLink(String pedidoId, {required String nome, required String whatsapp})`.
  - `PerfilService.documento` (`String?`) e `salvar(..., String? documento)`.
  - `QuemPaga({required PedidoResumo pedido, required String nomeLoja, required String? documentoDoPerfil, required Future<String?> Function() pix, required Future<void> Function(String documento) pagarEuMesmo, required Future<String> Function(String nome, String whatsapp) criarLink, required Future<void> Function(Uri) abrirLink})`.
- Textos: título `Quem paga este pedido?`; opções `Eu pago` e `Enviar para o cliente`; `PIX da loja (copia e cola)` + botão `Copiar` (SnackBar `PIX copiado`); sem chave: `Combine o pagamento com a loja.`; `Nome do cliente`, `WhatsApp do cliente`, botão `Enviar pelo WhatsApp`; situações: `Link enviado. Aguardando o cliente informar os dados.` / `Aguardando o pagamento do cliente.` / `O cliente avisou que pagou. A loja vai conferir.`; botões `Reenviar link` e `Trocar cliente`; opção desligada com `A loja ainda não cadastrou a chave PIX.`; campo `CPF ou CNPJ` com erro `CPF ou CNPJ inválido. Confira os números.`

- [ ] **Step 1: Write the failing widget tests** (claro e escuro), montando `QuemPaga` com funções falsas:
  - `eu pago pede o documento e mostra o pix` — sem documento no perfil: tocar `Eu pago` mostra `CPF ou CNPJ`; digitar `111.111.111-11` mostra o erro e não chama `pagarEuMesmo`; digitar `529.982.247-25` e confirmar chama `pagarEuMesmo('52998224725')` e depois exibe o texto do PIX e `Copiar`.
  - `enviar para o cliente abre o whatsapp` — preencher `Ana` e `(66) 99999-0000`, tocar `Enviar pelo WhatsApp` → `criarLink('Ana', '66999990000')` e `abrirLink` recebe `https://wa.me/5566999990000?text=` + mensagem com `linkDePagamento('COD')`.
  - `situações do link` — pedido com `aguardandoDados`, `aguardandoPagamento`, `informado` mostram os três textos; `Reenviar link` chama `abrirLink` sem `criarLink`.
  - `loja sem chave pix` — `pix` devolve `null`: `Enviar para o cliente` desligado com o aviso; `Eu pago` mostra `Combine o pagamento com a loja.`
  - `pedido pago esconde o bloco` — `PedidoScreen` de pedido com `pagamento_confirmado_em` não mostra `Quem paga este pedido?` (usar `definirParaTeste` do `NegociacaoService`, como em `orcamentos_test.dart`).
  - `perfil salva cpf ou cnpj` — em `carteira_perfil_test.dart`, o campo aparece e recusa `123`.
- [ ] **Step 2: Run** `cd dailyobra; flutter test test/quem_paga_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**: `flutter pub add url_launcher` e trocar a versão gravada por circunflexo; `abrirLink` padrão em `PedidoScreen` = `launchUrl(uri, mode: LaunchMode.externalApplication)`; `Clipboard.setData` no `Copiar`; métodos do serviço chamam as RPCs da Task 1 e recarregam como `_acao`.
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` em `dailyobra` — Expected: tudo verde (131 antigos + novos).
- [ ] **Step 5: Commit** — `feat(app): quem paga o pedido (eu pago ou link para o cliente)`.

### Task 4: Página do cliente

**Files:**
- Create: `dailyobra/web/pagar/index.html`
- Create: `dailyobra/web/pagar/qrcode.min.js` (de `https://cdnjs.cloudflare.com/ajax/libs/qrcode-generator/1.4.4/qrcode.min.js`, licença MIT no topo)

**Interfaces:**
- Consumes: `pedido_do_link`, `dados_do_pagador`, `avisar_pagamento` (Task 1) via `POST {SupabaseConfig.url}/rest/v1/rpc/{funcao}` com cabeçalhos `apikey` e `Content-Type: application/json`; erro do PostgREST traz `message`.
- Produces: página em `/pagar/?c={codigo}`.

- [ ] **Step 1: Download the QR library** para `dailyobra/web/pagar/qrcode.min.js` e conferir que começa pelo cabeçalho de licença e tem menos de 30 KB.
- [ ] **Step 2: Write `index.html`** (HTML + CSS + JS no mesmo arquivo, sem frameworks): lê `c` da URL; sem `c` ou erro `Link inválido ou substituído.` → tela "Link inválido"; carrega e mostra loja, itens (quantidade, unidade, preço, total), desconto quando houver, frete e total; situação `aguardando_dados` → formulário `Seu nome` + `CPF ou CNPJ` (validação igual à da Task 2) e botão `Continuar`; com `pix` → QR (`qrcode(0, 'M')`), texto copia e cola, botão `Copiar` e botão `Já paguei`; `informado` → `Pronto! A loja vai conferir o pagamento e confirmar.`; `pago` → `Pagamento confirmado pela loja.`; `cancelado` → `Este pedido foi cancelado.`; erros das funções aparecem em vermelho acima do botão. Visual: fundo claro, laranja `#F36E21`, fonte Inter (Google Fonts), coluna única até 480 px, sem rolagem lateral em 360 px. Constantes `SUPABASE_URL` e `SUPABASE_KEY` iguais às de `SupabaseConfig`.
- [ ] **Step 3: Check syntax** — `node --check` sobre o JS extraído, se o Node existir; senão, abrir o arquivo no navegador do app depois da publicação (Task 6).
- [ ] **Step 4: Commit** — `feat(web): página de pagamento do cliente`.

### Task 5: Parceiros — chave PIX e dados para a nota

**Files:**
- Modify: `dailyobra_parceiro/lib/screens/minha_loja_screen.dart` (campo `Chave PIX` entre WhatsApp e Endereço; salva `chave_pix` em `LojaService.atualizar`)
- Modify: `dailyobra_parceiro/lib/services/propostas_loja_service.dart` (colunas de `pedidos(...)`; `Future<String?> documentoDoPagador(String pedidoId)` lendo `pedido_documentos`)
- Modify: `dailyobra_parceiro/lib/screens/pedido_loja_screen.dart` (bloco "Dados para a nota" e aviso)
- Test: `dailyobra_parceiro/test/painel_test.dart`

**Interfaces:**
- Consumes: `Loja.chavePix`, `chavePixInvalida`, `PedidoResumo` (Task 2); `pedido_documentos` (Task 1).
- Textos: `Chave PIX` (ajuda `CPF, CNPJ, e-mail, celular com +55 ou chave aleatória`); bloco `Dados para a nota` com `Quem paga` = `O próprio construtor` ou `Cliente do construtor`, `Nome`, `CPF/CNPJ` (formatado `529.982.247-25` / `11.222.333/0001-81`), `WhatsApp`; sem pagador: `O construtor ainda não escolheu quem paga.`; aviso `Cliente informou o pagamento às {HH:mm}, confira no banco.` enquanto não confirmado.

- [ ] **Step 1: Write the failing widget tests** (claro e escuro): `minha loja salva a chave pix` (valor válido vai para `atualizar` como `{'chave_pix': '+5566999990000', ...}`; `66999990000` mostra o erro e não salva); `pedido mostra os dados para a nota` (pagador cliente, documento `52998224725` aparece `529.982.247-25`); `aviso de pagamento informado` (com `pagamento_informado_em` e sem confirmação, aparece o aviso com a hora; confirmado, some).
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/painel_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** os campos e blocos acima.
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` em `dailyobra_parceiro` — Expected: tudo verde (36 antigos + novos).
- [ ] **Step 5: Commit** — `feat(parceiros): chave PIX e dados para a nota`.

### Task 6: Publicação e conferência de ponta a ponta

**Files:**
- Modify: `README.md` (seção curta "Pagamento pelo cliente (link PIX)": como funciona e onde a loja cadastra a chave)

**Interfaces:**
- Consumes: tudo acima.

- [ ] **Step 1: Run all suites** — `flutter analyze` e `flutter test` nos três pacotes; `execute_sql` dos dois testes SQL. Expected: tudo verde.
- [ ] **Step 2: Merge and push** — merge do branch no `main` e `git push origin main` (aprovado no desenho); esperar o workflow do GitHub Pages terminar com `success`.
- [ ] **Step 3: Check the page** no navegador do app: `/pagar/?c=invalido` mostra "Link inválido". Criar com `execute_sql` uma loja temporária `Loja Teste DailyObra` (CNPJ de teste válido, chave PIX `+5566999990000`) com um pedido de teste — sem tocar nas lojas reais — gerar o link, abrir a página, informar `529.982.247-25`, conferir QR + copia e cola, tocar `Já paguei`, conferir o estado `informado`; depois apagar o pedido de teste e tudo o que ele criou.
- [ ] **Step 4: Rebuild the APKs** (`flutter build apk --release` nos dois apps pelo terminal) e copiar para `apk\DailyObra.apk` e `apk\DailyObraParceiros.apk`.
- [ ] **Step 5: Commit** o README e enviar (`docs: pagamento pelo cliente`).
