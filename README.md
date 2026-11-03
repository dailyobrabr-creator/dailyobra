# DailyObra: marketplace da construção

Dois apps Flutter sobre o mesmo Supabase (projeto `dailyobra`, São Paulo):

| Pasta | App | Para quem |
|---|---|---|
| `dailyobra` | **DailyObra** (`com.dailyobra.dailyobra`) | Construtor e engenheiro: vê lojas, ofertas e preços, monta o orçamento juntando produtos de várias lojas, manda proposta ou pedido, negocia e acompanha a entrega. Cashback na carteira. |
| `dailyobra_parceiro` | **DailyObra Parceiros** (`com.dailyobra.parceiros`) | Loja de material de construção: cadastro com CNPJ, preços e promoções, responde propostas (aceita, recusa, contraproposta), avança os pedidos e cuida do perfil (logo, capa, frete, pedido mínimo, equipe). |
| `dailyobra_comum` | pacote compartilhado | Tema claro e escuro, componentes, motor de orçamento da obra, lista inteligente, cotação entre lojas, modelos e login. |
| `supabase` | banco | Migrações (`migrations`) e o roteiro de testes das regras (`tests/marketplace_test.sql`). |

Preço, negociação, pedido e carteira são decididos no banco (funções `security definer` e RLS em todas as tabelas): o app nunca manda preço, só o que o construtor escolheu; o servidor lê das ofertas das lojas.

## Instalar no celular sem compilar

Os dois apps prontos ficam em `apk\`:

- `apk\DailyObra.apk`
- `apk\DailyObraParceiros.apk`

Mande o arquivo para o celular (WhatsApp, Google Drive ou cabo), abra e permita "instalar apps desta fonte" quando o Android pedir. Os dois podem ficar instalados juntos. Estão assinados com a chave de testes: servem para instalar à mão, não para a Play Store.

## Site (web) do construtor

O app do construtor também roda no navegador, com o mesmo código: no celular fica como o app (abas embaixo), no tablet ganha um trilho lateral e no computador um menu lateral com a barra laranja no topo, Início em vitrine, Orçamentos com o resumo fixo à direita e Enviados em lista e detalhe lado a lado.

Para ver na sua máquina:

```
cd dailyobra
flutter run -d chrome
```

## Painel da loja na web

O DailyObra Parceiros também abre no navegador, em `https://dailyobrabr-creator.github.io/dailyobra/parceiros/`, com a mesma conta do app: no computador ganha o menu lateral com a barra laranja da loja e, em Propostas, a lista com a proposta ou o pedido aberto ao lado. Sai junto com o site a cada push no `main`. Para os links de cadastro e de "Esqueci a senha" voltarem ao painel, inclua esse endereço no Supabase em **Authentication > URL Configuration > Redirect URLs**.

Para ver na sua máquina: `cd dailyobra_parceiro` e `flutter run -d chrome`.

## Publicar no GitHub Pages

O arquivo `.github/workflows/web.yml` testa os pacotes e publica o site a cada envio para a branch `main` (ou quando você manda rodar em **Actions**). Uma vez só:

1. No GitHub, crie um repositório (ex.: `dailyobra`). Pode ser público ou privado; o GitHub Pages em repositório privado depende do plano da conta.
2. Envie esta pasta inteira para ele, na branch `main`:

   ```
   git init
   git add .
   git commit -m "DailyObra"
   git branch -M main
   git remote add origin https://github.com/SEU-USUARIO/dailyobra.git
   git push -u origin main
   ```

   O `.gitignore` deixa de fora `build/`, os APKs e os rascunhos de trabalho.
3. No repositório: **Settings > Pages > Build and deployment > Source: GitHub Actions**.
4. Em **Actions**, acompanhe "Site no GitHub Pages". No fim, o endereço aparece no passo **publicar**: `https://SEU-USUARIO.github.io/dailyobra/`.
5. No Supabase, **Authentication > URL Configuration**: em **Site URL** coloque esse endereço e em **Redirect URLs** adicione o mesmo endereço (os links de confirmação de conta e de nova senha voltam para o site).

