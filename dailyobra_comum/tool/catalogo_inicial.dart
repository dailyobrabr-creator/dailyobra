// Catálogo DailyObra inicial: fonte única dos produtos padronizados, gera o SQL da migração.
// Uso: dart run tool/catalogo_inicial.dart > ../supabase/migrations/20261031130100_catalogo_inicial.sql
//
// Origem: os 109 materiais das planilhas "Projetos Calculos" (econômico, médio/alto, alto), unificados.
// As linhas "Alto" das planilhas viram produtos da linha premium. Quando a planilha usa outra unidade
// que dá para converter pelo próprio nome (coluna de 6 m em metros, caixa d'água em litros), o fator
// converte para a unidade do produto; quando não dá (caibro e viga por peça ou por metro), há um produto
// para cada unidade, sem inventar conversão.

import 'dart:io';

class CategoriaInicial {
  const CategoriaInicial(this.id, this.nome, this.ordem);
  final String id;
  final String nome;
  final int ordem;
}

class ItemInicial {
  const ItemInicial(this.id, this.nome, this.unidade, this.categoria, this.sinonimos);
  final String id;
  final String nome;
  final String unidade;
  final String categoria;
  final List<String> sinonimos;
  int get tier => tierDaCategoria[categoria]!;
}

const categoriasIniciais = [
  CategoriaInicial('basico', 'Básico', 1),
  CategoriaInicial('estrutura', 'Estrutura', 2),
  CategoriaInicial('alvenaria', 'Alvenaria', 3),
  CategoriaInicial('cobertura', 'Cobertura', 4),
  CategoriaInicial('hidraulica', 'Hidráulica', 5),
  CategoriaInicial('eletrica', 'Elétrica', 6),
  CategoriaInicial('acabamento', 'Acabamento', 7),
  CategoriaInicial('pintura', 'Pintura', 8),
  CategoriaInicial('loucas-metais', 'Louças e metais', 9),
  CategoriaInicial('ferramentas', 'Ferramentas', 10),
];

/// Nível de cashback por categoria (spec, seção 1): 1 = 1%, 2 = 2%, 3 = 3%, 4 = 5%
const tierDaCategoria = {
  'basico': 1, 'estrutura': 1, 'alvenaria': 1,
  'hidraulica': 2, 'eletrica': 2,
  'cobertura': 3, 'pintura': 3, 'ferramentas': 3,
  'acabamento': 4, 'loucas-metais': 4,
};

const percentualDoTier = {1: 0.01, 2: 0.02, 3: 0.03, 4: 0.05};

