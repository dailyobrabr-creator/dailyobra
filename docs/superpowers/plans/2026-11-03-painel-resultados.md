# Painel de resultados — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dono e gerente veem no Início do Parceiros os resultados do mês da loja (faturamento com variação, pedidos fechados, ticket médio, cashback gerado e top construtores), calculados no banco.

**Architecture:** Uma função `security definer` soma os pedidos de um período no servidor e só responde a dono e gerente. No Parceiros, contas puras definem o período do mês e a comparação; o `ResultadosService` chama a função duas vezes (mês e comparação) e a seção `Resultados do mês` (widget próprio) entra no Início só para quem gere a loja.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Supabase (Postgres, funções security definer; `apply_migration` e `execute_sql` pelo MCP).

**Spec:** `docs/superpowers/specs/2026-11-03-painel-resultados-design.md`

## Global Constraints

- Só dono e gerente: a seção não aparece para o vendedor (e o serviço não chama o banco para ele); o banco recusa com `Só o dono ou o gerente vê os resultados.`.
- Venda = pedido com `criado_em` em `[de, ate)` e `status <> 'cancelado'`; valor = `propostas.total`; cashback = `propostas.cashback_previsto`; ticket = faturamento ÷ pedidos.
- Textos exatos: `Resultados do mês`; dicas `Mês anterior` e `Próximo mês`; mês em minúsculas com o ano (`novembro de 2026`); `Faturamento`, `Pedidos fechados`, `Ticket médio`, `—` (ticket sem pedido), `Cashback gerado para os clientes`, `Top construtores`, `1 pedido` / `{n} pedidos`, `Construtor` (nome vazio); `Nenhum pedido em {mês} ainda.` (mês atual) e `Nenhum pedido em {mês}.` (mês passado); `+18,4% sobre o mesmo período de outubro` (mês atual), `+18,4% sobre outubro` (mês passado), `sem vendas em outubro para comparar`; `Período inválido.`.
- Variação com uma casa e vírgula; `+` na alta, `−` (U+2212) na baixa; o que arredonda para zero sai `0,0%`, sem sinal.
- Visual de hoje: `Indicador` na mesma grade do Início (2 colunas, espaço `Espaco.s3`, proporção 1,55), `Painel`, `Esqueleto`, `Aviso`; valores com `brl`.
- Banco: `security definer`, `set search_path = ''`, erros `P0001` em português; teste SQL numa transação que termina com `raise exception 'RESULTADO: ...'` (roda pelo `execute_sql` e desfaz tudo).
- Os apps usam `dart format lib test`; este plano não mexe no `dailyobra_comum`.
- O push no `main` publica o site e a migração vai para o banco de produção pelo MCP (aprovados junto com este plano).

## Review Focus

1. Troca rápida de mês (tocar ◀ duas vezes): a resposta atrasada de um mês não pode aparecer no outro — teste `resposta atrasada de outro mês é ignorada` (Task 3).
2. Pedido exatamente à 0h do dia 1 (entra) e à 0h do dia 1 do mês seguinte (sai) — dados de borda no teste SQL (Task 1).
3. Loja que nunca vendeu: ticket `—`, sem divisão por zero, `sem vendas … para comparar` — testes `variação` (Task 2) e `mês vazio` (Task 4).
4. Sair da loja e entrar em outra no mesmo aparelho: os números da loja anterior não aparecem — teste `limpar apaga os resultados` (Task 3) e `limpar()` no `dispose` da navegação (Task 4).
5. Construtor sem nome no perfil: aparece `Construtor`, com a empresa se houver — testes `construtor sem nome` (Tasks 1 e 3).

---

### Task 0: Setup

- [ ] Branch `painel-resultados` a partir do `main` (que já tem a spec e este plano), no próprio checkout.
- [ ] Workspace e ledger pelo `sdd-workspace` deste plano.

### Task 1: Banco — resultados_loja

**Files:**
- Create: `supabase/migrations/20261103180000_resultados_loja.sql`, `supabase/tests/resultados_loja_test.sql`

