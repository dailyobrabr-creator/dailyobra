# DailyObra Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar o DailyObra num marketplace da construção com dois apps Flutter (construtor e DailyObra Parceiros) sobre o mesmo Supabase, com cotação entre lojas, negociação de propostas, pedidos e cashback.

**Architecture:** Pacote Dart `dailyobra_comum` com tema claro/escuro, componentes, modelos, motor de orçamento, Smart List e cotação (funções puras e testadas). Dois apps finos (`dailyobra`, `dailyobra_parceiro`) só com telas e serviços de acesso. Toda regra de dinheiro e estado (preços, negociação, pedido, carteira) fica em funções `security definer` no Postgres, com RLS em todas as tabelas.

**Tech Stack:** Flutter 3.47 / Dart 3.13, supabase_flutter 2.18, google_fonts 8.0.0, intl, shared_preferences, image_picker (só no Parceiros), Postgres 17 no Supabase (projeto `wlqtwaiqtwxmmndlunvh`).

**Spec:** `docs/superpowers/specs/2026-10-31-marketplace-design.md`

## Global Constraints

- Pastas: `D:\dev\dailyobra_app\dailyobra_comum`, `D:\dev\dailyobra_app\dailyobra`, `D:\dev\dailyobra_app\dailyobra_parceiro`; migrações em `D:\dev\dailyobra_app\supabase\migrations`.
- IDs: `com.dailyobra.dailyobra` (DailyObra) e `com.dailyobra.parceiros` (DailyObra Parceiros); esquemas de link `dailyobra://login` e `dailyobraparceiros://login`.
- `google_fonts` fixo em `8.0.0` (a 9.x usa `material_ui` e quebra o `TextTheme`). `Supabase.initialize` usa `publishableKey`.
- `android/gradle.properties` dos dois apps: as opções `-Djavax.net.ssl.trustStore=C:/Users/luizh/.gradle/dailyobra-certificados.jks -Djavax.net.ssl.trustStorePassword=changeit` em `org.gradle.jvmargs`, mais `kotlin.incremental=false` e `kotlin.incremental.useClasspathSnapshot=false`.
- Builds Android rodam no painel de Terminal do usuário (fora do sandbox). Emulador: `emulator -avd Pixel_7 -no-snapshot-load -memory 4096`. Não usar `adb` do sandbox enquanto um `flutter run` estiver conectando.
- Texto de interface em português, frase com só a primeira letra maiúscula, sem caixa alta. Valores em R$ com `NumberFormat.currency(locale: 'pt_BR')` e algarismos tabulares.
- Dinheiro no banco em `numeric(12,2)`, quantidades em `numeric(12,3)`. O app nunca envia preço: o servidor lê das `ofertas`.
- Erros de regra das funções: `raise exception '<mensagem em português>' using errcode = 'P0001'`. O app mostra `PostgrestException.message` quando `code == 'P0001'`, senão uma mensagem genérica de conexão.
- Cashback: tier 1 = 0,01; 2 = 0,02; 3 = 0,03; 4 = 0,05. Validade da resposta da loja: 48 h. Validade da contraproposta: 24, 48 ou 72 h.
- Sem foto inventada: produto sem imagem mostra o quadro da categoria.
- Contraste mínimo 4,5:1 nos dois temas. Cores escuras: fundo #141519, superfícies #1C1E23 e #24272E, borda #343741, texto #F2F3F5 e #A8ACB6, botão #F36E21 com texto #1A0F07.
- A pasta não é repositório Git: no lugar de cada "commit", o checkpoint é `flutter analyze` sem problemas e os testes do pacote passando.

## Review Focus

1. Linha estranha na Smart List (vazia, só número, emoji, "1/2 saco", "1.000 tijolos", texto enorme) → não quebra; quantidade lida de forma sensata ou linha marcada como não reconhecida. Teste na Task 6.
2. Preço mudou ou promoção venceu entre a prévia e o envio → o servidor usa o preço atual e o app avisa "Os preços foram atualizados pelas lojas". Teste SQL na Task 5 e teste do serviço na Task 10.
3. Loja responde depois que o construtor cancelou ou a proposta expirou, ou duas respostas chegam juntas → a segunda é recusada com mensagem e nunca nascem dois pedidos (`for update` na proposta). Teste SQL na Task 5.
4. Mesmo saldo usado em duas cotações seguidas → a segunda reserva só o que sobrou, e o saldo disponível nunca fica negativo. Teste SQL na Task 5.
5. Cidade sem lojas, loja sem ofertas, categoria vazia, catálogo sem resultado na busca → estados vazios com orientação, nunca tela em branco nem erro. Testes de widget nas Tasks 9 e 13.

