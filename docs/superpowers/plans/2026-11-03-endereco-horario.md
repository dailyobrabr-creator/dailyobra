# Endereço com CEP e horário por seleção — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No cadastro e em Minha loja, a loja digita o CEP e o app preenche o endereço; o horário é escolhido por dia, com intervalo opcional; o construtor vê o endereço montado e as outras unidades.

**Architecture:** O banco guarda o endereço em campos e um gatilho monta o texto de exibição (`endereco`), que os apps antigos já leem. O horário continua texto, escrito pelo `escreverHorario` do comum no formato que o `lerHorario` lê. No Parceiros, dois blocos novos (`CamposEndereco`, com a busca no ViaCEP, e `EditorHorario`) entram no cadastro e em Minha loja; o DailyObra mostra a linha das outras unidades.

**Tech Stack:** Flutter 3.47 / Dart 3.13 (`http` 1.6.0, já resolvido no lock), Supabase (Postgres, gatilho, função `criar_loja`), ViaCEP.

**Spec:** `docs/superpowers/specs/2026-11-03-endereco-horario-design.md`

## Global Constraints

- ViaCEP: `GET https://viacep.com.br/ws/{8 dígitos}/json/`; `erro` na resposta (`true` ou `"true"`) = CEP não encontrado.
- Endereço montado: `Rua, Número[, Complemento][ – Bairro], CEP 00000-000` (travessão U+2013 com espaços), ex.: `R. Fernando Corrêa da Costa, 1500, sala 2 – Vila Operária, CEP 78700-000`.
- Horário: listas de 15 em 15 minutos de `00:00` a `23:45`; texto como `Seg a sex 7h às 11h e 13h às 18h; sáb 7h às 12h` (dias `seg ter qua qui sex sáb dom`; 2 dias seguidos com `e`, 3 ou mais com `a`; horas `7h`, `7h30`; trechos com `; `; primeira letra maiúscula); todos fechados = texto vazio; até 300 caracteres.
- Textos exatos: `CEP`, `00000-000`, `Rua`, `Número`, `Complemento`, `Bairro`, `Cidade`, `UF`, `Outras unidades`, `Buscando o CEP…`, `CEP não encontrado.`, `Não deu para buscar o CEP agora. Preencha o endereço à mão.`, `Endereço atual: {texto}`, `Outras unidades: {texto}`, `Informe o CEP com 8 números.`, `Informe a rua.`, `Informe o número (ou S/N).`, `Informe a cidade.`, `Escolha o estado.`, `Seg` … `Dom`, `Fechado`, `Abre`, `Fecha`, `Intervalo`, `Saída`, `Volta`, `Copiar segunda para terça a sexta`, `Confira o horário de {dia}.` (`segunda`, `terça`, `quarta`, `quinta`, `sexta`, `sábado`, `domingo`), `Não deu para ler o horário anterior ({texto}). Escolha de novo.`, `CEP inválido.`.
- Ao abrir um dia, o padrão é `08:00` às `18:00`; ao ligar o intervalo, `12:00` e `13:00`.
- Cadastro: CEP, Rua, Número, Cidade e UF obrigatórios. Minha loja: o endereço só é conferido e enviado quando a loja preenche o CEP; o horário só é enviado quando o editor foi alterado (assim a loja antiga não perde o texto que tinha).
- Banco: `security definer`, `set search_path = ''`, erros `P0001` em português; teste SQL numa transação que termina com `raise exception 'RESULTADO: ...'`.
- Nunca rodar `dart format` no `dailyobra_comum`; os apps usam `dart format lib test`.
- O push no `main` publica o site, a migração vai para o banco de produção pelo MCP e os dois APKs são gerados de novo (aprovados junto com este plano).

## Review Focus

1. CEP colado com traço ou espaço (`78700-000`, ` 78700 000`): busca com os 8 números — teste `CEP com traço busca os 8 números` (Task 3).
2. A pessoa troca o CEP antes da primeira resposta chegar: a resposta antiga não preenche nada — teste `resposta atrasada de outro CEP é ignorada` (Task 3).
3. Loja antiga (só texto, sem CEP) salva outra coisa em Minha loja: o endereço e o horário antigos ficam como estavam — teste `loja antiga salva sem mexer no endereço nem no horário` (Task 5).
4. Dia fechado no meio da semana: `Seg a qua …; sex …`, e o texto volta igual pelo `lerHorario` — teste `dias separados` (Task 1).
5. Horário antigo que o app não entende: sem mexer no editor, ele não é trocado — teste `sem mexer, o horário antigo fica` (Task 4) e o da Task 5.

