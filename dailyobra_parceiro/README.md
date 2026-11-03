# DailyObra Parceiros (app Android e iOS)

Painel da loja no marketplace DailyObra, no estilo dos apps de parceiros de delivery. Mesmo projeto Supabase do app do construtor (`../dailyobra`); o código em comum fica em `../dailyobra_comum`.

## Telas

- **Entrar**: login e criação de conta. Links do e-mail voltam para `dailyobraparceiros://login`.
- **Cadastrar loja** (primeiro acesso): nome, CNPJ (com conferência dos dígitos), cidade e UF, WhatsApp, endereço, horário, frete fixo e pedido mínimo. Quem cadastra vira dono.
- **Início**: loja aberta ou fechada, propostas novas, pedidos em andamento, total entregue no mês, produtos com preço e a lista do que precisa de resposta.
- **Propostas**: abas Novas, Negociando e Encerradas, atualizadas em tempo real.
  - Proposta: aceitar, recusar com motivo ou mandar contraproposta (preço por produto só para baixo, desconto no total, prazo de 24, 48 ou 72 horas e mensagem).
  - Pedido direto: confirmar ou recusar.
  - Pedido: marcar Em separação, Saiu para entrega e Entregue; confirmar o pagamento (libera o cashback do construtor junto com a entrega); cancelar enquanto não saiu.
- **Pedidos**: abas Em andamento, Entregues e Cancelados.
- **Produtos**: o catálogo mestre do DailyObra com o preço da loja em cada item, busca, filtro e categoria. Em cada produto: preço, promoção com data final, disponibilidade (disponível, sob consulta, sem estoque) e pausa.
- **Importar planilha** (ícone no topo de Produtos, para dono e gerente): a loja escolhe o CSV ou o Excel (.xlsx) exportado do sistema dela, até 3.000 produtos. O app acha as colunas pelo cabeçalho (ou pede para apontar produto e preço), liga cada produto ao catálogo como a lista inteligente, e mostra a revisão: ligados já marcados, "qual destes?" quando há dúvida, unidade diferente e preço inválido desmarcados, repetidos com só o mais barato marcado. Grava tudo de uma vez; os preços que não estão na planilha não mudam. No fim, a lista do que ficou fora do catálogo.
- **Clientes** (no celular, pela aba Mais): todo construtor que mandou proposta, nas abas Todos, Clientes e Leads, com busca, WhatsApp e histórico. A equipe inteira vê.
- **Configurações** (no celular, aba Mais): perfil, endereço e horário, entrega, pagamento, equipe (só o dono), aparência e conta. Cada seção grava só o que é dela.
- **Equipe** (só o dono): convida por e-mail quem já tem conta, como gerente ou vendedor, e remove integrantes.

Papéis: dono e gerente fazem tudo da loja; vendedor responde propostas e acompanha pedidos, sem mudar preços nem dados. O servidor confere o papel de novo em cada ação.

## Rodar

Abra a pasta `D:\dev\dailyobra_app` no VS Code, escolha o aparelho e rode a configuração **DailyObra Parceiros** (F5). Pelo terminal:

```
flutter run
flutter build apk --release   # APK em build\app\outputs\flutter-apk\app-release.apk
```

O APK pronto fica em `..\apk\DailyObraParceiros.apk`.

## Verificar

```
flutter analyze
flutter test        # cadastro da loja e painel em celular de 360 px, temas claro e escuro
```

## Ícone

Capacete do DailyObra em branco e laranja sobre o grafite da marca (#565966), para não confundir com o app do construtor. Para refazer: `dart run tool/gerar_icone.dart` e `dart run flutter_launcher_icons`.

## Configuração

- Identificador: `com.dailyobra.parceiros` (Android e iOS). Nome na tela: "DailyObra Parceiros".
- `android\gradle.properties` tem as mesmas opções do app do construtor (certificados do Avast para o Gradle e Kotlin sem compilação incremental).
- No painel do Supabase, inclua `dailyobraparceiros://login` em Authentication > URL Configuration > Redirect URLs.
