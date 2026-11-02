# DailyObra Marketplace: app do construtor e DailyObra Parceiros

Data: 31/10/2026. Status: aguardando revisão do Luiz.

## 1. Entendimento

**O que o Luiz pediu**
- O DailyObra funciona como um marketplace da construção, no modelo iFood: o app do construtor (engenheiro, pedreiro, construtora) e o **DailyObra Parceiros** (lojas de material).
- O construtor vê lojas, materiais e ofertas, vê todos os materiais da obra dele, escolhe cada item na loja que quiser (tijolo de uma, argamassa de outra, cimento de outra), monta um orçamento, envia para algumas lojas e negocia uma proposta.
- A loja se cadastra e tem um painel para mexer no perfil, nas imagens e nos produtos.
- Funções e visual de referência: protótipo `app_da_obra_mvp.tsx` (Início com Smart List, Resultado da cotação com Menor preço global e Melhor por loja, Proposta e Fechar pedido, Carteira com cashback por nível) e o documento de kick-off.
- Visual em tema claro e escuro, com as cores e a fonte da marca.
- Pastas: `D:\dev\dailyobra_app\dailyobra` e `D:\dev\dailyobra_app\dailyobra_parceiro`.

**Decisões tomadas na conversa**
- Dois apps separados no mesmo projeto, cada um com nome, ícone e identificador próprios, mais `dailyobra_comum` com o código compartilhado.
- Começar pelo coração do marketplace. Ficam para depois: pagamento no app, saque da carteira, integração Santri e importação de CSV, notificação push com o app fechado, chat.
- O cashback entra agora (a carteira do protótipo), só como abatimento em pedidos. Saque fica para depois porque exige validação legal e financeira.

**Suposições (podem ser corrigidas)**
- Lojas aparecem para os construtores assim que se cadastram, com o selo "Nova no DailyObra". O administrador pode suspender uma loja direto no Supabase. Aprovação prévia de lojas fica para depois.
- "Perto de você" é por cidade e estado (lojas da mesma cidade primeiro). GPS e raio de entrega ficam para depois.
- Frete: valor fixo por loja, cobrado uma vez por pedido. Nada de roteirização ou cubagem (regra do kick-off).
- Percentuais de cashback por nível: 1 = 1%, 2 = 2%, 3 = 3%, 4 = 5%, configuráveis numa tabela.

## 2. Estrutura do projeto

```
D:\dev\dailyobra_app\
  dailyobra_comum\        pacote Dart: tema claro/escuro, componentes, modelos, Supabase, motor de orçamento, Smart List, cotação
  dailyobra\              app DailyObra (construtor)        com.dailyobra.dailyobra
  dailyobra_parceiro\     app DailyObra Parceiros (lojas)   com.dailyobra.parceiros
  apk\                    APKs gerados para instalar sem cabo
  docs\                   este documento e o plano
```

- Os dois apps dependem de `dailyobra_comum` por caminho local (`path: ../dailyobra_comum`).
- O app atual (obras, estimativa, faixa da obra) vira parte do DailyObra. O motor de orçamento e os modelos de obra vão para o pacote comum.
- Os ajustes de build deste computador (certificados do Avast, `kotlin.incremental=false`) valem para os dois apps.
- VS Code: abrir `dailyobra_app`; `.vscode/launch.json` com "DailyObra" e "DailyObra Parceiros".

## 3. App DailyObra (construtor)

Abas: **Início · Orçamentos · Carteira · Perfil**.

### Início
- Saudação com o primeiro nome e a empresa (de `profiles`).
- Banner do Clube de Profissionais com o maior nível de cashback dos pedidos da pessoa e o saldo disponível. Sem pedidos: "Faça seu primeiro pedido e ganhe cashback".
- **Smart List**: campo de texto para colar ou digitar a lista, uma linha por item. **Cotar agora** interpreta as linhas (seção 6) e abre o resultado da cotação.
- Categorias em faixa deslizante. Tocar abre a lista de produtos da categoria, com o menor preço entre as lojas.
- **Ofertas**: produtos com preço promocional válido, mostrando preço cheio riscado, preço da oferta, loja e validade.
- **Lojas**: cartões com capa, logo, nome, cidade, frete, pedido mínimo, aberta/fechada e o selo "Nova".
- **Busca** no topo: produtos (nome, sinônimos) e lojas.