O endereço leva o nome do repositório (`--base-href "/nome-do-repositorio/"`). Se o repositório se chamar `SEU-USUARIO.github.io`, o site fica na raiz: troque o `--base-href` do workflow por `"/"`.

Só a chave publicável do Supabase vai no site (a mesma dos apps); as regras ficam no banco. Nunca coloque a chave secreta (`service_role` ou `sb_secret_...`) no código nem nos segredos do workflow.

## Ler a lista de um PDF ou foto

Na lista inteligente do Início, o clipe dentro do campo aceita PDF, JPG, PNG ou WEBP de até 10 MB (PDF com até 20 páginas). A função `ler-lista` do Supabase (`supabase/functions/ler-lista`) manda o arquivo para o Claude (Anthropic), que devolve os materiais com as quantidades; o texto abre na revisão da lista inteligente antes de cotar. Cada pessoa tem 30 leituras a cada 24 horas (`public.registrar_leitura_lista`). Nada do arquivo fica guardado.

Para ligar, uma vez:

1. Crie uma chave em https://console.anthropic.com (**API Keys**).
2. No Supabase: **Edge Functions > Secrets > Add new secret**, nome `ANTHROPIC_API_KEY`, valor a chave.

Sem a chave, o clipe avisa que a leitura ainda não está ligada. A chave fica só no Supabase: nunca no app, no site ou no GitHub. Testes das regras da função: `node --test supabase/functions/ler-lista/regras.test.ts`.

## Abrir e rodar pelo VS Code

1. **File > Open Folder** e escolha esta pasta (`D:\dev\dailyobra_app`). Se aparecer "Restricted Mode", clique em **Trust**.
2. Ligue o celular com **Depuração USB** (Configurações > Sobre o telefone > toque 7 vezes em "Número da versão"; depois Opções do desenvolvedor > Depuração USB) ou abra o emulador.
3. No canto inferior direito, escolha o aparelho.
4. Na aba **Run and Debug**, escolha **DailyObra** ou **DailyObra Parceiros** e aperte **F5**.

Pelo terminal, o mesmo:

```
cd dailyobra             # ou: cd dailyobra_parceiro
flutter run
```

Para gerar o APK de novo: `flutter build apk --release` dentro da pasta do app (sai em `build\app\outputs\flutter-apk\app-release.apk`).

## Testar o fluxo completo

1. No **Parceiros**, crie uma conta, cadastre a loja (CNPJ válido) e em **Produtos** coloque preço em alguns itens, um deles em promoção.
2. No **DailyObra**, entre com outra conta, informe a cidade no **Perfil** e veja a loja e a oferta no **Início**.
3. Cole uma lista na **Lista inteligente** (ex.: `100 sacos de cimento`, `20 barras ferro 5/16`), adicione ao orçamento e, em **Orçamentos**, toque em **Proposta**.
4. No **Parceiros**, a proposta aparece na hora em **Propostas**: mande uma contraproposta. No **DailyObra**, aceite: vira pedido, com cashback "a liberar" na **Carteira**.
5. No **Parceiros**, avance o pedido até **Entregue** e toque em **Confirmar pagamento**: o cashback fica disponível na carteira do construtor.

## Verificar

```
cd dailyobra_comum   && flutter analyze && flutter test
cd ../dailyobra      && flutter analyze && flutter test
cd ../dailyobra_parceiro && flutter analyze && flutter test
```

Os testes de tela do `dailyobra` passam por 360, 800 e 1366 px de largura, nos temas claro e escuro.

A página do cliente (`dailyobra/web/pagar/`) tem testes em Node, sem instalar nada: `node --test dailyobra/test/pagina_pagar_test.mjs` (na raiz do repositório).

