# DailyObra (app Android, iOS e web)

App do construtor no marketplace da construção: vitrine de lojas e ofertas, orçamento juntando produtos de várias lojas, proposta e negociação, pedidos e cashback. Continua com o orçamento estimado da obra, a lista de materiais e o acompanhamento por etapa. Mesmo projeto Supabase do app das lojas (`../dailyobra_parceiro`); o código em comum fica em `../dailyobra_comum`.

## Rodar no celular (Android)

1. **No celular**: Configurações > Sobre o telefone > toque 7 vezes em "Número da versão" para liberar as Opções do desenvolvedor. Depois, em Configurações > Sistema > Opções do desenvolvedor, ligue **Depuração USB**.
2. Ligue o celular no computador pelo cabo USB e, no aviso que aparece no celular, toque em **Permitir** (marque "sempre permitir deste computador").
3. No VS Code: **File > Open Folder** e escolha a pasta `D:\dev\dailyobra_app`. Se aparecer "Restricted Mode", clique em **Trust**.
4. No canto inferior direito do VS Code, clique no nome do aparelho e escolha o seu celular.
5. Na aba **Run and Debug**, escolha **DailyObra** e aperte **F5**. A primeira compilação leva alguns minutos; o app abre sozinho no celular e fica instalado.

Pelo terminal do VS Code (Terminal > New Terminal), dentro desta pasta:

```
flutter devices        # confere se o celular aparece
flutter run            # compila, instala e abre no celular
```

### No navegador

```
flutter run -d chrome                                  # abre o site em modo de desenvolvimento
flutter build web --release --base-href /dailyobra/    # gera o site em build\web
```

