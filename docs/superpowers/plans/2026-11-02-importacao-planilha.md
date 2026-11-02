# Importação de planilha de preços (Parceiros) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A loja sobe a planilha de preços (CSV ou .xlsx) no app Parceiros, confere a ligação de cada produto ao catálogo e grava tudo de uma vez.

**Architecture:** Leitura, detecção de colunas, leitura de preço e montagem da importação ficam no pacote comum (`planilha_precos.dart`), reaproveitando a pontuação da lista inteligente por um `ReconhecedorDeProdutos`. O Parceiros ganha a tela `ImportarPlanilhaScreen` e um `upsert` em lote no `OfertasService`. O banco não muda.

**Tech Stack:** Flutter 3.47 / Dart 3.13; `archive ^4.0.0` e `xml ^7.0.0` (comum, leitor próprio de .xlsx); `file_picker ^13.3.1` (Parceiros); supabase_flutter 2.18.

**Spec:** `docs/superpowers/specs/2026-11-02-importacao-planilha-design.md`

## Global Constraints

- Até 3.000 linhas de produto; no .xlsx vale a primeira planilha; arquivo .csv ou .xlsx.
- Promoção: uma validade para todas, padrão 7 dias; promoção maior ou igual ao preço é ignorada na linha.
- Gravação: um `upsert` em lote com `onConflict: 'loja_id,item_id'`, enviando `loja_id`, `item_id`, `preco`, `preco_promocional`, `promo_ate`; disponibilidade e pausa não vão no lote; nada é apagado.
- Só dono e gerente (`LojaService.instance.meuPapel.gere`) veem a importação.
- Banco sem mudanças (restrições: `preco > 0`, promoção `< preco` e com `promo_ate`).
- **Não rodar `dart format` no `dailyobra_comum`:** o pacote usa linhas longas; editar à mão no mesmo estilo. No `dailyobra_parceiro`, `dart format lib test` normalmente.
- Textos da tela em português do Brasil; números no formato brasileiro.
- Ruling do plano: o pacote `excel` prende `archive 3` e `xml 6`, incompatíveis com o `image` dos apps (`archive 4.6`, `xml 7`); por isso o leitor de .xlsx é próprio, como a spec previa.

## Review Focus

1. Planilha exportada com título, data ou linhas em branco antes do cabeçalho: o cabeçalho é procurado nas 10 primeiras linhas.
2. Preço como célula numérica do Excel (45.9), com ponto decimal em texto ("45.90"), com milhar ("1.234" e "1.234,50") e com texto junto ("R$ 45,90 / sc").
3. Linhas vazias no meio ou no fim e linhas com menos colunas que o cabeçalho: ignoradas ou lidas sem erro.
4. Nome com marca e medida colada ("CIMENTO CP II 50KG VOTORAN") e nome ambíguo ("VERGALHAO CA-50 BARRA 12M"): ligado e escolher, nessa ordem.
5. Planilha com exatamente 3.000 linhas monta; com 3.001 é recusada com mensagem.

---

### Task 1: Reconhecedor de produtos e unidade canônica (comum)

**Files:**
- Modify: `dailyobra_comum/lib/src/marketplace/smart_list.dart` (perto de `interpretarLista`, linhas 162-175)
- Test: `dailyobra_comum/test/smart_list_test.dart` (novo grupo no fim)

**Interfaces:**
- Produces:
  - `class ReconhecedorDeProdutos { ReconhecedorDeProdutos(List<ItemCatalogo> catalogo); LinhaSmartList reconhecer(String nome); }` — monta os índices uma vez; `reconhecer` chama `_decidir(nome, null, null, normalizar(nome), _indices)` (sem ler quantidade no começo do nome).
  - `String unidadeCanonica(String unidade)` — `_canonica(normalizar(unidade))`.

- [ ] **Step 1: Testes que falham** (grupo `ReconhecedorDeProdutos`, catálogo do arquivo):

```dart
final r = ReconhecedorDeProdutos(catalogo);
expect(r.reconhecer('CIMENTO CP II 50KG VOTORAN').item?.id, 'cimento-cp2-50kg');
final ferro = r.reconhecer('VERGALHAO CA-50 BARRA 12M');
expect(ferro.tipo, TipoLinha.escolher);
expect(ferro.candidatos.map((i) => i.id), containsAll(['vergalhao-5-16', 'vergalhao-3-8']));
expect(r.reconhecer('MANGUEIRA DE JARDIM 20M').tipo, TipoLinha.naoReconhecido);
expect(r.reconhecer('100 TIJOLO 8 FUROS').item?.id, 'tijolo-8-furos');
expect(unidadeCanonica('m²'), unidadeCanonica('M2'));
expect(unidadeCanonica('unidade'), unidadeCanonica('UN'));
expect(unidadeCanonica('Saco'), unidadeCanonica('SC'));
expect(unidadeCanonica('caixa'), isNot(unidadeCanonica('m²')));
```

