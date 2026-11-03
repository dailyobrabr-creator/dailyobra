# Endereço com CEP e horário por seleção — design

Data: 2026-11-03 · Item 2 das melhorias pedidas depois da Parte 2 (1: produtos por categoria, feito; 3: painel completo).

## Objetivo

No cadastro da loja e em Minha loja (DailyObra Parceiros), o endereço e o horário deixam de ser texto livre: a loja
digita o CEP e o app preenche o resto; o horário é escolhido dia a dia, sem digitar. O construtor continua vendo o
endereço, o horário e o "aberta · fecha às 17h30" como hoje, com o texto montado a partir dos campos.

Decidido na conversa:
- Loja com mais de uma unidade: **endereço principal pelo CEP + "Outras unidades" em texto** (opcional).
- Horário com **intervalo opcional** por dia (fechar para o almoço).
- Abordagem: endereço em campos no banco, que monta o texto de exibição; horário continua texto, escrito pelo editor
  no formato que o app já lê (`lerHorario`).

## 1. Endereço

- **Campos:** CEP (obrigatório, `00000-000`), Rua (obrigatória), Número (obrigatório; aceita `S/N`), Complemento
  (opcional), Bairro (opcional), Cidade e UF (obrigatórias, como hoje), Outras unidades (opcional, texto livre).
- **Busca do CEP:** com 8 dígitos, o app consulta `https://viacep.com.br/ws/{cep}/json/` direto do aparelho e preenche
  Rua, Bairro, Cidade e UF (todos continuam editáveis); o cursor vai para Número. Mensagens: `Buscando o CEP…`,
  `CEP não encontrado.` (resposta com `erro`) e `Não deu para buscar o CEP agora. Preencha o endereço à mão.` (falha de
  rede). CEP de cidade com um CEP só vem sem rua e bairro: a loja digita.
- **Texto de exibição** (montado pelo banco sempre que há CEP): `Rua, Número[, Complemento][ – Bairro], CEP 00000-000`
  (ex.: `R. Fernando Corrêa da Costa, 1500, sala 2 – Vila Operária, CEP 78700-000`). Sem CEP (lojas antigas), o
  `endereco` fica como está.
- **Lojas já cadastradas:** em Minha loja, sem CEP salvo, aparece `Endereço atual: {texto}` acima dos campos vazios;
  ao salvar com CEP, o texto passa a ser o montado.
- **App do construtor:** a página da loja mostra o endereço como hoje e, se houver, a linha
  `Outras unidades: {texto}`.

## 2. Horário

- **Editor:** uma linha por dia (`Seg` … `Dom`), cada uma `Fechado` ou aberta com `Abre` e `Fecha` escolhidos numa
  lista de 15 em 15 minutos (00:00 a 23:45); `Intervalo` liga a saída e a volta do almoço. Botão
  `Copiar segunda para terça a sexta`.
- **Validação:** fecha depois de abrir; com intervalo, abre < saída < volta < fecha. Mensagem:
  `Confira o horário de {dia}.`. Horário que passa da meia-noite fica de fora.
- **Texto salvo** (o mesmo formato que `lerHorario` lê): dias seguidos com o mesmo horário viram um trecho, trechos
  separados por `; `, primeira letra maiúscula: `Seg a sex 7h às 11h e 13h às 18h; sáb 7h às 12h`. Horas como `7h`,
  `7h30`; dias `seg ter qua qui sex sáb dom`. Todos os dias fechados: horário vazio.
- **Abrir o horário de hoje:** o editor lê o texto salvo com `lerHorario`; se não entender (ou um dia tiver mais de 2
  faixas), começa com todos os dias fechados e mostra `Não deu para ler o horário anterior ({texto}). Escolha de novo.`
- O limite do texto do horário sobe de 120 para 300 caracteres (dias diferentes com intervalo passam de 120).

## 3. Banco

- `lojas` ganha `cep` (8 dígitos), `logradouro` (até 120), `numero` (até 20), `complemento` (até 60), `bairro` (até
  80) e `outras_unidades` (até 200); `endereco` passa a até 300 e `horario` a até 300.
- Gatilho antes de inserir ou atualizar: com `cep` preenchido, `endereco` é montado como na seção 1 (o que o cliente
  mandar em `endereco` é trocado).
- `criar_loja` passa a aceitar e validar os campos novos (`CEP inválido.` quando não tem 8 dígitos); o resto da função
  fica igual. Minha loja grava pelo `update` de hoje (a permissão de dono e gerente já vale para as colunas novas).

## 4. Apps

- **Comum:** `Loja` ganha `cep`, `logradouro`, `numero`, `complemento`, `bairro` e `outrasUnidades`;
  `escreverHorario(List<FaixaHorario>)` gera o texto da seção 2 (o inverso de `lerHorario`).
- **Parceiros:** blocos `CamposEndereco` (com a busca do CEP injetável nos testes) e `EditorHorario`, usados no
  cadastro e em Minha loja; Minha loja passa a editar também Cidade e UF (vêm do CEP).
- **DailyObra:** a lista de lojas lê `outras_unidades`; a página da loja mostra a linha da seção 1.

## 5. Testes

- **Comum:** `escreverHorario` (dias úteis iguais, intervalo, sábado diferente, domingo fechado, dias alternados, tudo
  fechado) e ida e volta com `lerHorario`; `Loja.fromJson` com os campos novos.
- **SQL** (desfeito no fim): endereço montado com e sem complemento e bairro; loja sem CEP mantém o texto; `criar_loja`
  com os campos novos e com CEP inválido; horário de 300 caracteres aceito.
- **Parceiros:** CEP preenche os campos (busca falsa), CEP não encontrado, falha de rede; editor gera o texto, copia
  segunda, valida e abre o horário antigo (lido e não lido); cadastro e Minha loja mandam os campos novos.
- **DailyObra:** a página da loja mostra `Outras unidades: …`.

## Fora do escopo

Várias unidades com CEP cada uma, mapa, horário que passa da meia-noite, feriados, buscar CEP pelo endereço.