A publicação no GitHub Pages está no README da pasta de cima. A tela de abertura do site e os ícones ficam em `web\` (os ícones saem de `assets\icone\icone.png`).

### Instalar sem cabo

`..\apk\DailyObra.apk` é o app pronto. Mande o arquivo para o celular (WhatsApp, Google Drive, cabo), abra e permita "instalar apps desta fonte" quando o Android pedir. Para gerar de novo depois de mudar o código: `flutter build apk --release` (sai em `build\app\outputs\flutter-apk\app-release.apk`). Está assinado com a chave de testes: serve para instalar à mão, não para a Play Store.

### Avast neste computador

O Avast examina conexões HTTPS e troca o certificado dos sites; o Java do Gradle não confia nele e o build falhava com "PKIX path building failed". A solução já está configurada: `tool\certificados_gradle.ps1` criou `C:\Users\luizh\.gradle\dailyobra-certificados.jks` (certificados padrão do Java + o do Avast) e `android\gradle.properties` aponta o Gradle para ele. Nada no Windows, no Avast ou no Java foi alterado.

Em outro computador: com Avast, rode `powershell -ExecutionPolicy Bypass -File tool\certificados_gradle.ps1` uma vez; sem Avast, apague as duas opções `-Djavax.net.ssl.*` de `android\gradle.properties`.

## Telas

Navegação: **Início · Orçamentos · Carteira · Perfil**, com abas embaixo no celular (menos de 600 px), trilho lateral no tablet (600 a 1023 px) e menu lateral com a barra laranja no topo no computador (1024 px ou mais, conteúdo até 1320 px). O sino mostra as novidades: contraproposta, proposta aceita ou recusada, passos do pedido e cashback liberado (no computador, num painel à direita).

- **Entrar**: login, criação de conta (confirmação por e-mail) e recuperação de senha. Dá para usar o simulador sem conta.
- **Início** (vitrine): Clube DailyObra com o nível, contraproposta esperando resposta, pedido em andamento, a obra ativa, a economia do mês (comparando lojas, negociando e cashback, com os últimos 6 meses), **lista inteligente** (cole a lista da obra: "100 sacos de cimento", "ferro 5/16 20 barras"), categorias, ofertas do dia, "mais barato hoje" com a faixa de preço entre as lojas e as lojas perto (as da sua cidade primeiro). Bloco sem dados some ou vira convite.
- **Lista inteligente**: o que foi reconhecido (quantidade editável), o que precisa de escolha ("ferro" → qual bitola) e o que não está no catálogo. No computador, o texto colado fica ao lado, editável.
- **Produto**: preço em cada loja, do menor para o maior; adicionar com a loja mais barata ou escolher a loja. No computador, dados e botão à esquerda, preços à direita.
- **Loja**: capa, logo, frete, pedido mínimo, contato e os produtos com preço (grade de 3 colunas no tablet e 4 no computador).
- **Categoria e busca**: no tablet e no computador, grade com os filtros "Só com oferta", ordem (relevância, menor preço, nome) e, na busca, a categoria.
- **Orçamentos**:
  - Cotação: **Menor preço global** (cada produto na loja mais barata) ou **Melhor por loja** (uma loja só); grupos por loja com frete e aviso de pedido mínimo; trocar a loja de um produto; usar o saldo da carteira; **Proposta** (negociação) ou **Fechar pedido**.
  - Enviados: propostas e pedidos com o andamento, atualizados em tempo real. Contraproposta mostra o preço anunciado riscado e o ofertado, com Aceitar e Recusar. Pedido mostra os passos até a entrega.
- **Carteira**: saldo disponível, a liberar e reservado; economia do mês com a divisão e o gráfico; como ganhar por nível; extrato (em tabela no computador). Saque aparece como "em breve".
- **Perfil**: nome, empresa, cidade e UF, obra ativa (a que aparece no Início), tema (Sistema, Claro, Escuro), Minhas obras, Simulador e sair.
- **Obras** (pelo Perfil): lista, cadastro, ficha da obra com etapas e materiais, e o botão **Cotar materiais desta obra**, que leva a lista da obra para o orçamento já convertida em produtos do catálogo.

Quem pode o quê vem do banco (RLS): nas obras, administrador edita e exclui, membro registra o andamento, cliente só acompanha; no marketplace, cada construtor só vê os próprios orçamentos e a carteira.

## Motor de orçamento

`../dailyobra_comum/lib/src/orcamento/` é o mesmo motor do app web, em Dart. Os números (`tabelas_dados.dart`, `materiais_dados.dart`) são **gerados** do TypeScript para os dois darem o mesmo resultado; não edite esses arquivos à mão. Os testes ficam em `../dailyobra_comum/test/`, incluindo o caso salvo na planilha (153 m², alto padrão: R$ 472.379,30).

## Verificar

```
flutter analyze        # análise do código
flutter test           # telas em 360, 800 e 1366 px nos temas claro e escuro (o motor, a lista inteligente e a cotação são testados no dailyobra_comum)
```

## Ícone

`assets/icone/` tem as bases do ícone, recortadas do logo oficial empilhado (o "O" com o capacete) por `tool/gerar_icone.dart`. Para refazer: `dart run tool/gerar_icone.dart` e `dart run flutter_launcher_icons`. O manual pede validar o capacete em tamanhos pequenos: trate como proposta.

## Pendências de configuração (painel do Supabase)

- Em Authentication > URL Configuration > Redirect URLs, adicione `dailyobra://login` (e `dailyobraparceiros://login`, do app das lojas) e o endereço do site; em Site URL, o endereço do site. Sem isso, o link de confirmação de conta abre no navegador (a conta é confirmada mesmo assim; depois é só entrar no app) e o de nova senha não volta para o app.
- Em Authentication > SMTP, configure um provedor de e-mail: o envio padrão do Supabase tem limite baixo por hora.
- Identificador do app: `com.dailyobra.dailyobra` (Android e iOS). Troque antes de publicar nas lojas, se a empresa tiver um domínio próprio.
- Para a Play Store: criar a chave de assinatura de produção (hoje o build de release usa a chave de testes).
