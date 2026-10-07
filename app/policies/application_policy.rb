# Base class for all {https://github.com/varvet/pundit Pundit} authorization policies. It
# defines a deny-by-default contract: every action returns +false+ unless a subclass overrides
# it.
#
# Two identities are available to subclasses:
# * +user+ — the authenticated {User} (the login identity), or +nil+ when signed out.
# * {#actor} — the {Actor} the user is currently acting as ({User#current_profile}). This is
#   the entity checked against the social graph and {Permission Permissions}.
#
# In this application, policies delegate authorization decisions about the graph to
# {Actor#can?} (which resolves the {Permission Permissions} granted by the actor's {Tie Ties})
# and to model methods such as {Activity#visible_to?}.
#
# @see Actor
# @see User
class ApplicationPolicy
  attr_reader :user, :record

  # @param user [User, nil] the authenticated user.
  # @param record [Object] the record (or class) being authorized.
  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  # Aliases {#create?}: authorizing +new+ is the same as authorizing +create+.
  def new?
    create?
  end

  def update?
    false
  end

  # Aliases {#update?}: authorizing +edit+ is the same as authorizing +update+.
  def edit?
    update?
  end

  def destroy?
    false
  end

  private

  # The {Actor} the {#user} is currently acting as.
  #
  # @return [Actor, nil]
  def actor
    @actor ||= user&.current_profile
  end

  # Whether the acting actor is a site administrator, resolved through the +read admin+
  # {Permission} granted by the site's +Admin+ relation.
  #
  # @return [Boolean]
  def site_admin?
    actor ? actor.can?(:read, :admin) : false
  end

  # Whether the record's author or owner is the acting {#actor}.
  #
  # @return [Boolean]
  def author_or_owner?
    actor && (record.author_id == actor.id || record.owner_id == actor.id)
  end

  # Base class for policy scopes: resolves which records the acting user may see for a given
  # query. Subclasses must implement {#resolve}.
  class Scope
    # @param user [User, nil] the authenticated user.
    # @param scope [ActiveRecord::Relation] the base scope to filter.
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # @return [ActiveRecord::Relation] the records visible to the user.
    # @raise [NoMethodError] unless overridden by a subclass.
    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope

    # The {Actor} the {#user} is currently acting as.
    #
    # @return [Actor, nil]
    def actor
      @actor ||= user&.current_profile
    end
  end
end
