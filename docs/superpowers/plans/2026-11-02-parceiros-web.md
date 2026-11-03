# Parceiros na web — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O DailyObra Parceiros abre no navegador do computador, com menu lateral e propostas em duas colunas, publicado em `/dailyobra/parceiros/` junto com o site.

**Architecture:** Os limites de largura (`Formato`) vão para o `dailyobra_comum`. O Parceiros ganha uma moldura por largura (`LayoutParceiros`), as telas de proposta e pedido aprendem a abrir embutidas, e a plataforma web do app é gerada e publicada pelo workflow que já publica o site do construtor.

**Tech Stack:** Flutter 3.47 (web + Android), Dart 3.13, supabase_flutter, GitHub Actions + GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-11-02-parceiros-web-design.md`

## Global Constraints

- Endereço do painel: `https://dailyobrabr-creator.github.io/dailyobra/parceiros/` (base `/dailyobra/parceiros/`).
- Limites: celular abaixo de 600 px, tablet de 600 a 1023 px, computador a partir de 1024 px.
- Conteúdo dentro da moldura: no máximo 1320 px. Telas abertas por cima da navegação: coluna de no máximo 760 px.
- Visual atual: só os tokens e widgets que já existem (`c.topo`, `c.textoSobreTopo`, `c.borda`, `c.superficieSutil`, `MarcaDailyObra`, `LogoLoja`, `EstadoVazio`); nenhuma cor nova.
- Textos exatos: `DailyObra Parceiros` (título da página), `Escolha uma proposta ou pedido` (coluna vazia).
- No celular nada muda: abas embaixo e telas abrindo em tela cheia.
- Nunca rodar `dart format` no `dailyobra_comum` (estilo de linha longa); os apps usam `dart format lib test`.
- No Git Bash, `flutter build web --base-href ...` precisa de `MSYS_NO_PATHCONV=1` na frente.
- O push no `main` publica o site (aprovado junto com este plano). As URLs de redirecionamento do Supabase são ação do usuário.

## Review Focus

1. Atualizar a página (F5) em `/dailyobra/parceiros/` abre o painel de novo (título `DailyObra Parceiros`), não o site do construtor — conferido no ar na Task 5.
2. Depois da publicação, `/dailyobra/` e `/dailyobra/pagar/` continuam abrindo como antes — conferido no ar na Task 5.
3. Nome de loja comprido na barra laranja corta com reticências, sem estourar a linha — teste `nome comprido na barra não estoura` (Task 2).
4. A proposta aberta ao lado some da lista (expirou, foi removida): a coluna volta a `Escolha uma proposta ou pedido`, sem erro — teste `proposta que some da lista volta ao aviso` (Task 3).
5. Aceitar a proposta aberta ao lado troca a coluna para o pedido, sem empilhar tela — teste `aceitar abre o pedido na mesma coluna` (Task 3).

---

### Task 0: Setup

- [ ] Branch `parceiros-web` a partir do `main` no próprio checkout (como no plano anterior: os pacotes dependem de `../dailyobra_comum`).
- [ ] Workspace e ledger pelo `sdd-workspace` deste plano.

### Task 1: Comum — limites de largura no pacote comum

**Files:**
- Create: `dailyobra_comum/lib/src/ui/formato.dart`
- Modify: `dailyobra_comum/lib/dailyobra_comum.dart` (export, depois de `src/ui/faixa_obra.dart`), `dailyobra/lib/screens/layout_adaptativo.dart:8-18` (sai a definição)
- Test: `dailyobra_comum/test/formato_test.dart`

**Interfaces:**
- Produces: `enum Formato { celular, tablet, computador }`, `Formato formatoDe(double largura)`, `Formato formatoDoContexto(BuildContext context)` (largura de `MediaQuery.sizeOf`), exportados por `package:dailyobra_comum/dailyobra_comum.dart`.

- [ ] **Step 1: Write the failing test** `limites de largura`:

```dart
expect(formatoDe(599), Formato.celular);
expect(formatoDe(600), Formato.tablet);
expect(formatoDe(1023), Formato.tablet);
expect(formatoDe(1024), Formato.computador);
```

- [ ] **Step 2: Run** `cd dailyobra_comum; flutter test test/formato_test.dart` — Expected: FAIL (`formatoDe` não existe no comum).
- [ ] **Step 3: Implement** — move a definição de `layout_adaptativo.dart` (linhas 8-18, com o comentário) para `formato.dart`, em estilo de linha longa, e exporte. Os arquivos do construtor que usam `Formato` já importam o comum.
- [ ] **Step 4: Run** `cd dailyobra_comum; flutter analyze; flutter test` e `cd dailyobra; flutter analyze; flutter test` — Expected: tudo verde (o `layout_test.dart` do construtor continua passando).
- [ ] **Step 5: Commit** — `refactor(comum): limites de largura no pacote comum`.

