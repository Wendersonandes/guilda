puts "Seeding Guilda core..."
# Async adapter runs jobs in-process (no Solid Queue tables needed) and supports scheduled
# jobs (`wait:`), which the inline adapter does not.
ActiveJob::Base.queue_adapter = :async

# Clear database and reset cached singletons
puts "  Cleaning database..."
[Relation::Public, Relation::Follow, Relation::Reject, Relation::Owner, Relation::LocalAdmin].each do |klass|
  klass.instance_variable_set(:@instance, nil)
end

tables = %w[
  active_storage_attachments active_storage_blobs active_storage_variant_records
  action_text_rich_texts
  activities activity_actions activity_object_activities activity_object_audiences
  activity_objects actors audiences comments contacts flags friendly_id_slugs
  groups mentions noticed_events noticed_notifications permissions posts profiles
  projects project_images relation_permissions relations sites taggings tags ties users
]
ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{tables.join(', ')} RESTART IDENTITY CASCADE")

# ── Permissions & System Relations ──────────────────────────────
permissions = Permission.instances([
  [ :create, :activity ],
  [ :read,   :activity ],
  [ :update, :activity ],
  [ :destroy, :activity ],
  [ :follow, nil ],
  [ :represent, nil ],
  [ :create, :post ],
  [ :read,   :post ],
  [ :update, :post ],
  [ :destroy, :post ],
  [ :create, :comment ],
  [ :read,   :comment ],
  [ :update, :comment ],
  [ :destroy, :comment ]
])
puts "  Permissions: #{permissions.size} created"

public_rel = Relation::Public.instance
follow_rel = Relation::Follow.instance
reject_rel = Relation::Reject.instance
puts "  Relations: Public(#{public_rel.id}) Follow(#{follow_rel.id}) Reject(#{reject_rel.id})"

# ── Users & Profiles ────────────────────────────────────────────
puts "\nCreating users & profiles..."

users_data = [
  {
    email: "ana@example.com",
    name: "Ana Silva",
    city: "São Paulo",
    state: "SP",
    website: "https://anasilva.art.br",
    mobile: "11987654321",
    instagram: "anasilva",
    availability: "freelance",
    description: "Artista visual contemporânea focada em pintura a óleo de grande formato e instalações urbanas. Graduada em Belas Artes pela USP.",
    occupations: ["Design de Portfólio"]
  },
  {
    email: "bruno@example.com",
    name: "Bruno Costa",
    city: "Rio de Janeiro",
    state: "RJ",
    website: "https://brunocostaexpografia.com",
    mobile: "21987654321",
    instagram: "brunocosta.expografia",
    availability: "full_time",
    description: "Arquiteto e expógrafo com 10 anos de experiência desenhando fluxos e espaços expositivos para museus e galerias.",
    occupations: ["Expografia", "Montador de Exposições"]
  },
  {
    email: "carla@example.com",
    name: "Carla Mendes",
    city: "Belo Horizonte",
    state: "MG",
    website: "https://carlamendescultura.com",
    mobile: "31987654321",
    instagram: "carlamendescultura",
    availability: "freelance",
    description: "Especialista em redação de projetos culturais para leis de incentivo (Rouanet/ProAC) e editais públicos.",
    occupations: ["Escrita de Projetos", "Prestação de Contas", "Produtora Cultural"]
  },
  {
    email: "diego@example.com",
    name: "Diego Rocha",
    city: "São Paulo",
    state: "SP",
    website: "https://diegorochafoto.myportfolio.com",
    mobile: "11912345678",
    instagram: "diegorochafoto",
    availability: "full_time",
    description: "Fotógrafo especializado em registrar exposições, montagens e catálogo de obras de arte com fidelidade de cor.",
    occupations: ["Assessoria de Comunicação"]
  },
  {
    email: "elisa@example.com",
    name: "Elisa Torres",
    city: "Curitiba",
    state: "PR",
    website: "https://elisatorreslogistica.com.br",
    mobile: "41987654321",
    instagram: "elisatorreslog",
    availability: "unavailable",
    description: "Logística especializada em artes visuais. Transporte seguro de acervo, embalagem climatizada e laudo de estado para obras.",
    occupations: ["Transporte de Obras", "Produção de Exposições"]
  }
]