---

### Task 0: Setup

- [ ] Branch `endereco-horario` a partir do `main` (com a spec e este plano), no próprio checkout.
- [ ] Workspace e ledger pelo `sdd-workspace` deste plano.

### Task 1: Comum — texto do horário e campos da loja

**Files:**
- Modify: `dailyobra_comum/lib/src/marketplace/horario.dart` (nova `escreverHorario`), `dailyobra_comum/lib/src/marketplace/modelos.dart` (`Loja`)
- Test: `dailyobra_comum/test/horario_test.dart`, `dailyobra_comum/test/modelos_test.dart`

**Interfaces:**
- Produces: `String escreverHorario(List<FaixaHorario> faixas)` (o inverso de `lerHorario`; faixas fora de ordem são ordenadas); `Loja` ganha `String? cep` e `String logradouro, numero, complemento, bairro, outrasUnidades` (padrão `''`), lidos de `cep`, `logradouro`, `numero`, `complemento`, `bairro`, `outras_unidades`.

- [ ] **Step 1: Write the failing tests** (`f(dia, inicio, fim)` = `FaixaHorario` em minutos):
  - `escreve dias úteis iguais e sábado`: seg a sex 420–1080 e sáb 420–720 → `Seg a sex 7h às 18h; sáb 7h às 12h`.
  - `escreve intervalo`: seg a sex 420–660 e 780–1080 → `Seg a sex 7h às 11h e 13h às 18h`.
  - `meia hora`: seg 450–1050, ter a sex 420–1050, sáb 420–750 → `Seg 7h30 às 17h30; ter a sex 7h às 17h30; sáb 7h às 12h30`.
  - `dois dias seguidos usam e`: sáb e dom 480–720 → `Sáb e dom 8h às 12h`.
  - `dias separados`: seg a qua 480–1080 e sex 480–1080 → `Seg a qua 8h às 18h; sex 8h às 18h`.
  - `tudo fechado`: `[]` → `''`.
  - `ida e volta`: para cada texto acima, `escreverHorario(lerHorario(t)!) == t`.
  - `loja com endereço em campos` (`modelos_test.dart`): `Loja.fromJson` com `cep: '78700000'`, `logradouro`, `numero`, `complemento`, `bairro`, `outras_unidades` → campos iguais; sem eles → `cep` nulo e os outros `''`.
