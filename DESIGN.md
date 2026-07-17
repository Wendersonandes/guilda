---
name: Guilda
description: Plataforma de conexão e contratação para o ecossistema de Artes Visuais.
colors:
  primary: "#c84a32"        # Terracotta (Accent)
  primary-hover: "#ad3c26"  # Terracotta Hover
  neutral-bg: "#f7f7f5"     # Gallery White
  neutral-fg: "#18181b"     # Charcoal
  surface: "#ffffff"        # Pure White
  border: "#e7e7e4"         # Stone Border
  text-muted: "#71717a"     # Zinc Muted
typography:
  display:
    fontFamily: "Playfair Display, Georgia, serif"
    fontWeight: 700
    lineHeight: 1.2
  body:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontWeight: 400
    lineHeight: 1.5
rounded:
  sm: "4px"
  md: "8px"
  lg: "12px"
spacing:
  sm: "8px"
  md: "16px"
  lg: "24px"
components:
  button-primary:
    backgroundColor: "{colors.neutral-fg}"
    textColor: "{colors.surface}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-primary-hover:
    backgroundColor: "#27272a"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.neutral-fg}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-secondary-hover:
    backgroundColor: "#f4f4f5"
---

# Design System: Guilda

## 1. Overview

**Creative North Star: "O Catálogo de Galeria" (The Gallery Catalog)**

O design do Guilda é inspirado na sobriedade física de um catálogo de museu ou galeria de arte. As paredes de uma galeria são intencionalmente brancas para que as obras de arte sejam as protagonistas. Da mesma forma, a interface do Guilda recua completamente, apresentando uma estrutura limpa baseada em tipografia editorial rigorosa, espaçamento generoso e uma economia cromática absoluta. A estética do produto é definida pelo seu "trabalho invisível" — a percepção de que cada alinhamento, escolha tipográfica e espaço em branco foi cirurgicamente planejado.

### Key Characteristics:
- **Restrição Cromática**: Cores são tratadas como ferramentas funcionais de alta prioridade, não como elementos decorativos.
- **Estrutura de Grade Clássica**: Um layout de 3 colunas em desktop que organiza as ações, o conteúdo central do portfólio e os apoios laterais.
- **Tipografia Editorial**: Contraste refinado entre títulos com serifa clássica e textos de interface sem serifa modernos.
- **Ausência de Artifícios**: Sem gradientes coloridos, sem sombras pesadas e sem glassmorphism gratuito. A profundidade é demarcada por linhas de divisão e contrastes sutis de fundo.

## 2. Colors

A paleta de cores do Guilda segue a doutrina da restrição cromática, focando em tons orgânicos e sóbrios que remetem a materiais físicos.

### Primary
- **Terracota/Vermelho Queimado** (`#c84a32` / `oklch(0.52 0.18 32)`): Cor primária de destaque. Utilizada pontualmente para indicar foco, estados selecionados, pins geográficos ou links em destaque. Nunca utilizada em excesso.

### Neutral
- **Gallery White** (`#f7f7f5` / `oklch(0.97 0.003 70)`): O plano de fundo principal da aplicação. Um tom off-white quente que elimina o brilho incômodo do branco puro e traz conforto visual.
- **Charcoal/Preto de Carbono** (`#18181b` / `oklch(0.20 0.01 250)`): A cor principal para texto, títulos e para o preenchimento de botões primários. Define o peso visual e a seriedade da interface.
- **Pure White** (`#ffffff`): Reservado exclusivamente para superfícies que precisam se destacar do fundo, como cards, painéis flutuantes e campos de entrada.
- **Subtle Stone Border** (`#e7e7e4` / `oklch(0.92 0.002 70)`): A cor padrão para bordas finas, divisores e linhas de grade.
- **Muted Zinc Text** (`#71717a` / `oklch(0.53 0.01 250)`): Utilizado para textos secundários, metadados, timestamps e placeholders.