---

### Task 1: Pacote comum e reorganização

**Files:**
- Create: `dailyobra_comum/pubspec.yaml`, `dailyobra_comum/lib/dailyobra_comum.dart`, `dailyobra_comum/analysis_options.yaml`
- Move para `dailyobra_comum/lib/src/`: `orcamento/*` (motor e dados gerados), `models/obra.dart` → `obras/obra.dart`, `widgets/ui.dart` → `ui/ui.dart`, `widgets/faixa_obra.dart`, `widgets/resultado.dart`, `widgets/parametros_form.dart` → `ui/`, `theme/app_theme.dart` → `tema/tema.dart`, `services/supabase_config.dart`, `services/auth_service.dart` → `supabase/`, `screens/login_screen.dart` e `nova_senha_screen.dart` → `auth/`
- Move: `assets/marca/` → `dailyobra_comum/assets/marca/`; testes `orcamento_test`, `materiais_test`, `obra_test` → `dailyobra_comum/test/`
- Modify: imports de todo `dailyobra/lib` e `dailyobra/test/telas_test.dart`; `dailyobra/pubspec.yaml` (dependência `dailyobra_comum: {path: ../dailyobra_comum}`)
- Create: `D:\dev\dailyobra_app\.vscode\launch.json` com "DailyObra" (`cwd: dailyobra`) e "DailyObra Parceiros" (`cwd: dailyobra_parceiro`)

**Interfaces:**
- Produces: `package:dailyobra_comum/dailyobra_comum.dart` exporta tudo o que foi movido, com os nomes atuais (`AppColors`, `AppTheme`, `Painel`, `Selo`, `Aviso`, `Segmentado`, `CampoTexto`, `FaixaObra`, `calcularOrcamento`, `listarMateriais`, `ParametrosObra`, `Obra`, `AuthService`, `SupabaseConfig`, `LoginScreen`, `NovaSenhaScreen`). Assets referenciados com `package: 'dailyobra_comum'`.
- `SupabaseConfig.linkRetorno` passa a ser parâmetro de `AuthService.configurar(String linkRetorno)`, chamado no `main` de cada app.

- [ ] **Step 1:** Mover arquivos, criar `pubspec.yaml` do pacote (flutter, supabase_flutter ^2.18.3, google_fonts 8.0.0, intl ^0.20.3, flutter_localizations) e o arquivo de exportação.
- [ ] **Step 2:** Rodar `flutter pub get` em `dailyobra_comum` e `dailyobra`; `flutter clean` em `dailyobra` (caminhos antigos no `build`).
- [ ] **Step 3:** Rodar `flutter test` em `dailyobra_comum`. Esperado: os 22 testes de motor e obra passam.
- [ ] **Step 4:** Rodar `flutter analyze` e `flutter test` em `dailyobra`. Esperado: nenhum problema; os 10 testes de tela passam.

### Task 2: Tema claro e escuro

**Files:**
- Modify: `dailyobra_comum/lib/src/tema/tema.dart`
- Create: `dailyobra_comum/lib/src/tema/cores.dart`, `dailyobra_comum/lib/src/tema/preferencia_tema.dart`
- Test: `dailyobra_comum/test/tema_test.dart`

**Interfaces:**
- Produces: `class CoresDailyObra extends ThemeExtension<CoresDailyObra>` com `fundo, superficie, superficieElevada, borda, texto, textoSuave, acao, textoSobreAcao, acento, sucesso, aviso, erro, info, segPrevista, segNeutra, hachuraLaranja, hachuraVermelha`; `extension CoresContexto on BuildContext { CoresDailyObra get cores; }`; `AppTheme.claro([TextTheme? base])`, `AppTheme.escuro([TextTheme? base])`; `class PreferenciaTema extends ValueNotifier<ThemeMode>` com `static Future<PreferenciaTema> carregar()` e `Future<void> definir(ThemeMode)` (shared_preferences, chave `dailyobra.tema`).
- Todos os widgets do pacote passam a ler `context.cores` em vez de `AppColors` fixo. `AppColors` continua como as constantes do tema claro.

- [ ] **Step 1: Teste que falha**

