# Parceiros na web — design

Data: 2026-11-02 · Primeiro subprojeto da Parte 2 (painel da loja dos protótipos "App da Obra").

## Objetivo

A loja usa o DailyObra Parceiros no computador, pelo navegador, com o mesmo app do celular: é onde estão o Santri, as
planilhas e o faturamento. Os próximos subprojetos (importação D+0, painel de resultados, Mesa do Gerente, fila de
faturamento, destaques) entram nesse painel já pensados para o computador.

Decidido na conversa:

- Mesmo app Flutter compilado para a web, publicado no mesmo site do GitHub Pages:
  `https://dailyobrabr-creator.github.io/dailyobra/parceiros/`. Nada de painel HTML à parte (repetiria regras e telas)
  nem de segundo site ou repositório.
- Visual atual do Parceiros e do site do construtor; só muda a moldura da navegação por largura de tela.
- Sem link no app do construtor por enquanto: a loja recebe o endereço (fica no README).
- Regras, dados e o app do celular não mudam.

## 1. Publicação

- `dailyobra_parceiro` ganha a plataforma web (pasta `web/`): título `DailyObra Parceiros`, `theme-color` `#F36E21`,
  tela de carregamento igual à do site do construtor e ícones (favicon e manifest) gerados do ícone do Parceiros
  (capacete sobre o grafite `#565966`) pelo `flutter_launcher_icons`, com `web` ligado.
- O workflow `Site no GitHub Pages` (`.github/workflows/web.yml`) passa a:
  1. rodar `flutter pub get`, `flutter analyze` e `flutter test` no `dailyobra_parceiro`, como já faz nos outros dois;
  2. gerar o painel com `flutter build web --release --base-href "/${{ github.event.repository.name }}/parceiros/"`
     (o site do construtor já usa `"/${{ github.event.repository.name }}/"`);
  3. copiar `dailyobra_parceiro/build/web` para `dailyobra/build/web/parceiros` antes de subir o artefato.
  Um push no `main` publica o site do construtor, a página `/pagar/` e o painel juntos.

## 2. Layout por largura

- Os limites de largura saem do app do construtor e vão para o `dailyobra_comum`: `Formato { celular, tablet,
  computador }`, `formatoDe(double largura)` e `formatoDoContexto(BuildContext)` — celular abaixo de 600 px, tablet de
  600 a 1023 px, computador a partir de 1024 px. O app do construtor passa a importar de lá, sem mudar o comportamento.
- `NavegacaoScreen` do Parceiros escolhe a moldura pelo formato, com os mesmos quatro itens (Início, Propostas com o
  número de propostas novas, Produtos, Minha loja) e o mesmo `IndexedStack`:
  - **Celular:** as abas de baixo de hoje, sem mudança.
  - **Tablet:** `NavigationRail` com o símbolo da marca no alto (como no site do construtor).
  - **Computador:** menu lateral com a marca e os quatro itens e, à direita, a barra laranja do topo (mesma cor e
    altura da barra do site do construtor) com a logo e o nome da loja. O conteúdo fica com no máximo 1320 px,
    alinhado ao topo e centralizado, como no site.
- **Propostas no computador:** duas colunas. À esquerda, a lista de hoje (abas Novas, Pedidos, Encerradas); à direita,
  a proposta ou o pedido tocado, aberto ali mesmo, sem barra de título própria e com as ações no pé da coluna. Sem nada
  aberto, a coluna da direita diz `Escolha uma proposta ou pedido`. Aceitar uma proposta abre o pedido na mesma coluna.
  No celular e no tablet, tocar continua abrindo em tela cheia.
- Para isso `PropostaLojaScreen` e `PedidoLojaScreen` ganham `embutida` (padrão `false`), como o `PedidoScreen` do
  construtor: embutida, a tela é só o conteúdo e o rodapé de ações, sem `Scaffold` nem `AppBar`.
- As outras telas (Início, Produtos, Minha loja, Importar planilha, Equipe, Oferta) ficam numa coluna dentro da largura
  máxima. As janelas do Parceiros já são `showDialog` e servem no computador.

## 3. Login, sessão e arquivos

- Entrar com e-mail e senha funciona no navegador; o Supabase guarda a sessão no navegador.
- Cadastro e `Esqueci a senha` mandam o link de volta para o endereço do painel (o `AuthService.linkRetorno` do comum
  já usa o endereço da página na web). **Ação do usuário:** incluir
  `https://dailyobrabr-creator.github.io/dailyobra/parceiros/` nas URLs de redirecionamento do Supabase
  (Authentication > URL Configuration). Claude não mexe no painel do Supabase.
- Importar planilha e trocar logo ou capa leem o arquivo em bytes (`readAsBytes`), então escolher o arquivo do
  computador funciona; a redução da logo e da capa (largura máxima e qualidade) precisa valer também na web.
- O link `dailyobraparceiros://login` continua só no celular.

## 4. Testes

- Testes de tela do Parceiros nas larguras 360, 800 e 1366 px, claro e escuro (como `telas_largas_test.dart` do
  construtor): 360 mostra as abas de baixo; 800 mostra o trilho; 1366 mostra o menu lateral, a barra com o nome da loja
  e, em Propostas, a lista com a proposta tocada aberta ao lado (`Escolha uma proposta ou pedido` antes de tocar) e as
  ações do pedido no pé da coluna. Os testes atuais do Parceiros e do construtor continuam passando.
- `flutter build web --release --base-href /dailyobra/parceiros/` gera sem erro.
- Depois do push: o workflow termina com `success`; `/dailyobra/parceiros/` responde 200 e abre a tela de entrada no
  navegador; o site do construtor (`/dailyobra/`) e a página `/dailyobra/pagar/` continuam abrindo. As telas de quem está
  logado ficam com os testes de tela e com o usuário, porque Claude não entra com conta.

## 5. Riscos a conferir

- O site do construtor está em `/dailyobra/` e o painel em `/dailyobra/parceiros/`, no mesmo endereço: conferir no ar
  que o painel carrega os próprios arquivos (o service worker do site, se houver, não pode servir o app errado).
- `image_picker` e `file_picker` na web: escolher arquivo, reduzir a imagem e mandar para o Storage.
- Imagens do Storage (logo e capa) carregam no navegador como já carregam no site do construtor.

## Fora do escopo

Link para o painel no app do construtor, domínio próprio, instalar como aplicativo (PWA) e as funções novas do painel
(próximos subprojetos da Parte 2).