- [ ] **Step 2: Run** `cd dailyobra_comum; flutter test test/horario_test.dart test/modelos_test.dart` — Expected: FAIL (`escreverHorario` não existe; `Loja` sem os campos).
- [ ] **Step 3: Implement.** Agrupar por dia (1 a 7) as faixas ordenadas; dias seguidos com as mesmas faixas viram um trecho (`seg`, `sáb e dom`, `ter a sex`); faixas do dia unidas por ` e `; trechos por `; `; primeira letra maiúscula.
- [ ] **Step 4: Run** `cd dailyobra_comum; flutter analyze; flutter test` — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(comum): texto do horário a partir das faixas e endereço em campos na loja`.

### Task 2: Banco — endereço em campos

**Files:**
- Create: `supabase/migrations/20261103210000_endereco_loja.sql`, `supabase/tests/endereco_loja_test.sql`

**Interfaces:**
- Produces: colunas `lojas.cep` (`^\d{8}$`), `logradouro` (≤120), `numero` (≤20), `complemento` (≤60), `bairro` (≤80), `outras_unidades` (≤200); `lojas_endereco_check` e `lojas_horario_check` passam a ≤300; gatilho `lojas_endereco` (antes de inserir ou atualizar) que, com `cep`, monta `endereco` como na Global Constraints; `criar_loja(p jsonb)` aceita `cep` (só dígitos; diferente de 8 → `CEP inválido.`), `logradouro`, `numero`, `complemento`, `bairro`, `outras_unidades`, e o resto da função fica como está.

- [ ] **Step 1: Write the failing test** no padrão de `supabase/tests/importacao_estoque_test.sql`:
  - `criar_loja monta o endereço`: CEP `78700-000`, `R. Fernando Corrêa da Costa`, `1500`, `sala 2`, `Vila Operária`, outras unidades `Sagrada Família e Médici` → `endereco` = `R. Fernando Corrêa da Costa, 1500, sala 2 – Vila Operária, CEP 78700-000`, `cep` = `78700000`, `outras_unidades` gravado.
  - `sem complemento e bairro`: o dono apaga os dois → `R. Fernando Corrêa da Costa, 1500, CEP 78700-000`.
  - `cliente não troca o texto montado`: o dono grava `endereco = 'qualquer'` → continua o montado.
  - `loja sem CEP mantém o texto`: loja criada sem CEP com `endereco` `Lojas Vila Operária (matriz)` → igual; o dono troca o texto → fica o novo.
  - `CEP inválido`: `criar_loja` com `cep: '7870'` → `CEP inválido.`.
  - `horário até 300`: 300 caracteres gravam; 301 são recusados.
- [ ] **Step 2: Run** pelo MCP `execute_sql` — Expected: falha (coluna `cep` não existe).
- [ ] **Step 3: Implement** a migração e aplicar pelo MCP `apply_migration` com o nome `endereco_loja` (a `criar_loja` nova parte da atual em `20261031130200_marketplace_funcoes.sql`).
- [ ] **Step 4: Run** o teste — Expected: `RESULTADO: 6 de 6 ok`.
- [ ] **Step 5: Commit** — `feat(banco): endereço da loja em campos, montado pelo banco`.

### Task 3: Parceiros — busca do CEP e campos do endereço

**Files:**
- Modify: `dailyobra_parceiro/pubspec.yaml` (`http: ^1.6.0`)
- Create: `dailyobra_parceiro/lib/services/cep_service.dart`, `dailyobra_parceiro/lib/screens/campos_endereco.dart`
- Test: `dailyobra_parceiro/test/campos_endereco_test.dart`

**Interfaces:**
- Produces:
  - `class EnderecoCep { const EnderecoCep({required this.logradouro, required this.bairro, required this.cidade, required this.uf}); final String logradouro, bairro, cidade, uf; }`; `typedef BuscarCep = Future<EnderecoCep?> Function(String cep)`; `Future<EnderecoCep?> buscarCep(String cep, {http.Client? cliente})` (nulo = não encontrado; falha de rede ou resposta estranha → `FalhaComMensagem('Não deu para buscar o CEP agora. Preencha o endereço à mão.')`).
  - `class ControleEndereco` com os controladores `cep`, `logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `outrasUnidades` e `String? uf`; `ControleEndereco({String? cep, String logradouro = '', String numero = '', String complemento = '', String bairro = '', String cidade = '', String? uf, String outrasUnidades = ''})`; `bool get preenchido` (CEP com algum dígito); `Map<String, String> validar()` (chaves `cep`, `logradouro`, `numero`, `cidade`, `uf` com os textos da Global Constraints); `Map<String, dynamic> campos()` → `cep` (8 dígitos), `logradouro`, `numero`, `complemento` e `bairro` (nulos se vazios), `cidade`, `uf`, `outras_unidades` (nulo se vazio); `dispose()`.
  - `class CamposEndereco extends StatefulWidget { const CamposEndereco({super.key, required this.controle, this.erros = const {}, this.buscar}); }` (`buscar` padrão `buscarCep`).

- [ ] **Step 1: Write the failing tests:**
  - `buscarCep lê o ViaCEP` (com `MockClient` de `package:http/testing.dart`): resposta `{"cep":"78700-000","logradouro":"R. Fernando Corrêa da Costa","bairro":"Vila Operária","localidade":"Rondonópolis","uf":"MT"}` → os 4 campos; `{"erro": "true"}` e `{"erro": true}` → nulo; status 500 → `FalhaComMensagem` com o texto da Global Constraints; a URL pedida é `https://viacep.com.br/ws/78700000/json/`.
  - `CEP preenche rua, bairro, cidade e UF`: digitar `78700000` com a busca falsa → os campos mostram os valores; digitar `1500` em `Número` → `campos()` = `{'cep': '78700000', 'logradouro': 'R. Fernando Corrêa da Costa', 'numero': '1500', 'complemento': null, 'bairro': 'Vila Operária', 'cidade': 'Rondonópolis', 'uf': 'MT', 'outras_unidades': null}`.
  - `CEP com traço busca os 8 números`: colar ` 78700-000 ` → a busca recebe `78700000`.
  - `CEP não encontrado` (busca devolve nulo) e `falha de rede` (busca lança a `FalhaComMensagem`) → as mensagens na tela; os campos continuam editáveis.
  - `resposta atrasada de outro CEP é ignorada`: com `Completer`s, digitar `78700000` e depois `01001000`; responder o segundo e depois o primeiro → ficam os dados do segundo.
  - `validar mostra o que falta`: tudo vazio → as 5 mensagens.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter pub get; flutter test test/campos_endereco_test.dart` — Expected: FAIL (arquivos não existem).
- [ ] **Step 3: Implement.** A busca dispara quando o CEP chega a 8 dígitos (ignorando traço e espaços), mostra `Buscando o CEP…`, preenche e põe o foco em `Número`; UF numa lista com as 27 siglas (a mesma do cadastro, movida para cá e usada pelos dois).
- [ ] **Step 4: Run** `cd dailyobra_parceiro; dart format lib test; flutter analyze; flutter test test/campos_endereco_test.dart` — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(parceiros): endereço pelo CEP`.

