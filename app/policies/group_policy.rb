# Authorization for {Group Groups}. The policy +record+ is the group's {Actor}, so role checks
# are delegated to {Actor#has_relation_with?}. Public groups are listable by anyone; private
# groups only by members and above. Management actions (update, destroy, member management)
# require the +Admin+ role; leaving requires any membership role.
#
# @see Group
# @see GroupMembershipService
class GroupPolicy < ApplicationPolicy
  def index?
    record.actorable&.public_group? || member_or_above?
  end

  def show?
    true
  end

  def create?
    user.present?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def join?
    user.present?
  end

  def manage_members?
    admin?
  end

  def add_member?
    admin?
  end

  def remove_member?
    admin?
  end

  def change_role?
    admin?
  end

  def leave?
    (admin? || moderator? || member?) && !owner?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  # Does the acting actor hold the +Owner+ role in this group?
  # @return [Boolean]
  def owner?
    return false unless actor
    record.has_relation_with?(actor, "Owner")
  end

  # Does the acting actor hold the +Admin+ role in this group?
  # @return [Boolean]
  def admin?
    return false unless actor
    record.has_relation_with?(actor, "Admin") || owner?
  end

  # Does the acting actor hold the +Moderator+ role in this group?
  # @return [Boolean]
  def moderator?
    return false unless actor
    record.has_relation_with?(actor, "Moderator")
  end

  # Does the acting actor hold the +Member+ role in this group?
  # @return [Boolean]
  def member?
    return false unless actor
    record.has_relation_with?(actor, "Member")
  end

  # Does the acting actor hold any membership role (member, moderator or admin)?
  # @return [Boolean]
  def member_or_above?
    owner? || admin? || moderator? || member?
  end
end