- [ ] **Step 2: Rodar.** `cd dailyobra_comum && flutter test test/smart_list_test.dart` → FAIL (`ReconhecedorDeProdutos` não existe).
- [ ] **Step 3: Implementar** as duas peças acima.
- [ ] **Step 4: Rodar** o mesmo comando → PASS; `flutter analyze` sem problemas.
- [ ] **Step 5: Commit** `feat(comum): reconhecedor de produtos e unidade canônica`.

### Task 2: Leitura da planilha e montagem da importação (comum)

**Files:**
- Create: `dailyobra_comum/lib/src/marketplace/planilha_precos.dart`; export em `dailyobra_comum/lib/dailyobra_comum.dart`
- Modify: `dailyobra_comum/pubspec.yaml` (`archive: ^4.0.0`, `xml: ^7.0.0`)
- Test: `dailyobra_comum/test/planilha_precos_test.dart` (com catálogo próprio: cimento saco, tijolo un, vergalhões barra, piso `revestimento-ceramico` m²)

**Interfaces:**
- Consumes: `ReconhecedorDeProdutos`, `unidadeCanonica` (Task 1); `Oferta` (modelos).
- Produces:
  - `class PlanilhaInvalida implements Exception { const PlanilhaInvalida(this.mensagem); final String mensagem; }`
  - `const maxLinhasImportacao = 3000;`
  - `List<List<String>> lerCsv(String texto)` — separador da primeira linha não vazia (`;`, `,` ou tabulação), aspas (com `""`), BOM, `\r\n`.
  - `List<List<String>> lerXlsx(Uint8List bytes)` — primeira planilha (`xl/workbook.xml` + `_rels`), `sharedStrings` (inclusive texto com `<r>`), `inlineStr`, células vazias preenchidas pela referência (`B3` → coluna 1); número vira texto no formato brasileiro (`45.9` → `"45,9"`, `1234` → `"1234"`).
  - `List<List<String>> lerPlanilha(String nomeArquivo, Uint8List bytes)` — escolhe pela extensão (`.csv`, `.xlsx`; outra lança `PlanilhaInvalida('Envie um arquivo .csv ou .xlsx.')`); descarta linhas totalmente vazias; lança `PlanilhaInvalida` para vazia ("A planilha está vazia."), só cabeçalho ("A planilha só tem o cabeçalho.") e acima de 3.000 produtos ("A planilha passa de 3.000 produtos. Divida em partes.").
  - `class ColunasPlanilha { const ColunasPlanilha({this.linhaCabecalho = 0, this.nome, this.preco, this.promocao, this.unidade, this.codigo}); final int linhaCabecalho; final int? nome, preco, promocao, unidade, codigo; bool get completas; ColunasPlanilha copyWith({int? nome, int? preco}); }`
  - `ColunasPlanilha detectarColunas(List<List<String>> linhas)` — procura nas 10 primeiras linhas a primeira com nome e preço; senão, `linhaCabecalho: 0` e as colunas achadas; nomes da spec §2, sem acento e sem caixa.
  - `double? lerPreco(String texto)` — primeiro número do texto; com `.` e `,` o último é o decimal; só `,` é decimal; só `.` é milhar quando todos os grupos depois do primeiro têm 3 dígitos, senão decimal; `null` se não houver número ou se for `<= 0`.
  - `enum GrupoImportacao { ligado, escolher, fora }` e `enum AvisoImportacao { unidadeDiferente, repetido, precoInvalido, promocaoIgnorada }`
  - `class LinhaImportacao { final int numero; final String nome; final String? codigo; final String? unidadePlanilha; final GrupoImportacao grupo; final ItemCatalogo? item; final List<ItemCatalogo> candidatos; final double? preco; final double? promocao; final Set<AvisoImportacao> avisos; final bool marcada; LinhaImportacao copyWith({ItemCatalogo? item, double? preco, bool? marcada}); }` — `numero` é a linha na planilha (1 = primeira).
  - `List<LinhaImportacao> montarImportacao(List<List<String>> linhas, ColunasPlanilha colunas, List<ItemCatalogo> catalogo)` — regras da spec §2.4: ligado marcada salvo `unidadeDiferente` ou `precoInvalido`; escolher e fora desmarcadas; entre marcadas no mesmo item fica marcada só a de menor preço (as outras ganham `repetido`); promoção `>= preco` vira `null` com `promocaoIgnorada`.
  - `List<Oferta> ofertasDaImportacao(List<LinhaImportacao> linhas, {required String lojaId, DateTime? promoAte})` — só marcadas com item e preço; promoção só quando há `promoAte`.

