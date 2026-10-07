require "test_helper"

class MentionManagerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations
    @user_alice = users(:alice)
    @alice = create_profile_for(@user_alice, name: "Alice")
    
    @user_bob = users(:bob)
    @bob = create_profile_for(@user_bob, name: "Bob")
  end

  test "should parse and create mentions for valid and visible actors" do
    post = Post.new
    post.build_activity_object(
      description: "Hey @[Bob](bob), check this out!",
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    post.save!

    activity = Activity.create!(
      verb: :post,
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    activity.activity_objects << post.activity_object

    # Run CreateActivityAudiencesJob to copy audiences and trigger MentionManager
    perform_enqueued_jobs do
      CreateActivityAudiencesJob.perform_later(activity.id, nil) # nil defaults to Public
    end

    # Confirm Bob was mentioned
    assert_equal 1, post.activity_object.mentions.count
    assert_equal @bob, post.activity_object.mentioned_actors.first

    # Check notification delivery
    notifications = @bob.notifications.all
    assert_equal 1, notifications.count
    assert_match /Alice mencionou você/, notifications.first.message
  end

  test "should ignore self-mention" do
    post = Post.new
    post.build_activity_object(
      description: "Self-mentioning @[Alice](alice)",
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    post.save!

    activity = Activity.create!(
      verb: :post,
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    activity.activity_objects << post.activity_object

    perform_enqueued_jobs do
      CreateActivityAudiencesJob.perform_later(activity.id, nil)
    end

    assert_empty post.activity_object.mentions
  end

  test "should ignore mentions of profiles without visibility" do
    # Alice creates a private post (shared with no relations/audiences, or some custom ones Bob isn't in)
    # Let's say we share with Alice's custom relation, but Bob is not tied to it.
    custom_relation = @alice.relations.create!(name: "Secrets", type: "Relation::Custom")

    post = Post.new
    post.build_activity_object(
      description: "Private secret @[Bob](bob)",
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    post.save!

    activity = Activity.create!(
      verb: :post,
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    activity.activity_objects << post.activity_object

    perform_enqueued_jobs do
      CreateActivityAudiencesJob.perform_later(activity.id, [custom_relation.id])
    end

    # Bob does NOT have visibility of this activity
    assert_not activity.visible_to?(@bob)
    
    # Mention should not be created
    assert_empty post.activity_object.mentions
    assert_empty @bob.notifications.all
  end

  test "should not create mentions when the mentions feature is disabled" do
    Flipper.disable(:mentions)

    post = Post.new
    post.build_activity_object(
      description: "Hey @[Bob](bob), check this out!",
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    post.save!

    MentionManager.new(post.activity_object).call(post.activity_object.description)

    assert_empty post.activity_object.mentions
  end

  test "should sync mentions on update" do
    # 1. Create a comment mentioning Bob
    comment = Comment.new
    comment.build_activity_object(
      description: "Initial comment mentioning @[Bob](bob)",
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    comment.save!

    comment_activity = Activity.create!(
      verb: :post,
      author: @alice,
      user_author: @user_alice,
      owner: @alice
    )
    comment_activity.activity_object_activities.create!(
      activity_object: comment.activity_object,
      object_type: "Comment"
    )

    perform_enqueued_jobs do
      CreateActivityAudiencesJob.perform_later(comment_activity.id, nil)
    end

    assert_equal 1, comment.activity_object.mentions.count
    assert_equal @bob, comment.activity_object.mentioned_actors.first

    # 2. Update comment removing Bob and mentioning no one
    comment.update!(description: "Updated comment without mention")
    MentionManager.new(comment.activity_object).call(comment.text)

    # Bob's mention should be deleted
    assert_empty comment.activity_object.mentions
  end
end
