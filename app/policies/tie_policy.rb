# Authorization for {Tie Ties}. Ties are an internal detail of the social graph (created and
# managed through {Contact Contacts} and services), so they are never exposed directly: every
# action is denied and the {Scope} is empty. Site admins may inspect ties via the admin panel.
#
# @see Tie
# @see Contact
class TiePolicy < ApplicationPolicy
  def index?
    site_admin?
  end

  def show?
    site_admin?
  end

  class Scope < Scope
    def resolve
      scope.none
    end
  end
end
