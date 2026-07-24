require "test_helper"

class ActivityPolicyTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations

    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor   = create_profile_for(@bob, name: "Bob")

    @charlie = User.create!(email: "charlie@example.com", password: "password123", profile_name: "Charlie")
    @charlie_actor = create_profile_for(@charlie, name: "Charlie")

    # Public group: Alice is admin, Bob is member
    @group = Group.new(privacy: :public_group)
    @group.build_actor(name: "Test Group")
    GroupCreation.new(@alice_actor, @group).call
    @group_actor = @group.actor

    # Bob joins the group as member
    @bob_actor.connect_to(@group_actor, as: "follow")
    @group_actor.connect_to(@bob_actor, as: "member")

    # Private group: Alice is admin, Bob is member, Charlie is not
    @private_group = Group.new(privacy: :private_group)
    @private_group.build_actor(name: "Private Group")
    GroupCreation.new(@alice_actor, @private_group).call
    @private_group_actor = @private_group.actor

    @bob_actor.connect_to(@private_group_actor, as: "follow")
    @private_group_actor.connect_to(@bob_actor, as: "member")
  end

  test "logged in user can create post on own wall" do
    activity = Activity.new(verb: :post, author: @alice_actor, owner: @alice_actor)
    policy = ActivityPolicy.new(@alice, activity)
    assert policy.create?
  end

  test "group member can create post in the group" do
    activity = Activity.new(verb: :post, author: @bob_actor, owner: @group_actor)
    policy = ActivityPolicy.new(@bob, activity)
    assert policy.create?
  end

  test "non-member cannot create post in the group" do
    activity = Activity.new(verb: :post, author: @charlie_actor, owner: @group_actor)
    policy = ActivityPolicy.new(@charlie, activity)
    assert_not policy.create?
  end

  test "signed out user cannot create post" do
    activity = Activity.new(verb: :post, author: @alice_actor, owner: @alice_actor)
    policy = ActivityPolicy.new(nil, activity)
    assert_not policy.create?
  end

  test "private group member can create post" do
    activity = Activity.new(verb: :post, author: @bob_actor, owner: @private_group_actor)
    policy = ActivityPolicy.new(@bob, activity)
    assert policy.create?
  end

  test "private group non-member cannot create post" do
    activity = Activity.new(verb: :post, author: @charlie_actor, owner: @private_group_actor)
    policy = ActivityPolicy.new(@charlie, activity)
    assert_not policy.create?
  end

  test "silenced member cannot create post in the group" do
    @group_actor.disconnect_from(@bob_actor, "member")
    @group_actor.connect_to(@bob_actor, as: "silenced")
    @bob_actor.reload
    
    activity = Activity.new(verb: :post, author: @bob_actor, owner: @group_actor)
    policy = ActivityPolicy.new(@bob, activity)
    assert_not policy.create?
  end
end