const itensIniciais = [
  // Básico
  ItemInicial('cimento-cp2-50kg', 'Cimento CP II 50 kg', 'saco', 'basico', ['cimento', 'cp2', 'cp ii', 'cimento 50kg', 'itau', 'votoran', 'saco de cimento']),
  ItemInicial('areia-grossa', 'Areia grossa', 'm³', 'basico', ['areia', 'areia grossa', 'areia lavada']),
  ItemInicial('areia-media', 'Areia média', 'm³', 'basico', ['areia', 'areia media', 'areia fina']),
  ItemInicial('pedra-brita-1', 'Pedra brita nº 1', 'm³', 'basico', ['brita', 'pedra', 'pedra brita', 'brita 1']),
  ItemInicial('cal-hidratada-20kg', 'Cal hidratada 20 kg', 'saco', 'basico', ['cal', 'cal hidratada', 'ch3']),
  ItemInicial('argamassa-ac1-20kg', 'Argamassa colante AC-I 20 kg', 'saco', 'basico', ['argamassa', 'argamassa colante', 'ac1', 'ac-i', 'cimento cola']),
  ItemInicial('argamassa-ac3-20kg', 'Argamassa colante AC-III 20 kg', 'saco', 'basico', ['argamassa', 'ac3', 'ac-iii', 'porcelanato', 'argamassa porcelanato']),
  ItemInicial('lona-plastica-preta', 'Lona plástica preta para impermeabilização', 'rolo', 'basico', ['lona', 'plastico', 'lona preta', 'plastico preto']),
  // Estrutura
  ItemInicial('vergalhao-5mm', 'Vergalhão CA-60 5,0 mm (barra 12 m)', 'barra', 'estrutura', ['vergalhao', 'ferro', 'aco', '5mm', '5,0mm', '3/16', 'ca60', 'ferro 5mm']),
  ItemInicial('vergalhao-8mm', 'Vergalhão CA-50 8,0 mm 5/16 (barra 12 m)', 'barra', 'estrutura', ['vergalhao', 'ferro', 'aco', '8mm', '8,0mm', '5/16', 'ca50', 'ferro 5/16']),
  ItemInicial('vergalhao-10mm', 'Vergalhão CA-50 10,0 mm 3/8 (barra 12 m)', 'barra', 'estrutura', ['vergalhao', 'ferro', 'aco', '10mm', '10,0mm', '3/8', 'ca50', 'ferro 3/8']),
  ItemInicial('coluna-7x14-8mm', 'Coluna armada 7x14 cm 8 mm (6 m)', 'peça', 'estrutura', ['coluna', 'coluna pronta', 'coluna armada', '7x14', 'armacao', '8mm']),
  ItemInicial('coluna-7x14-10mm', 'Coluna armada 7x14 cm 10 mm (6 m)', 'peça', 'estrutura', ['coluna', 'coluna pronta', 'coluna armada', '7x14', 'armacao', '10mm']),
  ItemInicial('tela-soldada-10x10', 'Painel de tela soldada 10x10 cm', 'painel', 'estrutura', ['tela', 'tela soldada', 'malha', 'painel telado', '10x10']),
  ItemInicial('trelica-tr8', 'Treliça para laje TR 8', 'barra', 'estrutura', ['trelica', 'trelica laje', 'tr8']),
  ItemInicial('arame-recozido-18', 'Arame recozido nº 18', 'kg', 'estrutura', ['arame', 'arame recozido', 'arame 18']),
  ItemInicial('prego-17x27', 'Prego 17x27 com cabeça', 'kg', 'estrutura', ['prego', 'pregos', '17x27']),
  ItemInicial('tabua-mista-30cm', 'Tábua mista 30 cm', 'm', 'estrutura', ['tabua', 'tabua 30', 'madeira', 'forma', 'tabua de forma']),
  ItemInicial('tabua-mista-10cm', 'Tábua mista 10 cm', 'm', 'estrutura', ['tabua', 'tabua 10', 'sarrafo', 'madeira']),
  ItemInicial('ripao', 'Ripão de madeira', 'm', 'estrutura', ['ripao', 'ripa', 'madeira']),
  ItemInicial('estaca-marcacao', 'Estaca de madeira para marcação', 'unidade', 'estrutura', ['estaca', 'estacas', 'marcacao', 'piquete']),
  // Alvenaria
  ItemInicial('tijolo-6-furos', 'Tijolo cerâmico 6 furos 9x14x24 cm', 'unidade', 'alvenaria', ['tijolo', 'tijolo 6 furos', 'bloco ceramico', '6 furos', 'baiano']),
  ItemInicial('tijolo-8-furos', 'Tijolo cerâmico 8 furos 9x19x24 cm', 'unidade', 'alvenaria', ['tijolo', 'tijolo 8 furos', 'bloco ceramico', '8 furos', 'baiano']),
  ItemInicial('tijolo-9-furos', 'Tijolo cerâmico 9 furos 11,5x19x24 cm', 'unidade', 'alvenaria', ['tijolo', 'tijolo 9 furos', 'bloco ceramico', '9 furos']),
  ItemInicial('canaleta-ceramica', 'Canaleta cerâmica 9x19x19 cm', 'unidade', 'alvenaria', ['canaleta', 'canaletinha', 'meia canaleta']),
  // Cobertura
  ItemInicial('telha-fibrocimento-6mm', 'Telha de fibrocimento 6 mm 2,44 x 1,10 m', 'unidade', 'cobertura', ['telha', 'fibrocimento', 'eternit', 'brasilit', 'telha ondulada']),
  ItemInicial('parafuso-telha', 'Parafuso para telha com vedação', 'unidade', 'cobertura', ['parafuso telha', 'parafuso', 'fixador telha']),
  ItemInicial('telha-ceramica-romana', 'Telha cerâmica romana/portuguesa', 'unidade', 'cobertura', ['telha', 'telha ceramica', 'romana', 'portuguesa', 'telha barro']),
  ItemInicial('telha-zinco', 'Telha de aço zincado trapezoidal', 'm²', 'cobertura', ['telha', 'zinco', 'telha metalica', 'galvalume']),
  ItemInicial('telha-sanduiche', 'Telha termoacústica sanduíche', 'unidade', 'cobertura', ['telha', 'sanduiche', 'termoacustica', 'telha isolada']),
  ItemInicial('caibro-peroba-peca', 'Caibro peroba 5x5 cm (peça)', 'peça', 'cobertura', ['caibro', 'peroba', '5x5', 'madeira telhado']),
  ItemInicial('caibro-peroba-metro', 'Caibro peroba 5x5 cm (metro)', 'm', 'cobertura', ['caibro', 'peroba', '5x5', 'madeira telhado']),
  ItemInicial('caibro-misto-5x5', 'Caibro misto 5x5 cm', 'm', 'cobertura', ['caibro', 'misto', '5x5']),
  ItemInicial('viga-peroba-peca', 'Viga peroba 6x12 cm (peça)', 'peça', 'cobertura', ['viga', 'peroba', 'viga madeira', '6x12']),
  ItemInicial('viga-peroba-metro', 'Viga peroba 6x12 cm (metro)', 'm', 'cobertura', ['viga', 'peroba', 'viga madeira', '6x12']),
  ItemInicial('pintura-asfaltica-18l', 'Pintura asfáltica 18 L', 'lata', 'cobertura', ['pintura asfaltica', 'asfaltica', 'neutrol', 'impermeabilizante asfaltico']),
  ItemInicial('impermeabilizante-polimerico', 'Impermeabilizante polimérico 18 kg', 'caixa', 'cobertura', ['impermeabilizante', 'polimerico', 'viapol', 'vedacit']),
  ItemInicial('impermeabilizante-acrilico-18l', 'Impermeabilizante acrílico 18 L', 'balde', 'cobertura', ['impermeabilizante', 'acrilico', 'manta liquida', 'laje']),
  // Hidráulica
  ItemInicial('caixa-dagua-1000l', "Caixa d'água de polietileno 1.000 L", 'unidade', 'hidraulica', ["caixa d'agua", 'caixa dagua', 'reservatorio', '1000l', 'caixa agua']),
  ItemInicial('registro-gaveta-3-4', 'Registro de gaveta 3/4"', 'unidade', 'hidraulica', ['registro', 'registro gaveta', '3/4', 'gaveta']),
  ItemInicial('registro-pressao-3-4', 'Registro de pressão 3/4"', 'unidade', 'hidraulica', ['registro', 'registro pressao', '3/4', 'pressao']),
  ItemInicial('conexoes-agua-fria', 'Conexões PVC soldável água fria (sortidas)', 'unidade', 'hidraulica', ['conexao', 'conexoes', 'joelho', 'luva', 'te', 'agua fria', 'soldavel']),
  ItemInicial('conexoes-esgoto', 'Conexões PVC esgoto (sortidas)', 'unidade', 'hidraulica', ['conexao', 'conexoes', 'joelho esgoto', 'esgoto', 'curva']),
  ItemInicial('conexoes-agua-quente', 'Conexões CPVC água quente (sortidas)', 'unidade', 'hidraulica', ['conexao', 'conexoes', 'cpvc', 'agua quente', 'aquatherm']),
  ItemInicial('tubo-agua-fria-25mm', 'Tubo PVC soldável 25 mm (barra 6 m)', 'barra', 'hidraulica', ['tubo', 'cano', 'pvc', '25mm', 'agua fria', 'soldavel']),
  ItemInicial('tubo-esgoto-100mm', 'Tubo PVC esgoto 100 mm (barra 6 m)', 'barra', 'hidraulica', ['tubo', 'cano', 'esgoto', '100mm', 'pvc esgoto']),
  ItemInicial('tubo-agua-quente-22mm', 'Tubo CPVC 22 mm (barra 3 m)', 'barra', 'hidraulica', ['tubo', 'cano', 'cpvc', '22mm', 'agua quente']),
  ItemInicial('adesivo-pvc-175g', 'Adesivo plástico para PVC 175 g', 'unidade', 'hidraulica', ['adesivo', 'cola', 'cola pvc', 'adesivo plastico', 'tigre']),
  ItemInicial('caixa-sifonada-150', 'Caixa sifonada 150x150 mm', 'unidade', 'hidraulica', ['caixa sifonada', 'ralo', 'sifonada']),
  ItemInicial('caixa-gordura', 'Caixa de gordura', 'unidade', 'hidraulica', ['caixa gordura', 'caixa de gordura']),
  ItemInicial('caixa-passagem-esgoto', 'Caixa de passagem para esgoto', 'unidade', 'hidraulica', ['caixa passagem', 'caixa de inspecao', 'caixa esgoto']),
  ItemInicial('torneira-boia-3-4', 'Torneira boia 3/4"', 'unidade', 'hidraulica', ['boia', 'torneira boia', 'boia caixa']),
  ItemInicial('adaptador-flange-25mm', 'Adaptador com flange 25 mm', 'unidade', 'hidraulica', ['flange', 'adaptador flange', 'adaptador caixa']),
  ItemInicial('kit-cavalete-hidrometro', 'Kit cavalete para hidrômetro', 'unidade', 'hidraulica', ['cavalete', 'hidrometro', 'relogio de agua', 'kit cavalete']),
  // Elétrica
  ItemInicial('cabo-triplex-10mm', 'Cabo triplex 10 mm² (entrada de energia)', 'm', 'eletrica', ['cabo triplex', 'triplex', 'cabo entrada', 'multiplexado']),
  ItemInicial('cabo-flexivel-2-5mm', 'Cabo flexível 2,5 mm²', 'm', 'eletrica', ['cabo', 'fio', '2,5mm', '2,5', '2.5mm', 'cabo flexivel', 'sil']),
  ItemInicial('cabo-flexivel-4mm', 'Cabo flexível 4 mm²', 'm', 'eletrica', ['cabo', 'fio', '4mm', 'cabo flexivel']),
  ItemInicial('cabo-flexivel-6mm', 'Cabo flexível 6 mm²', 'm', 'eletrica', ['cabo', 'fio', '6mm', 'cabo flexivel']),
  ItemInicial('cabo-flexivel-10mm', 'Cabo flexível 10 mm²', 'm', 'eletrica', ['cabo', 'fio', '10mm', 'cabo flexivel']),
  ItemInicial('disjuntor-din', 'Disjuntor DIN monopolar', 'unidade', 'eletrica', ['disjuntor', 'din', 'disjuntor monopolar']),
  ItemInicial('padrao-entrada-energia', 'Padrão de entrada de energia monofásico', 'unidade', 'eletrica', ['padrao', 'padrao de energia', 'poste padrao', 'entrada de energia']),
  ItemInicial('fita-isolante-20m', 'Fita isolante 20 m', 'unidade', 'eletrica', ['fita isolante', 'fita', 'isolante']),
  ItemInicial('quadro-distribuicao-12', 'Quadro de distribuição 12 disjuntores', 'unidade', 'eletrica', ['quadro', 'quadro distribuicao', 'qdc', 'caixa disjuntor']),
  ItemInicial('tomada-2p-t-10a', 'Tomada 2P+T 10 A com placa', 'unidade', 'eletrica', ['tomada', 'tomadas', '2p+t', '10a']),
  ItemInicial('interruptor-simples', 'Interruptor simples com placa', 'unidade', 'eletrica', ['interruptor', 'interruptores', 'tecla']),
  ItemInicial('lampada-led-9w', 'Lâmpada LED 9 W', 'unidade', 'eletrica', ['lampada', 'lampadas', 'led', '9w']),
  ItemInicial('soquete-e27', 'Soquete E27', 'unidade', 'eletrica', ['soquete', 'bocal', 'e27']),
  ItemInicial('roldana-porcelana', 'Roldana de porcelana', 'unidade', 'eletrica', ['roldana', 'isolador', 'porcelana']),
  ItemInicial('caixa-luz-4x2', 'Caixa de luz 4x2', 'unidade', 'eletrica', ['caixa 4x2', 'caixinha', 'caixa de luz', '4x2']),
  ItemInicial('eletroduto-corrugado-25mm', 'Eletroduto corrugado 25 mm', 'm', 'eletrica', ['eletroduto', 'conduite', 'corrugado', 'mangueira']),
  ItemInicial('haste-aterramento', 'Haste de aterramento cobreada 2,4 m', 'unidade', 'eletrica', ['haste', 'aterramento', 'haste cobreada']),
  ItemInicial('luminaria-led-embutir', 'Luminária LED de embutir', 'unidade', 'eletrica', ['luminaria', 'plafon', 'iluminacao', 'spot']),
  // Acabamento
  ItemInicial('forro-pvc-200mm', 'Forro de PVC 200 mm', 'm', 'acabamento', ['forro', 'forro pvc', 'pvc']),
  ItemInicial('forro-gesso', 'Forro de gesso', 'm', 'acabamento', ['forro', 'forro gesso', 'gesso', 'drywall']),
  ItemInicial('cantoneira-forro', 'Cantoneira para forro', 'm', 'acabamento', ['cantoneira', 'acabamento forro', 'rodaforro']),
  ItemInicial('metalon-20x20', 'Metalon 20x20 mm', 'm', 'acabamento', ['metalon', 'tubo metalon', 'perfil']),
  ItemInicial('parafuso-bucha-6mm', 'Parafuso com bucha 6 mm', 'unidade', 'acabamento', ['parafuso', 'bucha', 'parafusos', 'bucha 6']),
  ItemInicial('revestimento-ceramico', 'Revestimento cerâmico (piso e parede)', 'm²', 'acabamento', ['piso', 'ceramica', 'revestimento', 'azulejo', 'pisos']),
  ItemInicial('porcelanato-retificado', 'Porcelanato retificado', 'm²', 'acabamento', ['porcelanato', 'piso', 'retificado', 'revestimento']),
  ItemInicial('espacador-piso', 'Espaçador para piso (pacote)', 'pacote', 'acabamento', ['espacador', 'cruzeta', 'espacador piso']),
  ItemInicial('nivelador-piso', 'Nivelador de piso (clipes)', 'pacote', 'acabamento', ['nivelador', 'clipe nivelador', 'nivelador piso']),
  ItemInicial('cunha-niveladora', 'Cunha niveladora (pacote)', 'pacote', 'acabamento', ['cunha', 'cunha niveladora']),
  ItemInicial('box-banheiro', 'Box de vidro para banheiro', 'unidade', 'acabamento', ['box', 'box banheiro', 'box vidro']),
  ItemInicial('armario-cozinha', 'Armário de cozinha', 'unidade', 'acabamento', ['armario', 'armario cozinha', 'gabinete']),
  ItemInicial('armario-cozinha-premium', 'Armário de cozinha (linha premium)', 'unidade', 'acabamento', ['armario', 'armario cozinha', 'planejado']),
  ItemInicial('espelho-banheiro', 'Espelho para banheiro', 'unidade', 'acabamento', ['espelho', 'espelho banheiro']),
  ItemInicial('espelho-banheiro-premium', 'Espelho lapidado para banheiro (linha premium)', 'unidade', 'acabamento', ['espelho', 'espelho lapidado']),
  // Pintura
  ItemInicial('tinta-acrilica-externa', 'Tinta acrílica para fachada 3,6 L', 'galão', 'pintura', ['tinta', 'tinta externa', 'acrilica', 'fachada', 'suvinil', 'coral']),
  ItemInicial('tinta-acrilica-interna', 'Tinta acrílica para interiores 3,6 L', 'galão', 'pintura', ['tinta', 'tinta interna', 'acrilica', 'latex', 'pva']),
  ItemInicial('tinta-acrilica-premium', 'Tinta acrílica premium para interiores 3,6 L', 'galão', 'pintura', ['tinta', 'tinta premium', 'acrilica premium']),
  ItemInicial('massa-corrida-pva', 'Massa corrida PVA 3,6 L', 'galão', 'pintura', ['massa corrida', 'massa', 'pva', 'massa parede']),
  ItemInicial('selador-acrilico-18l', 'Selador acrílico 18 L', 'lata', 'pintura', ['selador', 'fundo preparador', 'selador acrilico']),
  ItemInicial('textura-acrilica-25kg', 'Textura acrílica 25 kg', 'balde', 'pintura', ['textura', 'grafiato', 'textura acrilica']),
  ItemInicial('fita-crepe-48mm', 'Fita crepe 48 mm', 'rolo', 'pintura', ['fita crepe', 'fita', 'crepe']),
  ItemInicial('lixa-massa-150', 'Lixa para massa nº 150', 'folha', 'pintura', ['lixa', 'lixas', 'lixa massa']),
  // Louças e metais
  ItemInicial('bacia-caixa-acoplada', 'Bacia sanitária com caixa acoplada', 'unidade', 'loucas-metais', ['bacia', 'vaso', 'vaso sanitario', 'caixa acoplada', 'privada']),
  ItemInicial('bacia-caixa-acoplada-premium', 'Bacia sanitária com caixa acoplada (linha premium)', 'unidade', 'loucas-metais', ['bacia', 'vaso', 'vaso sanitario', 'caixa acoplada']),
  ItemInicial('torneira-banheiro', 'Torneira para lavatório', 'unidade', 'loucas-metais', ['torneira', 'torneira banheiro', 'lavatorio']),
  ItemInicial('torneira-banheiro-premium', 'Torneira para lavatório (linha premium)', 'unidade', 'loucas-metais', ['torneira', 'torneira banheiro', 'monocomando']),
  ItemInicial('torneira-cozinha', 'Torneira para cozinha', 'unidade', 'loucas-metais', ['torneira', 'torneira cozinha', 'torneira pia']),
  ItemInicial('torneira-cozinha-premium', 'Torneira para cozinha (linha premium)', 'unidade', 'loucas-metais', ['torneira', 'torneira cozinha', 'gourmet']),
  ItemInicial('chuveiro-eletrico', 'Chuveiro elétrico', 'unidade', 'loucas-metais', ['chuveiro', 'ducha', 'lorenzetti']),
  ItemInicial('chuveiro-premium', 'Chuveiro ducha (linha premium)', 'unidade', 'loucas-metais', ['chuveiro', 'ducha', 'ducha premium']),
  ItemInicial('kit-acessorios-banheiro', 'Kit de acessórios para banheiro', 'kit', 'loucas-metais', ['acessorios', 'kit banheiro', 'porta toalha', 'papeleira']),
  ItemInicial('kit-acessorios-banheiro-premium', 'Kit de acessórios para banheiro (linha premium)', 'kit', 'loucas-metais', ['acessorios', 'kit banheiro']),
  ItemInicial('pia-cozinha-inox', 'Pia de cozinha inox com cuba', 'unidade', 'loucas-metais', ['pia', 'pia cozinha', 'cuba', 'inox']),
  ItemInicial('pia-cozinha-premium', 'Pia de cozinha com cuba (linha premium)', 'unidade', 'loucas-metais', ['pia', 'pia cozinha', 'cuba', 'granito']),
  // Ferramentas
  ItemInicial('linha-nylon-pedreiro', 'Linha de nylon para pedreiro', 'rolo', 'ferramentas', ['linha', 'linha nylon', 'linha pedreiro']),
  ItemInicial('carrinho-de-mao', 'Carrinho de mão', 'unidade', 'ferramentas', ['carrinho', 'carrinho de mao', 'girica']),
  ItemInicial('colher-pedreiro', 'Colher de pedreiro', 'unidade', 'ferramentas', ['colher', 'colher pedreiro']),
  ItemInicial('nivel-bolha', 'Nível de bolha 40 cm', 'unidade', 'ferramentas', ['nivel', 'nivel bolha']),
  ItemInicial('trena-5m', 'Trena 5 m', 'unidade', 'ferramentas', ['trena', 'metro']),
  ItemInicial('pa-de-bico', 'Pá de bico', 'unidade', 'ferramentas', ['pa', 'pa de bico']),
];

