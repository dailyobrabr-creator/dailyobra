# Checkout: saldo na hora de pagar, formas de pagamento e link do cliente

Parte 1 de 2 das funções do protótipo "App da Obra" (`app_da_obra_checkout_fluxos.html`). A parte 2 é o painel da
loja (`painel_web_lojista.html`), com spec própria.

## 1. Objetivo e decisões

Levar para o checkout do DailyObra as funções do protótipo **mantendo o visual atual** do app: usar o saldo da carteira na
hora de pagar, escolher a forma de pagamento (PIX, cartão na loja, crediário da loja com aprovação), ver o titular da
nota, informar o CPF/CNPJ do cliente no link e ver a mensagem antes de enviar pelo WhatsApp.

Decisões do usuário (2026-11-02):

- Visual atual mantido; só entram as funções.
- Cartão e crediário **combinados com a loja**, sem gateway: o construtor escolhe no app, a loja recebe fora do app e
  confirma o pagamento como hoje.
- Saldo **só na hora de pagar** e **só no "Eu pago"** (sai da cotação).
- Forma de pagamento e prazo ficam em **campos do próprio pedido**.

Fora desta parte: gateway de pagamento, boleto pelo ERP, envio automático do WhatsApp (segue o link `wa.me`), cartão ou
crediário para o cliente do link (a página continua só com PIX).

## 2. Regras

### 2.1 Saldo da carteira

- A tela de cotação deixa de oferecer o saldo. A função `enviar_cotacao` continua aceitando `p_usar_saldo` (APKs antigos),
  mas o app novo sempre manda `false`.
- **Saldo usado no pedido** = soma dos lançamentos da conta `emissor` do pedido com tipo `saldo_usado` ou
  `saldo_devolvido` (`private.saldo_no_pedido(p_pedido)`). Vale para o saldo vindo da cotação (pedidos antigos) e para o
  do checkout.
- `usar_saldo(p_pedido, p_usar boolean)` — só o construtor do pedido; pedido não cancelado, sem pagamento confirmado nem
  informado; `pagador = 'proprio'`.
  - Ligar com saldo já usado no pedido não faz nada. Ligar sem saldo usado aplica `least(saldo disponível, total do
    pedido)`: move `disponivel → emissor` (tipo `saldo_usado`, com o pedido), baixa `pedidos.total` e soma em
    `propostas.saldo_aplicado`. Sem saldo disponível: erro `Você não tem saldo disponível.`
  - Desligar devolve o saldo usado no pedido: `emissor → disponivel` (`saldo_devolvido`), sobe `pedidos.total` e baixa
    `propostas.saldo_aplicado`.
  - Outros erros: `Pedido não encontrado.`, `Este pedido foi cancelado.`, `Este pedido já foi pago.`,
    `Escolha "Eu pago" para usar o saldo.`, `O pagamento já foi informado. Fale com a loja.`
- `criar_link_pagamento` devolve o saldo usado no pedido antes de gerar o link (o cliente paga o total; o cashback
  continua do construtor).
- Cancelar o pedido devolve todo o saldo usado nele (da cotação ou do checkout), pela mesma soma.
- O PIX sai sempre do total atual do pedido (já abatido). Total zero: sem PIX e sem link (regra existente).

### 2.2 Forma de pagamento (só no "Eu pago")

- Campos em `pedidos`: `forma_pagamento` (`pix` | `cartao` | `crediario`), `prazo` (`28` | `28/35` | `28/35/42`),
  `prazo_status` (`pendente` | `aprovado` | `recusado`), `prazo_respondido_em`.
- `escolher_pagamento(p_pedido, p_forma, p_prazo)` — mesmo dono e mesmas condições do saldo. Crediário exige prazo
  válido e grava `prazo_status = 'pendente'`; PIX e cartão limpam prazo, status e resposta. Erros:
  `Forma de pagamento inválida.`, `Escolha o prazo do crediário.`, mais os de 2.1.
- `responder_prazo(p_pedido, p_aprovar boolean)` — dono ou gerente da loja do pedido (`private.pode_gerir_loja`); só com
  prazo `pendente`. Grava `aprovado` ou `recusado` e a hora. Erros: `Pedido não encontrado.`,
  `Só o dono ou o gerente responde ao prazo.`, `Não há prazo para responder.`