```dart
test('contraste do texto nos dois temas é pelo menos 4,5:1', () {
  for (final c in [CoresDailyObra.claro, CoresDailyObra.escuro]) {
    expect(contraste(c.texto, c.fundo), greaterThanOrEqualTo(4.5));
    expect(contraste(c.textoSuave, c.superficie), greaterThanOrEqualTo(4.5));
    expect(contraste(c.textoSobreAcao, c.acao), greaterThanOrEqualTo(4.5));
  }
});
```
(`double contraste(Color a, Color b)` pela fórmula WCAG de luminância relativa, exportada de `cores.dart`.)
- [ ] **Step 2:** Rodar `flutter test test/tema_test.dart`. Esperado: FAIL (`CoresDailyObra` não existe).
- [ ] **Step 3:** Implementar `cores.dart`, `AppTheme.claro/escuro` e `PreferenciaTema`, e trocar as cores fixas dos widgets do pacote por `context.cores`.
- [ ] **Step 4:** Rodar os testes do pacote e os de tela do `dailyobra` com `theme: AppTheme.claro(base)` e `darkTheme: AppTheme.escuro(base)`. Esperado: PASS.

### Task 3: Banco base do marketplace

**Files:**
- Create: `supabase/migrations/20261031130000_marketplace_base.sql`

**Interfaces:**
- Produces: as tabelas da seção 8 do spec com os nomes e colunas de lá, mais `profiles.cidade text`, `profiles.uf char(2)` e `profiles.tema text`; funções auxiliares `private.membro_loja(p_loja uuid) returns text` (papel ou null) e `private.pode_gerir_loja(p_loja uuid) returns boolean` (dono ou gerente); bucket `lojas` público com políticas de escrita por `private.pode_gerir_loja((storage.foldername(name))[1]::uuid)`; `propostas` e `pedidos` na publicação `supabase_realtime`.
- Checks: `status` de `propostas` em ('enviada','contraproposta','aceita','recusada','cancelada','expirada'); de `pedidos` em ('confirmado','em_separacao','saiu_entrega','entregue','cancelado'); `tier_cashback between 1 and 4`; `preco > 0`; `preco_promocional < preco`; `frete_fixo >= 0`; `cnpj ~ '^\d{14}$'`.
- RLS como na seção 8: leitura pública (logados) de catálogo, categorias, tiers, lojas ativas e ofertas não pausadas de lojas ativas; escrita de ofertas e da própria loja por `pode_gerir_loja`; nenhuma política de insert/update/delete em `orcamentos`, `propostas`, `proposta_itens`, `proposta_eventos`, `pedidos`, `pedido_eventos`, `carteira_lancamentos`.

- [ ] **Step 1:** Escrever a migração e aplicar com `apply_migration` (nome `marketplace_base`).
- [ ] **Step 2:** Rodar `get_advisors` de segurança. Esperado: nenhum alerta novo.
- [ ] **Step 3:** Teste SQL em transação desfeita: como `anon`, nenhuma leitura nas tabelas novas; como `authenticated` sem loja, insert em `ofertas`, `propostas` e `carteira_lancamentos` é bloqueado (42501).

### Task 4: Catálogo inicial

**Files:**
- Create: `supabase/migrations/20261031130100_catalogo_inicial.sql`
- Create: `dailyobra_comum/tool/catalogo_inicial.dart` (fonte única dos produtos, gera o SQL)

**Interfaces:**
- Produces: 10 categorias (Básico, Estrutura, Alvenaria, Cobertura, Hidráulica, Elétrica, Acabamento, Pintura, Louças e metais, Ferramentas); cerca de 90 `catalogo_itens` com `id` texto estável (ex.: `cimento-cp2-50kg`), unidade comercial e sinônimos; `catalogo_planilha` cobrindo todos os 109 itens das planilhas (os que não são produto de loja ficam ligados a `null`); `cashback_tiers` com os quatro percentuais.
- Níveis: Básico, Estrutura e Alvenaria = 1; Hidráulica e Elétrica = 2; Cobertura, Pintura e Ferramentas = 3; Acabamento e Louças e metais = 4.

- [ ] **Step 1:** Escrever `catalogo_inicial.dart` com a lista e um teste `catalogo_inicial_test.dart`: ids únicos, todo item tem categoria válida e ao menos um sinônimo, e todos os 109 nomes da planilha (`materiaisPorPadrao`) aparecem no mapeamento.
- [ ] **Step 2:** Rodar o teste. Esperado: PASS.
- [ ] **Step 3:** Gerar o SQL com `dart run tool/catalogo_inicial.dart > ../supabase/migrations/20261031130100_catalogo_inicial.sql` e aplicar (nome `catalogo_inicial`).
- [ ] **Step 4:** Conferir com `execute_sql`: contagem de categorias = 10, itens entre 85 e 95, planilha = 109, tiers = 4.

### Task 5: Funções de negociação, pedido e carteira

**Files:**
- Create: `supabase/migrations/20261031130200_marketplace_funcoes.sql`
- Create: `supabase/tests/marketplace_test.sql`