users = {}
users_data.each do |data|
  user = User.find_or_initialize_by(email: data[:email])
  if user.new_record?
    user.password = "password123"
    user.profile_name = data[:name]
    user.save!
  end
  
  # Update custom profile attributes
  profile = user.current_profile.actorable
  profile.update!(
    country: "BR",
    city: data[:city],
    state: data[:state],
    website: data[:website],
    mobile: data[:mobile],
    instagram: data[:instagram],
    availability: data[:availability],
    occupation_list: data[:occupations],
    wizard_complete: true
  )
  profile.actor.update!(
    description: data[:description],
    email: data[:email]
  )

  users[data[:name].split.first.downcase.to_sym] = user
  puts "  #{data[:name]} (#{data[:email]}) — profile: #{user.current_profile&.name} (#{profile.city}/#{profile.state})"
end

actors = users.transform_values { |u| u.current_profile }

# ── Site & Global Roles ────────────────────────────────────────
puts "\nSetting up global roles..."
site_actor = Site.instance.actor
GroupMembershipService.new(site_actor, actors[:ana]).add(role: "admin")
puts "  Site: #{Site.instance.name}, Admin: Ana"

# ── Groups ──────────────────────────────────────────────────────
puts "\nCreating groups..."

def create_group(name:, description:, creator:, privacy: :public_group)
  group = Group.new
  group.build_actor(name: name, description: description)
  group.privacy = privacy.to_s
  GroupCreation.new(creator, group).call
end

groups = {}

groups[:sp] = create_group(
  name: "Artistas de São Paulo",
  description: "Hub para cooperação, compartilhamento de editais e montagem de projetos na capital paulista.",
  creator: actors[:ana]
)
puts "  Artistas de São Paulo (admin: Ana)"

groups[:montagem] = create_group(
  name: "Montagem e Expografia",
  description: "Círculo de discussão técnica sobre cenografia, expografia, iluminação e transporte de acervos.",
  creator: actors[:bruno],
  privacy: :private_group
)
puts "  Montagem e Expografia (admin: Bruno, private)"

groups[:editais] = create_group(
  name: "Editais e Projetos",
  description: "Espaço para compartilhar editais abertos, tirar dúvidas sobre escrita de projetos e articular parcerias.",
  creator: actors[:carla]
)
puts "  Editais e Projetos (admin: Carla)"

# ── Memberships ─────────────────────────────────────────────────
puts "\nEstablishing memberships..."

def add_member(group, user, role: "member")
  group.actor.connect_to(user, as: role)
  user.connect_to(group.actor, as: "follow")
end

# Artistas de São Paulo: Ana (admin), Diego (mod), Bruno (member), Carla (member)
add_member(groups[:sp], actors[:diego], role: "moderator")
add_member(groups[:sp], actors[:bruno])
add_member(groups[:sp], actors[:carla])
puts "  Artistas de São Paulo: +Diego(mod) +Bruno(member) +Carla(member)"

# Montagem e Expografia: Bruno (admin), Ana (member), Diego (member), Elisa (member)
add_member(groups[:montagem], actors[:ana])
add_member(groups[:montagem], actors[:diego])
add_member(groups[:montagem], actors[:elisa])
puts "  Montagem e Expografia: +Ana(member) +Diego(member) +Elisa(member)"

# Editais e Projetos: Carla (admin), Ana (member), Bruno (member), Elisa (member)
add_member(groups[:editais], actors[:ana])
add_member(groups[:editais], actors[:bruno])
add_member(groups[:editais], actors[:elisa])
puts "  Editais e Projetos: +Ana(member) +Bruno(member) +Elisa(member)"

# ── Contacts (follows) ──────────────────────────────────────────
puts "\nCreating contacts..."
actors[:ana].connect_to(actors[:bruno], as: "friend")
actors[:ana].connect_to(actors[:carla], as: "friend")
actors[:bruno].connect_to(actors[:diego], as: "colleague")
actors[:carla].connect_to(actors[:elisa], as: "friend")
actors[:diego].connect_to(actors[:ana],   as: "acquaintance")
actors[:elisa].connect_to(actors[:bruno], as: "acquaintance")
actors[:elisa].connect_to(actors[:carla], as: "colleague")
puts "  7 contacts created"

# ── Activities / Posts ──────────────────────────────────────────
puts "\nCreating posts..."

def create_post(author:, owner:, title:, body: "")
  activity = Activity.new(verb: :post, author: author, owner: owner)
  activity.user_author = author.subject.is_a?(Profile) ? author.subject.user : nil
  ActivityCreation.new(
    activity,
    text: { title: title, body: body },
    relation_ids: owner.activity_relation_ids
  ).call
end