- Recusado: o construtor escolhe outra forma (`escolher_pagamento` de novo).
- A confirmação do pagamento e a liberação do cashback (pago + entregue) não mudam.
- `criar_link_pagamento` grava `forma_pagamento = 'pix'` e limpa o prazo.

### 2.3 Link do cliente

- `criar_link_pagamento(p_pedido, p_nome, p_whatsapp, p_documento default null)`: documento opcional. Válido: grava em
  `pedido_documentos` e marca `documento_informado_em` (a página já abre no PIX). Inválido:
  `CPF ou CNPJ inválido. Confira os números.`
- `pedido_do_link` passa a devolver `documento_mascarado` quando há documento: CPF `***.982.247-**`, CNPJ
  `**.222.333/0001-**`. O documento inteiro nunca sai na página.
- Na página, com o PIX na tela: `Nota no CPF/CNPJ {mascarado}` e o link `Corrigir`, que reabre o formulário
  (`dados_do_pagador` já regrava antes do pagamento).
- O app mostra a mensagem exata (`mensagemDoLink`) antes de abrir o WhatsApp.

## 3. Telas (visual atual)

**App do construtor — bloco "Quem paga este pedido?"**

- Eu pago, nesta ordem:
  1. Titular da nota: nome do perfil e CPF/CNPJ formatado, com `Alterar`. Sem documento, o campo atual.
  2. Interruptor `Usar saldo da carteira ({saldo disponível})` com `Abate {valor} neste pedido.` quando ligado.
  3. `Forma de pagamento`: `PIX` (copia e cola, como hoje), `Cartão na loja`
     (`Pague na maquininha da loja na entrega ou retirada.`) e `Crediário da loja` (prazo `28 dias`, `28/35 dias`,
     `28/35/42 dias` e o botão `Pedir prazo`; depois `Aguardando a loja aprovar o prazo.`,
     `Prazo aprovado: {prazo} dias.` ou `A loja recusou o prazo. Escolha PIX ou cartão.`).
  4. `Total a pagar` com o total atual.
- Enviar para o cliente: `Nome do cliente`, `WhatsApp do cliente`, `CPF ou CNPJ do cliente (opcional)`, o cartão
  `Mensagem que vai no WhatsApp` com o texto exato e o botão `Enviar pelo WhatsApp`.
- Orçamentos: sai o interruptor `Usar saldo da carteira`.

**Parceiros — tela do pedido e lista**

- Painel Pagamento: forma escolhida (`PIX`, `Cartão na loja`, `Crediário: {prazo} dias`). Prazo pendente: `Aprovar prazo` e
  `Recusar` para dono e gerente; vendedor vê `Aguardando o gerente aprovar o prazo.`. Respondido: `Prazo aprovado.` ou
  `Prazo recusado.`
- Lista de pedidos: selo `Prazo para aprovar` enquanto o prazo estiver pendente.

**Página do cliente**: documento mascarado e `Corrigir` (seção 2.3).

## 4. Testes

- SQL (`supabase/tests/checkout_pagamento_test.sql`, desfeito no fim): liga e desliga o saldo (total, `saldo_aplicado`,
  carteira e PIX recalculados); ligar duas vezes não aplica duas vezes; só o dono; não depois de informado ou pago; só no
  "Eu pago"; link devolve o saldo; cancelamento devolve o saldo do checkout; formas e prazo (pedir, aprovar, recusar,
  vendedor e outra loja recusados); link com documento grava e a página devolve só o mascarado; documento inválido
  recusado. O teste do checkout (23) e o do marketplace (48) seguem verdes.
- Telas (claro e escuro): bloco do pagamento (saldo, formas, estados do prazo, prévia, documento opcional), Orçamentos sem
  o interruptor, pedido no Parceiros (forma, aprovar e recusar, vendedor sem botões) e selo da lista.
- Página (Node): documento mascarado com `Corrigir` e a volta ao formulário.

## 5. Compatibilidade

- Pedidos antigos com saldo da cotação aparecem com o interruptor ligado; desligar devolve esse saldo.
- APK antigo ainda pode reservar saldo na cotação; o pedido criado segue as mesmas regras.
- Os campos novos são nulos nos pedidos de hoje; o painel mostra a forma só quando houver.