**Interfaces:**
- Produces (todas `security definer`, `search_path = ''`, `execute` só para `authenticated`):
  - `public.criar_loja(p jsonb) returns uuid`
  - `public.enviar_cotacao(p_itens jsonb, p_modo text, p_obra uuid, p_usar_saldo boolean, p_mensagem text) returns jsonb` → `{orcamento_id, propostas:[{id, loja_id, total}], precos_atualizados: bool}`
  - `public.responder_proposta(p_proposta uuid, p_acao text, p_precos jsonb, p_desconto numeric, p_mensagem text, p_motivo text, p_validade_horas int) returns text` (novo status)
  - `public.decidir_contraproposta(p_proposta uuid, p_aceitar boolean) returns text`
  - `public.cancelar_proposta(p_proposta uuid) returns text`
  - `public.atualizar_pedido(p_pedido uuid, p_status text) returns text`
  - `public.confirmar_pagamento(p_pedido uuid) returns void`
  - `public.expirar_propostas() returns int` (chamada no início de cada função acima e pelas telas)
  - visão `public.carteira_saldos(construtor_id, disponivel, pendente, reservado)` com `security_invoker`
- `enviar_cotacao` recebe `p_itens` como `[{item_id, loja_id, quantidade}]` e devolve `precos_atualizados = true` quando o cliente mandou `preco_visto` diferente do vigente (o campo `preco_visto` é opcional e só serve para esse aviso).

- [ ] **Step 1: Testes SQL que falham** (`marketplace_test.sql`, tudo em `begin … rollback`, usuários de teste inseridos em `auth.users` dentro da transação, resultados numa tabela temporária e `select` final). Casos, com o resultado esperado:
  - loja A envia contraproposta numa proposta da loja B → erro P0001
  - construtor cota 10 sacos a R$ 40,00 e a loja aumenta para R$ 45,00 antes do envio → proposta com `subtotal_anunciado = 450.00` e `precos_atualizados = true`
  - contraproposta com preço maior que o anunciado → erro P0001
  - `decidir_contraproposta` numa proposta `enviada` → erro P0001
  - aceitar duas vezes a mesma proposta (segunda chamada) → erro P0001 e 1 pedido só
  - responder proposta cancelada ou com `valida_ate` vencida → erro P0001 e status `expirada`
  - saldo disponível R$ 30,00, duas cotações com `usar_saldo` → reservas somam R$ 30,00 e `disponivel` = 0
  - recusa devolve a reserva → `disponivel` volta ao valor anterior
  - pedido aceito de R$ 1.000,00 em itens tier 4 → lançamento `pendente` de R$ 50,00
  - `entregue` sem pagamento → `disponivel` não muda; depois de `confirmar_pagamento` → `disponivel` +50,00
  - vendedor chama `confirmar_pagamento` → erro P0001
  - loja abaixo do pedido mínimo → erro P0001 com o valor mínimo na mensagem
  - pedido cancelado pela loja em `em_separacao` → cashback pendente estornado
- [ ] **Step 2:** Rodar o script com `execute_sql` antes da migração. Esperado: falha (funções inexistentes).
- [ ] **Step 3:** Escrever as funções e aplicar a migração (nome `marketplace_funcoes`). Transições exatamente como na seção 9 do spec; `select … for update` na proposta e nos saldos.
- [ ] **Step 4:** Rodar o script de novo. Esperado: todas as linhas com `ok = true`.
- [ ] **Step 5:** `get_advisors` de segurança e de desempenho sem alertas novos de nível WARN.

### Task 6: Modelos do marketplace e Smart List

**Files:**
- Create: `dailyobra_comum/lib/src/marketplace/modelos.dart`, `dailyobra_comum/lib/src/marketplace/smart_list.dart`, `dailyobra_comum/lib/src/marketplace/texto.dart`
- Test: `dailyobra_comum/test/smart_list_test.dart`