### Semantic
- **Error/Destructive** (`#ef4444` / `oklch(0.58 0.22 20)`): Tons avermelhados para ações destrutivas (deletar conta, desativar perfil).
- **Success** (`#10b981` / `oklch(0.64 0.18 160)`): Tons esverdeados para feedbacks positivos e sucesso.

**The 5% Highlight Rule.** O tom Terracota (`#c84a32`) nunca deve ocupar mais do que 5% da área visual de qualquer tela. Sua força está na sua raridade. Se tudo brilha, nada se destaca.

## 3. Typography

A tipografia do Guilda estabelece um diálogo entre o clássico e o contemporâneo, facilitando a leitura de biografias de artistas e descrições técnicas de fornecedores.

**Display Font:** `Playfair Display`, `Georgia`, `serif`
**Body Font:** `ui-sans-serif`, `system-ui`, `sans-serif` (Tailwind default sans stack)

### Hierarchy
- **Display** (Bold, `text-2xl` / 1.5rem ou `text-3xl` / 1.875rem, `leading-tight`): Utilizado para nomes de perfis no cabeçalho e títulos principais de projetos. Usa a fonte com serifa.
- **Headline** (Semibold, `text-xl` / 1.25rem, `leading-snug`): Utilizado para títulos de seções, cabeçalhos de cards e títulos secundários. Usa a fonte com serifa.
- **Title** (Medium, `text-lg` / 1.125rem, `leading-snug`): Utilizado para títulos de projetos menores ou seções secundárias.
- **Body** (Regular, `text-base` / 1rem ou `text-sm` / 0.875rem, `leading-relaxed`): Usado para biografias, descrições de projetos e textos longos. Comprimento máximo limitado a 65–75ch para evitar fadiga ocular.
- **Label** (Medium, `text-xs` / 0.75rem ou `text-sm` / 0.875rem, `leading-none`): Usado para botões, inputs, abas, badges de categorias e links de navegação. Usa fonte sem serifa.

**The Editorial Line Length Rule.** Textos de portfólio e biografia devem sempre respeitar a largura máxima de `max-w-2xl` (~65ch) para garantir legibilidade ideal sob qualquer resolução.

## 4. Elevation

O Guilda adota um sistema essencialmente bidimensional e plano, em conformidade com a sobriedade física do design. Não são utilizadas sombras flutuantes ou sobreposições tridimensionais complexas no feed e nos perfis.

**The Flat Gallery Rule.** Elementos e cards são planos na tela. A distinção visual entre o fundo (`#f7f7f5`) e as superfícies (`#ffffff`) é feita através de bordas finas de 1px (`#e7e7e4`). Sombras sutis (`shadow-sm`) são permitidas apenas como feedback ativo a interações (como hover em cards de projetos) ou em modais/dropdowns sobrepostos.

### Shadow Vocabulary
- **Interactive Focus** (`shadow-sm`): `0 1px 2px 0 rgba(0, 0, 0, 0.05)`. Aplicada em cards ao passar o mouse.
- **Overlay Drop** (`shadow-md`): `0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03)`. Usada exclusivamente para menus suspensos (dropdowns) e modais.

## 5. Components

### Buttons
- **Shape**: Cantos levemente suavizados (8px de raio / `rounded-lg`).
- **Primary**: Preenchimento Charcoal (`bg-zinc-900`) e texto branco (`text-white`). Visual limpo, pesado e de alta prioridade.
  - *Hover*: `hover:bg-zinc-800`
  - *Focus*: `focus:ring-2 focus:ring-zinc-900 focus:ring-offset-1`
- **Secondary**: Fundo branco (`bg-white`), borda fina (`border border-stone-300`) e texto Charcoal (`text-zinc-800`).
  - *Hover*: `hover:bg-stone-50`
- **Terracotta Alert/Action**: Usado pontualmente quando uma ação precisa de um destaque artístico específico (como "Contratar" ou "Seguir"). Fundo Terracota (`bg-[#c84a32]`) e texto branco (`text-white`).
  - *Hover*: `hover:bg-[#ad3c26]`

