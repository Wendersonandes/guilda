require "test_helper"

class GroupJoinFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations

    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor   = create_profile_for(@bob, name: "Bob")

    @public_group = Group.new(privacy: :public_group)
    @public_group.build_actor(name: "Open Group")
    GroupCreation.new(@alice_actor, @public_group).call

    @private_group = Group.new(privacy: :private_group)
    @private_group.build_actor(name: "Closed Group")
    GroupCreation.new(@alice_actor, @private_group).call

    perform_enqueued_jobs
  end

  test "join public group creates bidirectional ties" do
    sign_in @bob

    post group_memberships_path(@public_group),
         params: { actor_id: @bob_actor.id, role: "member" }

    assert_response :redirect
    assert_equal "Você entrou no grupo.", flash[:notice]

    # Verify bidirectional ties
    assert @bob_actor.reload.connected_with?(@public_group.actor)
    assert @public_group.actor.reload.connected_with?(@bob_actor)
    assert @public_group.actor.member_roles_for(@bob_actor).include?("member")
  end

  test "join private group creates pending request" do
    sign_in @bob

    post group_memberships_path(@private_group),
         params: { actor_id: @bob_actor.id, role: "member" }

    assert_response :redirect
    assert_equal "Solicitação enviada. Aguardando aprovação.", flash[:notice]

    # Only one-sided
    assert @bob_actor.reload.connected_with?(@private_group.actor)
    assert_not @private_group.actor.reload.connected_with?(@bob_actor)
  end

  test "recover from stale one-sided contact on public group join" do
    sign_in @bob

    # Simulate stale contact: create a one-sided contact manually
    @bob_actor.sent_contacts.create!(receiver: @public_group.actor)

    post group_memberships_path(@public_group),
         params: { actor_id: @bob_actor.id, role: "member" }

    assert_response :redirect
    assert_equal "Você entrou no grupo.", flash[:notice]

    # Should now be fully connected both ways
    assert @public_group.actor.reload.member_roles_for(@bob_actor).include?("member")
  end

  test "member of public group can leave and join again" do
    sign_in @bob

    # Bob joins
    post group_memberships_path(@public_group),
         params: { actor_id: @bob_actor.id, role: "member" }
    assert_equal "Você entrou no grupo.", flash[:notice]

    # Bob leaves
    delete group_membership_path(@public_group, @bob_actor, role: "member")
    assert_response :redirect

    # Cleanup should have removed contacts
    assert_nil @bob_actor.reload.contact_to(@public_group.actor)

    # Bob can join again
    post group_memberships_path(@public_group),
         params: { actor_id: @bob_actor.id, role: "member" }
    assert_equal "Você entrou no grupo.", flash[:notice]
  end

  test "member of private group can leave and request to join again" do
    sign_in @bob

    # Bob requests to join and is approved
    @bob_actor.connect_to(@private_group.actor, as: "follow")
    @private_group.actor.connect_to(@bob_actor, as: "member")

    # Bob leaves
    delete group_membership_path(@private_group, @bob_actor, role: "member")
    assert_response :redirect

    # Cleanup should have removed contacts
    assert_nil @bob_actor.reload.contact_to(@private_group.actor)

    # Bob can request to join again
    post group_memberships_path(@private_group),
         params: { actor_id: @bob_actor.id, role: "member" }
    assert_equal "Solicitação enviada. Aguardando aprovação.", flash[:notice]
  end
end