**Interfaces:**
- Produces (`modelos.dart`): `Categoria{id, nome, ordem}`, `ItemCatalogo{id, nome, unidade, categoriaId, tier, sinonimos, imagemUrl?}`, `Loja{id, nome, descricao, logoUrl?, capaUrl?, whatsapp, cidade, uf, freteFixo, pedidoMinimo, aberta, nova}`, `enum Disponibilidade{disponivel, sobConsulta, semEstoque}`, `Oferta{lojaId, itemId, preco, precoPromocional?, promoAte?, disponibilidade, pausada}` com `double? precoVigente(DateTime hoje)` (null se pausada ou sem estoque), `enum ModoProposta{negociacao, pedido}`, `enum StatusProposta{enviada, contraproposta, aceita, recusada, cancelada, expirada}`, `enum StatusPedido{confirmado, emSeparacao, saiuEntrega, entregue, cancelado}` (cada enum com `codigo` do banco e `rotulo` em português) e `fromJson` em todos.
- Produces (`texto.dart`): `String normalizar(String)` (minúsculas, sem acento, espaços simples, mantém `5/16`, `2,5mm`, `50kg`).
- Produces (`smart_list.dart`): `enum TipoLinha{reconhecido, escolher, naoReconhecido}`; `class LinhaSmartList{String original; double quantidade; String? unidadeFalada; TipoLinha tipo; ItemCatalogo? item; List<ItemCatalogo> candidatos}`; `List<LinhaSmartList> interpretarLista(String texto, List<ItemCatalogo> catalogo)`; `Map<String, double> somarPorItem(List<LinhaSmartList>)`.
- Regra de decisão: pontuação = termos em comum (medidas valem 3, demais 1); `reconhecido` se a maior pontuação ≥ 2 e supera a segunda em pelo menos 2; `escolher` se ≥ 2 sem essa folga (até 3 candidatos); senão `naoReconhecido`.

- [ ] **Step 1: Testes que falham**, com um catálogo de teste de 6 itens (cimento 50 kg, areia média m³, vergalhão 5/16 barra 12 m, vergalhão 3/8, cabo flexível 2,5 mm rolo 100 m, tijolo 8 furos):
  - `'100 sacos de cimento itaú'` → reconhecido cimento, quantidade 100
  - `'20 barras ferro 5/16'` → reconhecido vergalhão 5/16, 20
  - `'5 rolos fio 2,5mm'` → reconhecido cabo 2,5, 5
  - `'cimento 50 sacos'` → 50 (o "50" de "50kg" no nome não conta como quantidade quando vem depois da palavra)
  - `'areia 3 m3'` → 3; `'- tijolo 8 furos'` → 1; `'1.000 tijolos'` → 1000; `'2,5 m³ de areia'` → 2.5; `'1/2 saco cimento'` → 0.5 (fração só conta como quantidade no começo da linha; `5/16` no meio é medida)
  - `'ferro'` → escolher com os dois vergalhões
  - `'parafuso sextavado'` → naoReconhecido; `''`, `'   '`, `'🙂'` → ignoradas (sem linha)
  - linha de 2.000 caracteres → não lança exceção
  - `somarPorItem` de `'10 sacos cimento\n5 cimento'` → `{cimento: 15}`
- [ ] **Step 2:** Rodar `flutter test test/smart_list_test.dart`. Esperado: FAIL.
- [ ] **Step 3:** Implementar `texto.dart`, `modelos.dart` e `smart_list.dart`.
- [ ] **Step 4:** Rodar o teste. Esperado: PASS.

### Task 7: Cotação

**Files:**
- Create: `dailyobra_comum/lib/src/marketplace/cotacao.dart`
- Test: `dailyobra_comum/test/cotacao_test.dart`

**Interfaces:**
- Consumes: modelos da Task 6.
- Produces: `class ItemDesejado{String itemId; double quantidade; String? lojaFixada}`; `enum ModoCotacao{menorPrecoGlobal, melhorPorLoja}`; `class LinhaCotada{ItemCatalogo item; double quantidade; Oferta oferta; double precoUnitario; double total; double cashback; bool sobConsulta}`; `class GrupoLoja{Loja loja; List<LinhaCotada> linhas; double subtotal; double frete; bool abaixoMinimo; double get total}`; `class ResultadoCotacao{List<GrupoLoja> grupos; List<ItemCatalogo> semOferta; double get total; double get cashbackPrevisto}`; `ResultadoCotacao cotar({required List<ItemDesejado> itens, required Map<String, ItemCatalogo> catalogo, required List<Oferta> ofertas, required Map<String, Loja> lojas, required ModoCotacao modo, required DateTime hoje, required Map<int, double> percentualPorTier, String? cidade})`.

- [ ] **Step 1: Testes que falham** (3 lojas, 3 itens):
  - menor preço global põe tijolo na loja A, argamassa na B e cimento na C quando cada uma é a mais barata naquele item
  - item com `lojaFixada` fica na loja fixada mesmo não sendo a mais barata
  - promoção com `promoAte` ontem usa o preço cheio; com `promoAte` hoje usa o promocional
  - oferta pausada ou `semEstoque` é ignorada; `sobConsulta` entra com `sobConsulta = true`
  - empate de preço vai para a loja da mesma `cidade`, depois para o menor frete
  - melhor por loja escolhe a que atende mais itens; com empate, a de menor total com frete
  - frete entra uma vez por loja; `abaixoMinimo` quando o subtotal é menor que `pedidoMinimo`
  - cashback de R$ 1.000,00 em item tier 4 = 50,00; o frete não gera cashback
  - item sem oferta em nenhuma loja vai para `semOferta` e fica fora do total
