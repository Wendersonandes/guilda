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
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  current_profile_id     :bigint
#
# Indexes
#
#  index_users_on_current_profile_id    (current_profile_id)
#  index_users_on_email                 (email) UNIQUE
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
end
