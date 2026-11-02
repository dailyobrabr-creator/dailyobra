# Checkout bifurcado: "Eu pago" ou "Enviar para o cliente"

Data: 2026-11-02 · Origem: lacuna nº 1 do PRD "App da Obra" · Caminho: arquitetural

## 1. Objetivo

Tirar o atrito entre quem monta a lista (mestre, engenheiro) e quem paga (o dono da obra), já no piloto da Operário.
Depois que a loja aceita e o pedido nasce (total final), o construtor escolhe quem paga:

- **Eu pago:** a nota sai no CPF/CNPJ dele; ele vê o PIX da loja no app.
- **Enviar para o cliente:** o app abre o WhatsApp do construtor com uma mensagem e um link; o cliente abre uma página leve,
  sem login, confere os materiais, informa nome e CPF/CNPJ e paga por PIX direto à loja. A nota sai no documento do cliente.

Sucesso: o mestre manda o link em poucos toques; o cliente paga sem instalar nada; a loja sabe quem pagou (dados para a nota),
vê o aviso "cliente informou o pagamento" e confirma; o cashback continua indo para quem montou o pedido.

## 2. Decisões tomadas com o usuário

| Tema | Decisão |
| --- | --- |
| Cashback | Continua liberando com o pedido **pago e entregue** (regra atual); até lá fica a liberar. |
| CPF/CNPJ do cliente | O **cliente informa** na página; o mestre só põe nome e WhatsApp. |
| Página do cliente | **HTML leve no site** (GitHub Pages), sem login; não usa o app Flutter web. |
| Pagamento | **PIX direto na chave da loja**, sem gateway e sem passar pela plataforma; a loja confirma no Parceiros como hoje. |
| Envio | Link grátis do WhatsApp (`wa.me`), disparado pelo WhatsApp do próprio construtor. |

Padrões assumidos: o CPF/CNPJ de quem paga para si fica salvo no perfil (pedido uma vez, editável no Perfil); "Enviar para o
cliente" exige chave PIX cadastrada na loja; o link vale até o pedido ser pago ou cancelado; trocar o cliente ou mudar para
"Eu pago" invalida o link anterior.

## 3. Fluxo e situações

Situação do pagamento de um pedido (derivada, nesta ordem de precedência):

1. `cancelado` — pedido cancelado.
2. `pago` — `pedidos.pagamento_confirmado_em` preenchido (a loja confirmou).
3. `informado` — o cliente apertou "Já paguei" (`pagamento_informado_em`).
4. `aguardando_pagamento` — pagador escolhido e `documento_informado_em` preenchido.
5. `aguardando_dados` — link enviado, o cliente ainda não informou o documento.
6. `sem_pagador` — ninguém escolhido ainda (pedidos de hoje continuam funcionando assim).

## 4. Dados (Supabase)

Migração nova, sem mudar as funções e regras existentes de proposta, pedido e cashback.

- `lojas.chave_pix text` — aceita CPF ou CNPJ (só dígitos), e-mail, celular (+55DDDNÚMERO) ou chave aleatória (UUID);
  validada no banco. Editável só por dono/gerente (como os demais dados da loja).
- `profiles.documento text` — CPF (11) ou CNPJ (14) com dígitos verificadores válidos.
- `pedidos`: `pagador text check (pagador in ('proprio','cliente'))` (nulo até escolher), `pagador_nome text`,
  `pagador_whatsapp text` (10 a 13 dígitos), `link_codigo text unique` (aleatório, 22 caracteres URL-safe, só quando
  `pagador = 'cliente'`), `documento_informado_em timestamptz` (quando o documento de quem paga foi gravado; o construtor vê
  a situação sem ver o documento), `pagamento_informado_em timestamptz`.
- `pedido_documentos (pedido_id uuid primary key references pedidos on delete cascade, documento text not null)` — o CPF/CNPJ
  de quem paga fica à parte: RLS deixa só os membros da loja do pedido lerem; ninguém grava direto (só as funções).

Funções `security definer` com `search_path = ''` e erros `P0001` em português, no padrão das atuais:

| Função | Quem chama | O que faz |
| --- | --- | --- |
| `pagar_eu_mesmo(p_pedido uuid, p_documento text)` | construtor do pedido | Valida o documento, grava no perfil e em `pedido_documentos`; `pagador = 'proprio'`, nome = `profiles.nome` (vazio → erro "Complete seu nome no Perfil"); apaga link e aviso; preenche `documento_informado_em`. |
| `criar_link_pagamento(p_pedido uuid, p_nome text, p_whatsapp text)` | construtor do pedido | Exige chave PIX na loja e pedido não pago/cancelado; WhatsApp com DDD (10 a 13 dígitos; o app acrescenta 55 no `wa.me` quando faltar); `pagador = 'cliente'`, novo `link_codigo`, limpa documento, `documento_informado_em` e aviso; devolve o código. "Reenviar link" reabre o WhatsApp com o mesmo código; "Trocar cliente" chama esta função de novo. |
| `pedido_do_link(p_codigo text)` | público (anon) | Devolve JSON: loja (nome, cidade, uf, whatsapp), itens (nome, quantidade, unidade, preço unitário, total), frete, total, situação, nome do pagador, se o documento já foi informado e o PIX copia e cola (só se houver documento). Código desconhecido → erro "Link inválido ou substituído". |
| `dados_do_pagador(p_codigo text, p_nome text, p_documento text)` | público | Valida nome e CPF/CNPJ; grava `pagador_nome` e `pedido_documentos`; só antes de pago/cancelado. |
| `avisar_pagamento(p_codigo text)` | público | Exige documento informado; marca `pagamento_informado_em = now()` (repetir não muda a hora). |
| `pix_copia_e_cola(p_pedido uuid)` | interna | Monta o BR Code (seção 5). |

O que a loja já tem continua igual: `confirmar_pagamento`, `atualizar_pedido` e a liberação do cashback (pago e entregue).
As funções públicas nunca devolvem dados do construtor, de outros pedidos nem o documento em si.

## 5. PIX copia e cola (BR Code estático do Banco Central)

Campos EMV, cada um como ID (2) + tamanho (2) + valor:
`00`=`01` · `26` = { `00`=`br.gov.bcb.pix`, `01`=chave } · `52`=`0000` · `53`=`986` · `54`=total com ponto e 2 casas ·
`58`=`BR` · `59`=nome da loja (até 25, sem acento, maiúsculas) · `60`=cidade (até 15, sem acento, maiúsculas) ·
`62` = { `05`=identificador `DO` + 8 primeiros caracteres do id do pedido, maiúsculos } · `63`=CRC16-CCITT-FALSE
(polinômio 0x1021, inicial 0xFFFF) em hexadecimal maiúsculo, calculado sobre tudo até `6304` inclusive.
Teste com o exemplo do manual do BC e conferência independente do CRC.

## 6. App do construtor

- **Tela do pedido** (`pedido_screen.dart`): bloco "Quem paga este pedido?" enquanto a situação não for `pago`/`cancelado`.
  - "Eu pago": pede o CPF/CNPJ se o perfil não tiver; depois mostra o PIX copia e cola da loja com "Copiar" (sem chave PIX:
    "Combine o pagamento com a loja", como hoje).
  - "Enviar para o cliente": nome e WhatsApp → "Enviar pelo WhatsApp" abre `https://wa.me/55…?text=…` com a mensagem
    "Olá, {nome}! Preparei os materiais da sua obra na {loja}: total {total}. Para pagar direto à loja por PIX e receber a nota
    no seu nome, abra: {link}". Depois mostra a situação, "Reenviar link" e "Trocar cliente". Desligado, com aviso, quando a
    loja não tem chave PIX.
- **Perfil**: campo CPF/CNPJ (opcional, validado).
- Endereço do link: `https://dailyobrabr-creator.github.io/dailyobra/pagar/?c={codigo}` (constante no `dailyobra_comum`).

## 7. Página do cliente

- Arquivo `dailyobra/web/pagar/index.html` (+ `qrcode.min.js` guardado no repositório), publicado junto com o site.
- Chama as funções públicas pelo endpoint REST do Supabase com a chave publicável (a mesma do app).
- Mostra loja, materiais, frete e total → formulário nome + CPF/CNPJ (validação na página e no banco) → QR do PIX, copia e
  cola com "Copiar" e botão "Já paguei" → estados `informado` ("A loja vai conferir e confirmar"), `pago`, `cancelado` e
  link inválido. Visual claro do DailyObra (laranja #F36E21, Inter), funciona em 360 px.

## 8. App Parceiros

- **Minha loja**: campo Chave PIX (dono/gerente).
- **Pedido da loja**: bloco "Dados para a nota" (quem paga, nome, CPF/CNPJ, WhatsApp) e o aviso "Cliente informou o pagamento
  às HH:MM, confira no banco" junto do "Confirmar pagamento" atual.

## 9. Testes

- SQL (transação desfeita no fim, com `raise exception 'RESULTADO: …'`): cada função nova, validações, troca de cliente
  invalida o link, documento invisível ao construtor e a quem não é da loja, BR Code com CRC conferido.
- `dailyobra_comum`: modelos e textos novos.
- Widgets: tela do pedido (Eu pago, Enviar para o cliente, situações, loja sem chave PIX); Parceiros (chave PIX, dados para a
  nota, aviso de pagamento informado). Claro e escuro, como os testes atuais.
- Página: conferida no navegador do app (é pública) em cada estado.

## 10. Fora do escopo

Cartão, boleto ou gateway; API paga de WhatsApp; crediário/limite do Santri; fila de faturamento; notificações push.
