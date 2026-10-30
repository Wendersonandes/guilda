require "test_helper"

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  uid                    :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  current_profile_id     :bigint
#
# Indexes
#
#  index_users_on_current_profile_id    (current_profile_id)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_provider_and_uid      (provider,uid) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (current_profile_id => actors.id) ON DELETE => nullify
#
class UserTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @bob = users(:bob)
    @alice = users(:alice)
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @alice_actor = create_profile_for(@alice, name: "Alice")

    # Create a group
    @group = Group.new(privacy: :public_group)
    @group.build_actor(name: "Test Group User")
    GroupCreation.new(@alice_actor, @group).call
  end

  test "User model delegates role and permission helpers to current_profile" do
    # 1. Test has_permission?
    assert_not @bob.has_permission?(:update, :activity, @group)

    # 2. Test add_role
    assert_difference "Tie.count", 2 do
      @bob.add_role(:member, @group)
    end

    assert @bob.has_role?(:member, @group)

    # 3. Test has_permission? after adding role
    assert @bob.has_permission?(:read, :activity, @group)
    assert @bob.has_permission?(:create, :post, @group)

    # 4. Test remove_role
    assert_difference "Tie.count", -2 do
      @bob.remove_role(:member, @group)
    end

    assert_not @bob.has_role?(:member, @group)
  end

  test "banned user cannot authenticate" do
    assert @bob.active_for_authentication?

    GroupMembershipService.new(Site.instance.actor, @bob_actor).add(role: "banned")
    @bob.reload

    assert_not @bob.active_for_authentication?
    assert_equal :banned, @bob.inactive_message
  end

  test "user is configured as a Pay customer with Stripe as default processor" do
    assert_respond_to @bob, :payment_processor
    assert_respond_to @bob, :pay_subscriptions
    assert_respond_to @bob, :pay_charges
    assert_respond_to @bob, :subscribed?
    assert_respond_to @bob, :subscription

    customer = @bob.set_payment_processor(:stripe)
    assert_equal "stripe", customer.processor
    assert_equal @bob, customer.owner
    assert_respond_to customer, :subscriptions
    assert_respond_to customer, :charges
    assert_respond_to customer, :subscribe
    assert_respond_to customer, :checkout
    assert_respond_to customer, :billing_portal
  end

  test "pay_customer_name delegates to current_profile name or falls back to email" do
    assert_equal "Bob", @bob.pay_customer_name

    @bob.current_profile = nil
    assert_equal @bob.email, @bob.pay_customer_name
  end

  test "from_omniauth creates a new user, profile and actor when user does not exist" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "10987654321",
      info: {
        email: "carlos@example.com",
        name: "Carlos Silva"
      }
    )

    assert_difference -> { User.count } => 1, -> { Profile.count } => 1, -> { Actor.count } => 1 do
      user = User.from_omniauth(auth)
      assert user.persisted?
      assert_equal "carlos@example.com", user.email
      assert_equal "google_oauth2", user.provider
      assert_equal "10987654321", user.uid
      assert_equal "Carlos Silva", user.current_profile.name
    end
  end

  test "from_omniauth links existing user with matching email" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "999888777",
      info: {
        email: @bob.email,
        name: "Bob Updated"
      }
    )

    assert_no_difference "User.count" do
      user = User.from_omniauth(auth)
      assert_equal @bob.id, user.id
      assert_equal "google_oauth2", user.reload.provider
      assert_equal "999888777", user.uid
    end
  end

  test "from_omniauth returns existing user with matching provider and uid" do
    @bob.update!(provider: "google_oauth2", uid: "555444333")

    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "555444333",
      info: {
        email: "different_email@example.com"
      }
    )

    assert_no_difference "User.count" do
      user = User.from_omniauth(auth)
      assert_equal @bob.id, user.id
    end
  end

  test "from_omniauth returns nil for blank auth payload" do
    assert_nil User.from_omniauth(nil)
    assert_nil User.from_omniauth(OmniAuth::AuthHash.new)
  end
end
