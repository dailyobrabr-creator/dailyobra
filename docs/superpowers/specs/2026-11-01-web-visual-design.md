# DailyObra: web responsivo do construtor e visual "vitrine viva"

Data: 01/11/2026 · Aprovado na conversa por partes (Início no protótipo, funções, telas, banco e publicação).

## 1. Entendimento

**O que o usuário pediu**
- Criar o web responsivo e melhorar o visual ("achei muito simples").
- Web só para o construtor. O DailyObra Parceiros continua só no celular.
- Visual da direção A ("vitrine viva"), com as funções das direções B ("canteiro") e C ("premium escuro").
- O site vai para o GitHub.
- Economia do mês = comparando lojas + negociação + cashback.

**Suposições confirmadas ou tomadas**
- "Funções do d e c" = funções da B e da C.
- "Colocar no GitHub" = código num repositório e site publicado pelo GitHub Pages.
- O visual novo vale para o app do construtor no celular (Android e iOS) e no web. O Parceiros recebe o mesmo acabamento pelas peças comuns (cores, cartões, tipografia), sem as funções novas e sem mudar de layout.
- Protótipo aprovado do Início: `docs/prototipos/inicio.html` (computador, tablet e celular; claro e escuro). Ele é a referência visual desta entrega.

**Fora do escopo**
Web do Parceiros, página pública de apresentação, notificação com o app fechado, pagamento no app, saque, domínio próprio.

## 2. Arquitetura do web

- **Mesmo código:** o app `dailyobra` (Flutter) compila também para web. Nada de regra duplicada: serviços, lista inteligente, cotação e funções do servidor são os mesmos.
- **Layout adaptativo pela largura da janela** (um widget `LayoutAdaptativo` decide):
  - **Celular, menos de 600 px:** abas embaixo (Início, Orçamentos, Carteira, Perfil); obras pelo Perfil.
  - **Tablet, de 600 a 1023 px:** trilho lateral só com ícones, com o número de pendências sobre o ícone de Orçamentos.
  - **Computador, 1024 px ou mais:** menu lateral de 248 px com a marca, os itens (Início, Orçamentos, Carteira, Minhas obras, Perfil) e o cartão do Clube embaixo. Barra laranja no topo de todas as telas com saudação, cidade, busca, botão de tema, sino e iniciais. Conteúdo com no máximo 1320 px; formulários com no máximo 720 px.
- **Publicação:**
  - `.github/workflows/web.yml` instala o Flutter estável, roda `flutter analyze` e `flutter test` nos pacotes `dailyobra_comum` e `dailyobra`, compila com `flutter build web --release --base-href /<nome-do-repositório>/` e publica no GitHub Pages pelo próprio Actions.
  - O nome do repositório vem da variável do GitHub, sem nada fixo no código.
- **Navegador:**
  - `web/index.html` e `web/manifest.json` com título "DailyObra", ícone da marca, cor de tema #F36E21 e tela de abertura com o símbolo enquanto o app carrega.
  - Links do e-mail (confirmação e nova senha) voltam para o endereço do site. O `AuthService` usa o endereço atual da página como retorno quando roda no navegador.
- **Compatibilidade:** `dailyobra_comum/lib/src/supabase/erros.dart` deixa de importar `dart:io`. A falha de conexão é reconhecida por `ClientException` e por `SocketException`, numa importação condicional que só existe fora do navegador. A mensagem para a tela continua a mesma.
- **Segurança:** o repositório pode ser público. O código só tem a chave publicável; nenhuma chave secreta entra no repositório nem no workflow.

## 3. Visual: direção A em todo o app

