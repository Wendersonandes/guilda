# Service object managing a member's role within a {Group} or {Site}. Membership is expressed as
# {Tie Ties} from the granting {Actor} to the member's actor, using role relations (e.g.
# "member", "admin", "professional").
#
# @see Group
# @see Site
# @see Actor#connect_to
# @see Actor#disconnect_from
class GroupMembershipService
  PUNITIVE_ROLES = %w[silenced banned].freeze

  # @param group_actor [Actor] the group or site actor.
  # @param member_actor [Actor] the member's actor.
  def initialize(group_actor, member_actor)
    @group = group_actor
    @member = member_actor
  end

  # Adds the member with the given role. Defaults to replacing existing roles (replace: true).
  # Use {#add_role} for additive role assignment.
  #
  # @param role [String] the role relation name.
  # @param replace [Boolean] whether to replace existing roles.
  # @return [Tie] the resulting membership tie.
  def add(role: "member", replace: true)
    role_str = role.to_s.downcase

    if replace || PUNITIVE_ROLES.include?(role_str)
      @group.ties_to(@member).destroy_all
    else
      punitive_relations = @group.relations.where("LOWER(name) IN (?)", PUNITIVE_ROLES)
      @group.ties_to(@member).where(relation: punitive_relations).destroy_all
    end

    tie = @group.connect_to(@member, as: role)
    check_project_downgrade!
    tie
  end

  # Adds a role additively (without replacing existing positive roles).
  #
  # @param role [String] the role relation name.
  # @return [Tie] the resulting membership tie.
  def add_role(role)
    add(role: role, replace: false)
  end

  # Changes the member's role from one relation to another.
  #
  # @param from [String] the current role relation name.
  # @param to [String] the new role relation name.
  # @return [Tie] the resulting membership tie.
  def change_role(from:, to:)
    to_str = to.to_s.downcase
    if PUNITIVE_ROLES.include?(to_str)
      @group.ties_to(@member).destroy_all
    else
      @group.disconnect_from(@member, from)
    end
    tie = @group.connect_to(@member, as: to)
    check_project_downgrade!
    tie
  end

  # Removes the member. When +role+ is given, only that role tie is removed;
  # otherwise all ties and contacts are destroyed bidirectionally.
  #
  # @param role [String, nil] the role relation name to remove, or +nil+ for full removal.
  # @return [void]
  def remove(role: nil)
    if role
      @group.disconnect_from(@member, role)
      if @group.ties_to(@member).empty?
        @member.disconnect_from(@group, "follow")
      end
      [ @group, @member ].each do |actor|
        other = actor == @group ? @member : @group
        contact = actor.contact_to(other)
        contact&.destroy unless contact&.reload&.established?
      end
    else
      @group.ties_to(@member).destroy_all
      @member.ties_to(@group).destroy_all
      @group.contact_to(@member)&.destroy
      @member.contact_to(@group)&.destroy
    end
    check_project_downgrade!
  end

  private

  def check_project_downgrade!
    return unless @group == Site.instance.actor
    profile = @member.actorable
    return unless profile.is_a?(Profile)

    # Revert public projects to draft if the actor can no longer publish projects
    unless @member.can?(:publish, :project, @group)
      profile.projects.visibility_public.update_all(visibility: Project.visibilities[:draft])
    end
  end
end
