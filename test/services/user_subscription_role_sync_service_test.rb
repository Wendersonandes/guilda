# frozen_string_literal: true

require "test_helper"

class UserSubscriptionRoleSyncServiceTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @user = users(:bob)
    @profile_actor = create_profile_for(@user, name: "Bob", role: "member")
    @site_actor = Site.instance.actor
  end

  test "grants professional role when user is subscribed" do
    assert_not @site_actor.has_relation_with?(@profile_actor, "Professional")

    customer = @user.set_payment_processor(:stripe)
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_test_123",
      processor_plan: "price_test_123",
      status: "active",
      quantity: 1
    )

    # Reload to ensure associations and state are fresh
    assert @user.reload.subscribed?
    assert @site_actor.reload.has_relation_with?(@profile_actor, "Professional")
    assert @profile_actor.can?(:publish, :project, @site_actor)
  end

  test "revokes professional role when subscription becomes inactive or canceled" do
    customer = @user.set_payment_processor(:stripe)
    subscription = customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_test_456",
      processor_plan: "price_test_456",
      status: "active",
      quantity: 1
    )

    assert @site_actor.has_relation_with?(@profile_actor, "Professional")

    # Update subscription to canceled
    subscription.update!(status: "canceled", ends_at: 1.day.ago)

    assert_not @user.subscribed?
    assert_not @site_actor.has_relation_with?(@profile_actor, "Professional")
  end

  test "sync service is idempotent" do
    assert_not @site_actor.has_relation_with?(@profile_actor, "Professional")

    # Running with user not subscribed
    UserSubscriptionRoleSyncService.new(@user).call
    assert_not @site_actor.has_relation_with?(@profile_actor, "Professional")

    # Now grant role via sync service manually
    customer = @user.set_payment_processor(:stripe)
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_test_789",
      processor_plan: "price_test_789",
      status: "trialing",
      trial_ends_at: 30.days.from_now,
      quantity: 1
    )

    assert @site_actor.has_relation_with?(@profile_actor, "Professional")

    # Calling sync service again should not duplicate ties
    assert_no_difference "Tie.count" do
      UserSubscriptionRoleSyncService.new(@user).call
    end

    assert @site_actor.has_relation_with?(@profile_actor, "Professional")
  end
end