### Loja (vitrine)
Capa, logo, descrição, cidade, horário, WhatsApp, frete e pedido mínimo; produtos por categoria com preço da loja. Adicionar ao orçamento fixa aquele item **naquela loja**.

### Produto
Nome padronizado, unidade, categoria, quadro de imagem (sem foto inventada: ícone da categoria) e **preço em todas as lojas**, do menor para o maior, com oferta e disponibilidade. Escolher a loja e a quantidade adiciona ao orçamento.

### Orçamentos
- **Resultado da cotação** (o carrinho em montagem):
  - Alternância **Menor preço global** (cada item na loja mais barata que tem oferta) e **Melhor por loja** (a loja que atende o maior número de itens pelo menor total; empate vai para o menor total).
  - Itens agrupados por loja: quantidade (editável), preço unitário, total, troca de loja do item, remover.
  - Por loja: subtotal, frete e o aviso de pedido mínimo quando não atingido.
  - Itens sem oferta em nenhuma loja aparecem como "Sem oferta no momento" e não entram nos totais.
  - Rodapé fixo: total geral, cashback previsto e o interruptor "Usar saldo da carteira (R$ X)".
  - **Proposta**: envia uma proposta de negociação para cada loja do orçamento, com mensagem opcional.
  - **Fechar pedido**: envia um pedido direto para cada loja, ao preço anunciado. A loja só confirma ou recusa.
  - O carrinho fica salvo no aparelho e sobrevive a fechar o app.
- **Enviados**: orçamentos enviados com a situação por loja e os pedidos com acompanhamento. O detalhe da proposta mostra o preço anunciado contra o ofertado por item, o desconto, o frete, o total, a mensagem da loja e a validade, com **Aceitar contraproposta**, **Recusar** e **Cancelar**.
- Acompanhamento do pedido: Aguardando loja → Confirmado → Em separação → Saiu para entrega → Entregue, com data e hora de cada passo e o botão de WhatsApp da loja.

### Carteira
- Saldo disponível, cashback pendente e saldo reservado (usado em propostas ainda abertas).
- Extrato: cada lançamento com descrição, loja, nível, data e valor.
- **Usar no carrinho** leva ao orçamento com o interruptor de saldo ligado.
- Botão Sacar aparece desabilitado com "Em breve".

### Perfil
Nome, empresa, cidade e estado (usados para ordenar as lojas), tema (Sistema, Claro, Escuro), **Minhas obras** (telas atuais de obra e estimativa, mais **Cotar materiais desta obra**, que manda a lista de materiais da obra para a cotação já ligada aos produtos do catálogo) e Sair.

## 4. App DailyObra Parceiros (lojas)

Abas: **Início · Propostas · Produtos · Minha loja**. O login é o mesmo do DailyObra (Supabase Auth).

- **Primeiro acesso**: depois do login, se a pessoa não faz parte de nenhuma loja, cadastra a loja: nome, CNPJ (dígitos verificadores conferidos), endereço, cidade, estado, WhatsApp, horário, frete fixo, pedido mínimo e descrição. Quem cadastra vira **dono**.
- **Início**: números reais da loja: propostas aguardando resposta, pedidos em andamento, pedidos entregues no mês e faturamento no mês. Abaixo, as propostas mais urgentes (que vencem primeiro).
- **Propostas**: abas Novas, Em negociação, Pedidos.
  - Proposta de negociação: itens, quantidades, preço anunciado. Ações: **Aceitar**, **Recusar** (motivo obrigatório) e **Contraproposta** (preço por item e/ou desconto no total, validade de 24, 48 ou 72 horas, mensagem).
  - Pedido direto (Fechar pedido): **Confirmar** ou **Recusar** (motivo).
  - Pedido confirmado: avançar a situação, **Confirmar pagamento recebido** e WhatsApp do construtor.
- **Produtos**: busca no catálogo DailyObra por nome ou categoria; para cada produto, preço, preço de oferta com data de validade, disponibilidade (Disponível, Sob consulta, Sem estoque) e pausar. A loja não cria produto nem muda nome, unidade, categoria ou nível de cashback.
- **Minha loja**: trocar logo e capa (foto da galeria ou da câmera, reduzida antes de enviar), editar dados, abrir e fechar a loja, equipe (dono convida por e-mail de quem já tem conta, com o papel gerente ou vendedor), tema e sair.
- Permissões: **dono** faz tudo; **gerente** faz tudo menos equipe e excluir a loja; **vendedor** responde propostas e atualiza pedidos, sem mexer em preços nem na loja.

