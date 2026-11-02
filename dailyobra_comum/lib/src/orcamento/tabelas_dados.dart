// GERADO por gerar-dart.mjs a partir de src/lib/orcamento (app web). Não editar à mão:
// mude o TypeScript e gere de novo, para os dois motores continuarem com os mesmos números.
// Origem: "Orçamento de Obra 09.2025.xlsm", abas "Tabela Construção nova" e "Listas".

part of 'tabelas.dart';

const construcaoNovaResidencial = <EtapaId, LinhaEtapa>{
  EtapaId.preparacao: LinhaEtapa(
    nome: "Preparação",
    descricao: "Limpeza do terreno, marcações e primeiros ajustes para o início da obra.",
    custoM2: {Padrao.economico: 23.43, Padrao.medio: 39.125009629224216, Padrao.mediaAlta: 43.24657074951193, Padrao.alto: 60.3286524074074},
    maoDeObra: {Padrao.economico: 0.3, Padrao.medio: 0.53, Padrao.mediaAlta: 0.53, Padrao.alto: 0.53},
  ),
  EtapaId.aluguelEquipamentos: LinhaEtapa(
    nome: "Aluguel de equipamentos",
    descricao: "Custos com ferramentas e máquinas essenciais para a execução da obra.",
    custoM2: {Padrao.economico: 25.2, Padrao.medio: 50.2, Padrao.mediaAlta: 85.2, Padrao.alto: 89.46000000000001},
    maoDeObra: {Padrao.economico: 1.0, Padrao.medio: 1.0, Padrao.mediaAlta: 1.0, Padrao.alto: 1.0},
  ),
  EtapaId.fundacao: LinhaEtapa(
    nome: "Fundação",
    descricao: "Etapa de escavação, formas, ferragem e concretagem da fundação da casa.",
    custoM2: {Padrao.economico: 82.29, Padrao.medio: 103.03311742522871, Padrao.mediaAlta: 104.2887119414378, Padrao.alto: 97.06348694275823},
    maoDeObra: {Padrao.economico: 0.4, Padrao.medio: 0.4, Padrao.mediaAlta: 0.4, Padrao.alto: 0.4},
  ),
  EtapaId.fundacaoLaje: LinhaEtapa(
    nome: "Fundação Laje",
    descricao: "Etapa de escavação, formas, ferragem e concretagem da fundação da casa.",
    custoM2: {Padrao.economico: 140.15, Padrao.medio: 140.15, Padrao.mediaAlta: 107.0651468802839, Padrao.alto: 123.68766610187282},
    maoDeObra: {Padrao.economico: 0.4, Padrao.medio: 0.4, Padrao.mediaAlta: 0.4, Padrao.alto: 0.4},
  ),
  EtapaId.estrutura: LinhaEtapa(
    nome: "Estrutura",
    descricao: "Montagem de pilares e vigas da estrutura.",
    custoM2: {Padrao.economico: 100.2, Padrao.medio: 100.69, Padrao.mediaAlta: 141.52448862026364, Padrao.alto: 157.1333336265371},
    maoDeObra: {Padrao.economico: 0.4, Padrao.medio: 0.4, Padrao.mediaAlta: 0.4, Padrao.alto: 0.4},
  ),
  EtapaId.estruturaLaje: LinhaEtapa(
    nome: "Estrutura Laje",
    descricao: "Montagem e concretagem da laje de piso ou cobertura da estrutura.",
    custoM2: {Padrao.economico: 289.23862789772494, Padrao.medio: 289.23862789772494, Padrao.mediaAlta: 295.0248, Padrao.alto: 297.0248},
    maoDeObra: {Padrao.economico: 0.4, Padrao.medio: 0.4, Padrao.mediaAlta: 0.4, Padrao.alto: 0.4},
  ),
  EtapaId.alvenaria: LinhaEtapa(
    nome: "Alvenaria",
    descricao: "Levantamento das paredes com blocos ou tijolos até o nível do teto.",
    custoM2: {Padrao.economico: 181.99, Padrao.medio: 182.99, Padrao.mediaAlta: 192.1395, Padrao.alto: 193.1395},
    maoDeObra: {Padrao.economico: 0.4, Padrao.medio: 0.4, Padrao.mediaAlta: 0.4, Padrao.alto: 0.4},
  ),
  EtapaId.calhasPlatibanda: LinhaEtapa(
    nome: "Calhas e Rufos Platibanda",
    descricao: "Instalação de calhas, rufos e impermeabilização da platibanda.",
    custoM2: {Padrao.economico: 45.6, Padrao.medio: 55.5, Padrao.mediaAlta: 105.2, Padrao.alto: 110.46000000000001},
    maoDeObra: {Padrao.economico: 0.49, Padrao.medio: 0.49, Padrao.mediaAlta: 0.49, Padrao.alto: 0.49},
  ),
  EtapaId.calhasTelhado: LinhaEtapa(
    nome: "Calhas e Rufos Telhado aparente",
    descricao: "Instalação de calhas e rufos do telhado aparente.",
    custoM2: {Padrao.economico: 28.44, Padrao.medio: 35.56, Padrao.mediaAlta: 53.32, Padrao.alto: 55.986000000000004},
    maoDeObra: {Padrao.economico: 0.49, Padrao.medio: 0.49, Padrao.mediaAlta: 0.49, Padrao.alto: 0.49},
  ),
  EtapaId.coberturaPlatibanda: LinhaEtapa(
    nome: "Cobertura Platibanda",
    descricao: "Execução da cobertura plana com caída interna e impermeabilização.",
    custoM2: {Padrao.economico: 170.63, Padrao.medio: 170.8663345363318, Padrao.mediaAlta: 374.6325707616381, Padrao.alto: 406.35538823078014},
    maoDeObra: {Padrao.economico: 0.49, Padrao.medio: 0.49, Padrao.mediaAlta: 0.49, Padrao.alto: 0.49},
  ),
  EtapaId.telhado3Aguas: LinhaEtapa(
    nome: "Telhado aparente 3 ou mais águas",
    descricao: "Execução da cobertura com necessidade de tesouras para sustentação.",
    custoM2: {Padrao.economico: 248.8080943367756, Padrao.medio: 267.89984925639925, Padrao.mediaAlta: 244.46122102773904, Padrao.alto: 267.1928369922177},
    maoDeObra: {Padrao.economico: 0.49, Padrao.medio: 0.49, Padrao.mediaAlta: 0.49, Padrao.alto: 0.49},
  ),
  EtapaId.telhadoAparente: LinhaEtapa(
    nome: "Telhado aparente",
    descricao: "Execução da cobertura sem necessidade de tesouras, somente vigas, caibros e ripas.",
    custoM2: {Padrao.economico: 174.17304965380177, Padrao.medio: 181.05297352717778, Padrao.mediaAlta: 224.2027138854609, Padrao.alto: 253.40875160061725},
    maoDeObra: {Padrao.economico: 0.49, Padrao.medio: 0.49, Padrao.mediaAlta: 0.49, Padrao.alto: 0.49},
  ),
  EtapaId.eletrica: LinhaEtapa(
    nome: "Instalações Elétricas",
    descricao: "Passagem de eletrodutos, fiação, tomadas, interruptores e quadros.",
    custoM2: {Padrao.economico: 166.7, Padrao.medio: 137.17, Padrao.mediaAlta: 193.31, Padrao.alto: 185.58},
    maoDeObra: {Padrao.economico: 0.49, Padrao.medio: 0.49, Padrao.mediaAlta: 0.49, Padrao.alto: 0.49},
  ),
  EtapaId.hidraulica: LinhaEtapa(
    nome: "Instalações Hidráulicas",
    descricao: "Rede de água, esgoto e reservatórios com tubos e conexões.",
    custoM2: {Padrao.economico: 111.11, Padrao.medio: 103.82615160007302, Padrao.mediaAlta: 105.79326501824973, Padrao.alto: 139.86417407407407},
    maoDeObra: {Padrao.economico: 0.49, Padrao.medio: 0.49, Padrao.mediaAlta: 0.49, Padrao.alto: 0.49},
  ),
  EtapaId.forro: LinhaEtapa(
    nome: "Forro",
    descricao: "Instalação de forros de gesso, PVC ou outro material no teto.",
    custoM2: {Padrao.economico: 51.94, Padrao.medio: 68.04913191023532, Padrao.mediaAlta: 92.7220550038197, Padrao.alto: 148.17197860962565},
    maoDeObra: {Padrao.economico: 0.49, Padrao.medio: 0.55, Padrao.mediaAlta: 0.55, Padrao.alto: 0.55},
  ),
  EtapaId.revestimentos: LinhaEtapa(
    nome: "Revestimentos",
    descricao: "Aplicação de pisos e revestimentos em paredes internas e externas.",
    custoM2: {Padrao.economico: 141.62005545689559, Padrao.medio: 175.9604466901243, Padrao.mediaAlta: 237.06745315726286, Padrao.alto: 394.6717841879365},
    maoDeObra: {Padrao.economico: 0.4, Padrao.medio: 0.4, Padrao.mediaAlta: 0.4, Padrao.alto: 0.4},
  ),
  EtapaId.pintura: LinhaEtapa(
    nome: "Pintura",
    descricao: "Preparação de superfícies e pintura de paredes, forros e fachadas.",
    custoM2: {Padrao.economico: 169.4, Padrao.medio: 207.5846007622292, Padrao.mediaAlta: 196.3960371360666, Padrao.alto: 312.862206237037},
    maoDeObra: {Padrao.economico: 0.45, Padrao.medio: 0.49, Padrao.mediaAlta: 0.51, Padrao.alto: 0.51},
  ),
  EtapaId.esquadrias: LinhaEtapa(
    nome: "Esquadrias e aberturas",
    descricao: "Colocação de portas, janelas e demais elementos de fechamento.",
    custoM2: {Padrao.economico: 85.3, Padrao.medio: 135.1, Padrao.mediaAlta: 245.3, Padrao.alto: 275.96250000000003},
    maoDeObra: {Padrao.economico: 0.4, Padrao.medio: 0.4, Padrao.mediaAlta: 0.4, Padrao.alto: 0.4},
  ),
  EtapaId.acabamentos: LinhaEtapa(
    nome: "Acabamentos (louças e metais)",
    descricao: "Instalação de pias, vasos, torneiras e demais itens de acabamento.",
    custoM2: {Padrao.economico: 46.90204563335956, Padrao.medio: 40.38496624703521, Padrao.mediaAlta: 97.38986503692387, Padrao.alto: 287.77777777777777},
    maoDeObra: {Padrao.economico: 0.3, Padrao.medio: 0.3, Padrao.mediaAlta: 0.3, Padrao.alto: 0.3},
  ),
  EtapaId.limpeza: LinhaEtapa(
    nome: "Limpeza Final",
    descricao: "Remoção de resíduos e entrega da obra limpa e pronta para uso.",
    custoM2: {Padrao.economico: 25.3, Padrao.medio: 30.3, Padrao.mediaAlta: 55.2, Padrao.alto: 62.1},
    maoDeObra: {Padrao.economico: 0.7, Padrao.medio: 0.7, Padrao.mediaAlta: 0.7, Padrao.alto: 0.7},
  ),
};

