# Product

## Register

product

## Users

A plataforma atende a dois grupos principais de usuários do setor de Artes Visuais:
1. **Profissionais e Fornecedores**: Produtores, expógrafos, cenógrafos, transportadores especializados, designers, contadores e escritores de projetos. Acessam a plataforma para publicar seu portfólio, expandir clientela, receber feedbacks e recomendações.
2. **Artistas Visuais e Contratantes**: Pintores, fotógrafos, escultores, galerias, museus e instituições culturais. Buscam conectar-se a fornecedores de confiança, montar equipes para editais aprovados, e contratar serviços específicos.

### Casos de Uso Principais

#### Artistas
- **Montagem de equipe regional**: Artista aprovado em edital em outro estado precisa montar equipe local do zero, sem conhecer profissionais locais.
- **Escrita de projetos**: Artista quer escrever um projeto para um edital, mas não tem o tempo ou a expertise necessária para tirar o projeto do rascunho.
- **Design de exposição**: Artista que precisa encontrar um designer para criar o folder/identidade visual de sua nova exposição.
- **Atualização de portfólio**: Artista que precisa encontrar um fotógrafo para atualizar a foto do seu currículo.
- **Modelagem 3D**: Artista que quer encontrar um profissional para criar uma renderização em 3D de seu projeto expositivo.
- **Documentação burocrática**: Artista que precisa de Carta de Anuência de outros profissionais para cumprir os requisitos de inscrição em Edital Público.

#### Profissionais
- **Produção pontual**: Um produtor(a) quer encontrar um profissional para uma produção pontual.
- **Expansão de clientela**: Profissional já presta serviço para Artistas, mas deseja expandir sua clientela.
- **Reputação na comunidade**: Profissional recebe feedback e pode ser recomendado pela comunidade.
- **Registro de montagem**: Profissional precisa encontrar um fotógrafo para registrar a montagem de uma exposição.

## Product Purpose

Simplificar, centralizar e profissionalizar a busca e a contratação de profissionais e fornecedores no setor das Artes Visuais no Brasil. O sucesso significa estabelecer a Guilda como a ferramenta padrão de trabalho para contratação artística, permitindo aos profissionais exporem seus portfólios e aos contratantes montarem equipes em poucos cliques.

### Finanças & Sustentabilidade
- **Plano de Assinatura**: O mecanismo de financiamento da plataforma será via assinatura anual cobrada apenas dos usuários cadastrados como "fornecedores/profissionais".
- **Acesso Gratuito**: Os demais usuários poderão usar a plataforma gratuitamente e interagir com os usuários cadastrados como profissionais.

## Brand Personality

- **Minimalista**: Uma interface limpa, moderna e minimalista, com uma economia de cores principalmente nos botões.
- **Profissional**: O objetivo da plataforma é ser usada estritamente como uma ferramenta de trabalho, sem a necessidade de torná-la um playground colorido de onde as pessoas não querem sair.
- **Elegante**: Aparência elegante, com atenção rigorosa a detalhes como tipografia e espaçamento entre os elementos.
- **Trabalho Invisível**: A interface deve transmitir rigor técnico e estético, onde o usuário final compreenda que existe um trabalho invisível por trás de cada escolha estética e elemento apresentado em tela.

## Anti-references

- **Playgrounds coloridos**: Interfaces super saturadas, cheias de elementos decorativos desnecessários ou gamificação agressiva para reter atenção.
- **Estética de Rede Social Mainstream**: Excesso de notificações chamativas, feeds poluídos e elementos que competem com o portfólio de arte.
- **SaaS-cream genérico**: Cards com gradientes vibrantes em roxo/azul, ilustrações corporativas intercambiáveis e falta de sobriedade.
- **Descuido tipográfico e de espaçamento**: Falta de alinhamento cirúrgico, uso de fontes padrão de navegador sem refinamento ou botões excessivamente coloridos sem propósito.

## Design Principles

1. **O Trabalho Invisível (Invisible Craft)** — A interface transparece rigor técnico, precisão de espaçamento, alinhamento cirúrgico e tipografia sofisticada. O usuário percebe a qualidade no silêncio e na organização visual.
2. **Economia de Cor (Chromatic Restraint)** — A cor é uma ferramenta funcional de foco e ação (principalmente nos botões), e não uma distração decorativa. A plataforma é uma ferramenta de produtividade.
3. **Foco no Portfólio (Focus on the Work)** — A interface recua para que as imagens e projetos dos profissionais sejam os verdadeiros protagonistas visuais da tela.
4. **Fricção Mínima na Descoberta (Zero-friction Search)** — Organização da informação estruturada de forma que o usuário encontre profissionais e serviços com o menor número possível de cliques.

## Accessibility & Inclusion

- **WCAG 2.1 AA**: Garantia de contraste de cores adequado (mínimo 4.5:1 para texto normal, 3:1 para texto grande) em toda a interface.
- **Navegação Sem Fricção**: Suporte completo a navegação via teclado e marcação semântica limpa para leitores de tela.
- **Sensibilidade a Movimento**: Respeito à preferência de sistema do usuário para redução de movimentos (`prefers-reduced-motion`).

## Scope & MVP

### Funcionalidades Essenciais (MVP)

#### User
- Autenticação de usuários: Signup/login com e-mail, recuperação de senha e destruição de conta.
- Atualização de informações de conta: Alteração de senha e e-mail (com validação se o e-mail inserido existe/é válido).

#### Profile
- Perfil público: Perfil público do usuário com avatar, bio, links e portfólio.
- Campo principal de atuação: Escolha de área principal de atuação (como Artes Visuais, Música, Artes Cênicas) e categorias secundárias (como expografia, cenografia, transporte, design, escrita de projetos, contador).
- Interações sociais: Seguir outros perfis.
- Projetos: Publicar projetos, curtir e comentar em projetos de outros perfis.
- Feed: Feed de projetos de perfis seguidos, com paginação ou rolagem infinita (infinite scroll).
- Busca avançada: Busca de perfis por endereço (cidade, estado) ou por categoria de atuação.

#### Project
- Organização do portfólio: Projetos podem ser reordenados.
- Visibilidade: Projetos podem estar como públicos, rascunhos ou privados.
- Galeria de imagens: Suporte a múltiplas imagens por projeto que podem ser reordenadas.
- Imagem de Destaque: Usuário pode enviar uma imagem de destaque ou escolher entre as imagens da galeria do projeto.

### Funcionalidades Futuras (Não-MVP)
- **Jobs Board**: Espaço para empresas publicarem vagas e oportunidades.
- **Mensagens Diretas (DMs)**: Comunicação direta por mensagens entre usuários.
- **Analytics**: Painel com visualizações e engajamento do portfólio.
- **Colaboração**: Possibilidade de adicionar profissionais como colaboradores em outros Projetos.
- **Avaliações**: Sistema de recomendação e feedback sobre os profissionais por quem contratou os serviços.

## Information Architecture

### Layout de 3 Colunas (Desktop)
- **Coluna Esquerda (1ª coluna)**: Links de acesso rápido às principais funcionalidades da plataforma.
- **Coluna Central (2ª coluna - 60% do espaço horizontal)**: Conteúdo principal da tela apresentada (como o feed, portfólio ou resultados da busca).
- **Coluna Direita (3ª coluna)**: Espaço reservado para pequenos anúncios do setor, indicações de conteúdo, sugestões de profissionais e serviços úteis.
