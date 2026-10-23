namespace :admin do
  desc "Concede o papel de Administrador a um usuário via email, slug ou ID: bin/rails admin:grant[usuario@exemplo.com]"
  task :grant, [ :identifier ] => :environment do |_t, args|
    identifier = args[:identifier]
    if identifier.blank?
      abort "Uso: bin/rails admin:grant[email_slug_ou_id]"
    end

    actor = find_admin_target_actor(identifier)
    site_actor = Site.instance.actor

    GroupMembershipService.new(site_actor, actor).add_role("admin")
    puts "✓ Papel de Administrador concedido com sucesso para #{actor.name} (#{actor.slug})!"
  end

  desc "Remove o papel de Administrador de um usuário via email, slug ou ID: bin/rails admin:revoke[usuario@exemplo.com]"
  task :revoke, [ :identifier ] => :environment do |_t, args|
    identifier = args[:identifier]
    if identifier.blank?
      abort "Uso: bin/rails admin:revoke[email_slug_ou_id]"
    end

    actor = find_admin_target_actor(identifier)
    site_actor = Site.instance.actor

    unless site_actor.has_relation_with?(actor, "Admin")
      puts "! #{actor.name} (#{actor.slug}) não possui o papel de Administrador."
      next
    end

    GroupMembershipService.new(site_actor, actor).remove(role: "admin")
    puts "✓ Papel de Administrador revogado com sucesso de #{actor.name} (#{actor.slug})!"
  end

  desc "Lista todos os administradores atuais da plataforma: bin/rails admin:list"
  task list: :environment do
    site_actor = Site.instance.actor
    admins = site_actor.contacts_for("admin")

    if admins.empty?
      puts "Nenhum administrador encontrado."
    else
      puts "Administradores da plataforma (#{admins.count}):"
      admins.each do |admin|
        user_email = admin.actorable.is_a?(Profile) ? admin.actorable.user&.email : "N/A"
        puts "  - #{admin.name} (slug: #{admin.slug}, email: #{user_email})"
      end
    end
  end

  def find_admin_target_actor(value)
    str = value.to_s.strip

    if str.include?("@")
      user = User.find_by(email: str)
      if user&.current_profile
        return user.current_profile
      elsif user&.profiles&.first
        return user.profiles.first.actor
      end
    end

    actor = if str.match?(/\A\d+\z/)
      Actor.find_by(id: str)
    else
      Actor.find_by(slug: str)
    end

    return actor if actor

    abort "Erro: Nenhum ator ou usuário encontrado para '#{value}'."
  end
end