**Cores** (somam-se às de `CoresDailyObra`; claro / escuro)
- **Topo laranja:** fundo #F36E21 nos dois temas, texto e ícones #252832 (contraste 5:1; branco sobre esse laranja não passa em 4,5:1). Busca com fundo #FFFFFF e texto #535965.
- **Preço:** `acao` (#A43F05 no claro, #F36E21 no escuro).
- **Selo de desconto:** fundo `acao` com texto `textoSobreAcao`.
- **Fundo de destaque suave** (item ativo do menu, prazo, ícone da lista inteligente): #FDE9DC no claro, #3A2416 no escuro.
- **Cartão escuro** (Clube e pedido a caminho): #252832 no claro, #2A2D35 no escuro, com texto claro.
- **Categorias:** fundo suave e ícone da mesma família, claro / escuro, num mapa `coresDaCategoria(id)`:

| Categoria | Fundo claro | Ícone claro | Fundo escuro | Ícone escuro |
|---|---|---|---|---|
| basico | #FDE3D2 | #8A3504 | #3A2416 | #FFB98F |
| estrutura | #EDE7F6 | #4C2F94 | #2A2340 | #C4B2F2 |
| alvenaria | #E6ECF4 | #3B4A63 | #232A36 | #B4C3DA |
| cobertura | #E4EEF0 | #2F4F5A | #1D2C31 | #9CC4CF |
| hidraulica | #DCEBFB | #1D4ED8 | #1C2A44 | #8AB4FF |
| eletrica | #FDF1C7 | #7A4F00 | #3A3015 | #F0C75E |
| acabamento | #F3E8DD | #6B4B2E | #33281E | #D9B894 |
| pintura | #E3F5EA | #166534 | #16301F | #7FD6A4 |
| loucas-metais | #F6E3EC | #8E2453 | #3A1C2A | #F2A5C6 |
| ferramentas | #E0F4F4 | #0F5F5F | #143233 | #7FD3D3 |

**Peças** (no `dailyobra_comum`, usadas pelos dois apps)
- **Cartões:** raio 16, borda de 1 px, sem sombra.
- **Títulos de seção:** 17 px/700, com "Ver todas" em `acao`.
- **`CartaoOferta`:**
  - área da categoria com 112 px de altura e o ícone no centro (foto da loja quando existir);
  - selo de desconto no canto superior esquerdo;
  - nome em até 2 linhas com altura fixa, para todos os cartões da linha terem a mesma altura;
  - nome da loja;
  - preço antigo riscado em cima e preço atual embaixo.
- **`CartaoLoja`:** capa (foto ou faixa na cor da loja) com a logo sobreposta, frete, número de ofertas e selo aberta ou fechada.
- **`TileCategoria`:** ícone de 40 px e nome lado a lado no computador (grade de 4 por linha); ícone em cima e nome embaixo no tablet e no celular. O nome quebra em até 2 linhas, nunca corta.
- **`MarcaDailyObra`:** logo completo no claro; símbolo branco e laranja com o nome escrito no escuro; só o símbolo no trilho. As imagens saem do logo oficial reduzido (480 px de largura) e do símbolo recortado.
- **Esqueletos:** de carregamento com brilho, e transições curtas entre telas (200 ms).

**Regras**
- Nenhum texto pode ser cortado sem reticências.
- Nenhuma rolagem lateral na página.
- Contraste de 4,5:1 nos dois temas.
- Números com algarismos tabulares.

## 4. Início

**Ordem dos blocos**
- **Computador:** coluna principal com obra ativa e economia lado a lado, lista inteligente, categorias, ofertas do dia (4 por linha) e mais barato hoje. Coluna lateral fixa de 340 px com a contraproposta, o pedido a caminho e as lojas perto.
- **Tablet e celular:** uma coluna, na ordem contraproposta, pedido a caminho, lista inteligente, obra ativa e economia, categorias, ofertas, mais barato hoje e lojas perto.
- **No celular:** o topo laranja tem cantos arredondados embaixo e a busca em largura total. Categorias e ofertas rolam para o lado. O Clube vira cartão no começo da tela, porque não há menu lateral.

**Blocos**
- **Obra ativa:**
  - A obra fixada no Perfil ou, sem escolha, a última atualizada.
  - Mostra o percentual de etapas concluídas, a barra, a etapa atual e "X de Y etapas". Tocar abre a obra.
  - Sem obras: convite "Cadastre sua obra e cote os materiais dela", que abre o cadastro.
- **Você economizou em <mês>:** total do mês e barras dos últimos 6 meses, com o mês atual em laranja. Tocar abre a Carteira, onde fica a divisão (seção 6). Sem pedidos ainda: "Feche seu primeiro pedido pelo app para ver a economia aqui".
- **Lista inteligente:** campo de texto direto no Início e "Cotar agora", que abre a revisão que já existe.
- **Contraproposta esperando você:**
  - A que vence primeiro, com loja, resumo, valor e prazo ("Responda em 5 h"), e o botão Ver proposta.
  - Com mais de uma: "N contrapropostas esperando você", com o botão indo para Enviados.
  - Sem nenhuma: o bloco não aparece.
- **Pedido a caminho:** o pedido mais recente em separação ou saindo para entrega, com loja, valor e a barra de 4 passos. Sem nenhum: o bloco não aparece.
- **Categorias e Ofertas do dia:** como hoje, com as peças novas.
- **Mais barato hoje:**
  - Até 5 produtos com oferta em 2 ou mais lojas abertas, com "de R$ X a R$ Y" e o menor preço em destaque.
  - Primeiro os que estão no orçamento; depois, os de maior diferença relativa ((maior − menor) / maior).
  - Tocar abre o produto.
  - Sem produtos assim: o bloco não aparece.
- **Lojas perto:** até 5 lojas, as da cidade do perfil primeiro e as abertas antes das fechadas. Mostra logo, nome, frete, número de ofertas, selo aberta ou fechada e, quando fechada, o horário cadastrado.

## 5. Novidades (sino)

- **Origem:** os últimos 30 dias, até 50 itens, das tabelas que o banco já grava (RLS já permite ao construtor ler as dele):
  - `proposta_eventos` das propostas do construtor com `papel <> 'construtor'`: aceita, recusada (com o motivo), contraproposta e expirada;
  - `pedido_eventos` dos pedidos do construtor com autor diferente dele e `para` em `em_separacao`, `saiu_entrega`, `entregue`, `cancelado` e `pagamento_confirmado` (o "confirmado" fica de fora para não repetir o "aceita");
  - `carteira_lancamentos` do tipo `cashback_liberado` na conta `disponivel`.
- **Texto de cada item:** loja, o que aconteceu e quando ("Casa do Construtor mandou uma contraproposta · há 2 h"). Tocar abre a proposta, o pedido ou a Carteira.
- **Número no sino:** itens mais novos que o "visto até", guardado no aparelho (`dailyobra.novidades.vistoAte`). Abrir a lista zera o número.
- **Atualização:** a lista recarrega junto com as propostas, pelo tempo real que já existe.
- **Apresentação:** painel lateral de 380 px no computador; tela própria no celular e no tablet.
- **Sem nada:** "Nenhuma novidade por aqui. Quando uma loja responder, aparece neste lugar."

## 6. Economia do mês

- **Por pedido não cancelado,** no mês de `pedidos.criado_em` (horário de Brasília):
  - **comparando** = soma de (`preco_maior` − `preco_anunciado`) × quantidade dos itens. Propostas antigas, sem `preco_maior`, contam 0.
  - **negociando** = soma de (`preco_anunciado` − preço fechado) × quantidade + `desconto` da proposta. Preço fechado = `preco_ofertado` quando houve contraproposta, senão o anunciado.
  - **cashback** = `cashback_previsto` da proposta.
  - **total** = comparando + negociando + cashback.
- **Onde aparece:**
  - Início: só o total.
  - Carteira: total, barras de 6 meses e a divisão "Comparando lojas R$ X · Negociando R$ Y · Cashback R$ Z".

## 7. Outras telas no computador e no tablet

- **Orçamentos:**
  - Cotação em duas colunas: grupos por loja à esquerda; resumo fixo à direita com modo, total, cashback, interruptor de saldo e os botões Proposta e Fechar pedido. O motivo de bloqueio fica no resumo.
  - No celular continua o rodapé fixo.
  - Enviados em mestre e detalhe: lista à esquerda e proposta ou pedido à direita, sem trocar de tela.
- **Produto:** quadro da categoria e dados à esquerda; preços por loja à direita; quantidade e "Adicionar ao orçamento" sempre visíveis.
- **Loja:** capa larga (220 px), dados e contato ao lado da logo, produtos em grade de 3 colunas (tablet) ou 4 (computador).
- **Categoria e busca:** grade de `CartaoOferta`, com filtros por categoria (busca), "só com oferta" e ordem por menor preço ou nome.
- **Lista inteligente (revisão):** texto colado editável à esquerda (reinterpretar ao editar); itens reconhecidos, a escolher e não reconhecidos à direita.
- **Carteira:** saldo, gráfico de economia e níveis à esquerda; extrato em tabela à direita (data, descrição, loja, nível, valor).
- **Perfil:** formulário centralizado de até 720 px, com a escolha da obra ativa.
- **Minhas obras:** grade de cartões.
- **Janelas:** contraproposta, trocar loja, mensagem da proposta e quantidade abrem centralizadas (até 560 px) no computador e de baixo no celular.

## 8. Banco (Supabase)

- **Migração `20261101120000_economia.sql`:**
  - `alter table public.proposta_itens add column preco_maior numeric(12,2) check (preco_maior > 0)`.
  - `enviar_cotacao` passa a gravar `preco_maior` = o maior entre o preço anunciado e o maior preço vigente do item nas lojas ativas e abertas, com oferta não pausada e não "sem estoque".
  - `public.economia_mensal(p_meses int default 6)`: devolve `mes date, comparando numeric, negociando numeric, cashback numeric, total numeric`, só do usuário logado, com os meses sem pedido valendo 0. É `security invoker`, porque a RLS já filtra; `execute` só para `authenticated`.
- **Testes:** `supabase/tests/marketplace_test.sql` ganha estas verificações:
  - `preco_maior` gravado no envio (cimento: loja A 45 e loja B 38; proposta para a B grava 45);
  - economia do mês com contraproposta e cashback;
  - pedido cancelado fora da conta;
  - outro construtor não vê a economia de ninguém.

## 9. Erros e estados

- Sem conexão: faixa "Sem conexão. Mostrando os dados carregados por último." (como hoje), também no web.
- Cada bloco do Início some quando não tem dados (contraproposta, pedido, mais barato) ou mostra um convite (obra, economia).
- Imagem de loja que não carrega volta para a cor da loja e as iniciais.
- Busca sem resultado, categoria vazia e lojas inexistentes mantêm as mensagens atuais.

## 10. Testes

- **Widgets do `dailyobra`:**
  - Início, Orçamentos, Produto, Carteira e Novidades em 360, 800 e 1366 px de largura, claro e escuro, sem estouro de layout;
  - o menu certo em cada largura (abas, trilho, menu lateral);
  - os blocos do Início que aparecem e somem conforme os dados.
- **Unidades no `dailyobra_comum`:**
  - `maisBaratoHoje` (ordem: orçamento primeiro, depois diferença relativa; ignora lojas fechadas e produtos com uma loja só);
  - `novidadesDe(...)` (filtros por papel e autor, ordem e contagem desde o "visto até");
  - leitura de `economia_mensal`;
  - `coresDaCategoria` com contraste de 4,5:1 nos dois temas.
- **Parceiros:** os testes atuais continuam passando com o acabamento novo.
- **Web:** `flutter build web` sem erro no GitHub Actions e na máquina; o site aberto no navegador do app, conferido nas três larguras.

## 11. Critérios de aceite

1. O web abre no navegador e, no computador, mostra o menu lateral, a barra laranja com busca e o Início do protótipo aprovado. No tablet, trilho; no celular, abas.
2. O app do construtor no celular tem o visual novo, nos dois temas, sem texto cortado nem rolagem lateral em 360 px.
3. O Início mostra obra ativa, economia, lista inteligente, contraproposta, pedido a caminho, categorias, ofertas, mais barato hoje e lojas perto, cada um some ou convida quando não há dados.
4. O sino conta as novidades desde a última abertura e cada item leva à tela certa.
5. A economia do mês bate com a conta da seção 6 (testado no banco).
6. Orçamentos no computador tem o resumo fixo à direita, e Enviados mostra lista e detalhe lado a lado.
7. Um envio para o GitHub publica o site pelo Actions, e o login por e-mail volta para o site.
8. Parceiros continua funcionando, com o acabamento novo.

## 12. Pendências do usuário

- Criar o repositório no GitHub, enviar a pasta e ligar o Pages ("GitHub Actions" como origem). O README terá o passo a passo.
- No Supabase (Authentication > URL Configuration): pôr o endereço do site como Site URL ou incluí-lo em Redirect URLs.