- [ ] **Step 1: Testes que falham**, um por regra:
  - `lerCsv`: `'﻿Produto;Preço\r\n"Cal; 20 kg";12,5\r\n'` → `[['Produto','Preço'],['Cal; 20 kg','12,5']]`; o mesmo com `,` e com tabulação; aspas duplas internas (`"Tubo ""100"""`).
  - `lerPreco`: `'R$ 1.234,56'`→1234.56; `'1234,56'`→1234.56; `'45.90'`→45.9; `'1.234'`→1234; `'45,90 / sc'`→45.9; `'45,9'`→45.9; `'0'`, `''`, `'sob consulta'`→null.
  - `detectarColunas`: cabeçalho na linha 0 com "Descrição", "Valor unitário", "Preço promocional", "UN", "SKU" → índices certos; título e linha vazia antes do cabeçalho → `linhaCabecalho: 2`; "Mercadoria;Custo" → `completas == false`.
  - `lerXlsx`: .xlsx montado no teste com `ZipEncoder` (`[Content_Types].xml`, `xl/workbook.xml`, `xl/_rels/workbook.xml.rels`, `xl/sharedStrings.xml`, `xl/worksheets/sheet1.xml`). Células: `A1` "Produto" (compartilhado), `B1` "Preço" (compartilhado, em dois `<r>`: "Pre" + "ço"), `C1` "Un" (`inlineStr`); `A2` "CIMENTO CP II 50KG" (compartilhado), `B2` número `45.9`, sem `C2`; sem `A3`, `B3` número `1234`. Esperado: `[['Produto', 'Preço', 'Un'], ['CIMENTO CP II 50KG', '45,9'], ['', '1234']]`; o mesmo arquivo por `lerPlanilha('tabela.xlsx', bytes)`.
  - `lerPlanilha`: `.pdf` → `PlanilhaInvalida('Envie um arquivo .csv ou .xlsx.')`; linhas vazias no meio e no fim são descartadas (`'Produto;Preço\n\nCAL;12\n;\n'` → 2 linhas); só cabeçalho e vazia lançam; cabeçalho + 3.000 linhas passa; + 3.001 lança.
  - `montarImportacao`: cimento ligado e marcado; vergalhão em escolher, desmarcado; mangueira fora; cimento com unidade "CX" → `unidadeDiferente`, desmarcado; duas linhas de cimento (45,90 e 44,50) → só a de 44,50 marcada, a outra com `repetido`; preço "sob consulta" → `precoInvalido`, desmarcado; promoção 50 com preço 45 → `promocao == null` e `promocaoIgnorada`; linha com menos colunas lida sem erro.
  - `ofertasDaImportacao`: só as marcadas, com `lojaId`; promoção só com `promoAte`.
- [ ] **Step 2: Rodar.** `cd dailyobra_comum && flutter test test/planilha_precos_test.dart` → FAIL (arquivo não existe).
- [ ] **Step 3: Implementar** `planilha_precos.dart` e as dependências (`flutter pub add archive:^4.0.0 xml:^7.0.0` no comum); conferir que `flutter pub get` resolve também em `dailyobra` e `dailyobra_parceiro`.
- [ ] **Step 4: Rodar** o teste → PASS; `flutter test` e `flutter analyze` do comum sem falhas.
- [ ] **Step 5: Commit** `feat(comum): leitura de planilha de preços e montagem da importação`.

### Task 3: Tela de importação e gravação em lote (Parceiros)

**Files:**
- Create: `dailyobra_parceiro/lib/screens/importar_planilha_screen.dart`
- Modify: `dailyobra_parceiro/lib/services/ofertas_service.dart` (novo `salvarVarias`), `dailyobra_parceiro/lib/screens/produtos_screen.dart` (ação no `AppBar`), `dailyobra_parceiro/pubspec.yaml` (`file_picker: ^13.3.1`)
- Test: `dailyobra_parceiro/test/importar_planilha_test.dart`

**Interfaces:**
- Consumes: tudo de `planilha_precos.dart` (Task 2); `OfertasService.instance.catalogo`; `LojaService.instance.loja`, `meuPapel.gere`.
- Produces:
  - `Future<void> salvarVarias(List<Oferta> ofertas)` em `OfertasService` — um `upsert` da lista (campos das Global Constraints) e depois `carregar(lojaId)`; lança `FalhaComMensagem`.
  - `class ArquivoPlanilha { const ArquivoPlanilha(this.nome, this.bytes); final String nome; final Uint8List bytes; }`
  - `ImportarPlanilhaScreen({super.key, Future<ArquivoPlanilha?> Function()? escolher, Future<void> Function(List<Oferta>)? salvar})` — padrão: `FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv', 'xlsx'])` e `OfertasService.instance.salvarVarias`.
  - Em `ProdutosScreen`: `IconButton(tooltip: 'Importar planilha', icon: Icon(Icons.upload_file_outlined))` só quando `meuPapel.gere`, abrindo a tela.
