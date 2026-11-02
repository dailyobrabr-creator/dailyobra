# DailyObra Parceiros: importação de planilha de preços

Data: 02/11/2026 · Desenho aprovado na conversa ("Aprovado, segue").

## 1. Entendimento

- **Pedido:** importação de planilha de preços no app Parceiros.
- **Objetivo:** a loja cadastra centenas de preços de uma vez a partir da lista que o sistema dela já exporta; as lojas de Rondonópolis (Operário, Comapa e Taipa) passam a ter produtos.
- **Suposições:** arquivo CSV ou Excel (.xlsx) com uma linha de cabeçalho e um produto por linha (nome e preço; código, unidade e preço promocional opcionais). Nenhum preço entra sem a loja conferir.
- **Sucesso:** escolher o arquivo, conferir e gravar em poucos minutos, com o resumo do que entrou e do que ficou de fora.
- **Fora do escopo:** sincronização automática com o sistema da loja, cadastro de itens novos no catálogo, importação pelo app do construtor ou pelo site.

## 2. Fluxo

1. **Produtos e preços → Importar planilha** (dono e gerente; o vendedor não vê o botão). Arquivo .csv ou .xlsx, até 3.000 linhas de produto.
2. **Colunas:** detectadas pelo cabeçalho, sem diferença de maiúsculas ou acentos:
   - nome: "produto", "descrição", "descricao", "nome", "item";
   - preço: "preço", "preco", "valor", "preço de venda", "preço venda", "valor unitário";
   - promoção: "promoção", "preço promocional", "oferta";
   - unidade: "unidade", "un", "und", "unid";
   - código: "código", "codigo", "sku", "ref", "referência".
   Sem nome ou preço reconhecidos, a tela pede para a loja escolher qual coluna é o nome e qual é o preço. No .xlsx vale a primeira planilha.
3. **Ligação ao catálogo:** cada nome passa pelo reconhecimento da lista inteligente e vai para um de três grupos: **ligado** (um item), **escolher** (até 3 candidatos; a loja toca no certo) e **fora do catálogo** (fica de fora e aparece no resumo).
4. **Revisão:** cada linha mostra o nome da loja, o item do catálogo com a unidade dele e o preço editável. Regras:
   - **unidade diferente** (a unidade da planilha não bate com a do catálogo, como caixa × m²): a linha vem desmarcada até a loja conferir;
   - **item repetido** (duas linhas no mesmo item do catálogo): fica marcada só a mais barata;
   - **preço inválido** (vazio, zero ou não numérico): a linha vem desmarcada com o aviso "preço inválido";
   - **promoção:** se houver coluna de promoção, uma data de validade para todas (padrão: 7 dias); promoção maior ou igual ao preço é ignorada naquela linha.
5. **Gravar N preços:** grava as linhas marcadas de uma vez (um `upsert` em lote por loja e item). Para cada item gravado, preço e promoção passam a ser os da planilha (sem coluna de promoção, a promoção antiga do item sai). Disponibilidade e pausa não mudam. Itens fora da planilha ficam como estavam: nada é apagado.
6. **Resumo:** "N preços gravados · M fora do catálogo", com a lista dos nomes fora do catálogo para enviar ao suporte.

## 3. Leitura de valores

- **CSV:** separador detectado na linha do cabeçalho (`;`, `,` ou tabulação), aspas com separador dentro, BOM do Excel e quebra de linha do Windows.
- **Preço:** "R$ 1.234,56", "1234,56", "1.234,56", "1234.56" e "12" viram número; texto sem número é inválido.
- **Unidade:** comparação pelas mesmas unidades canônicas da lista inteligente (saco, m², m³, barra, unidade, kg, metro, rolo, lata, galão, caixa...). Sem coluna de unidade, não há aviso de unidade.

## 4. Peças

- **`dailyobra_comum/lib/src/marketplace/planilha_precos.dart`** (novo): `lerCsv(String)`, `lerXlsx(Uint8List)` → linhas; `detectarColunas(List<String> cabecalho)` → índices de nome, preço, promoção, unidade e código; `lerPreco(String)`; `montarImportacao(linhas, colunas, catalogo)` → linhas de importação com grupo, item, candidatos, preço, promoção, avisos e se vem marcada.
- **`smart_list.dart`:** `reconhecerProduto(String nome, List<ItemCatalogo> catalogo)` → item ligado ou candidatos, com a mesma pontuação da lista inteligente (sem ler quantidade no começo do nome).
- **Parceiros:** `ImportarPlanilhaScreen` (arquivo → colunas, se preciso → revisão → resumo) e `OfertasService.salvarVarias(List<Oferta>)` com um `upsert` só.
- **Dependências do Parceiros:** `file_picker` (a mesma do app do construtor) e um leitor de .xlsx (pacote `excel`; se não servir no Android e no web, leitor próprio com `archive`, que já vem com o pacote `image`).
- **Banco:** nada muda. As regras de acesso já permitem que dono e gerente gravem ofertas da própria loja; as restrições de preço (maior que zero, promoção menor que o preço e com validade) continuam valendo.

## 5. Erros

- Arquivo que não é .csv/.xlsx, vazio, só com cabeçalho ou acima de 3.000 linhas: mensagem clara e nada é gravado.
- Falha ao gravar: a mensagem do servidor aparece e nada é gravado (o lote é uma operação só).
- Nenhuma linha marcada: o botão de gravar fica desligado.

## 6. Testes

- **Comum:** CSV com `;`, `,` e tabulação, aspas, BOM e preço em formato brasileiro; cabeçalhos variados e escolha manual de colunas; .xlsx montado no próprio teste; ligação ao catálogo ("CIMENTO CP II 50KG VOTORAN" → Cimento CP II 50 kg; nome ambíguo → escolher; "Mangueira de jardim" → fora); unidade diferente desmarcada; repetidos com só o mais barato marcado; preço inválido desmarcado; promoção maior que o preço ignorada.
- **Parceiros:** a tela com arquivo de teste mostra as contagens; editar o preço vale na gravação; o lote gravado leva os preços certos (serviço de teste); o vendedor não vê o botão.