# Ana Silva posts
create_post(
  author: actors[:ana], owner: groups[:sp].actor,
  title: "Procura-se Expógrafo em SP!",
  body: "Olá pessoal! Acabo de ser selecionada no Edital do Centro Cultural SP e preciso de um expógrafo com urgência para desenhar o fluxo da exposição em Outubro. Quem tiver portfólio por aqui, por favor me envie!"
)

create_post(
  author: actors[:ana], owner: actors[:ana],
  title: "Nova série de Pinturas finalizada",
  body: "Terminei hoje a última tela da série 'Cores da Cidade'. São trabalhos em grande formato explorando texturas de asfalto e pigmentos minerais. Animada para expor!"
)

# Bruno Costa posts
create_post(
  author: actors[:bruno], owner: groups[:montagem].actor,
  title: "Dica de Expografia: Circulação",
  body: "Em espaços pequenos, evite criar barreiras visuais no centro da sala. Use painéis suspensos ou divisórias leves para orientar o olhar sem sufocar o visitante."
)

create_post(
  author: actors[:bruno], owner: actors[:bruno],
  title: "Renderização 3D de Projeto Expositivo",
  body: "Compartilhando os renders 3D que criei para a próxima exposição coletiva de fotógrafos. O foco foi a iluminação direcionada para destacar o contraste das fotos."
)

# Carla Mendes posts
create_post(
  author: actors[:carla], owner: groups[:editais].actor,
  title: "Edital Funarte Aberto!",
  body: "Saiu o novo edital de fomento às artes visuais. Vou fazer uma live explicando os critérios de pontuação da planilha financeira nesta quarta às 19h."
)

create_post(
  author: actors[:carla], owner: groups[:editais].actor,
  title: "Guia Rápido: Carta de Anuência",
  body: "Amigos, lembrem-se: a Carta de Anuência para editais públicos deve detalhar a função exata do profissional e estar assinada digitalmente. Não deixem para a última hora!"
)

# Diego Rocha posts
create_post(
  author: actors[:diego], owner: groups[:montagem].actor,
  title: "Importância do Registro de Montagem",
  body: "Registrar o processo de montagem (o 'por trás das câmeras') agrega muito valor ao portfólio do artista e da galeria. Mostra o trabalho invisível que acontece antes da abertura."
)

create_post(
  author: actors[:diego], owner: groups[:sp].actor,
  title: "Equipamento pronto para amanhã",
  body: "Lentes limpas, flashes carregados e cartão formatado. Amanhã é dia de registrar o acervo completo da nova galeria no Jardins."
)

# Elisa Torres posts
create_post(
  author: actors[:elisa], owner: groups[:montagem].actor,
  title: "Embalagem para Obras de Grande Formato",
  body: "Trabalho recente: embalagem em caixa de madeira tratada com revestimento de espuma de alta densidade para transporte terrestre intermunicipal seguro."
)

create_post(
  author: actors[:elisa], owner: groups[:editais].actor,
  title: "Planejamento Logístico para Editais",
  body: "Na escrita de projetos, nunca subestimem o custo do transporte. Caixas de madeira e caminhão climatizado têm valores específicos que precisam estar previstos na planilha orçamentária."
)

puts "  10 posts created"

# ── Comments ────────────────────────────────────────────────────
puts "\nCreating comments..."

def create_comment(author:, parent_activity:, text:)
  user_author = author.subject.is_a?(Profile) ? author.subject.user : nil
  CommentCreation.new(
    author: author,
    user_author: user_author,
    parent_activity: parent_activity,
    text: text
  ).call
end

# Find posts by their titles
posts = Activity.where(verb: :post).to_a
welcome_post      = posts.find { |p| p.direct_object&.title&.include?("Procura-se Expógrafo") }
turbo_post        = posts.find { |p| p.direct_object&.title&.include?("Dica de Expografia") }
ci_pr_post        = posts.find { |p| p.direct_object&.title&.include?("Edital Funarte") }
campaign_post     = posts.find { |p| p.direct_object&.title&.include?("Guia Rápido") }
animada_post      = posts.find { |p| p.direct_object&.title&.include?("Nova série") }

initial_activity_count = Activity.count

# ── Comment threads ──

# Post 1: Procura-se Expógrafo em SP! (welcome_post)
c1 = create_comment(
  author: actors[:bruno],
  parent_activity: welcome_post,
  text: "Parabéns pelo edital, @[Ana Silva](ana-silva)! Tenho muito interesse. Acabo de subir no meu portfólio alguns renders em 3D de projetos expositivos parecidos. Se quiser, podemos conversar!"
)

