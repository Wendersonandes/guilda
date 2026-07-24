require "test_helper"

class GroupPolicyTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @carol_user = User.create!(email: "carol@example.com", password: "password123", profile_name: "Carol")
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @carol_actor = @carol_user.current_profile
    @alice.update!(current_profile: @alice_actor)
    @bob.update!(current_profile: @bob_actor)
    @group = create_group_with_admin(@alice_actor)
    @group_actor = @group.actor
  end

  test "index? is true for everyone" do
    assert GroupPolicy.new(nil, @group_actor).index?
    assert GroupPolicy.new(@alice, @group_actor).index?
  end

  test "show? is true for everyone" do
    assert GroupPolicy.new(nil, @group_actor).show?
    assert GroupPolicy.new(@alice, @group_actor).show?
  end

  test "create? requires authenticated user" do
    assert GroupPolicy.new(@alice, Actor.new(actorable_type: "Group")).create?
    assert_not GroupPolicy.new(nil, Actor.new(actorable_type: "Group")).create?
  end

  test "owner is connected upon group creation" do
    group = Group.new
    group.build_actor(name: "New Group")
    GroupCreation.new(@bob_actor, group).call
    assert group.actor.has_relation_with?(@bob_actor, "Owner")
    assert_not group.actor.has_relation_with?(@bob_actor, "Admin")
  end

  test "owner has admin permissions" do
    # @alice is the owner of @group (creator)
    assert GroupPolicy.new(@alice, @group_actor).update?
    assert GroupPolicy.new(@alice, @group_actor).destroy?
    assert GroupPolicy.new(@alice, @group_actor).manage_members?
    assert GroupPolicy.new(@alice, @group_actor).add_member?
    assert GroupPolicy.new(@alice, @group_actor).remove_member?
    assert GroupPolicy.new(@alice, @group_actor).change_role?
    assert_not GroupPolicy.new(@alice, @group_actor).leave?
  end

  test "admin has admin permissions" do
    # bob is connected as admin custom relation
    @group_actor.connect_to(@bob_actor, as: "admin")
    assert GroupPolicy.new(@bob, @group_actor).update?
    assert_not GroupPolicy.new(@bob, @group_actor).destroy?
    assert GroupPolicy.new(@bob, @group_actor).manage_members?
    assert GroupPolicy.new(@bob, @group_actor).add_member?
    assert GroupPolicy.new(@bob, @group_actor).remove_member?
    assert GroupPolicy.new(@bob, @group_actor).change_role?
    assert GroupPolicy.new(@bob, @group_actor).leave?
  end

  test "leave? is true for any member except owner" do
    @group_actor.connect_to(@bob_actor, as: "member")
    assert_not GroupPolicy.new(@alice, @group_actor).leave?
    assert GroupPolicy.new(@bob, @group_actor).leave?
    assert_not GroupPolicy.new(@carol_user, @group_actor).leave?
  end

  test "join? requires authenticated user" do
    @group.update!(privacy: :private_group)
    assert GroupPolicy.new(@bob, @group_actor).join?
    assert GroupPolicy.new(@alice, @group_actor).join?
    assert_not GroupPolicy.new(nil, @group_actor).join?
  end

  private

  def create_group_with_admin(admin_actor)
    group = Group.new
    group.build_actor(name: "Test Group Policy")
    GroupCreation.new(admin_actor, group).call
  end
end
