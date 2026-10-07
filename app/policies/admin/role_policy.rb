# Authorization for the admin *roles* area, where site administrators manage relations and
# permissions. Listing requires the +read admin+ permission and mutating roles requires
# +update role+, both granted by the site's +Admin+ relation.
#
# @see Site
# @see Permission
class Admin::RolePolicy < ApplicationPolicy
  def index?
    site_admin?
  end

  def create?
    role_manager?
  end

  def update?
    role_manager?
  end

  private

  # Whether the acting actor may manage site roles (+update role+).
  #
  # @return [Boolean]
  def role_manager?
    actor ? actor.can?(:update, :role) : false
  end
end