**Interfaces:**
- Produces: `public.resultados_loja(p_loja uuid, p_de timestamptz, p_ate timestamptz) returns jsonb` → `{"faturamento": n, "pedidos": n, "cashback": n, "top": [{"construtor_id", "nome", "empresa", "pedidos", "total"}]}`; até 5 no `top`, pelo total, empate por mais pedidos e depois pelo nome; `nome` e `empresa` saem `''` quando nulos; sem venda, `top` é `[]` e os números são 0. Índice `pedidos_loja_criado_idx` em `pedidos (loja_id, criado_em)`.

- [ ] **Step 1: Write the failing test** `supabase/tests/resultados_loja_test.sql` no padrão de `importacao_estoque_test.sql` (tabelas `r`/`v`, `pg_temp.como`, `pg_temp.admin`, `RESULTADO` no fim), com o ajudante `pg_temp.venda(loja uuid, construtor uuid, total numeric, cashback numeric, quando timestamptz, status text default 'confirmado', saldo numeric default 0)`, que como admin cria orçamento, proposta `aceita` (`total`, `cashback_previsto`, `saldo_aplicado`) e pedido (`total` − `saldo`, `status`, `criado_em = quando`).
  - Dados: loja A (dono `d001`, gerente `a001`, vendedor `e001`) e loja B (dono `f001`); construtores `c001` (`Ana Souza`, `Souza Obras`), `c002` (nome e empresa nulos), `c003` a `c007`. Novembro: `p_de = '2026-11-01 00:00-04'`, `p_ate = '2026-12-01 00:00-04'`.
  - Vendas da loja A em novembro: `c001` 1000 (cashback 20) e 500 (10); `c002` 800 (16, saldo 100); `c003` 300; `c007` 100 e 100; `c004` 200; `c005` 100; `c006` 50 exatamente em `p_de`. Fora: `c001` 9999 cancelado em novembro; `c001` 400 em outubro; `c003` 700 exatamente em `p_ate`; `c001` 600 na loja B em novembro.
  - `dono vê novembro`: faturamento 3150, pedidos 9, cashback 46.
  - `top tem 5, pelo total, empate por pedidos`: `c001` (1500, 2), `c002` (800, 1), `c003` (300, 1), `c007` (200, 2), `c004` (200, 1).
  - `total da proposta mesmo com saldo`: `c002` com total 800.
  - `construtor sem nome`: `c002` com `nome = ''` e `empresa = ''`; `c001` com `Ana Souza` e `Souza Obras`.
  - `gerente vê o mesmo`: igual ao do dono.
  - `vendedor recusado` e `outra loja recusada` (dono de B pedindo a A): `Só o dono ou o gerente vê os resultados.`.
  - `período inválido`: `p_ate = p_de` → `Período inválido.`.
  - `mês sem venda`: outubro de 2025 → `{"faturamento": 0, "pedidos": 0, "cashback": 0, "top": []}`.
- [ ] **Step 2: Run** pelo MCP `execute_sql` — Expected: falha com `function public.resultados_loja(uuid, timestamp with time zone, timestamp with time zone) does not exist`.
- [ ] **Step 3: Implement** a migração (função `stable` com as regras da Global Constraints; `revoke execute` de `public, anon`, `grant` para `authenticated`; índice) e aplicar pelo MCP `apply_migration` com o nome `resultados_loja`.
- [ ] **Step 4: Run** o teste — Expected: `RESULTADO: 9 de 9 ok`.
- [ ] **Step 5: Commit** — `feat(banco): resultados da loja por período`.

### Task 2: Parceiros — período, variação e nome do mês

**Files:**
- Create: `dailyobra_parceiro/lib/services/periodo_resultados.dart`
- Test: `dailyobra_parceiro/test/periodo_resultados_test.dart`

**Interfaces:**
- Produces: `class PeriodoResultados { final DateTime de, ate, deAnterior, ateAnterior; final bool mesAtual; }`; `PeriodoResultados periodoDoMes(DateTime mes, DateTime agora)` (`mes` é qualquer data do mês); `String nomeDoMes(DateTime mes)` (`novembro de 2026`); `String nomeSoDoMes(DateTime mes)` (`novembro`); `double? variacao(double atual, double anterior)` (nulo com anterior 0); `String textoVariacao(PeriodoResultados p, {required double atual, required double anterior})`.