### Task 2: Parceiros — moldura por largura

**Files:**
- Create: `dailyobra_parceiro/lib/screens/layout_parceiros.dart`
- Modify: `dailyobra_parceiro/lib/screens/navegacao_screen.dart:41-108`, `dailyobra_parceiro/test/apoio.dart`
- Test: `dailyobra_parceiro/test/layout_test.dart`

**Interfaces:**
- Consumes: `Formato`, `formatoDoContexto` (Task 1); `Aba`, `abaAtual` (`componentes.dart`).
- Produces: `LayoutParceiros({Key? key, required Aba aba, required ValueChanged<Aba> onAba, required int novas, required Loja? loja, required Widget conteudo})`; chaves `Key('menu-lateral')`, `Key('barra-da-loja')`, `Key('conteudo-adaptativo')`; em `test/apoio.dart`, `Future<void> abrirLargura(WidgetTester tester, Widget tela, double largura, {bool escuro = false})` (como o do construtor: `physicalSize = Size(largura, 900)`, `devicePixelRatio = 1`, mesmo `MaterialApp` do `abrir`).

- [ ] **Step 1: Write the failing tests** (claro e escuro), abrindo `LayoutParceiros(aba: Aba.inicio, onAba: abas.add, novas: 2, loja: minhaLoja, conteudo: const Text('Conteúdo'))`:
  - `celular: abas embaixo` (360): `NavigationBar` uma vez, `NavigationRail` nenhuma, `find.text('2')` uma vez, sem exceção.
  - `tablet: trilho lateral` (800): `NavigationRail` uma vez, `NavigationBar` nenhuma, `find.text('2')` uma vez.
  - `computador: menu lateral e barra da loja` (1366): `Key('menu-lateral')` uma vez; `find.descendant(of: find.byKey(const Key('barra-da-loja')), matching: find.text(minhaLoja.nome))` uma vez; tocar em `Produtos` deixa `abas == [Aba.produtos]`; largura de `Key('conteudo-adaptativo')` ≤ 1320.
  - `nome comprido na barra não estoura` (1366): loja com nome `Operário Construção e Acabamentos Materiais para Construção Filial 01 Matriz Rondonópolis` → `tester.takeException()` nulo.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/layout_test.dart` — Expected: FAIL (`LayoutParceiros` não existe).
- [ ] **Step 3: Implement** `LayoutParceiros`:
  - itens nesta ordem, com os ícones de hoje: Início (`dashboard`), Propostas (`inbox`, com o `Badge` de `novas`), Produtos (`sell`), Minha loja (`storefront`);
  - celular: o `NavigationBar` de hoje, com a borda de cima;
  - tablet: `NavigationRail` como o do construtor (`labelType: none`, `minWidth: 80`, `MarcaDailyObra(soSimbolo: true, altura: 36)` no alto, `Tooltip` com o rótulo);
  - computador: menu lateral no estilo do `_MenuLateral` de `dailyobra/lib/screens/layout_adaptativo.dart` (marca no alto e os quatro itens; sem o cartão do Clube), `VerticalDivider` e, à direita, a barra da loja (`Material` em `c.topo`, `EdgeInsets.symmetric(horizontal: Espaco.s8, vertical: 18)`, `LogoLoja(loja: loja, tamanho: 36)` e o nome em `titleMedium` negrito `c.textoSobreTopo`, uma linha com reticências; sem loja, só a barra) sobre o conteúdo;
  - conteúdo: `Align(topCenter)` + `ConstrainedBox(maxWidth: 1320)` + `KeyedSubtree(key: Key('conteudo-adaptativo'))`.
  `NavegacaoScreen` mantém `initState`, `dispose`, `PopScope` e o `IndexedStack`, e troca o `Scaffold` por `LayoutParceiros`, ouvindo `PropostasLojaService` (para `novas`) e `LojaService` (para `loja: LojaService.instance.minhaLoja`).
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` no Parceiros — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(parceiros): moldura por largura (abas, trilho e menu lateral)`.

### Task 3: Parceiros — propostas em duas colunas e telas por cima numa coluna

**Files:**
- Modify: `dailyobra_parceiro/lib/screens/propostas_screen.dart`, `inicio_screen.dart:257-300` (`CartaoPropostaLoja`), `proposta_loja_screen.dart`, `pedido_loja_screen.dart`, `componentes.dart`, `oferta_screen.dart`, `importar_planilha_screen.dart`, `equipe_screen.dart`, `cadastro_loja_screen.dart`
- Test: `dailyobra_parceiro/test/painel_test.dart`

**Interfaces:**
- Consumes: `formatoDoContexto` (Task 1), `abrirLargura` (Task 2).
- Produces: `PropostaLojaScreen({Key? key, required String id, bool embutida = false})`; `PedidoLojaScreen({Key? key, required String pedidoId, bool embutida = false})`; `CartaoPropostaLoja({Key? key, required PropostaResumo proposta, ValueChanged<PropostaResumo>? onAbrir, bool selecionado = false})`; `ColunaCentral({Key? key, required Widget child})` em `componentes.dart`.

- [ ] **Step 1: Write the failing tests** (no laço claro/escuro do `painel_test.dart`, com `preparar()` e as fixtures de lá):
  - `propostas no computador abrem ao lado` (1366, `PropostasScreen`): `Escolha uma proposta ou pedido` uma vez; tocar no primeiro `CartaoPropostaLoja` → `PropostaLojaScreen` uma vez, o aviso some, `find.byType(AppBar)` uma vez (nada empilhado) e `find.widgetWithText(OutlinedButton, 'Recusar')` uma vez.
  - `pedido aberto ao lado tem as ações no pé` (1366): aba `Pedidos`, tocar no cartão → `find.widgetWithText(FilledButton, 'Marcar como em separação')` uma vez e `find.byType(AppBar)` uma vez.
  - `aceitar abre o pedido na mesma coluna` (1366): abrir `p1` e chamar `preparar(propostas: [proposta('p1', status: StatusProposta.aceita, pedido: pedido(StatusPedido.confirmado))])` → `PedidoLojaScreen` uma vez e `Marcar como em separação` na coluna.
  - `proposta que some da lista volta ao aviso` (1366): abrir `p1` e chamar `preparar(propostas: [proposta('p2', modo: ModoProposta.pedido)])` → `Escolha uma proposta ou pedido` uma vez, sem exceção.
  - `no celular a proposta abre em tela cheia` (`abrir`, 360): tocar no primeiro cartão → `find.text('Proposta')` uma vez (título da tela aberta).
  - `tela aberta por cima fica numa coluna no computador` (1366, `PedidoLojaScreen(pedidoId: 'ped1')` aberta direto): largura do primeiro `ListView` ≤ 760 e do botão `Marcar como em separação` ≤ 760.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/painel_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**:
  - `ColunaCentral`: `Align(alignment: Alignment.topCenter, heightFactor: 1, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 760), child: child))` — o `heightFactor: 1` deixa usar o mesmo widget no `body` e no `bottomNavigationBar` sem ocupar a tela toda.
  - `PropostasScreen` vira `StatefulWidget` com `String? _aberta` (id da proposta). No computador: `TabBar(isScrollable: true, tabAlignment: TabAlignment.start)` e, no corpo, `Row`: listas com 440 px de largura (cartões com `onAbrir: (p) => setState(() => _aberta = p.id)` e `selecionado: p.id == _aberta`), `VerticalDivider(width: 1)` e a coluna aberta. A coluna busca `servico.proposta(_aberta)`: nula → `EstadoVazio(titulo: 'Escolha uma proposta ou pedido', texto: 'Toque numa proposta ou pedido da lista para abrir aqui.')`; sem pedido → `PropostaLojaScreen(key: ValueKey(p.id), id: p.id, embutida: true)`; com pedido → `PedidoLojaScreen(key: ValueKey(p.pedido!.id), pedidoId: p.pedido!.id, embutida: true)`. Em celular e tablet a tela fica como hoje.
  - `CartaoPropostaLoja`: com `onAbrir`, chama ele em vez de empilhar a tela; `selecionado` pinta o fundo de `c.superficieSutil`.
  - `embutida` nas duas telas: sem `Scaffold` nem `AppBar`; `Column(crossAxisAlignment: stretch)` com o conteúdo em `Expanded` e o rodapé de ações embaixo; "não encontrada" vira só o `EstadoVazio`. Sem `embutida`, `body` e `bottomNavigationBar` ganham `ColunaCentral`.
  - `ColunaCentral` também no `body` e no `bottomNavigationBar` de `ContrapropostaScreen`, `OfertaScreen`, `ImportarPlanilhaScreen`, `EquipeScreen` e `CadastroLojaScreen`.
- [ ] **Step 4: Run** `dart format lib test; flutter analyze; flutter test` no Parceiros — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(parceiros): propostas em duas colunas no computador`.

