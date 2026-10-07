# Authorization for {Group Groups}. The policy +record+ is the group's {Actor}, so
# authorization is delegated to {Actor#can?} against the group context (the role's
# {Permission} grants). Public groups are listable by anyone; private groups only by members
# and above. Management actions require the +update member+/+update group+ capabilities; only
# the owner may destroy the group, and only non-owners may leave it.
#
# @see Group
# @see Actor#can?
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
    can?(:update, :group)
  end

  def destroy?
    can?(:destroy, :group)
  end

  def join?
    user.present?
  end

  def manage_members?
    can?(:update, :member)
  end

  def add_member?
    can?(:create, :member)
  end

  def remove_member?
    can?(:destroy, :member)
  end

  def change_role?
    can?(:update, :member)
  end

  def leave?
    member_or_above? && !owner?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  # Whether the acting actor may perform +action+ on +object+ within this group's context.
  #
  # @return [Boolean]
  def can?(action, object)
    actor ? actor.can?(action, object, record) : false
  end

  # Does the acting actor hold the +Owner+ role in this group? (identity, used for +leave?+)
  # @return [Boolean]
  def owner?
    actor ? record.has_relation_with?(actor, "Owner") : false
  end

  # Whether the acting actor holds any membership role (member or above). Equivalent to being
  # granted +read group+; silenced actors are excluded.
  # @return [Boolean]
  def member_or_above?
    can?(:read, :group)
  end
end
