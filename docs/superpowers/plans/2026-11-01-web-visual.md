# Web responsivo do construtor e visual "vitrine viva": plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O app do construtor roda no navegador (celular, tablet e computador), publicado pelo GitHub Pages, com o visual "vitrine viva" e as funções novas do Início (obra ativa, economia, contraproposta, pedido a caminho, mais barato hoje, lojas perto, novidades).

**Architecture:** O mesmo app Flutter `dailyobra` compila para web. Um `LayoutAdaptativo` escolhe abas (menos de 600 px), trilho (600 a 1023 px) ou menu lateral com barra laranja (1024 px ou mais). Peças visuais e lógica pura novas ficam no `dailyobra_comum`; a economia do mês é calculada no Postgres (`economia_mensal`) a partir de uma coluna nova gravada no envio (`preco_maior`).

**Tech Stack:** Flutter 3.47 / Dart 3.13 (Android, iOS e web), supabase_flutter 2.18, google_fonts 8.0.0, shared_preferences, Postgres 17 no Supabase (`wlqtwaiqtwxmmndlunvh`), GitHub Actions + GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-11-01-web-visual-design.md` (referência visual: `docs/prototipos/inicio.html`)

## Global Constraints

- Pastas: `D:\dev\dailyobra_app\dailyobra_comum`, `...\dailyobra`, `...\dailyobra_parceiro`; migrações em `...\supabase\migrations`; workflow em `...\.github\workflows\web.yml`.
- Larguras: celular < 600 px; tablet 600 a 1023 px; computador ≥ 1024 px. Menu lateral 248 px; trilho 80 px; coluna lateral do Início 340 px; conteúdo máximo 1320 px; formulários máximo 720 px; janelas no computador até 560 px; painel de novidades 380 px.
- Topo laranja #F36E21 nos dois temas com texto/ícones #252832; busca #FFFFFF com texto #535965.
- Cores novas (claro / escuro): destaque suave #FDE9DC / #3A2416; cartão escuro #252832 / #2A2D35; mapa de categorias exatamente como na tabela da seção 3 do spec.
- Cartões com raio 16 e borda de 1 px, sem sombra; títulos de seção 17 px peso 700; transições de 200 ms.
- Nenhum texto cortado sem reticências, nenhuma rolagem lateral, contraste ≥ 4,5:1 nos dois temas, números com algarismos tabulares.
- `google_fonts` fixo em 8.0.0; `Supabase.initialize` com `publishableKey`; nenhuma chave secreta no repositório nem no workflow.
- O pacote comum não importa `dart:io` em código usado pelo web (só via importação condicional).
- Chave do "visto até" das novidades: `dailyobra.novidades.vistoAte`; chave da obra ativa: `dailyobra.obraAtiva`.
- Builds Android no painel de Terminal do usuário (`cd D:\...; flutter build apk --release`). A pasta não é repositório Git: o checkpoint de cada tarefa é `flutter analyze` sem problemas e os testes passando.
- Texto de interface em português, só a primeira letra maiúscula.

## Review Focus

1. Larguras na divisa (599, 600, 1023, 1024) e muito largas (1920): o menu certo aparece, o conteúdo fica centralizado no máximo de 1320 px, sem estouro. Teste na Task 6.
2. Recarregar a página ou voltar no navegador: o app abre no Início com a sessão restaurada, sem erro. Conferência manual na Task 11.
3. Novidades geradas pelo próprio construtor (cancelou, aceitou a contraproposta) não contam, e eventos anteriores ao "visto até" não somam no sino. Teste na Task 5.
4. Economia com propostas antigas sem `preco_maior`, pedidos cancelados e meses sem pedido: zero, nunca nulo. Testes nas Tasks 1 e 5.
5. Nomes enormes (loja, produto, categoria) e valores grandes (R$ 1.234.567,89) em 360 e 1366 px: reticências ou ajuste, nunca estouro. Testes nas Tasks 4 e 8.

---

### Task 1: Banco: preço maior no envio e economia do mês

**Files:**
- Create: `supabase/migrations/20261101120000_economia.sql`
- Modify: `supabase/tests/marketplace_test.sql`

**Interfaces:**
- Produces: coluna `public.proposta_itens.preco_maior numeric(12,2) check (preco_maior > 0)`; `public.enviar_cotacao` grava `preco_maior = greatest(preco_anunciado, max(preço vigente do item nas lojas ativas e abertas, oferta não pausada e diferente de 'sem_estoque'))`; `public.economia_mensal(p_meses int default 6) returns table(mes date, comparando numeric, negociando numeric, cashback numeric, total numeric)`, `security invoker`, `search_path = ''`, meses no fuso `America/Sao_Paulo`, só pedidos com status diferente de `cancelado`, meses vazios com 0, ordem crescente; `execute` só para `authenticated`.
- Conta (por item de pedido não cancelado): comparando = (`coalesce(preco_maior, preco_anunciado)` − `preco_anunciado`) × quantidade; negociando = (`preco_anunciado` − `coalesce(preco_ofertado, preco_anunciado)`) × quantidade, mais o `desconto` da proposta uma vez; cashback = `cashback_previsto` da proposta uma vez.

- [ ] **Step 1: Testes que falham** no `marketplace_test.sql` (antes do `rollback`):
  - proposta do construtor para a loja B (cimento 38, loja A com 45) grava `preco_maior = 45` no item;
  - depois de p1 (contraproposta 45→42 com desconto 20, aceita) e do pedido da B, `economia_mensal(6)` do construtor no mês atual: comparando inclui (45 − 38) × quantidade da B, negociando inclui (45 − 42) × 10 + 20, cashback = soma dos `cashback_previsto` dos pedidos não cancelados; `total` = soma das três;
  - o pedido cancelado (ped7) não entra;
  - `economia_mensal(6)` devolve 6 linhas, com 0 nos meses sem pedido;
  - chamada como a loja A devolve 6 linhas zeradas (não vê pedidos de outro construtor como seus).
- [ ] **Step 2:** Rodar o roteiro pelo `execute_sql`. Esperado: as verificações novas com `ok = false` (função e coluna ainda não existem: erro capturado).
- [ ] **Step 3:** Escrever e aplicar a migração (`apply_migration`, nome `economia`), recriando `enviar_cotacao` com o mesmo corpo atual mais o `preco_maior` no `insert` dos itens.
- [ ] **Step 4:** Rodar o roteiro inteiro. Esperado: todas as linhas `ok = true` (38 anteriores + novas). Rodar `get_advisors` (segurança): nada novo além dos avisos já registrados.

### Task 2: Comum: pronto para o navegador

**Files:**
- Modify: `dailyobra_comum/lib/src/supabase/erros.dart`, `dailyobra_comum/lib/src/supabase/auth_service.dart`
- Create: `dailyobra_comum/lib/src/supabase/conexao_io.dart`, `dailyobra_comum/lib/src/supabase/conexao_web.dart`
- Test: `dailyobra_comum/test/cnpj_test.dart` (grupo `mensagemDoServidor`), `dailyobra_comum/test/auth_test.dart`

**Interfaces:**
- Produces: `bool ehFalhaDeConexao(Object erro)` (exportada só para uso interno de `erros.dart`), escolhida por `import 'conexao_io.dart' if (dart.library.js_interop) 'conexao_web.dart'`; a versão web reconhece `http.ClientException`; a io reconhece também `SocketException` e `HandshakeException`.
- Produces: `AuthService.linkRetorno` passa a ser um getter: no web devolve `Uri.base` sem caminho de rota e sem fragmento (`origin + pathname` da base); fora do web, `'dailyobra://login'` ou o valor definido por `AuthService.definirLinkRetorno(String)` (o Parceiros chama com `'dailyobraparceiros://login'`).

- [ ] **Step 1:** Testes que falham: `ehFalhaDeConexao(http.ClientException('x'))` true e `Exception('x')` false; `mensagemDoServidor(SocketException('x'))` continua "Sem conexão…" na VM; `AuthService.definirLinkRetorno('dailyobraparceiros://login')` faz `AuthService.linkRetorno` devolver esse valor.
- [ ] **Step 2:** Rodar `flutter test test/cnpj_test.dart test/auth_test.dart`. Esperado: FAIL (funções não existem).
- [ ] **Step 3:** Implementar; trocar a atribuição em `dailyobra_parceiro/lib/main.dart` por `AuthService.definirLinkRetorno(...)`.
- [ ] **Step 4:** Rodar os testes do comum e do Parceiros. Esperado: PASS; `grep -rn "dart:io" dailyobra_comum/lib` só encontra `conexao_io.dart`.

### Task 3: Comum: cores da vitrine e marca

**Files:**
- Modify: `dailyobra_comum/lib/src/tema/cores.dart`, `dailyobra_comum/lib/src/tema/tema.dart`
- Create: `dailyobra_comum/lib/src/tema/categorias.dart`, `dailyobra_comum/assets/marca/simbolo.png`, `dailyobra_comum/assets/marca/simbolo_claro.png`, `dailyobra_comum/assets/marca/logo_tela.png` (copiados de `docs/prototipos/marca/`: símbolo recortado 256 px e logo de 480 px)
- Test: `dailyobra_comum/test/tema_test.dart`

**Interfaces:**
- Produces em `CoresDailyObra`: `topo` (#F36E21 nos dois), `textoSobreTopo` (#252832), `destaqueSuave` (#FDE9DC / #3A2416), `cartaoEscuro` (#252832 / #2A2D35), `textoCartaoEscuro` (#FFFFFF / #F2F3F5), `textoCartaoEscuroSuave` (#B8BBC4 / #A8ACB6), incluídos em `copyWith` e `lerp`.
- Produces: `class CorCategoria { final Color fundo; final Color icone; }` e `CorCategoria coresDaCategoria(String categoriaId, Brightness brilho)` com a tabela do spec; id desconhecido → par de "basico".
- Produces em `tema.dart`: `Raio.xl = 16`; `CardTheme`/borda dos painéis com raio 16.

- [ ] **Step 1:** Testes que falham: contraste ≥ 4,5 para `textoSobreTopo` sobre `topo`, `icone` sobre `fundo` das 10 categorias nos dois brilhos, `textoCartaoEscuro` sobre `cartaoEscuro`, `acao` sobre `destaqueSuave`; `coresDaCategoria('xyz', Brightness.light)` igual ao de `'basico'`; os três arquivos de marca existem e decodificam (`Image.asset` no teste com `rootBundle.load`).
- [ ] **Step 2:** Rodar `flutter test test/tema_test.dart`. Esperado: FAIL.
- [ ] **Step 3:** Implementar e copiar os arquivos de marca.
- [ ] **Step 4:** Rodar. Esperado: PASS.

### Task 4: Comum: peças da vitrine

**Files:**
- Modify: `dailyobra_comum/lib/src/ui/marketplace_ui.dart`, `dailyobra_comum/lib/src/ui/ui.dart` (Painel com raio 16), `dailyobra/lib/screens/componentes.dart` (tira o `TituloSecao` do app, que passa a vir do comum, para não haver dois com o mesmo nome)
- Create: `dailyobra_comum/lib/src/ui/vitrine.dart`
- Test: `dailyobra_comum/test/marketplace_ui_test.dart`

**Interfaces:**
- Produces em `vitrine.dart`:
  - `CartaoOferta({required ItemCatalogo item, required Oferta oferta, required DateTime hoje, String? nomeLoja, VoidCallback? onTap, double? largura})`: área de 112 px na cor da categoria com ícone (ou a imagem do produto), selo "-N%" quando em promoção, nome em 2 linhas com altura fixa, loja em 1 linha, preço antigo riscado acima do atual.
  - `TileCategoria({required Categoria categoria, required bool horizontal, VoidCallback? onTap})`: horizontal = ícone 40 px e nome ao lado; vertical = ícone em cima; nome em até 2 linhas.
  - `MarcaDailyObra({required bool soSimbolo, double altura = 30})`: claro = `logo_tela.png`; escuro = `simbolo_claro.png` + texto "Daily" e "Obra" (laranja); `soSimbolo` = `simbolo.png` / `simbolo_claro.png` conforme o brilho.
  - `EsqueletoBrilho({double altura, double? largura, double raio = 16})`: bloco com brilho animado (1,2 s).
  - `TituloSecao(String texto, {String? acao, VoidCallback? onAcao})` (17 px/700, "Ver todas" em `acao`), movido do app para o comum.
  - `GraficoMeses({required List<(String rotulo, double valor)> meses})`: barras com rótulo embaixo, a última em `topo`.
  - `BarraPassos({required int feitos, int total = 4, String? inicio, String? fim})`.
- Modify: `CartaoLoja` ganha `capa` (foto da loja ou faixa na cor da logo, 64 px) e `ofertas` (int?) com selo aberta/fechada; `ChipCategoria` passa a usar `coresDaCategoria`.

- [ ] **Step 1:** Testes que falham, em 360 e 1366 px, claro e escuro: `CartaoOferta` com nome de 80 caracteres e preço R$ 1.234.567,89 sem estouro, selo "-15%" presente quando em promoção e ausente sem promoção; quatro `CartaoOferta` lado a lado num `Row` com `Expanded` têm a mesma altura; `TileCategoria` "Louças e metais" horizontal em 150 px sem estouro; `MarcaDailyObra` mostra `logo_tela.png` no claro e o texto "Obra" no escuro; `GraficoMeses` com 6 meses desenha 6 rótulos; `CartaoLoja` fechada mostra "fechada".
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar `flutter test` no comum e no app. Esperado: PASS (os testes antigos de peças e de telas continuam passando com o `TituloSecao` do comum).

### Task 5: Comum: mais barato hoje, novidades e economia

**Files:**
- Create: `dailyobra_comum/lib/src/marketplace/vitrine_dados.dart`
- Test: `dailyobra_comum/test/vitrine_dados_test.dart`

**Interfaces:**
- Produces: `class FaixaPreco { ItemCatalogo item; double menor; double maior; int lojas; Oferta melhor; }`; `List<FaixaPreco> maisBaratoHoje({required List<ItemCatalogo> itens, required List<Oferta> ofertas, required Map<String, Loja> lojas, required DateTime hoje, Set<String> noOrcamento = const {}, int limite = 5})` — só lojas abertas, preço vigente, 2+ lojas; ordem: itens de `noOrcamento` primeiro, depois maior `(maior − menor) / maior`, depois nome.
- Produces: `enum TipoNovidade { aceita, recusada, contraproposta, expirada, emSeparacao, saiuEntrega, entregue, cancelado, pagamentoConfirmado, cashbackLiberado }`; `class Novidade { TipoNovidade tipo; String? propostaId; String? pedidoId; String? lojaNome; String? detalhe; double? valor; DateTime quando; String get texto; }`; `List<Novidade> novidadesDe({required List<Map<String, dynamic>> eventosProposta, required List<Map<String, dynamic>> eventosPedido, required List<Map<String, dynamic>> cashback, required String usuarioId})` — ignora `papel == 'construtor'` em propostas, ignora `autor == usuarioId` e `para == 'confirmado'` em pedidos, ordena do mais novo ao mais velho, no máximo 50; `int contarDesde(List<Novidade>, DateTime? vistoAte)`.
- Produces: `class EconomiaMes { DateTime mes; double comparando; double negociando; double cashback; double get total; factory EconomiaMes.fromJson(Map) }`.
- Formato esperado das linhas de evento (o serviço da Task 7 monta assim): proposta `{proposta_id, para, papel, justificativa, valores, criado_em, loja_nome}`; pedido `{pedido_id, para, autor, criado_em, loja_nome, total}`; cashback `{valor, descricao, criado_em, loja_nome, pedido_id}`.

- [ ] **Step 1:** Testes que falham:
  - `maisBaratoHoje`: produto com uma loja fica fora; loja fechada fica fora; item do orçamento vem antes de outro com diferença maior; limite 5;
  - `novidadesDe`: evento de proposta com `papel: 'construtor'` fora; evento de pedido com `autor` igual ao usuário fora; `para: 'confirmado'` fora; contraproposta vira `TipoNovidade.contraproposta` com texto "Casa do Construtor mandou uma contraproposta"; ordem decrescente por data;
  - `contarDesde`: 3 novidades, `vistoAte` entre a 1ª e a 2ª → 1; `vistoAte` nulo → 3;
  - `EconomiaMes.fromJson({'mes': '2026-10-01', 'comparando': '70.00', 'negociando': 50, 'cashback': null, 'total': 120})` → cashback 0, total 120.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar e exportar.
- [ ] **Step 4:** Rodar. Esperado: PASS.

### Task 6: App: layout adaptativo e navegação

**Files:**
- Create: `dailyobra/lib/screens/layout_adaptativo.dart`, `dailyobra/lib/screens/topo_vitrine.dart`
- Modify: `dailyobra/lib/screens/navegacao_screen.dart`, `dailyobra/lib/screens/componentes.dart` (`Aba` ganha `obras`)
- Test: `dailyobra/test/layout_test.dart`

**Interfaces:**
- Produces: `enum Formato { celular, tablet, computador }`; `Formato formatoDe(double largura)` (< 600, < 1024, resto); `class LayoutAdaptativo extends StatelessWidget { LayoutAdaptativo({required Aba aba, required ValueChanged<Aba> onAba, required Widget conteudo, required int pendencias}) }` — celular: `NavigationBar` com Início, Orçamentos, Carteira, Perfil; tablet: `NavigationRail` de 80 px com `MarcaDailyObra(soSimbolo: true)`; computador: menu de 248 px com marca, itens (Início, Orçamentos, Carteira, Minhas obras, Perfil) e o cartão do Clube (saldo de `CarteiraService`, "Usar no orçamento").
- Produces: `TopoVitrine({required bool compacto})` — saudação, cidade, busca (abre `BuscaScreen`), botão de tema, sino com número de novidades, iniciais; `compacto` = versão do celular (cantos de 24 px, busca embaixo). No computador é mostrado acima do conteúdo de todas as abas.
- Conteúdo centralizado com `ConstrainedBox(maxWidth: 1320)`.

- [ ] **Step 1:** Testes que falham: em 599 px aparece `NavigationBar` e não aparece `NavigationRail`; em 600 px aparece `NavigationRail`; em 1023 px ainda trilho; em 1024 px aparece o texto "Minhas obras" no menu e o cartão do Clube; em 1920 px o conteúdo tem no máximo 1320 px de largura; tocar "Carteira" no menu troca a aba; tudo sem estouro, claro e escuro.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar e ligar na `NavegacaoScreen` (a aba Minhas obras abre `ObrasScreen` dentro do layout).
- [ ] **Step 4:** Rodar todos os testes do app. Esperado: PASS.

### Task 7: App: serviços de economia, novidades e obra ativa

**Files:**
- Create: `dailyobra/lib/services/economia_service.dart`, `dailyobra/lib/services/novidades_service.dart`
- Modify: `dailyobra/lib/services/obras_service.dart`, `dailyobra/lib/services/negociacao_service.dart` (recarregar novidades junto com o tempo real), `dailyobra/lib/screens/navegacao_screen.dart` (iniciar/limpar)
- Test: `dailyobra/test/servicos_test.dart`

**Interfaces:**
- Produces: `EconomiaService.instance` (`ChangeNotifier`) com `List<EconomiaMes> meses`, `EconomiaMes? get atual`, `Future<void> carregar()` (RPC `economia_mensal`), `limpar()`, `@visibleForTesting definirParaTeste(List<EconomiaMes>)`.
- Produces: `NovidadesService.instance` com `List<Novidade> itens`, `int get naoVistas`, `Future<void> carregar()` (três consultas: `proposta_eventos` com `propostas!inner(construtor_id, lojas(nome))`, `pedido_eventos` com `pedidos!inner(construtor_id, total, lojas(nome))`, `carteira_lancamentos` com `tipo = cashback_liberado` e `conta = disponivel`; últimos 30 dias), `Future<void> marcarVistas()` (grava `dailyobra.novidades.vistoAte`), `limpar()`, `definirParaTeste(...)`.
- Produces em `ObrasService`: `Obra? get obraAtiva` (a fixada em `dailyobra.obraAtiva` se ainda existir, senão a de `atualizadaEm` mais recente), `Future<void> fixarAtiva(String obraId)`.

- [ ] **Step 1:** Testes que falham: `obraAtiva` sem fixada devolve a mais recente; fixada que sumiu volta para a mais recente; `NovidadesService.definirParaTeste` com 3 itens e `vistoAte` antigo dá `naoVistas == 3`, e `marcarVistas()` zera (com `SharedPreferences.setMockInitialValues`).
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar todos os testes do app. Esperado: PASS.

### Task 8: App: Início novo

**Files:**
- Modify: `dailyobra/lib/screens/inicio_screen.dart`
- Test: `dailyobra/test/inicio_test.dart`

**Interfaces:**
- Consumes: Tasks 3 a 7.
- Blocos e ordem exatamente como na seção 4 do spec e no protótipo `docs/prototipos/inicio.html`: computador em duas colunas (principal + lateral fixa de 340 px); tablet e celular em uma coluna na ordem contraproposta, pedido, lista, obra + economia, categorias, ofertas, mais barato, lojas; no celular, o cartão do Clube no começo.

- [ ] **Step 1:** Testes que falham (360, 800 e 1366 px; claro e escuro; sem estouro):
  - com uma contraproposta aberta aparece "Contraproposta" e "Responda em"; com três aparece "3 contrapropostas esperando você"; sem nenhuma o bloco some;
  - pedido `saiuEntrega` aparece "Pedido saiu para entrega"; sem pedido em andamento o bloco some;
  - sem obras aparece "Cadastre sua obra"; com obra aparece "42% concluída" para a obra de teste;
  - economia do mês com total 1.284,00 aparece "R$ 1.284,00" e 6 rótulos de mês; sem pedidos aparece "Feche seu primeiro pedido";
  - "Mais barato hoje" lista o cimento ("de R$ 38,00 a R$ 45,00") e não lista produto de uma loja só;
  - em 1366 px a coluna lateral contém "Lojas perto" à direita da coluna principal (posição x maior);
  - nome de loja de 70 caracteres não estoura em 360 px.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar todos os testes do app. Esperado: PASS.

### Task 9: App: novidades e carteira com economia

**Files:**
- Create: `dailyobra/lib/screens/novidades_screen.dart`
- Modify: `dailyobra/lib/screens/carteira_screen.dart`, `dailyobra/lib/screens/topo_vitrine.dart` (sino abre painel ou tela)
- Test: `dailyobra/test/novidades_carteira_test.dart`

**Interfaces:**
- Produces: `NovidadesScreen` (tela no celular/tablet) e `PainelNovidades` (painel lateral de 380 px no computador, aberto como `showGeneralDialog` alinhado à direita); abrir chama `NovidadesService.marcarVistas()`; tocar item abre `PropostaScreen`, `PedidoScreen` ou a aba Carteira.
- Carteira: bloco "Economia" com `GraficoMeses` e a divisão "Comparando lojas · Negociando · Cashback"; no computador, duas colunas (saldo, economia e níveis | extrato em tabela com data, descrição, loja, nível, valor).

- [ ] **Step 1:** Testes que falham: sino com 2 não vistas mostra "2"; abrir as novidades zera o número; sem novidades aparece "Nenhuma novidade por aqui"; tocar uma contraproposta abre a `PropostaScreen`; carteira com economia (70 comparando, 50 negociando, 4 cashback) mostra as três parcelas e o total R$ 124,00; em 1366 px o extrato aparece à direita do saldo; sem estouro em 360/800/1366, claro e escuro.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar todos os testes do app. Esperado: PASS.

### Task 10: App: outras telas no computador e no tablet

**Files:**
- Modify: `dailyobra/lib/screens/orcamentos_screen.dart`, `produto_screen.dart`, `loja_screen.dart`, `categoria_screen.dart`, `busca_screen.dart`, `smart_list_screen.dart`, `perfil_screen.dart`, `obras_screen.dart`, `componentes.dart` (`mostrarJanela` centraliza no computador e sobe de baixo no celular)
- Test: `dailyobra/test/telas_largas_test.dart`

**Interfaces:**
- Produces: `Future<T?> mostrarJanela<T>(BuildContext, {required WidgetBuilder construtor})` — computador: `Dialog` de até 560 px; demais: `showModalBottomSheet`.
- Orçamentos (≥ 1024 px): cotação à esquerda, resumo fixo à direita (modo, total, cashback, saldo, Proposta, Fechar pedido e o motivo de bloqueio); Enviados com lista à esquerda e `PropostaScreen`/`PedidoScreen` embutidas à direita (sem `Scaffold` próprio quando embutidas: parâmetro `embutida`).
- Produto, Loja, Categoria/Busca, Lista inteligente, Perfil e Obras conforme a seção 7 do spec (grades de 3 colunas no tablet e 4 no computador com `CartaoOferta`; perfil com escolha da obra ativa).

- [ ] **Step 1:** Testes que falham, em 1366 px: Orçamentos com 3 lojas mostra o total geral e os botões no resumo à direita (x maior que o dos grupos); tocar uma proposta em Enviados mostra o detalhe na mesma tela; loja com 8 produtos mostra 4 cartões na primeira linha; Lista inteligente mostra o texto colado e os itens lado a lado; Perfil mostra "Obra ativa" com as obras; em 360 px as telas continuam como hoje (os testes antigos passam); sem estouro, claro e escuro.
- [ ] **Step 2:** Rodar. Esperado: FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Rodar todos os testes do app. Esperado: PASS.

### Task 11: Web: plataforma, publicação e conferência no navegador

**Files:**
- Create: `dailyobra/web/` (via `flutter create --platforms web .`, apagando o `test/widget_test.dart` que o comando recria), `.github/workflows/web.yml`, `.gitignore` na raiz
- Modify: `dailyobra/web/index.html` (título, cor #F36E21, tela de abertura com `simbolo.png`), `dailyobra/web/manifest.json` (nome "DailyObra", `theme_color` #F36E21, ícones gerados do ícone do app), `README.md` da raiz (seção "Publicar no GitHub Pages"), `dailyobra/README.md`

**Interfaces:**
- Workflow: em `push` para `main` e manual; Flutter estável (`subosito/flutter-action@v2`); `flutter pub get`, `flutter analyze` e `flutter test` em `dailyobra_comum` e `dailyobra`; `flutter build web --release --base-href "/${{ github.event.repository.name }}/"`; `actions/upload-pages-artifact@v3` com `dailyobra/build/web`; `actions/deploy-pages@v4`; permissões `pages: write`, `id-token: write`.
- `.gitignore`: `build/`, `.dart_tool/`, `*.iml`, `.superpowers/`, `apk/` e `**/android/local.properties`.

- [ ] **Step 1:** `flutter build web --release --base-href /dailyobra/` em `dailyobra`. Esperado: "✓ Built build\web" sem erro.
- [ ] **Step 2:** Servir `dailyobra/build/web` localmente (`python -m http.server` no Terminal) e abrir no navegador do app em 375, 768 e 1366 px. Esperado: login com a marca; simulador sem conta abre; nenhum erro no console; recarregar a página volta ao mesmo ponto sem erro.
- [ ] **Step 3:** Validar o YAML do workflow (estrutura e chaves) e escrever o passo a passo do README: criar o repositório, enviar a pasta, Settings > Pages > Source "GitHub Actions", copiar o endereço para o Supabase.
- [ ] **Step 4:** Rodar `flutter analyze` e `flutter test` nos três pacotes. Esperado: nenhum problema e tudo passando.

### Task 12: Parceiros com o acabamento novo, APKs e entrega

**Files:**
- Modify: `dailyobra_parceiro/lib/screens/*.dart` só onde usam peças trocadas (`TituloSecao` do comum, raio 16), sem mudar layout nem função
- Create: `apk/DailyObra.apk`, `apk/DailyObraParceiros.apk` (novas versões)

- [ ] **Step 1:** `flutter analyze` e `flutter test` no Parceiros. Esperado: nenhum problema; 24/24 (ou mais) passando.
- [ ] **Step 2:** No Terminal do usuário, `flutter build apk --release` em cada app; instalar no emulador e abrir. Esperado: os dois abrem no login com o visual novo, sem erro no logcat.
- [ ] **Step 3:** Rodar de novo `supabase/tests/marketplace_test.sql`. Esperado: tudo `ok = true`.
- [ ] **Step 4:** Copiar os APKs para `apk\`, atualizar os READMEs e fazer a revisão final do conjunto.