### Task 4: Parceiros — plataforma web e publicação

**Files:**
- Create: `dailyobra_parceiro/web/` (`index.html`, `flutter_bootstrap.js`, `manifest.json`, `favicon.png`, `icons/`, `marca/simbolo.png`, `marca/simbolo_claro.png`)
- Modify: `dailyobra_parceiro/pubspec.yaml` (bloco `flutter_launcher_icons`), `.github/workflows/web.yml`, `README.md`

- [ ] **Step 1: Generate** — `cd dailyobra_parceiro; flutter create --platforms web --org com.dailyobra .`. Expected: pasta `web/` nova; o resto do `git status` só no `.metadata`. Apague o que mais ele criar (por exemplo `test/widget_test.dart`).
- [ ] **Step 2: Brand** — copie `dailyobra/web/index.html`, `dailyobra/web/flutter_bootstrap.js` (é ele que tira a tela de abertura) e `dailyobra/web/marca/` por cima do gerado. No `index.html`: `description` `Painel da loja parceira do DailyObra: propostas, pedidos e produtos.`, `apple-mobile-web-app-title` e `<title>` `DailyObra Parceiros`, `aria-label` `Carregando o DailyObra Parceiros`, e o ícone da aba vira `<link rel="icon" type="image/png" href="favicon.png">`. `manifest.json` igual ao do site com `name` e `short_name` `DailyObra Parceiros` e a mesma `description`.
- [ ] **Step 3: Icons** — no `pubspec.yaml`, dentro de `flutter_launcher_icons`:

```yaml
  web:
    generate: true
    image_path: "assets/icone/icone.png"
    background_color: "#F6F7F9"
    theme_color: "#F36E21"
```

  Rode `dart run flutter_launcher_icons`. Expected: `web/favicon.png` e `web/icons/*.png` com o capacete sobre o grafite. Se mexer em `android/` ou `ios/`, desfaça com `git checkout -- android ios`; confira que o `manifest.json` manteve os textos do Step 2.
- [ ] **Step 4: Workflow** — em `.github/workflows/web.yml`, depois do passo do construtor:

```yaml
      - name: Painel da loja (análise e testes)
        working-directory: dailyobra_parceiro
        run: |
          flutter pub get
          flutter analyze
          flutter test
```

  e depois de `Gerar o site`:

```yaml
      # O painel da loja fica em https://<usuario>.github.io/<repositorio>/parceiros/
      - name: Gerar o painel da loja
        working-directory: dailyobra_parceiro
        run: |
          flutter build web --release --base-href "/${{ github.event.repository.name }}/parceiros/"
          cp -r build/web ../dailyobra/build/web/parceiros
```

- [ ] **Step 5: README** — seção `Painel da loja na web`: o endereço, que sai junto com o site a cada push no `main`, e a ação do usuário (incluir o endereço nas URLs de redirecionamento do Supabase, em Authentication > URL Configuration, para os links de cadastro e de "Esqueci a senha").
- [ ] **Step 6: Build** — `cd dailyobra_parceiro; MSYS_NO_PATHCONV=1 flutter build web --release --base-href /dailyobra/parceiros/`. Expected: `√ Built build\web`; `grep -c '<title>DailyObra Parceiros</title>' build/web/index.html` → 1; `grep -c 'href="/dailyobra/parceiros/"' build/web/index.html` → 1.
- [ ] **Step 7: Commit** — `feat(parceiros): painel na web publicado em /parceiros/`.

### Task 5: Publicar e conferir no ar

- [ ] **Step 1: Run all suites** — `flutter analyze` e `flutter test` nos três pacotes e `node --test dailyobra/test/pagina_pagar_test.mjs`. Expected: tudo verde.
- [ ] **Step 2: Merge and push** — `main` avança para o branch (fast-forward) e `git push origin main`.
- [ ] **Step 3: Workflow** — `Site no GitHub Pages` do commit termina com `success` (API do GitHub por `curl`).
- [ ] **Step 4: No ar** — `/dailyobra/parceiros/` responde 200 com `<title>DailyObra Parceiros</title>`; no navegador abre a tela de entrada do Parceiros e, depois de atualizar a página, abre de novo o painel; `/dailyobra/` abre o site do construtor e `/dailyobra/pagar/?c=invalido` mostra `Link inválido`.
- [ ] **Step 5: Relatório** — lembrar o usuário de incluir `https://dailyobrabr-creator.github.io/dailyobra/parceiros/` nas URLs de redirecionamento do Supabase e de conferir, logado no navegador, a importação de planilha e a troca de logo e capa (escolher, reduzir e enviar: o código é o mesmo do celular, mas o seletor da web só dá para testar com conta). Os APKs não precisam ser refeitos: no celular nada muda.