### Task 4: Parceiros — editor do horário

**Files:**
- Create: `dailyobra_parceiro/lib/screens/editor_horario.dart`
- Test: `dailyobra_parceiro/test/editor_horario_test.dart`

**Interfaces:**
- Consumes: `lerHorario`, `escreverHorario`, `FaixaHorario` (comum, Task 1).
- Produces: `class ControleHorario extends ChangeNotifier` com `ControleHorario.doTexto(String texto)`; por dia (1 = segunda … 7 = domingo) `aberto`, `abre`, `fecha`, `intervalo`, `saida`, `volta` (minutos), alterados por `void abrirDia(int dia, bool aberto)`, `void definir(int dia, {int? abre, int? fecha, bool? intervalo, int? saida, int? volta})` e `void copiarSegunda()`; `String? naoLido` (o texto que não deu para ler); `bool alterado`; `String texto()`; `String? validar()`. `class EditorHorario extends StatelessWidget { const EditorHorario({super.key, required this.controle}); }`.

- [ ] **Step 1: Write the failing tests:**
  - `texto do horário escolhido`: seg a sex 07:00–18:00 com intervalo 11:00–13:00 e sáb 07:00–12:00 → `Seg a sex 7h às 11h e 13h às 18h; sáb 7h às 12h`.
  - `abre o horário salvo`: `doTexto('Seg 7h30 às 17h30; ter a sex 7h às 17h30; sáb 7h às 12h30')` → `texto()` igual, `alterado` falso; segunda aberta 450–1050; domingo fechado.
  - `sem mexer, o horário antigo fica`: `doTexto('Comercial')` → todos fechados, `naoLido` `Comercial`, `alterado` falso; o editor mostra `Não deu para ler o horário anterior (Comercial). Escolha de novo.`.
  - `copiar segunda`: segunda 08:00–12:00 e 13:00–18:00 → `copiarSegunda()` → terça a sexta iguais; sábado como estava; `alterado` verdadeiro.
  - `validar`: segunda abre 18:00 e fecha 08:00 → `Confira o horário de segunda.`; sábado com saída depois da volta → `Confira o horário de sábado.`; certo → nulo.
  - `escolher no editor` (tela, claro e escuro): editor todo fechado; ligar `Seg` → aparecem `Abre` `08:00` e `Fecha` `18:00`; escolher `17:30` em `Fecha` → `texto()` = `Seg 8h às 17h30`.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/editor_horario_test.dart` — Expected: FAIL (arquivo não existe).
- [ ] **Step 3: Implement.** Dia com mais de 2 faixas no texto lido = não lido; abrir um dia usa 08:00–18:00; ligar o intervalo usa 12:00–13:00; listas `DropdownButton` com 96 horários.
- [ ] **Step 4: Run** `cd dailyobra_parceiro; dart format lib test; flutter analyze; flutter test test/editor_horario_test.dart` — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(parceiros): horário escolhido por dia`.

### Task 5: Parceiros — cadastro e Minha loja

**Files:**
- Modify: `dailyobra_parceiro/lib/services/loja_service.dart` (`DadosLoja` e `_colunas`), `dailyobra_parceiro/lib/screens/cadastro_loja_screen.dart`, `dailyobra_parceiro/lib/screens/minha_loja_screen.dart`
- Test: `dailyobra_parceiro/test/cadastro_test.dart`, `dailyobra_parceiro/test/painel_test.dart`

**Interfaces:**
- Consumes: `ControleEndereco`, `CamposEndereco`, `BuscarCep` (Task 3); `ControleHorario`, `EditorHorario` (Task 4).
- Produces: `DadosLoja` com `String? cep` e `logradouro`, `numero`, `complemento`, `bairro`, `outrasUnidades` (padrão `''`); `CadastroLojaScreen({super.key, this.criar, this.buscarCep})`; `MinhaLojaScreen({super.key, required this.tema, this.buscarCep})`.