/// R$ por metro linear de muro com 2,5 m de altura (Listas!L2:L6)
const muroPorMetro = <AcabamentoMuro, double>{AcabamentoMuro.economico: 304.35, AcabamentoMuro.chapiscado: 335.15022000000005, AcabamentoMuro.rebocadoInterno: 382.47343106400007, AcabamentoMuro.reboco2Lados: 459.42708539407687, AcabamentoMuro.texturado: 551.8638149753651};

/// Listas!H2:H4
const piscinaPorMetroPerimetro = <TipoPiscina, double>{TipoPiscina.fibra: 1500.0, TipoPiscina.vinil: 2000.0, TipoPiscina.alvenaria: 2800.0};

/// Listas!B16:E18, R$/m²
const gourmetM2 = <TipoGourmet, Map<Padrao, double>>{
  TipoGourmet.churrasqueira: {Padrao.economico: 45.0, Padrao.medio: 75.0, Padrao.mediaAlta: 95.0, Padrao.alto: 145.0},
  TipoGourmet.churrasqueiraIlha: {Padrao.economico: 155.0, Padrao.medio: 235.0, Padrao.mediaAlta: 285.0, Padrao.alto: 425.0},
  TipoGourmet.churrasqueiraIlhaPlanejados: {Padrao.economico: 330.0, Padrao.medio: 495.0, Padrao.mediaAlta: 660.0, Padrao.alto: 995.0},
};

/// Fração da área construída usada como área gourmet (Res1!U44)
const gourmetFracaoArea = <TipoGourmet, double>{TipoGourmet.churrasqueira: 0.15, TipoGourmet.churrasqueiraIlha: 0.25, TipoGourmet.churrasqueiraIlhaPlanejados: 0.25};

/// Listas!B21:E22, R$/m²
const jardimM2 = <TipoJardim, Map<Padrao, double>>{
  TipoJardim.grama: {Padrao.economico: 75.0, Padrao.medio: 95.0, Padrao.mediaAlta: 115.0, Padrao.alto: 125.0},
  TipoJardim.gramaVegetacao: {Padrao.economico: 135.0, Padrao.medio: 165.0, Padrao.mediaAlta: 185.0, Padrao.alto: 295.0},
};

/// Fração da área construída usada como jardim (Res1!U46)
const jardimFracaoArea = <TipoJardim, double>{TipoJardim.grama: 0.2, TipoJardim.gramaVegetacao: 0.25};