As regras do banco são conferidas por `supabase/tests/marketplace_test.sql` (roda numa transação desfeita no fim; cada linha do resultado tem `ok = true`), por `supabase/tests/checkout_bifurcado_test.sql`, `supabase/tests/checkout_pagamento_test.sql` e `supabase/tests/importacao_estoque_test.sql` (também desfeitos no fim; terminam com a contagem de verificações ok).

## Pagamento pelo cliente (link PIX)

Depois que a loja aceita, o construtor escolhe no pedido quem paga:

- **Eu pago**: informa o CPF ou CNPJ dele (fica salvo no **Perfil**; **Alterar** troca), a nota sai no nome dele e ele escolhe a forma: **PIX** (copia e cola da loja), **Cartão na loja** (maquininha na entrega ou retirada) ou **Crediário da loja** (prazo de 28, 28/35 ou 28/35/42 dias, que o dono ou o gerente da loja aprova ou recusa). O interruptor **Usar saldo da carteira** abate o saldo neste pedido: o saldo entra só aqui, na hora de pagar (a cotação não usa mais saldo), e o PIX sai com o total novo.
- **Enviar para o cliente**: informa nome, WhatsApp e, se quiser, o CPF ou CNPJ do dono da obra; o app mostra a mensagem exata e abre o WhatsApp com o link `https://dailyobrabr-creator.github.io/dailyobra/pagar/?c=...`. O link devolve à carteira o saldo que estava no pedido. A página (`dailyobra/web/pagar/`) não pede conta nem app: o cliente vê os materiais, informa nome e CPF/CNPJ para a nota (se o construtor já informou, a página abre no PIX mostrando só o documento mascarado, com **Corrigir**), paga pelo QR ou pelo copia e cola direto à loja e toca em **Já paguei**. "Trocar cliente" gera outro link e o antigo para de funcionar.

A loja cadastra a chave PIX em **Minha loja > Chave PIX** no app Parceiros (CPF, CNPJ, e-mail, celular com +55 ou chave aleatória); a chave fica na tabela `loja_pix`, que só a equipe da loja lê (quem paga vê só o PIX do pedido). Sem chave, só o "Eu pago" fica disponível. Se o saldo DailyObra cobriu o pedido inteiro, não há PIX nem link: o construtor só informa o CPF/CNPJ para a nota. No pedido, o painel **Pagamento** mostra a forma escolhida; com prazo do crediário pendente, dono e gerente tocam em **Aprovar prazo** ou **Recusar** (o vendedor vê o aviso) e a lista de pedidos mostra o selo **Prazo para aprovar**. O bloco **Dados para a nota** mostra quem paga, nome, CPF/CNPJ e WhatsApp, e aparece o aviso quando o cliente informou o pagamento. A loja confere no banco e toca em **Confirmar pagamento**; o cashback do construtor continua liberando com pedido pago e entregue. Não há gateway: o dinheiro vai direto para a conta da loja.

## Avast neste computador

O Avast examina conexões HTTPS e o Java do Gradle não confia no certificado dele. Os dois apps já apontam o Gradle para `C:\Users\luizh\.gradle\dailyobra-certificados.jks` (criado por `dailyobra\tool\certificados_gradle.ps1`), em `android\gradle.properties`. Nada no Windows, no Avast ou no Java foi alterado. Em outro computador sem Avast, apague as duas opções `-Djavax.net.ssl.*` desse arquivo; com Avast, rode o script lá também.

## Importar planilha de preços (app Parceiros)

Em **Produtos e preços**, o ícone de enviar arquivo abre a importação (só para dono e gerente). Aceita CSV (separado por `;`, `,` ou tabulação, em UTF-8 ou no padrão do Excel), Excel `.xlsx` e LibreOffice `.ods` (primeira planilha), até 3.000 produtos. O cabeçalho pode ter "Produto"/"Descrição", "Preço"/"Valor", "Preço promocional", "Unidade" e "Código" em qualquer ordem; se não tiver, a loja aponta as colunas. Cada produto é ligado ao catálogo pelo mesmo reconhecimento da lista inteligente, e a loja confere antes de gravar. A leitura fica em `dailyobra_comum/lib/src/marketplace/planilha_precos.dart`; a tela, em `dailyobra_parceiro/lib/screens/importar_planilha_screen.dart`.