/// `nome na planilha|unidade na planilha` →(id do produto, fator de conversão para a unidade do produto).
/// null = não é produto de loja (estrutura sob medida, item de canteiro).
const Map<String, (String, double)?> planilhaParaCatalogo = {
  'Estacas para marcação|und': ('estaca-marcacao', 1),
  'Tabua 10 cm mista|mt': ('tabua-mista-10cm', 1),
  'Relógio de agua|und': ('kit-cavalete-hidrometro', 1),
  'Linha de nylon|und': ('linha-nylon-pedreiro', 1),
  'Cimento 50kg|und': ('cimento-cp2-50kg', 1),
  'Areia grossa|m³': ('areia-grossa', 1),
  'Cal|und': ('cal-hidratada-20kg', 1),
  'Pedra brita|m³': ('pedra-brita-1', 1),
  'Coluna 7x14 8mm 6 mts|und': ('coluna-7x14-8mm', 1),
  'Coluna 7x14 8mm 6 mts|mt': ('coluna-7x14-8mm', 1 / 6),
  'Coluna 7x14 10mm 6 mts|und': ('coluna-7x14-10mm', 1),
  'Pintura Asfaltica 18lt|und': ('pintura-asfaltica-18l', 1),
  'Pregos 17x27|kg': ('prego-17x27', 1),
  'Tijolo 6 furos 24cm|und': ('tijolo-6-furos', 1),
  'Tabua 30 cm mista|mt': ('tabua-mista-30cm', 1),
  'Ripao|mt': ('ripao', 1),
  'Arames recozidos 18|kg': ('arame-recozido-18', 1),
  'Vergalhões de aço 8mm|und': ('vergalhao-8mm', 1),
  'Vergalhões de aço 5mm|und': ('vergalhao-5mm', 1),
  'Sapatas|und': null,
  'Painel telado 10x10|und': ('tela-soldada-10x10', 1),
  'Treliça|und': ('trelica-tr8', 1),
  'Caibro peroba 5x5|und': ('caibro-peroba-peca', 1),
  'Caibro peroba 5x5|mt': ('caibro-peroba-metro', 1),
  'Viga Peroba|und': ('viga-peroba-peca', 1),
  'Viga Peroba|mt': ('viga-peroba-metro', 1),
  'Tijolo 8 furos 24cm|und': ('tijolo-8-furos', 1),
  'Tijolo 9 furos 24cm|und': ('tijolo-9-furos', 1),
  'Canaletinha|und': ('canaleta-ceramica', 1),
  'Impermeabilizante polímero|cx': ('impermeabilizante-polimerico', 1),
  'Impermeabilizante|bd': ('impermeabilizante-acrilico-18l', 1),
  'Telha Fibrocimento|und': ('telha-fibrocimento-6mm', 1),
  'Parafuso p/ telha|und': ('parafuso-telha', 1),
  'Telha Romana/Portuguesa|und': ('telha-ceramica-romana', 1),
  'Tesouras|und': null,
  'Telha de zinco|m²': ('telha-zinco', 1),
  'Caibro misto 5x5|mt': ('caibro-misto-5x5', 1),
  'Telha sanduiche|und': ('telha-sanduiche', 1),
  'Cabo triplex|mt': ('cabo-triplex-10mm', 1),
  'Disjuntor|und': ('disjuntor-din', 1),
  'Padrão de energia|und': ('padrao-entrada-energia', 1),
  'Fita isolante|und': ('fita-isolante-20m', 1),
  'Cabo 2,5mm|mt': ('cabo-flexivel-2-5mm', 1),
  'Cabo 4mm|mt': ('cabo-flexivel-4mm', 1),
  'Cabo 10mm|mt': ('cabo-flexivel-10mm', 1),
  'Cabo 6mm|mt': ('cabo-flexivel-6mm', 1),
  'Quadro Distribuição|und': ('quadro-distribuicao-12', 1),
  'Tomadas|und': ('tomada-2p-t-10a', 1),
  'Interruptores|und': ('interruptor-simples', 1),
  'Lampadas|und': ('lampada-led-9w', 1),
  'Soquetes|und': ('soquete-e27', 1),
  'Roldanas|und': ('roldana-porcelana', 1),
  'Caixa 4x2|und': ('caixa-luz-4x2', 1),
  'Eletroduto|mt': ('eletroduto-corrugado-25mm', 1),
  'Haste aterramento|und': ('haste-aterramento', 1),
  'Iluminação alto|und': ('luminaria-led-embutir', 1),
  // Planilha em litros de capacidade: o produto é a caixa de 1.000 L
  "Caixa D'agua|lt": ('caixa-dagua-1000l', 1 / 1000),
  'Registros gaveta|und': ('registro-gaveta-3-4', 1),
  'Registros pressão|und': ('registro-pressao-3-4', 1),
  'Conexoes agua fria|und': ('conexoes-agua-fria', 1),
  'Conexoes esgoto|und': ('conexoes-esgoto', 1),
  'Conexoes agua quente|und': ('conexoes-agua-quente', 1),
  'Tubos agua fria|br': ('tubo-agua-fria-25mm', 1),
  'Tubos esgoto|br': ('tubo-esgoto-100mm', 1),
  'Tubos agua quente|br': ('tubo-agua-quente-22mm', 1),
  'Adesivo plastico 175g|und': ('adesivo-pvc-175g', 1),
  'Caixa sifonada|und': ('caixa-sifonada-150', 1),
  'Caixa de gordura|und': ('caixa-gordura', 1),
  'Caixa de passagem|und': ('caixa-passagem-esgoto', 1),
  'Boia|und': ('torneira-boia-3-4', 1),
  'Flange|und': ('adaptador-flange-25mm', 1),
  'Forro pvc|mt': ('forro-pvc-200mm', 1),
  'Forro gesso|mt': ('forro-gesso', 1),
  'Cantoneira|mt': ('cantoneira-forro', 1),
  'Metalon|mt': ('metalon-20x20', 1),
  'Parafusos|und': ('parafuso-bucha-6mm', 1),
  // "mt" de revestimento nas planilhas é área (m²)
  'Revestimentos|mt': ('revestimento-ceramico', 1),
  'Revestimento alto|mt': ('porcelanato-retificado', 1),
  'Argamassas|und': ('argamassa-ac1-20kg', 1),
  'Espaçador|und': ('espacador-piso', 1),
  'Nivelador|und': ('nivelador-piso', 1),
  'Cunha|und': ('cunha-niveladora', 1),
  'Tinta externa|gl': ('tinta-acrilica-externa', 1),
  'Tinta interna|gl': ('tinta-acrilica-interna', 1),
  'Tinta interna premium|gl': ('tinta-acrilica-premium', 1),
  'Massa corrida|gl': ('massa-corrida-pva', 1),
  'Selador|und': ('selador-acrilico-18l', 1),
  'Textura externa medio|und': ('textura-acrilica-25kg', 1),
  'Plástico para impermeabilização (lonas)|und': ('lona-plastica-preta', 1),
  'Fita crepe|br': ('fita-crepe-48mm', 1),
  'Lixas|br': ('lixa-massa-150', 1),
  'Bacia c caixa|und': ('bacia-caixa-acoplada', 1),
  'Bacia c caixa Alto|und': ('bacia-caixa-acoplada-premium', 1),
  'Torneira banheiro|gl': ('torneira-banheiro', 1),
  'Torneira banheiro alto|gl': ('torneira-banheiro-premium', 1),
  'Torneira cozinha|gl': ('torneira-cozinha', 1),
  'Torneira cozinha Alto|gl': ('torneira-cozinha-premium', 1),
  'Chuveiro|und': ('chuveiro-eletrico', 1),
  'Chuveiro Alto|und': ('chuveiro-premium', 1),
  'Acessórios de banheiro|und': ('kit-acessorios-banheiro', 1),
  'Acessórios de banheiro Alto|und': ('kit-acessorios-banheiro-premium', 1),
  'Pia cozinha|und': ('pia-cozinha-inox', 1),
  'Pia cozinha Alto|und': ('pia-cozinha-premium', 1),
  'Armario Cozinha|br': ('armario-cozinha', 1),
  'Armario Cozinha Alto|br': ('armario-cozinha-premium', 1),
  'Espelho|br': ('espelho-banheiro', 1),
  'Espelho Alto|br': ('espelho-banheiro-premium', 1),
  'Box Banheiro|und': ('box-banheiro', 1),
  'Almoxarifado/banheiro|und': null,
};