- [ ] **Step 1: Write the failing tests:**
  - `meio do mês compara com o mesmo período`: `periodoDoMes(DateTime(2026, 11, 20), DateTime(2026, 11, 3, 14, 30))` → `de` `DateTime(2026, 11)`, `ate` `DateTime(2026, 12)`, `deAnterior` `DateTime(2026, 10)`, `ateAnterior` `DateTime(2026, 10, 3, 14, 30)`, `mesAtual` true.
  - `dia 31 com mês anterior curto`: agora `DateTime(2026, 3, 31, 10)` → `ateAnterior` `DateTime(2026, 3)` (fevereiro inteiro).
  - `janeiro compara com dezembro`: `periodoDoMes(DateTime(2027, 1), DateTime(2027, 1, 15, 9))` → `deAnterior` `DateTime(2026, 12)`, `ateAnterior` `DateTime(2026, 12, 15, 9)`.
  - `mês passado compara com o anterior inteiro`: `periodoDoMes(DateTime(2026, 10), DateTime(2026, 11, 3))` → `de` `DateTime(2026, 10)`, `ate` `DateTime(2026, 11)`, `deAnterior` `DateTime(2026, 9)`, `ateAnterior` `DateTime(2026, 10)`, `mesAtual` false.
  - `nome do mês`: `nomeDoMes(DateTime(2026, 11))` == `novembro de 2026`; `nomeDoMes(DateTime(2027, 3))` == `março de 2027`.
  - `variação`, com `atual = periodoDoMes(DateTime(2026, 11), DateTime(2026, 11, 3))` e `passado = periodoDoMes(DateTime(2026, 10), DateTime(2026, 11, 3))`: `textoVariacao(atual, atual: 1184, anterior: 1000)` == `+18,4% sobre o mesmo período de outubro`; `textoVariacao(passado, atual: 1184, anterior: 1000)` == `+18,4% sobre setembro`; 948/1000 → `−5,2% sobre setembro`; 1000/1000 e 999,9/1000 → `0,0% sobre setembro`; anterior 0 → `sem vendas em setembro para comparar`; `variacao(5, 0)` é nulo.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/periodo_resultados_test.dart` — Expected: FAIL (arquivo não existe).
- [ ] **Step 3: Implement.** Meses numa lista própria (`janeiro` … `dezembro`), sem `intl` de datas. No mês atual, `ateAnterior` é o menor entre `DateTime(agora.year, agora.month - 1, agora.day, agora.hour, agora.minute, agora.second, agora.millisecond)` e `de` (o `DateTime` passa para o mês seguinte quando o dia não existe).
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(parceiros): período e variação dos resultados`.

### Task 3: Parceiros — ResultadosService

**Files:**
- Create: `dailyobra_parceiro/lib/services/resultados_service.dart`
- Test: `dailyobra_parceiro/test/resultados_service_test.dart`

**Interfaces:**
- Consumes: o JSON da Task 1; `periodoDoMes` e `PeriodoResultados` (Task 2).
- Produces:
  - `class ConstrutorTop { final String construtorId, nome, empresa; final int pedidos; final double total; String get exibicao; factory ConstrutorTop.fromJson(Map<String, dynamic>) }` (`exibicao`: `Construtor` com nome vazio).
  - `class ResultadosPeriodo { const ResultadosPeriodo({this.faturamento = 0, this.pedidos = 0, this.cashback = 0, this.top = const []}); final double faturamento; final int pedidos; final double cashback; final List<ConstrutorTop> top; double? get ticket; factory ResultadosPeriodo.fromJson(Map<String, dynamic>) }` (números do JSON como `num`).
  - `class ResultadosService extends ChangeNotifier` com `static final instance`; `DateTime? mes`, `PeriodoResultados? periodo`, `ResultadosPeriodo? atual`, `ResultadosPeriodo? anterior`, `bool carregando`, `String? erro`; `Future<void> carregar(DateTime mes, {DateTime? agora})`; `Future<void> recarregar()` (o mesmo mês); `void limpar()`; `@visibleForTesting void definirParaTeste({required Future<ResultadosPeriodo> Function(DateTime de, DateTime ate) buscar})`.
  - Caminho real: `rpc('resultados_loja', params: {'p_loja': <loja de LojaService>, 'p_de': de.toUtc().toIso8601String(), 'p_ate': ate.toUtc().toIso8601String()})` para o mês e para a comparação, em paralelo, dentro de `comMensagem`; `FalhaComMensagem` vira `erro`. Um contador descarta a resposta de um `carregar` mais antigo.

