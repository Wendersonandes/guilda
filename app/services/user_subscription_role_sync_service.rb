# frozen_string_literal: true

# Synchronizes the "Professional" role and permissions on the user's active profile
# based on their subscription status in Stripe / Pay.
#
# When subscribed (active or in trial):
#   Grants the "Professional" role on Site.instance.actor to current_profile.
# When not subscribed (canceled, expired, past due, or inactive):
#   Revokes the "Professional" role on Site.instance.actor, automatically reverting
#   public projects to draft per application domain rules.
class UserSubscriptionRoleSyncService
  ROLE_NAME = "professional"
  RELATION_NAME = "Professional"

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call
    return unless user && Site.instance&.actor

    site_actor = Site.instance.actor
    profile_actor = user.current_profile
    return unless profile_actor

    if user_subscribed?
      grant_role(site_actor, profile_actor)
    else
      revoke_role(site_actor, profile_actor)
    end
  end

  private

  def user_subscribed?
    user.payment_processor&.subscriptions&.active&.any? || user.subscribed?
  end

  def grant_role(site_actor, profile_actor)
    return if site_actor.has_relation_with?(profile_actor, RELATION_NAME)

    GroupMembershipService.new(site_actor, profile_actor).add_role(ROLE_NAME)
  end

  def revoke_role(site_actor, profile_actor)
    return unless site_actor.has_relation_with?(profile_actor, RELATION_NAME)

    GroupMembershipService.new(site_actor, profile_actor).remove(role: ROLE_NAME)
  end
end
