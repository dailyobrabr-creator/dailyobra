# Entregar a loja da Operário ao dono

A Operário já está no DailyObra com endereço, WhatsApp, capa, banner e produtos, mas ainda sem equipe. O dono entra com o CNPJ e um código de acesso. Faça nesta ordem.

## 1. Antes de gerar o código

No painel do Supabase, em **Authentication > URL Configuration**:

- **Site URL**: `https://dailyobrabr-creator.github.io/dailyobra/`
- **Redirect URLs**: `https://dailyobrabr-creator.github.io/dailyobra/`, `https://dailyobrabr-creator.github.io/dailyobra/parceiros/`, `dailyobra://login` e `dailyobraparceiros://login`

Em **Authentication > SMTP**, configure um provedor de e-mail. O envio padrão do Supabase tem limite baixo por hora, e o dono precisa receber o e-mail de confirmação da conta.

## 2. Gerar o código

No **SQL Editor** do Supabase, rode:

```sql
select private.gerar_codigo_loja(id) from public.lojas where cnpj = '36931301000186';
```

- O código aparece uma vez só. Copie na hora.
- Ele vale 30 dias e bloqueia depois de cinco tentativas erradas.
- Rodar de novo gera outro código, e o anterior deixa de valer.
- Depois que o dono entra, a função recusa novo código, porque a loja já tem equipe.

## 3. O que mandar para o dono

1. Abrir o DailyObra Parceiros: `https://dailyobrabr-creator.github.io/dailyobra/parceiros/`
2. Criar a conta e confirmar o e-mail.
3. Tocar em **Minha loja já está no DailyObra**.
4. Informar o CNPJ e o código de acesso.
5. Conferir **Configurações**: cadastrar a chave PIX e convidar a equipe.

## 4. Banner

O banner fica em **Configurações > Perfil da loja**. Dono e gerente enviam, trocam ou removem. O atual é o Feirão de Acabamentos, de 03 a 21 de novembro: depois do dia 21 ele precisa ser trocado ou removido.

A atualização sozinha a partir do site ainda não existe, porque o `operariotem.com.br` recusa acesso automático. Ela depende de a empresa que cuida do site liberar o robô do DailyObra ou criar um link fixo para o banner atual.