- [ ] **Step 1: Write the failing tests:**
  - `lê o resultado do banco`: `ResultadosPeriodo.fromJson({'faturamento': 3150, 'pedidos': 9, 'cashback': 46.5, 'top': [{'construtor_id': 'c1', 'nome': 'Ana Souza', 'empresa': 'Souza Obras', 'pedidos': 2, 'total': 1500}]})` → faturamento 3150.0, pedidos 9, cashback 46.5, ticket 350.0, `top.single.exibicao` `Ana Souza`, `top.single.total` 1500.0; `const ResultadosPeriodo().ticket` é nulo.
  - `construtor sem nome`: `nome: ''` → `exibicao` `Construtor`.
  - `carrega o mês e a comparação`: `buscar` devolve faturamento 1184 para `de == DateTime(2026, 11)` e 1000 para o resto e guarda os períodos pedidos; `carregar(DateTime(2026, 11), agora: DateTime(2026, 11, 3, 14, 30))` → `mes` `DateTime(2026, 11)`, `atual.faturamento` 1184, `anterior.faturamento` 1000, períodos pedidos `[(DateTime(2026, 11), DateTime(2026, 12)), (DateTime(2026, 10), DateTime(2026, 10, 3, 14, 30))]`, `carregando` false, `erro` nulo.
  - `resposta atrasada de outro mês é ignorada`: `buscar` devolve futuros de `Completer` por `de`; chama `carregar(novembro)` e depois `carregar(outubro)` sem esperar; completa outubro e depois novembro → fica `mes` outubro, com os números de outubro.
  - `erro vira mensagem`: `buscar` lança `FalhaComMensagem('Sem conexão.')` → `erro` `Sem conexão.`, `carregando` false.
  - `limpar apaga os resultados`: depois de carregar, `limpar()` → `mes`, `atual` e `anterior` nulos.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/resultados_service_test.dart` — Expected: FAIL (arquivo não existe).
- [ ] **Step 3: Implement** no jeito do `OfertasService` (instância única, `_teste`, `notifyListeners`).
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(parceiros): serviço dos resultados do mês`.

### Task 4: Parceiros — seção Resultados do mês no Início

**Files:**
- Create: `dailyobra_parceiro/lib/screens/resultados_mes.dart`
- Modify: `dailyobra_parceiro/lib/screens/inicio_screen.dart` (`Indicador`, grade e `onRefresh`), `dailyobra_parceiro/lib/screens/navegacao_screen.dart:36-40` (`dispose`)
- Test: `dailyobra_parceiro/test/resultados_mes_test.dart`

**Interfaces:**
- Consumes: `nomeDoMes`, `nomeSoDoMes`, `variacao`, `textoVariacao` (Task 2); `ResultadosService`, `ResultadosPeriodo`, `ConstrutorTop` (Task 3).
- Produces: `class ResultadosDoMes extends StatefulWidget { const ResultadosDoMes({super.key, this.agora}); final DateTime Function()? agora; }` (relógio para os testes; padrão `DateTime.now`); `Indicador` ganha `String? detalhe` e `Color? corDetalhe`.