### Chips
- **Style**: Fundo levemente cinza/areia (`bg-stone-100`), texto Charcoal (`text-zinc-800`), sem borda, cantos arredondados (`rounded-full`), fonte pequena e média (`text-xs font-medium px-2.5 py-0.5`).
- **Selected variant**: Fundo Terracota (`bg-[#c84a32]`), texto branco (`text-white`).

### Cards / Containers
- **Corner Style**: Raio moderado de 8px (`rounded-lg`) ou 12px (`rounded-xl`).
- **Background & Border**: Fundo branco (`bg-white`), borda fina (`border border-stone-200`). Sem sombras permanentes em estado de repouso.
- **Internal Padding**: `p-4` (para listagens rápidas) ou `p-6` (para detalhes de perfil/projetos).

### Inputs / Fields
- **Style**: Largura total (`w-full`), cantos em 8px (`rounded-lg`), borda stone (`border border-stone-300`), fundo branco (`bg-white`), padding interno confortável (`px-3 py-2 text-sm`). Placeholders em cinza claro (`placeholder:text-zinc-400`).
- **Focus**: Borda Charcoal (`focus:border-zinc-900`) acompanhada de contorno sutil (`focus:ring-1 focus:ring-zinc-900`).
- **Error State**: Borda vermelha (`border-red-400 focus:ring-red-400`).

### Navigation
- **Style, typography, default/hover/active states**: Fundo branco (`bg-white`), borda inferior fina (`border-b border-stone-200`), fixado no topo (`fixed top-0 left-0 right-0 z-50`). Altura de 56px (`h-14`). Links de navegação usando fonte sans-serif, tamanho pequeno/médio (`text-sm font-medium`), cor do texto secundário (`text-zinc-600 hover:text-zinc-900 transition-colors`).

### Layout de 3 Colunas (Desktop)
- **Implementação**: Grid de 12 colunas em desktop (`grid grid-cols-1 lg:grid-cols-12 gap-6`).
  - **Coluna 1 (Esquerda)**: Ocupa 3 colunas (`lg:col-span-3`). Menu lateral de links rápidos.
  - **Coluna 2 (Meio)**: Ocupa 6 colunas (`lg:col-span-6`). Concentra 60% do espaço horizontal e exibe o conteúdo principal (Feed, Portfólio, Projetos).
  - **Coluna 3 (Direita)**: Ocupa 3 colunas (`lg:col-span-3`). Sidebar lateral com anúncios, recomendações e sugestões de serviços.

## 6. Do's and Don'ts

### Do:
- **Do** usar o tom Terracota (`#c84a32`) de forma extremamente parcimoniosa (≤5% da tela), principalmente para foco ativo ou botões de conversão específicos.
- **Do** priorizar linhas divisórias finas (`border-stone-200`) e variação de cor de fundo em vez de aplicar sombras projetadas pesadas.
- **Do** manter o alinhamento e o espaçamento vertical consistentes em múltiplos de 4px ou 8px para transparecer o "trabalho invisível" de design.
- **Do** garantir que todas as imagens de portfólio de projetos estejam em contêineres limpos, sem filtros ou bordas coloridas artificiais.

### Don't:
- **Don't** criar layouts barulhentos ou saturados de cores que compitam com o portfólio visual dos artistas e fornecedores.
- **Don't** usar degradês coloridos em botões, textos (`background-clip: text`) ou fundos.
- **Don't** utilizar glassmorphism (desfoque de fundo decorativo em cards) como padrão visual.
- **Don't** usar bordas coloridas grossas ou laterais destacadas (side-stripe borders) como sinalizadores em cards ou alertas.
- **Don't** quebrar o layout de 3 colunas estabelecido em desktop, garantindo que o feed ou portfólio principal ocupe exatamente a coluna central de 60%.