- Tela, em passos: (1) explicação ("CSV ou Excel exportado do seu sistema, com uma coluna de produto e uma de preço") e botão **Escolher arquivo**; (2) se `!colunas.completas`, dois seletores "Coluna do produto" e "Coluna do preço" com os títulos do cabeçalho e o botão **Continuar**; (3) revisão: contagem `'$n ${n == 1 ? 'ligado' : 'ligados'} · $e para escolher · $f fora do catálogo'`, linhas com caixa de marcar, nome da planilha, item do catálogo (seletor quando há candidatos), unidade do catálogo e campo de preço; avisos em texto ("unidade da planilha: CX; o catálogo vende por saco", "repetido", "preço inválido", "promoção maior que o preço, ignorada"); se houver coluna de promoção, "Promoções valem até dd/mm" com seletor de data (padrão hoje + 7 dias); botão **Gravar N preços** (desligado com zero); (4) resumo `"N preços gravados · M fora do catálogo"`, a lista dos nomes fora do catálogo e **Voltar para produtos**. `PlanilhaInvalida` e `FalhaComMensagem` aparecem como aviso, sem sair do passo.

- [ ] **Step 1: Testes que falham** (catálogo de teste do `apoio.dart`: cimento, tijolo, torneira):
  - `'dono vê Importar planilha e vendedor não'` — `ProdutosScreen` com `preparar()` e com `preparar(papel: PapelLoja.vendedor)`; `find.byTooltip('Importar planilha')` → um e nenhum.
  - `'revisão conta os grupos e grava os preços marcados'` — `escolher` devolve CSV `'Produto;Preço\nCIMENTO CP II 50KG VOTORAN;45,90\nTIJOLO 8 FUROS;1,35\nMANGUEIRA DE JARDIM;30,00\n'`; tocar **Escolher arquivo**; `find.textContaining('2 ligados')`, `find.textContaining('1 fora do catálogo')`; trocar o preço do tijolo para `1,40`; tocar **Gravar 2 preços**; o `salvar` falso recebe `{cimento-cp2-50kg: 45.9, tijolo-8-furos: 1.4}`; aparece `'2 preços gravados'`.
  - `'unidade diferente vem desmarcada'` — CSV com `Produto;Preço;Unidade` e `CIMENTO CP II 50KG;45,90;CX` → botão **Gravar 0 preços** desligado e o aviso com "CX".
  - `'colunas desconhecidas pedem a escolha'` — CSV `'Mercadoria;Custo\nCIMENTO CP II 50KG;45,90\n'` → aparecem "Coluna do produto" e "Coluna do preço"; escolher "Mercadoria" e "Custo"; **Continuar** leva à revisão: `find.textContaining('1 ligado ·')`.
  - `'arquivo inválido avisa sem sair'` — `escolher` devolve `ArquivoPlanilha('lista.pdf', ...)` → `'Envie um arquivo .csv ou .xlsx.'`.
- [ ] **Step 2: Rodar.** `cd dailyobra_parceiro && flutter test test/importar_planilha_test.dart` → FAIL (tela não existe).
- [ ] **Step 3: Implementar** a tela, `salvarVarias`, a ação em `ProdutosScreen` e `flutter pub add file_picker:^13.3.1`.
- [ ] **Step 4: Rodar** → PASS; `dart format lib test`, `flutter analyze` e `flutter test` do Parceiros sem falhas.
- [ ] **Step 5: Commit** `feat(parceiros): importação de planilha de preços`.

### Task 4: Entrega

**Files:**
- Modify: `README.md` (raiz: seção da importação e como as três lojas de Rondonópolis entram), `dailyobra_parceiro/README.md` (tela de produtos)
- Create: `apk/DailyObra.apk`, `apk/DailyObraParceiros.apk` (novas versões; a pasta é ignorada pelo git)

- [ ] **Step 1:** `flutter analyze` e `flutter test` em `dailyobra_comum`, `dailyobra` e `dailyobra_parceiro`. Esperado: sem problemas e tudo passando.
- [ ] **Step 2:** No Terminal do usuário, `flutter build apk --release` nos dois apps; instalar no emulador; no Parceiros sem conta, conferir que abre no login sem erro no logcat. Copiar os APKs para `apk\`.
- [ ] **Step 3:** READMEs; commit `docs: importação de planilha e APKs` e `git push` (o site republica pelo Actions; conferir o resultado).