## Atualizar pelo Santri (estoque do dia)

Em **Produtos e preços**, o ícone de estoque abre **Atualizar pelo Santri** (só para dono e gerente). A loja exporta do Santri ADM o relatório **"Valor do estoque analítico"** (`.ods`, `.xlsx` ou `.csv`) e escolhe o arquivo. Ele é lido no próprio navegador ou celular: só código, nome, unidade, preço e disponível dos produtos usados vão para o banco; o custo não sai do computador e o arquivo não é guardado. O resumo mostra o que muda (preço novo, voltou ao estoque, ficou sem estoque, não veio no relatório) e separa em **Conferir** o preço que mudou mais de 30% ou ficou em R$ 1,00 ou menos (só entra marcado). Produto do catálogo ainda sem ligação aparece com a sugestão mais parecida do relatório (só itens que começam pela mesma palavra do produto, como "TIJOLO" para tijolo) para **Ligar**, trocar (**Outro**), **Procurar** no relatório por nome ou código ou **Pular**; o que é ligado atualiza sozinho nos dias seguintes. Vários códigos no mesmo produto: vale o mais barato com estoque. As ligações ficam na tabela `loja_produtos` e a gravação é a função `importar_estoque` (teste em `supabase/tests/importacao_estoque_test.sql`); a leitura do relatório e as regras ficam em `dailyobra_comum/lib/src/marketplace/leitor_ods.dart` e `estoque_santri.dart`. A Operário já começa com as 61 ligações conferidas item a item.

## Lojas cadastradas pelo suporte

Operário, Comapa e Taipa (Rondonópolis-MT) foram cadastradas com os dados públicos dos sites delas, sem conta dona, sem preços e com **frete a combinar** (o app mostra "Frete a combinar" até a loja salvar o frete). Quando cada loja criar a conta no app Parceiros (sem cadastrar a loja de novo, porque o CNPJ já existe), ligue a conta à loja no **SQL Editor** do Supabase:

```sql
insert into public.loja_membros (loja_id, user_id, papel)
select l.id, u.id, 'dono' from public.lojas l, auth.users u
where l.cnpj = '04769422000187' and u.email = 'email-da-loja@exemplo.com';
```

CNPJs: Operário `36931301000186`, Comapa `04769422000187`, Taipa `33651993000463`. A partir daí a loja edita o perfil, o frete e os preços pelo app Parceiros, e pode subir a planilha de preços de uma vez (Produtos e preços > Importar planilha). As logos e capas delas (montadas a partir das logos oficiais) ficam em `dailyobra/web/lojas/` e são servidas pelo site; quando a loja trocar a logo pelo app, passa a valer a dela.

O selo **aberta / fechada** sai do horário que a loja escreve ("Seg a sex 7h às 18h; sáb 7h às 12h"), no fuso do estado dela. O interruptor do app Parceiros pausa os pedidos (a loja sai da cotação) sem apagar o horário.

## Pendências no painel do Supabase

- **Authentication > URL Configuration > Redirect URLs**: adicione `dailyobra://login`, `dailyobraparceiros://login` e o endereço do site no GitHub Pages; em **Site URL**, o endereço do site (links de confirmação de conta e de nova senha voltam para o app ou para o site certo).
- **Authentication > SMTP**: configure um provedor de e-mail; o envio padrão do Supabase tem limite baixo por hora.
- **Authentication > Password security**: ligue a proteção contra senhas vazadas.
- Para publicar nas lojas: criar a chave de assinatura de produção e, se a empresa tiver domínio próprio, revisar os identificadores dos apps.

## Fica para depois

Pagamento dentro do app, saque da carteira (o botão aparece como "em breve"), integração com o sistema da loja e importação de planilha de preços, aviso no celular com o app fechado e chat.