- [ ] **Step 2:** Rodar o teste. Esperado: FAIL.
- [ ] **Step 3:** Implementar `cotar`.
- [ ] **Step 4:** Rodar o teste. Esperado: PASS.

### Task 8: Utilidades comuns (CNPJ, erros do servidor, imagem de produto)

**Files:**
- Create: `dailyobra_comum/lib/src/marketplace/cnpj.dart`, `dailyobra_comum/lib/src/supabase/erros.dart`, `dailyobra_comum/lib/src/ui/marketplace_ui.dart`
- Test: `dailyobra_comum/test/cnpj_test.dart`, `dailyobra_comum/test/marketplace_ui_test.dart`

**Interfaces:**
- Produces: `bool cnpjValido(String)`, `String formatarCnpj(String)`; `String mensagemDoServidor(Object erro)` (P0001 → mensagem do servidor; `SocketException`/`ClientException` → "Sem conexão. Verifique a internet e tente de novo."; demais → "Não foi possível concluir agora. Tente de novo."); widgets `ImagemProduto(item, {tamanho})` (quadro com ícone da categoria quando `imagemUrl` é null), `CartaoProduto`, `CartaoLoja`, `ChipCategoria`, `PrecoOferta` (cheio riscado + promocional), `RodapeTotal(total, cashback, acoes)`, `EstadoVazio(titulo, texto, acao?)`.

- [ ] **Step 1:** Testes que falham: `cnpjValido('11.222.333/0001-81')` true, `'11222333000180'` false, `'00000000000000'` false; `CartaoProduto` e `RodapeTotal` em 360 px nos temas claro e escuro, sem overflow, com nome de produto de 80 caracteres.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar. Esperado: PASS.

### Task 9: DailyObra: serviços e Início

**Files:**
- Create: `dailyobra/lib/services/catalogo_service.dart`, `dailyobra/lib/services/carrinho_service.dart`, `dailyobra/lib/services/perfil_service.dart`
- Create: `dailyobra/lib/screens/inicio_screen.dart` (substitui o atual), `dailyobra/lib/screens/busca_screen.dart`, `dailyobra/lib/screens/categoria_screen.dart`, `dailyobra/lib/screens/loja_screen.dart`, `dailyobra/lib/screens/produto_screen.dart`, `dailyobra/lib/screens/smart_list_screen.dart`
- Test: `dailyobra/test/inicio_test.dart`

**Interfaces:**
- Consumes: modelos, `interpretarLista`, componentes da Task 8.
- Produces: `CatalogoService.instance` (`ChangeNotifier`) com `Future<void> carregar()`, `List<Categoria> categorias`, `List<ItemCatalogo> itens`, `List<Loja> lojas` (cidade do perfil primeiro), `List<Oferta> ofertas`, `List<(Oferta, ItemCatalogo, Loja)> ofertasEmPromocao(DateTime)`, `List<(Oferta, Loja)> precosDoItem(String itemId)`, `Map<int, double> percentualPorTier` (de `cashback_tiers`), `Map<String, String> planilhaParaItem` (de `catalogo_planilha`, chave `"<nome>|<unidade>"`), `String? erro` (falha de carga mantém os dados anteriores e as telas mostram a faixa "Sem conexão. Mostrando os dados carregados por último."), e `@visibleForTesting definirParaTeste(...)`; `CarrinhoService.instance` com `List<ItemDesejado> itens`, `adicionar(itemId, quantidade, {lojaFixada})`, `alterarQuantidade`, `fixarLoja`, `remover`, `limpar`, `substituirPor(Map<String,double>)`, persistido em shared_preferences na chave `dailyobra.carrinho.v1`; `PerfilService.instance` com `nome`, `empresa`, `cidade`, `uf` e `Future<void> salvar(...)`.
- Início: saudação, banner do Clube (lê `carteira_saldos`), Smart List com "Cotar agora" → `SmartListScreen` (linhas reconhecidas, escolher, não reconhecidas) → "Adicionar ao orçamento", categorias, ofertas, lojas, busca.

- [ ] **Step 1:** Testes de widget que falham: Início com 2 lojas e 3 ofertas mostra "Ofertas" e as lojas; Início sem lojas mostra o estado vazio "Ainda não há lojas na sua cidade"; Smart List com `'100 sacos de cimento\nparafuso sextavado'` mostra 1 reconhecido e 1 "Não reconhecido"; produto com 3 lojas lista do menor para o maior preço; tudo em 360 px, claro e escuro.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar serviços e telas.
- [ ] **Step 4:** Rodar. Esperado: PASS; `flutter analyze` sem problemas.

