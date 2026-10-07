# Authorization for {Activity Activities}. Any signed-in user may list and create activities;
# an activity is shown when it is public or {Activity#visible_to? visible} to the acting actor;
# only its author or owner may update or destroy it. The {Scope} narrows listings to the
# activities shared with the acting actor.
#
# @see Activity
class ActivityPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    record.public? || actor && record.visible_to?(actor)
  end

  def create?
    return false unless user.present? && actor.present?
    if record.parent_id.present?
      return false unless ActivityPolicy.new(user, record.parent).show?
    end
    return false if record.owner.nil?

    if record.relation_ids_to_authorize.present?
      allowed_ids = [ Relation::Public.instance.id ] + actor.relation_ids
      allowed_ids += record.owner.relation_ids if record.owner && record.owner != actor
      allowed_ids << Relation::Owner.instance.id if record.owner && record.owner.actorable_type == "Group"
      return false unless (record.relation_ids_to_authorize.map(&:to_i) - allowed_ids).empty?
    end

    return true if record.owner_id == actor.id
    actor.can?(:create, :activity, record.owner)
  end

  def update?
    actor && record.author_id == actor.id
  end

  def destroy?
    actor && record.author_id == actor.id
  end

  def flag?
    user.present? && actor.present? && record.author_id != actor.id
  end

  def flag_form?
    flag?
  end

  def unflag?
    user.present? && actor.present? && record.author_id != actor.id
  end

  class Scope < Scope
    # @return [ActiveRecord::Relation<Activity>] activities shared with the acting actor.
    def resolve
      scope.shared_with(actor)
    end
  end
end
