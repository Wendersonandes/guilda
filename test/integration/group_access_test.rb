require "test_helper"

class GroupAccessTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations

    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor   = create_profile_for(@bob, name: "Bob")

    # Public group: Alice is admin, Bob is NOT a member
    @public_group = Group.new(privacy: :public_group)
    @public_group.build_actor(name: "Public Club", description: "Open to all")
    GroupCreation.new(@alice_actor, @public_group).call

    # Private group: Alice is admin, Bob is NOT a member
    @private_group = Group.new(privacy: :private_group)
    @private_group.build_actor(name: "Secret Club", description: "Members only")
    GroupCreation.new(@alice_actor, @private_group).call

    perform_enqueued_jobs
  end

  test "non-member can view public group posts and members" do
    sign_in @bob

    get group_path(@public_group)
    assert_response :success

    # Should see group content (not private lock screen)
    assert_match @public_group.name, response.body
    assert_match "members", response.body
  end

  test "non-member sees private group lock screen without content" do
    sign_in @bob

    get group_path(@private_group)
    assert_response :success

    # Should see lock screen
    assert_match "Private Group", response.body
    assert_match "Request to join", response.body

    # Should NOT see members count in content area
    assert_no_match /No posts yet/, response.body
  end

  test "member of private group can view content" do
    sign_in @bob

    # Bob requests to join, Alice approves
    @bob_actor.connect_to(@private_group.actor, as: "follow")
    @private_group.actor.connect_to(@bob_actor, as: "member")

    get group_path(@private_group)
    assert_response :success
    assert_match @private_group.name, response.body
  end

  test "public group shows join button for non-member on index" do
    sign_in @bob

    get groups_path
    assert_response :success
    assert_match "Join", response.body
  end

  test "public group index shows member badge for existing member" do
    sign_in @alice

    get groups_path
    assert_response :success
    assert_match "Member", response.body
  end
end