### Task 10: DailyObra: Orçamentos, propostas e pedidos

**Files:**
- Create: `dailyobra/lib/services/negociacao_service.dart`
- Create: `dailyobra/lib/screens/orcamentos_screen.dart`, `dailyobra/lib/screens/proposta_screen.dart`, `dailyobra/lib/screens/pedido_screen.dart`
- Test: `dailyobra/test/orcamentos_test.dart`

**Interfaces:**
- Consumes: `cotar`, `CarrinhoService`, `CatalogoService`, `mensagemDoServidor`.
- Produces: `NegociacaoService.instance` com `Future<ResultadoEnvio> enviar({required ModoProposta modo, required ResultadoCotacao cotacao, required bool usarSaldo, String? mensagem, String? obraId})` (chama `enviar_cotacao`, manda `preco_visto` de cada linha; `ResultadoEnvio{String orcamentoId; bool precosAtualizados}`), `List<PropostaResumo> propostas`, `List<PedidoResumo> pedidos`, `aceitarContraproposta(id)`, `recusarContraproposta(id)`, `cancelar(id)`, `cancelarPedido(id)`, e assinatura em tempo real de `propostas` e `pedidos` que recarrega a lista.
- Tela Orçamentos: abas "Cotação" e "Enviados"; alternância Menor preço global / Melhor por loja; grupos por loja; rodapé com total, cashback e o interruptor de saldo; botões Proposta e Fechar pedido (desabilitados com o motivo quando há loja abaixo do mínimo ou carrinho vazio).

- [ ] **Step 1:** Testes que falham: cotação de 3 itens em 3 lojas mostra 3 grupos e o total certo; trocar para Melhor por loja mostra 1 grupo e os itens "Sem oferta nesta loja"; loja abaixo do mínimo desabilita Fechar pedido com o texto do mínimo; `precosAtualizados = true` mostra "Os preços foram atualizados pelas lojas"; detalhe de contraproposta mostra anunciado × ofertado e os botões Aceitar/Recusar; pedido `saiuEntrega` mostra os 4 passos com o terceiro marcado.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar. Esperado: PASS.

### Task 11: DailyObra: Carteira, Perfil, obras e navegação

**Files:**
- Create: `dailyobra/lib/services/carteira_service.dart`, `dailyobra/lib/screens/carteira_screen.dart`, `dailyobra/lib/screens/perfil_screen.dart`, `dailyobra/lib/screens/navegacao_screen.dart`
- Modify: `dailyobra/lib/screens/obra_screen.dart` (botão "Cotar materiais desta obra"), `dailyobra/lib/main.dart` (tema, `PreferenciaTema`, abas Início · Orçamentos · Carteira · Perfil), `dailyobra/lib/screens/obras_screen.dart` (vira tela aberta pelo Perfil)
- Test: `dailyobra/test/carteira_perfil_test.dart`

**Interfaces:**
- Produces: `CarteiraService.instance` com `disponivel`, `pendente`, `reservado` (de `carteira_saldos`) e `List<Lancamento> extrato` (`Lancamento{descricao, loja?, tier?, valor, conta, data}`); `Map<String,double> materiaisDaObraNoCatalogo(ResultadoMateriais, Map<String,String> planilhaParaItem)` em `dailyobra_comum` (soma quantidades por item do catálogo, ignora os sem ligação).

- [ ] **Step 1:** Testes que falham: carteira com disponível 125,50 e pendente 50,00 mostra os dois e o botão Sacar desabilitado com "Em breve"; `materiaisDaObraNoCatalogo` da casa de referência econômica soma o cimento de todas as etapas num item só; Perfil troca o tema para Escuro e o `MaterialApp` passa a `ThemeMode.dark`.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar todos os testes do `dailyobra`. Esperado: PASS; `flutter analyze` sem problemas.

### Task 12: DailyObra Parceiros: projeto, login e cadastro da loja