- [ ] **Step 1: Write the failing tests:**
  - `cadastro_test.dart`: o ajudante `preencher` passa a digitar o CEP (busca falsa com Rondonópolis/MT) e o número; `campos válidos cadastram com o CNPJ só com dígitos` passa a conferir `cep` `78700000`, `logradouro`, `numero` `1500`, `cidade` `Rondonópolis`, `uf` `MT`, `horario` `''` e que `endereco` não vai; `cadastro vazio mostra o que falta` passa a esperar `Informe o CEP com 8 números.`, `Informe a rua.` e `Informe o número (ou S/N).`.
  - `painel_test.dart`: o teste `horário traz um exemplo no formato que o app lê` sai e entram:
    - `minha loja salva endereço e horário`: loja sem CEP com `endereco` `Lojas Vila Operária (matriz)` e `horario` `Seg a sex 7h às 18h` → mostra `Endereço atual: Lojas Vila Operária (matriz)`; digitar CEP e número, ligar sábado e salvar → a atualização tem os campos do endereço e `horario` `Seg a sex 7h às 18h; sáb 8h às 18h`.
    - `loja antiga salva sem mexer no endereço nem no horário`: mesma loja, com `horario` `Comercial`; mudar só a descrição e salvar → a atualização não tem `cep`, `logradouro`, `endereco` nem `horario`.
    - `minha loja abre com o endereço em campos`: loja com CEP → os campos já preenchidos e sem `Endereço atual`.
- [ ] **Step 2: Run** `cd dailyobra_parceiro; flutter test test/cadastro_test.dart test/painel_test.dart` — Expected: FAIL (campos novos ausentes).
- [ ] **Step 3: Implement.** O cadastro troca Cidade, UF, Endereço e Horário pelos blocos novos e manda `ControleEndereco.campos()` + `horario: controle.texto()`; Minha loja usa os blocos (Cidade e UF passam a ser editáveis), mostra `Endereço atual` quando não há CEP e o texto existe, confere o endereço só se `preenchido` e manda o horário só se `alterado` (vazio → nulo); a mensagem de `validar()` do horário aparece num `Aviso` acima do botão de salvar.
- [ ] **Step 4: Run** `cd dailyobra_parceiro; dart format lib test; flutter analyze; flutter test` — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(parceiros): cadastro e Minha loja com endereço pelo CEP e horário por dia`.

### Task 6: DailyObra — outras unidades

**Files:**
- Modify: `dailyobra/lib/services/catalogo_service.dart:138` (coluna `outras_unidades`), `dailyobra/lib/screens/loja_screen.dart` (linha nova)
- Test: `dailyobra/test/loja_test.dart`

**Interfaces:**
- Consumes: `Loja.outrasUnidades` (Task 1).

- [ ] **Step 1: Write the failing test** `loja mostra outras unidades`: loja `a` com `endereco` `R. A, 100, CEP 78700-000` e `outrasUnidades` `Sagrada Família e Médici` → `Outras unidades: Sagrada Família e Médici` na tela; sem `outrasUnidades` a linha não aparece.
- [ ] **Step 2: Run** `cd dailyobra; flutter test test/loja_test.dart` — Expected: FAIL (texto não aparece).
- [ ] **Step 3: Implement** a linha depois do endereço, com `Icons.storefront_outlined`, e a coluna no `select` das lojas.
- [ ] **Step 4: Run** `cd dailyobra; dart format lib test; flutter analyze; flutter test` — Expected: tudo verde.
- [ ] **Step 5: Commit** — `feat(construtor): outras unidades da loja`.

### Task 7: README, suítes, publicação e APKs

- [ ] README: no cadastro e em Minha loja, o endereço pelo CEP (ViaCEP), outras unidades e o horário por dia com intervalo; `endereco_loja_test.sql` na lista de `Verificar`. Commit — `docs: endereço pelo CEP e horário por dia`.
- [ ] Suítes: `flutter analyze` e `flutter test` em `dailyobra_comum`, `dailyobra` e `dailyobra_parceiro`; `node --test dailyobra/test/pagina_pagar_test.mjs`; `endereco_loja_test.sql` (6 de 6).
- [ ] Revisão final do branch, antes de publicar.
- [ ] Publicar: `main` avança para o branch (fast-forward), `git push origin main`, workflow `Site no GitHub Pages` com `success`, `/dailyobra/` e `/dailyobra/parceiros/` respondendo 200.
- [ ] APKs: `cd D:\dev\dailyobra_app\dailyobra_parceiro; flutter build apk --release` e `cd D:\dev\dailyobra_app\dailyobra; flutter build apk --release` pelo terminal, com cópia para `apk\DailyObraParceiros.apk` e `apk\DailyObra.apk`.