- [ ] **Step 1: Write the failing tests** (claro e escuro; `abrir` e `rolarAte` do `apoio.dart`; `ResultadosDoMes(agora: () => DateTime(2026, 11, 3, 14, 30))` num `Scaffold` com `ListView`; valores esperados com `brl.format(...)`):
  - `dono vê os resultados do mês`: novembro com faturamento 3150, pedidos 9, cashback 46 e top `Ana Souza`/`Souza Obras` (2 pedidos, 1500) e um sem nome (1 pedido, 800); comparação com faturamento 2000 → `Resultados do mês`, `novembro de 2026`, `Faturamento` com `brl.format(3150)` e `+57,5% sobre o mesmo período de outubro`, `Pedidos fechados` `9`, `Ticket médio` `brl.format(350)`, `Cashback gerado para os clientes` `brl.format(46)`, `Top construtores`, `Ana Souza`, `Souza Obras · 2 pedidos`, `brl.format(1500)`, `Construtor`, `1 pedido`.
  - `voltar um mês e voltar para o atual`: no mês atual a seta `Próximo mês` está desligada (`onPressed` nulo); tocar `Mês anterior` mostra `outubro de 2026`, pede ao serviço o período de outubro e o texto passa a `… sobre setembro`; tocar `Próximo mês` volta para `novembro de 2026`.
  - `mês vazio`: tudo zero → `Nenhum pedido em novembro ainda.`, `Ticket médio` `—`, `sem vendas em outubro para comparar`; em outubro → `Nenhum pedido em outubro.`.
  - `erro aparece`: `buscar` lança `FalhaComMensagem('Sem conexão.')` → `Sem conexão.` na tela.
  - `vendedor não vê a seção`: `InicioScreen` com `LojaService` (papel vendedor), `PropostasLojaService.definirParaTeste()` e `OfertasService.definirParaTeste(categorias: categoriasTeste, catalogo: catalogoTeste)` → `Resultados do mês` não aparece e `buscar` não é chamado; com papel dono aparece (depois de `rolarAte`).
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/resultados_mes_test.dart` — Expected: FAIL (arquivo não existe).
- [ ] **Step 3: Implement:**
  - `Indicador`: `detalhe` em `t.bodySmall` abaixo do rótulo, cor `corDetalhe ?? c.textoSuave`; os 4 cartões de hoje não mudam.
  - `ResultadosDoMes`: carrega no `initState` o mês de `agora()`; título `Resultados do mês` em `t.titleMedium` (como `Precisa de resposta`); linha com `IconButton` `Icons.chevron_left` (`Mês anterior`), o nome do mês e `Icons.chevron_right` (`Próximo mês`, desligado no mês atual); grade de 4 `Indicador` igual à do Início; o de faturamento com `detalhe: textoVariacao(...)` e cor `c.sucesso` na alta, `c.erro` na baixa e `c.textoSuave` sem mudança ou sem comparação; `Top construtores` num `Painel`, uma linha por construtor (`exibicao`; abaixo `empresa · n pedidos` ou só `n pedidos`; total com `brl` à direita) ou o texto de mês vazio; `Esqueleto(altura: 160)` enquanto carrega sem dados do mês; `Aviso(erro)`.
  - Início: `if (loja.meuPapel.gere) ...[const SizedBox(height: Espaco.s6), const ResultadosDoMes()]` depois da grade de indicadores e do painel `Coloque seus preços`; no `onRefresh`, `if (loja.meuPapel.gere) await ResultadosService.instance.recarregar();`.
  - `NavegacaoScreen.dispose`: `ResultadosService.instance.limpar();` junto do `OfertasService.instance.limpar()`.
- [ ] **Step 4: Run** `cd dailyobra_parceiro; dart format lib test; flutter analyze; flutter test` — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(parceiros): resultados do mês no início`.

### Task 5: README, suítes, publicação e APK

- [ ] README: depois do parágrafo de `Atualizar pelo Santri`, um parágrafo `Resultados do mês` (o que mostra, a regra de venda, só dono e gerente, função `resultados_loja`, teste `supabase/tests/resultados_loja_test.sql`) e o teste na lista de `Verificar`. Commit — `docs: resultados do mês`.
- [ ] Suítes: `flutter analyze` e `flutter test` em `dailyobra_comum`, `dailyobra` e `dailyobra_parceiro`; `node --test dailyobra/test/pagina_pagar_test.mjs`; `resultados_loja_test.sql` (9 de 9).
- [ ] Revisão final do branch, antes de publicar.
- [ ] Publicar: `main` avança para o branch (fast-forward), `git push origin main`, workflow `Site no GitHub Pages` com `success` e `/dailyobra/parceiros/` respondendo 200.
- [ ] APK: `cd D:\dev\dailyobra_app\dailyobra_parceiro; flutter build apk --release` pelo terminal e cópia para `apk\DailyObraParceiros.apk`.
