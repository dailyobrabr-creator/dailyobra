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

O app do construtor também roda no navegador, com o mesmo código: no celular fica como o app (abas embaixo), no tablet ganha um trilho lateral e no computador um menu lateral com a barra laranja no topo, Início em vitrine, Orçamentos com o resumo fixo à direita e Enviados em lista e detalhe lado a lado. O app das lojas continua só no Android.

Para ver na sua máquina:

```
cd dailyobra
flutter run -d chrome
```

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

As regras do banco são conferidas por `supabase/tests/marketplace_test.sql` (roda numa transação desfeita no fim; cada linha do resultado tem `ok = true`).

## Avast neste computador

O Avast examina conexões HTTPS e o Java do Gradle não confia no certificado dele. Os dois apps já apontam o Gradle para `C:\Users\luizh\.gradle\dailyobra-certificados.jks` (criado por `dailyobra\tool\certificados_gradle.ps1`), em `android\gradle.properties`. Nada no Windows, no Avast ou no Java foi alterado. Em outro computador sem Avast, apague as duas opções `-Djavax.net.ssl.*` desse arquivo; com Avast, rode o script lá também.

## Lojas cadastradas pelo suporte

Operário, Comapa e Taipa (Rondonópolis-MT) foram cadastradas com os dados públicos dos sites delas, sem conta dona, sem preços e com **frete a combinar** (o app mostra "Frete a combinar" até a loja salvar o frete). Quando cada loja criar a conta no app Parceiros (sem cadastrar a loja de novo, porque o CNPJ já existe), ligue a conta à loja no **SQL Editor** do Supabase:

```sql
insert into public.loja_membros (loja_id, user_id, papel)
select l.id, u.id, 'dono' from public.lojas l, auth.users u
where l.cnpj = '04769422000187' and u.email = 'email-da-loja@exemplo.com';
```

CNPJs: Operário `36931301000186`, Comapa `04769422000187`, Taipa `33651993000463`. A partir daí a loja edita o perfil, o frete e os preços pelo app Parceiros.

## Pendências no painel do Supabase

- **Authentication > URL Configuration > Redirect URLs**: adicione `dailyobra://login`, `dailyobraparceiros://login` e o endereço do site no GitHub Pages; em **Site URL**, o endereço do site (links de confirmação de conta e de nova senha voltam para o app ou para o site certo).
- **Authentication > SMTP**: configure um provedor de e-mail; o envio padrão do Supabase tem limite baixo por hora.
- **Authentication > Password security**: ligue a proteção contra senhas vazadas.
- Para publicar nas lojas: criar a chave de assinatura de produção e, se a empresa tiver domínio próprio, revisar os identificadores dos apps.

## Fica para depois

Pagamento dentro do app, saque da carteira (o botão aparece como "em breve"), integração com o sistema da loja e importação de planilha de preços, aviso no celular com o app fechado e chat.