## 5. Visual

- Tokens em `dailyobra_comum`, dois esquemas:
  - Claro: o atual (superfícies #FFFFFF e #F6F7F9, texto #252832, botão #A43F05 com texto branco, laranja #F36E21 como acento).
  - Escuro: fundo #141519, superfícies #1C1E23 e #24272E, bordas #343741, texto #F2F3F5 e #A8ACB6, botão principal #F36E21 com texto #1A0F07, acento #F36E21.
  - Estados (sucesso, aviso, erro, informação) com versões clara e escura. Contraste mínimo 4,5:1 em texto.
- Fonte Inter. Cantos 10 a 16 px nos cartões, 6 px em campos e botões. Sombras discretas só em rodapé fixo e folhas que sobem.
- Componentes do protótipo: saudação, banner do Clube (cor sólida da marca, sem gradiente), Smart List, chips de categoria, cartão de produto (imagem, quantidade, fornecedor, unitário, total), rodapé de total, barra de abas com ícones de linha.
- Ícones: Material Symbols de linha, só quando ajudam a navegar.
- Os dois apps seguem o tema do aparelho, com escolha manual guardada no aparelho.
- Ícone do Parceiros: o mesmo capacete sobre fundo grafite.

## 6. Catálogo DailyObra e Smart List

### Catálogo inicial
- Cerca de 90 produtos padronizados a partir dos 109 itens das planilhas Projetos Calculos. Duplicados por unidade são unificados, e o que não é produto de loja fica de fora (ex.: "Almoxarifado/banheiro").
- Cada produto: nome padronizado, unidade comercial (saco, unidade, metro, m², m³, kg, galão, lata, barra, rolo, caixa, milheiro), categoria (Básico, Estrutura, Alvenaria, Cobertura, Hidráulica, Elétrica, Acabamento, Pintura, Louças e metais, Ferramentas), nível de cashback (1 a 4), sinônimos para a Smart List e, quando houver, EAN e NCM.
- Tabela de ligação `planilha → produto`, para "Cotar materiais desta obra" converter a lista estimada em itens do catálogo.

### Smart List
- Uma linha por item. Formatos aceitos: `100 sacos de cimento itaú`, `20 barras ferro 5/16`, `5 rolos fio 2,5mm`, `cimento 50 sacos`, `areia 3 m3`, linhas com marcador (`- `, `• `, `1)`).
- Quantidade: primeiro número da linha (aceita `2,5`, `1.000`). Sem número, quantidade 1.
- Unidade falada (sacos, sc, barras, br, rolos, un, und, peças, m, metros, m², m2, m³, m3, kg, latas, galões, milheiro) é usada para o casamento e descartada do texto.
- Casamento: texto e catálogo normalizados (minúsculas, sem acento, "5/16" e "2,5mm" mantidos como termos). A pontuação conta os termos em comum com nome e sinônimos, com peso maior para medidas.
- Resultado por linha: **reconhecido** (um produto claramente melhor), **escolher** (até 3 candidatos próximos, o construtor toca no certo) ou **não reconhecido** (fica marcado, pode editar o texto ou buscar).
- Linhas repetidas do mesmo produto somam as quantidades.

## 7. Cotação

Função pura em `dailyobra_comum`, testada:
- Entrada: itens (produto, quantidade, loja fixada ou não) e ofertas das lojas.
- Preço vigente da oferta: o promocional, quando existe e `promo_ate` é hoje ou depois; senão, o preço normal. Ofertas pausadas ou "Sem estoque" ficam de fora. "Sob consulta" entra, com o aviso.
- Menor preço global: cada item sem loja fixada vai para a oferta de menor preço vigente. Empate vai para a loja da mesma cidade e depois para a de menor frete.
- Melhor por loja: para cada loja, conta quantos itens ela atende e o total (itens + frete). Escolhe a que atende mais itens; empate vai para o menor total. Itens que ela não tem ficam como "Sem oferta nesta loja".
- Por loja: subtotal, frete fixo (uma vez) e a sinalização de pedido mínimo.
- Cashback previsto: soma de (total do item × percentual do nível do produto). O frete não gera cashback.
- O cálculo no aparelho é só prévia. No envio, o servidor recalcula tudo com os preços dele.

## 8. Dados (Supabase, projeto `dailyobra`)

Tabelas novas (todas com RLS):

| Tabela | Conteúdo principal |
|---|---|
| `lojas` | nome, cnpj (único), descricao, logo_path, capa_path, whatsapp, endereco, cidade, uf, horario, frete_fixo, pedido_minimo, aberta, status (`ativa`, `suspensa`), criada_em |
| `loja_membros` | loja_id, user_id, papel (`dono`, `gerente`, `vendedor`) |
| `catalogo_categorias` | id, nome, ordem |
| `catalogo_itens` | id, nome, unidade, categoria_id, tier_cashback (1–4), sinonimos text[], ean, ncm, imagem_path, ativo |
| `catalogo_planilha` | nome do item na planilha, unidade da planilha, item_id |
| `cashback_tiers` | tier, percentual, vigente_desde |
| `ofertas` | loja_id, item_id (único por loja), preco, preco_promocional, promo_ate, disponibilidade (`disponivel`, `sob_consulta`, `sem_estoque`), pausada, atualizada_em |
| `orcamentos` | construtor_id, obra_id (opcional), modo (`negociacao`, `pedido`), mensagem, criado_em |
| `propostas` | orcamento_id, loja_id, construtor_id, modo, status, subtotal_anunciado, desconto, frete, total, cashback_previsto, saldo_aplicado, mensagem_construtor, mensagem_loja, motivo_recusa, valida_ate, timestamps |
| `proposta_itens` | proposta_id, item_id, nome e unidade (cópia), quantidade, preco_anunciado (cópia), preco_ofertado |
| `proposta_eventos` | proposta_id, de, para, autor, papel, valores (jsonb), justificativa, criado_em |
| `pedidos` | proposta_id (único), loja_id, construtor_id, total, status, pagamento_confirmado_em, entregue_em, timestamps |
| `pedido_eventos` | pedido_id, de, para, autor, criado_em |
| `carteira_lancamentos` | transacao_id, construtor_id, conta (`pendente`, `disponivel`, `reservado`, `emissor`), valor (+/−), tipo, pedido_id, proposta_id, descricao, criado_em |

- `profiles` ganha cidade, uf e tema.
- Storage: bucket `lojas` (leitura pública), escrita em `lojas/{loja_id}/...` só por dono e gerente daquela loja.
- Tempo real: `propostas` e `pedidos` na publicação `supabase_realtime`. O RLS vale também para os eventos em tempo real.

### Quem vê o quê (RLS)
- Catálogo, categorias, tiers e lojas ativas (com as ofertas não pausadas delas): qualquer usuário logado lê.
- Ofertas: dono e gerente da loja escrevem.
- `lojas`: membros editam a própria (status só pelo administrador). Cadastro de loja nova pela função `criar_loja`, que já põe o criador como dono.
- Orçamentos, propostas, itens, eventos e pedidos: o construtor lê os dele, e os membros da loja leem os da loja. **Ninguém escreve direto**: tudo passa pelas funções da seção 9.
- Carteira: o construtor lê só os próprios lançamentos. Ninguém insere, altera ou apaga pelo app.

## 9. Regras no servidor (funções `security definer`)

Cada função confere `auth.uid()` e o papel, registra evento e roda numa transação.

- `criar_loja(dados)` → loja com o usuário como dono. CNPJ válido e não usado.
- `enviar_cotacao(itens[{item_id, loja_id, quantidade}], modo, obra_id, usar_saldo, mensagem)`:
  - Agrupa por loja e lê os preços vigentes no servidor.
  - Recusa loja suspensa, item sem oferta ativa e loja abaixo do pedido mínimo, com mensagem clara do que corrigir.
  - Cria o orçamento, uma proposta por loja (com os preços copiados) e os itens, com validade de 48 h para a loja responder.
  - Saldo usado: reserva proporcional ao total de cada proposta (`disponivel −`, `reservado +`).
- `responder_proposta(proposta_id, acao, precos[{item_id, preco}], desconto, mensagem, motivo, validade_horas)`, só membros da loja:
  - Negociação: `enviada → aceita | recusada | contraproposta`.
  - Pedido direto: `enviada → aceita | recusada`.
  - Contraproposta: os preços só podem baixar e o desconto não passa do subtotal.
- `decidir_contraproposta(proposta_id, aceitar)`, só o construtor: `contraproposta → aceita | recusada`.
- `cancelar_proposta(proposta_id)`, só o construtor: `enviada | contraproposta → cancelada`.
- Expiração: ao ler ou agir, proposta com `valida_ate` vencida passa a `expirada` (feito dentro das funções e de uma consulta usada pelas telas).
- Ao virar `aceita`:
  - Cria o pedido (`confirmado`).
  - Converte a reserva de saldo em uso.
  - Lança o cashback pendente (`emissor −`, `pendente +`), calculado pelo total final de cada item e pelo nível do produto.
- Ao virar `recusada | cancelada | expirada`: devolve a reserva (`reservado −`, `disponivel +`).
- `atualizar_pedido(pedido_id, status)`, só membros da loja: `confirmado → em_separacao → saiu_entrega → entregue`. `cancelado` é permitido à loja antes de `saiu_entrega` e ao construtor só em `confirmado`. Cancelar estorna o cashback pendente e devolve o saldo usado.
- `confirmar_pagamento(pedido_id)`, só dono ou gerente. Quando o pedido está **entregue e com pagamento confirmado**, libera o cashback (`pendente −`, `disponivel +`).
- Visão `carteira_saldos` por construtor (disponível, pendente, reservado).

## 10. Erros e situações-limite

- Sem internet: telas mostram o último conteúdo carregado com o aviso "Sem conexão", e os botões de envio ficam desabilitados com o motivo.
- Recusa do servidor (permissão, etapa errada, pedido mínimo, preço mudou): mensagem em português vinda da função, sem jogar código de erro na cara do usuário.
- Preço mudou entre a prévia e o envio: o servidor usa o preço atual, e o app avisa "Os preços foram atualizados pelas lojas" mostrando o novo total.
- Loja fechada: aparece com o selo "Fechada" e ainda recebe propostas, que ela responde quando abrir.
- Estoque zerado não bloqueia nada (regra do kick-off), só sinaliza.
- Imagens: até 2 MB depois de reduzidas, apenas JPEG ou PNG.

## 11. Testes

- Pacote comum: motor de orçamento (os testes atuais), Smart List (formatos da seção 6, sinônimos, ambíguos, não reconhecidos, somatório), cotação (menor preço global, melhor por loja, empates, promoção vencida, frete, mínimo, cashback), CNPJ.
- Banco: script SQL de testes em transação desfeita no final, com usuários de teste temporários:
  - permissões por papel;
  - estados da proposta e do pedido (inclusive transições proibidas);
  - preço sempre vindo do servidor;
  - contraproposta só para baixo;
  - reserva e devolução de saldo;
  - cashback só liberado com entrega e pagamento;
  - ninguém escreve direto nas tabelas protegidas.
- Telas: testes de widget dos dois apps em celular de 360 px, temas claro e escuro, sem estouro de layout, cobrindo Início, Smart List, cotação, proposta, carteira, vitrine, produto, e no Parceiros: cadastro, propostas, produtos e loja.
- Build: os dois APKs compilados, instalados e abertos no emulador, com a análise do Dart sem problemas.

## 12. Critérios de aceite

1. O construtor cola uma lista na Smart List, vê os itens reconhecidos e os não reconhecidos, e chega a um orçamento com menor preço global distribuído entre lojas diferentes.
2. Alterna para Melhor por loja e vê o total de uma loja só.
3. Envia Proposta. Cada loja recebe a sua no Parceiros em tempo real, faz contraproposta, e o construtor vê e aceita. Vira pedido com cashback pendente.
4. A loja avança o pedido até Entregue e confirma o pagamento. O cashback aparece como disponível na Carteira do construtor.
5. O construtor usa o saldo num novo pedido. Se a loja recusar, o saldo volta.
6. A loja cadastra perfil, logo, capa e preços com oferta, e isso aparece no app do construtor (vitrine, ofertas, comparação de preço).
7. Uma loja nunca vê propostas de outra, e o construtor nunca vê orçamentos de outro (testado no banco).
8. Os dois apps funcionam em claro e escuro, e os dois APKs instalam lado a lado.

## 13. Pendências fora do código

- Supabase: adicionar `dailyobra://login` e `dailyobraparceiros://login` em Redirect URLs, e configurar SMTP próprio.
- Fotos dos produtos do catálogo: virão do saneamento (IndexaAI) numa etapa futura.
- Chave de assinatura de produção para publicar nas lojas de aplicativo.