c2 = create_comment(
  author: actors[:carla],
  parent_activity: welcome_post,
  text: "Que notícia maravilhosa, Ana! Se você precisar de ajuda com a prestação de contas do edital depois, me avisa. Já fiz a gestão de dois projetos nesse mesmo espaço."
)

# Reply to Bruno's comment (depth 1 → 2)
c3 = create_comment(
  author: actors[:ana],
  parent_activity: c1,
  text: "Obrigada, Bruno! Adorei o seu portfólio. Vou te mandar uma mensagem privada para combinarmos uma reunião esta semana para te mostrar a planta do espaço."
)

c4 = create_comment(
  author: actors[:diego],
  parent_activity: c1,
  text: "Se precisarem de documentação fotográfica da montagem e da exposição final, estou disponível! Tenho bastante experiência com iluminação de obras de arte."
)

# Reply to Diego's reply (depth 2 → 3)
create_comment(
  author: actors[:bruno],
  parent_activity: c4,
  text: "Excelente, Diego! Com certeza vamos precisar. Um bom registro faz toda a diferença para o portfólio de expografia também."
)

# Post 2: Dica de Expografia: Circulação (turbo_post)
create_comment(
  author: actors[:ana],
  parent_activity: turbo_post,
  text: "Dica de ouro, Bruno! Na minha última exposição, erramos um pouco na circulação perto da entrada e gerou um gargalo nos dias de abertura mais cheios."
)

c5 = create_comment(
  author: actors[:elisa],
  parent_activity: turbo_post,
  text: "E complementando pelo lado da logística: pensem sempre se a largura das portas e passagens condiz com o tamanho da maior obra a ser transportada para dentro da sala."
)

# Reply to Elisa's comment
create_comment(
  author: actors[:bruno],
  parent_activity: c5,
  text: "Exatamente, Elisa! O laudo de acessibilidade física e a logística de montagem devem ser pensados em conjunto com a expografia."
)

# Post 3: Edital Funarte Aberto! (ci_pr_post)
c6 = create_comment(
  author: actors[:diego],
  parent_activity: ci_pr_post,
  text: "Muito obrigado por compartilhar, @[Carla Mendes](carla-mendes)! Essa live vai ser fundamental, pois a planilha orçamentária da Funarte sempre gera muitas dúvidas."
)

# Reply to Diego
create_comment(
  author: actors[:carla],
  parent_activity: c6,
  text: "Com certeza, Diego! Vou focar bastante na parte de contratação de fornecedores (como expógrafos, transportadoras e fotógrafos) para não faltar verba na execução."
)

# Post 4: Guia Rápido: Carta de Anuência (campaign_post)
c7 = create_comment(
  author: actors[:diego],
  parent_activity: campaign_post,
  text: "Excelente lembrete. Muitos artistas esquecem de me pedir a anuência e acabam correndo no último dia de inscrição do edital."
)

# Reply to Diego
create_comment(
  author: actors[:carla],
  parent_activity: c7,
  text: "Sim! E sem a assinatura correta de todos os membros da equipe técnica, a proposta é desclassificada na fase de habilitação documental. É um erro bobo mas super comum."
)

# Post 5: Nova série de Pinturas finalizada (animada_post)
create_comment(
  author: actors[:bruno],
  parent_activity: animada_post,
  text: "As texturas ficaram incríveis, Ana! A iluminação para essas telas vai precisar ser bem rasante para destacar o relevo da tinta."
)

create_comment(
  author: actors[:carla],
  parent_activity: animada_post,
  text: "Uau, trabalho magnífico! Parabéns, Ana. Certamente trará um impacto visual fortíssimo no espaço expositivo."
)

comment_count = Activity.count - initial_activity_count
puts "  #{comment_count} comment activities created"

# ── Summary ─────────────────────────────────────────────────────
puts "\n#{'='*60}"
puts "Seed complete!"
puts "#{'='*60}"
puts "  Users:     #{User.count} (#{Profile.count} profiles)"
puts "  Groups:    #{Group.count}"
puts "  Actors:    #{Actor.count}"
  puts "  Contacts:  #{Contact.count}"
  puts "  Ties:      #{Tie.count}"
  puts "  Activities: #{Activity.count}"
  puts "  Relations: #{Relation::Custom.count} custom"
  puts "#{'='*60}"
  puts "\nLogin with any email above, password: password123"
  puts "Try: http://localhost:3000/groups/#{groups[:sp].actor.slug}"
