require "test_helper"

class GroupMembershipServiceTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @carol_user = User.create!(email: "carol@example.com", password: "password123", profile_name: "Carol")
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @carol_actor = @carol_user.current_profile
    @group = create_group_with_admin(@alice_actor)
    @group_actor = @group.actor
  end

  test "add member with default role" do
    assert_difference [ "Contact.count", "Tie.count" ], 1 do
      GroupMembershipService.new(@group_actor, @bob_actor).add
    end
    assert @group_actor.has_relation_with?(@bob_actor, "Member")
  end

  test "add member with admin role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "admin")
    assert @group_actor.has_relation_with?(@bob_actor, "Admin")
  end

  test "add member with owner role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "owner")
    assert @group_actor.has_relation_with?(@bob_actor, "Owner")
  end

  test "add member with moderator role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "moderator")
    assert @group_actor.has_relation_with?(@bob_actor, "Moderator")
  end

  test "change_role switches relation" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "member")
    assert @group_actor.has_relation_with?(@bob_actor, "Member")

    GroupMembershipService.new(@group_actor, @bob_actor).change_role(from: "member", to: "moderator")
    assert_not @group_actor.has_relation_with?(@bob_actor, "Member")
    assert @group_actor.has_relation_with?(@bob_actor, "Moderator")
  end

  test "remove with specific role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "member")
    assert_difference "Tie.count", -1 do
      GroupMembershipService.new(@group_actor, @bob_actor).remove(role: "member")
    end
    assert_not @group_actor.has_relation_with?(@bob_actor, "Member")
  end

  test "add replaces existing role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "member")
    assert @group_actor.has_relation_with?(@bob_actor, "Member")

    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "moderator")
    assert @group_actor.has_relation_with?(@bob_actor, "Moderator")
    assert_not @group_actor.has_relation_with?(@bob_actor, "Member")
    assert_equal 1, @group_actor.ties_to(@bob_actor).count
  end

  test "remove all roles" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "member")

    assert_difference "Tie.count", -1 do
      GroupMembershipService.new(@group_actor, @bob_actor).remove
    end
    assert_empty @group_actor.member_roles_for(@bob_actor)
  end

  private

  def create_group_with_admin(admin_actor)
    group = Group.new
    group.build_actor(name: "Test Group Service")
    GroupCreation.new(admin_actor, group).call
  end
end
