# Authorization for {Project Projects}. Public projects are readable by everyone; drafts and
# private projects are readable only by the owning profile. Management actions (create, update,
# destroy, reorder) are restricted to the owning profile.
#
# @see Project
class ProjectPolicy < ApplicationPolicy
  # Anyone may see a public project; drafts/private only the owner.
  def show?
    record.visible_to?(actor)
  end

  def index?
    actor.present?
  end

  def create?
    profile? && actor.present?
  end
  alias_method :new?, :create?

  def update?
    owner?
  end
  alias_method :edit?, :update?

  def destroy?
    owner?
  end

  def reorder?
    owner?
  end

  class Scope < Scope
    # @return [ActiveRecord::Relation<Project>] public projects plus the acting profile's own.
    def resolve
      return scope.publicly_visible unless actor&.actorable.is_a?(Profile)

      scope.where(visibility: Project.visibilities[:public])
           .or(scope.where(profile_id: actor.actorable_id))
    end
  end

  private

  # Whether the acting actor is a profile (able to own projects).
  def profile?
    actor&.actorable.is_a?(Profile)
  end

  # Whether the acting actor owns the project's profile.
  def owner?
    profile? && record.profile_id == actor.actorable_id
  end
end