String _q(String s) => "'${s.replaceAll("'", "''")}'";
String _arr(List<String> l) => "array[${l.map(_q).join(', ')}]::text[]";

String gerarSql() {
  final b = StringBuffer()
    ..writeln('-- GERADO por dailyobra_comum/tool/catalogo_inicial.dart. Não editar à mão: mude o Dart e gere de novo.')
    ..writeln('-- Catálogo DailyObra inicial a partir das planilhas Projetos Calculos.')
    ..writeln()
    ..writeln("alter table public.catalogo_planilha add column fator numeric(12, 6) not null default 1 check (fator > 0);")
    ..writeln()
    ..writeln('insert into public.catalogo_categorias (id, nome, ordem) values');
  b.writeln(categoriasIniciais.map((c) => '  (${_q(c.id)}, ${_q(c.nome)}, ${c.ordem})').join(',\n'));
  b
    ..writeln('on conflict (id) do update set nome = excluded.nome, ordem = excluded.ordem;')
    ..writeln()
    ..writeln('insert into public.catalogo_itens (id, nome, unidade, categoria_id, tier_cashback, sinonimos) values');
  b.writeln(itensIniciais
      .map((i) => '  (${_q(i.id)}, ${_q(i.nome)}, ${_q(i.unidade)}, ${_q(i.categoria)}, ${i.tier}, ${_arr(i.sinonimos)})')
      .join(',\n'));
  b
    ..writeln('on conflict (id) do update set nome = excluded.nome, unidade = excluded.unidade, categoria_id = excluded.categoria_id,')
    ..writeln('  tier_cashback = excluded.tier_cashback, sinonimos = excluded.sinonimos;')
    ..writeln()
    ..writeln('insert into public.catalogo_planilha (nome, unidade, item_id, fator) values');
  b.writeln(planilhaParaCatalogo.entries.map((e) {
    final partes = e.key.split('|');
    final d = e.value;
    return '  (${_q(partes[0])}, ${_q(partes[1])}, ${d == null ? 'null' : _q(d.$1)}, ${d == null ? 1 : d.$2})';
  }).join(',\n'));
  b
    ..writeln('on conflict (nome, unidade) do update set item_id = excluded.item_id, fator = excluded.fator;')
    ..writeln()
    ..writeln('insert into public.cashback_tiers (tier, percentual) values');
  b.writeln(percentualDoTier.entries.map((e) => '  (${e.key}, ${e.value})').join(',\n'));
  b.writeln('on conflict (tier) do update set percentual = excluded.percentual;');
  return b.toString();
}

void main() => stdout.write(gerarSql());