**Files:**
- Create via `flutter create --org com.dailyobra --project-name dailyobra_parceiro --platforms android,ios dailyobra_parceiro` e depois ajustar `applicationId`/`namespace` para `com.dailyobra.parceiros`, `android:label="DailyObra Parceiros"`, `CFBundleDisplayName`, esquema `dailyobraparceiros://login`, `INTERNET`, `enableOnBackInvokedCallback`, `gradle.properties` (Global Constraints), ícone (capacete sobre #565966) com `flutter_launcher_icons`
- Create: `dailyobra_parceiro/lib/main.dart`, `dailyobra_parceiro/lib/services/loja_service.dart`, `dailyobra_parceiro/lib/screens/cadastro_loja_screen.dart`
- Test: `dailyobra_parceiro/test/cadastro_test.dart`

**Interfaces:**
- Consumes: `LoginScreen`, `AuthService`, tema, `cnpjValido`, `mensagemDoServidor`.
- Produces: `LojaService.instance` com `Loja? minhaLoja`, `String? meuPapel`, `Future<void> carregar()`, `Future<String> criar(Map<String, dynamic>)` (RPC `criar_loja`), `Future<void> atualizar(Map<String, dynamic>)`, `Future<String> enviarImagem(XFile, {required bool capa})` (reduz para 1600 px, JPEG, até 2 MB, caminho `lojas/{id}/logo.jpg` ou `capa.jpg`, devolve URL pública com `?v=<timestamp>`).
- Fluxo do `main`: sem sessão → `LoginScreen`; com sessão e sem loja → `CadastroLojaScreen`; com loja → navegação (Task 13).

- [ ] **Step 1:** Teste que falha: cadastro com CNPJ inválido mostra "CNPJ inválido" e não chama o serviço; com todos os campos válidos chama `criar` com o CNPJ só com dígitos.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar; `flutter analyze` sem problemas.

### Task 13: DailyObra Parceiros: Início, Propostas, Produtos e Minha loja

**Files:**
- Create: `dailyobra_parceiro/lib/services/propostas_loja_service.dart`, `dailyobra_parceiro/lib/services/ofertas_service.dart`
- Create: `dailyobra_parceiro/lib/screens/navegacao_screen.dart`, `inicio_screen.dart`, `propostas_screen.dart`, `proposta_loja_screen.dart`, `pedido_loja_screen.dart`, `produtos_screen.dart`, `oferta_screen.dart`, `minha_loja_screen.dart`, `equipe_screen.dart`
- Test: `dailyobra_parceiro/test/painel_test.dart`

**Interfaces:**
- Consumes: RPCs da Task 5, `LojaService`.
- Produces: `PropostasLojaService.instance` com `novas`, `emNegociacao`, `pedidos`, `aceitar(id)`, `recusar(id, motivo)`, `contrapropor(id, {Map<String,double> precos, double desconto, int validadeHoras, String? mensagem})`, `atualizarPedido(id, StatusPedido)`, `confirmarPagamento(id)`, e tempo real; `OfertasService.instance` com `Map<String, Oferta> minhas`, `salvar(Oferta)`, `pausar(itemId, bool)`; números do Início calculados a partir dessas listas (sem número fixo).
- Permissões na interface: vendedor não vê "Produtos" editável nem "Minha loja > Equipe"; os botões seguem o papel de `LojaService.meuPapel` (o servidor confere de novo).
- Equipe: convite por e-mail de quem já tem conta, pela função `public.convidar_membro(p_loja uuid, p_email text, p_papel text)` (adicionar à migração da Task 5, só dono, P0001 "Não encontramos uma conta com este e-mail" quando não existe).

- [ ] **Step 1:** Testes que falham: Início com 2 propostas novas e 1 pedido em andamento mostra 2 e 1; contraproposta com preço acima do anunciado mostra "O preço só pode baixar" e não envia; recusa sem motivo mostra "Informe o motivo"; vendedor não vê o botão de editar preço; Produtos com busca sem resultado mostra o estado vazio; tudo em 360 px, claro e escuro.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar; `flutter analyze` sem problemas nos três pacotes.

### Task 14: Builds, emulador e entrega

**Files:**
- Modify: `dailyobra/README.md`, create `dailyobra_parceiro/README.md`, create `D:\dev\dailyobra_app\README.md` (como abrir no VS Code, rodar cada app, instalar os APKs, pendências do Supabase)
- Create: `D:\dev\dailyobra_app\apk\DailyObra.apk`, `D:\dev\dailyobra_app\apk\DailyObraParceiros.apk`

- [ ] **Step 1:** `flutter analyze` e `flutter test` nos três pacotes. Esperado: nenhum problema e tudo passando.
- [ ] **Step 2:** No Terminal do usuário: `flutter run -d emulator-5554` em cada app. Esperado: "Flutter run key commands" e nenhum erro de Dart no console; captura de tela do login de cada app.
- [ ] **Step 3:** `flutter build apk --release` em cada app, instalar os dois no emulador e abrir. Esperado: os dois ícones lado a lado e os dois abrem na tela de login.
- [ ] **Step 4:** Rodar de novo `supabase/tests/marketplace_test.sql`. Esperado: tudo `ok = true` (critérios 3, 4, 5 e 7 do spec no nível do banco).
- [ ] **Step 5:** Copiar os APKs para `apk\` e escrever os READMEs.
