require "test_helper"

class ContactFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor = create_profile_for(@bob, name: "Bob")
  end

  test "full contact flow: connect → verify tie → check permissions" do
    @alice_actor.connect_to(@bob_actor, as: "follower")

    assert @alice_actor.connected_with?(@bob_actor)
    assert_not @bob_actor.connected_with?(@alice_actor)

    follower_rel = @alice_actor.relation_custom("follower")
    tie = @alice_actor.sent_ties.find_by(relation: follower_rel)
    assert tie
    assert tie.positive?

    assert @alice_actor.allow?(@bob_actor, :read, :activity)
  end

  test "connect via suggestions parameters" do
    clear_enqueued_jobs

    # Sign in user
    sign_in @alice

    # Simulate POST from suggestions bar
    post contacts_path(actor_id: @bob_actor.slug, as: "follower"), as: :turbo_stream
    assert_response :success

    # Verify connection was established
    assert @alice_actor.reload.connected_with?(@bob_actor)

    # Check that bob is in Alice's follower relation
    follower_rel = @alice_actor.relation_custom("follower")
    tie = @alice_actor.sent_ties.find_by(relation: follower_rel)
    assert tie
    assert_equal @bob_actor, tie.contact.receiver

    # Perform background jobs
    perform_enqueued_jobs

    # Verify created contact Activity and its audiences
    activity = Activity.last
    assert_not_nil activity
    assert_equal "follow", activity.verb
    assert_equal @alice_actor, activity.author
    assert_equal @bob_actor, activity.owner
    assert_equal @bob_actor.activity_relation_ids.sort, activity.audiences.map(&:relation_id).sort
  end


  test "contacts_for filters by relation" do
    @alice_actor.connect_to(@bob_actor, as: "follower")

    contacts = @alice_actor.contacts_for("follower")
    assert_includes contacts, @bob_actor
    assert_equal 1, contacts.count
  end

  test "bidirectional tie establishes mutual permissions" do
    @alice_actor.connect_to(@bob_actor, as: "follower")
    @bob_actor.connect_to(@alice_actor, as: "follower")

    assert @alice_actor.allow?(@bob_actor, :read, :activity)
    assert @bob_actor.allow?(@alice_actor, :read, :activity)
  end
end
