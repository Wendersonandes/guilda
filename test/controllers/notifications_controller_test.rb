require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @user.update!(current_profile: @actor)

    @bob_user = users(:bob)
    @bob_actor = create_profile_for(@bob_user)
    @bob_user.update!(current_profile: @bob_actor)

    sign_in @user

    # Create a post as Bob to trigger a notification
    @post = Post.new
    @post.build_activity_object(
      title: "",
      description: "Bob's status update",
      author: @bob_actor,
      user_author: @bob_user,
      owner: @bob_actor
    )
    @post.save!
    @post_activity_object = @post.activity_object

    # Establish Alice following Bob
    ActivityAction.create!(actor: @actor, activity_object: @bob_actor.activity_object, follow: true)

    # Bob publishes a post, which triggers a notification to Alice (@actor)
    @post_activity = Activity.new(
      verb: :post,
      author: @bob_actor,
      owner: @bob_actor,
      user_author: @bob_user
    )
    @post_activity = ActivityCreation.new(@post_activity, text: { body: "Alice should get this" }).call
    
    @notification = @actor.notifications.last
  end

  test "should redirect index when not signed in" do
    sign_out @user
    get notifications_path
    assert_redirected_to new_user_session_path
  end

  test "should get index" do
    get notifications_path
    assert_response :success
    assert_select "h1", "Notifications"
    assert_includes response.body, "bob publicou um novo post."
  end

  test "should mark notification as read" do
    assert @notification.unread?
    patch notification_path(@notification)
    assert_redirected_to notifications_path
    assert @notification.reload.read?
  end

  test "should mark notification as read via turbo stream" do
    assert @notification.unread?
    patch notification_path(@notification), as: :turbo_stream
    assert_response :success
    assert @notification.reload.read?
    assert_match /turbo-stream action="replace" target="post_published_notifier_notification_#{@notification.id}"/, response.body
    assert_match /turbo-stream action="replace" target="nav_notification_badge"/, response.body
  end

  test "should mark all notifications as read" do
    # Create another notification by Bob
    activity2 = Activity.new(
      verb: :post,
      author: @bob_actor,
      owner: @bob_actor,
      user_author: @bob_user
    )
    ActivityCreation.new(activity2, text: { body: "Alice should get this too" }).call

    assert_equal 2, @actor.notifications.unread.count

    post mark_all_as_read_notifications_path
    assert_redirected_to notifications_path
    assert_equal 0, @actor.notifications.unread.count
  end

  test "should mark all notifications as read via turbo stream" do
    post mark_all_as_read_notifications_path, as: :turbo_stream
    assert_response :success
    assert_equal 0, @actor.notifications.unread.count
    assert_match /turbo-stream action="replace" target="notifications_list_container"/, response.body
    assert_match /turbo-stream action="replace" target="nav_notification_badge"/, response.body
  end

  test "should not mark others notification as read" do
    # Try to mark Alice's notification as read as Bob
    sign_out @user
    sign_in @bob_user

    patch notification_path(@notification)
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
    assert @notification.reload.unread?
  end

  test "should broadcast badge update on notification creation" do
    stream_name = Turbo::StreamsChannel.send(:stream_name_from, [@actor, :notifications])
    assert_broadcasts(stream_name, 1) do
      perform_enqueued_jobs do
        activity = Activity.new(
          verb: :post,
          author: @bob_actor,
          owner: @bob_actor,
          user_author: @bob_user
        )
        ActivityCreation.new(activity, text: { body: "Broadcast check" }).call
      end
    end
  end

  test "should broadcast badge update on notification update" do
    stream_name = Turbo::StreamsChannel.send(:stream_name_from, [@actor, :notifications])
    assert_broadcasts(stream_name, 1) do
      @notification.mark_as_read
    end
  end

  test "should filter notifications by date" do
    # Create an old notification
    old_activity = Activity.new(
      verb: :post,
      author: @bob_actor,
      owner: @bob_actor,
      user_author: @bob_user
    )
    perform_enqueued_jobs do
      old_activity = ActivityCreation.new(old_activity, text: { body: "Old post" }).call
    end
    old_notification = @actor.notifications.last
    old_notification.update!(created_at: 10.days.ago)

    # Date filter: hoje (should only show today's, which is @notification, not old_notification)
    get notifications_path(date: "hoje")
    assert_response :success
    assert_includes response.body, "post_published_notifier_notification_#{@notification.id}"
    assert_not_includes response.body, "post_published_notifier_notification_#{old_notification.id}"

    # Date filter: 15_days (should show both)
    get notifications_path(date: "15_days")
    assert_response :success
    assert_includes response.body, "post_published_notifier_notification_#{@notification.id}"
    assert_includes response.body, "post_published_notifier_notification_#{old_notification.id}"
  end

  test "should filter notifications by author" do
    # Create another user and follow activity / post to trigger a notification from Charlie
    charlie_user = User.create!(email: "charlie@example.com", password: "password123", profile_name: "Charlie Brown")
    charlie_actor = charlie_user.current_profile

    ActivityAction.create!(actor: @actor, activity_object: charlie_actor.activity_object, follow: true)

    activity_charlie = Activity.new(
      verb: :post,
      author: charlie_actor,
      owner: charlie_actor,
      user_author: charlie_user
    )
    perform_enqueued_jobs do
      ActivityCreation.new(activity_charlie, text: { body: "Charlie post" }).call
    end

    charlie_notification = @actor.notifications.last

    # Filter by Bob
    get notifications_path(author_id: @bob_actor.id)
    assert_response :success
    assert_includes response.body, "post_published_notifier_notification_#{@notification.id}"
    assert_not_includes response.body, "post_published_notifier_notification_#{charlie_notification.id}"

    # Filter by Charlie
    get notifications_path(author_id: charlie_actor.id)
    assert_response :success
    assert_includes response.body, "post_published_notifier_notification_#{charlie_notification.id}"
    assert_not_includes response.body, "post_published_notifier_notification_#{@notification.id}"
  end

  test "should filter notifications by type" do
    # Bob follows Alice (@actor)
    perform_enqueued_jobs do
      follow_activity = Activity.create!(
        verb: :follow,
        author: @bob_actor,
        owner: @actor
      )
      follow_activity.send(:notify_owner_of_new_follower)
    end

    follow_notification = @actor.notifications.where(type: "NewFollowerNotifier::Notification").last
    assert_not_nil follow_notification

    # Bob comments on Alice's post
    alice_post = Post.new
    alice_post.build_activity_object(
      description: "Alice's post",
      author: @actor,
      user_author: @user,
      owner: @actor
    )
    alice_post.save!

    post_activity = Activity.new(
      verb: :post,
      author: @actor,
      user_author: @user,
      owner: @actor
    )
    post_activity.activity_objects << alice_post.activity_object
    post_activity.save!
    post_activity.audiences.create!(relation: Relation::Public.instance)

    comment_activity = nil
    perform_enqueued_jobs do
      comment_activity = CommentCreation.new(
        author: @bob_actor,
        user_author: @bob,
        parent_activity: post_activity,
        text: "Bob commented on Alice's post!"
      ).call
    end

    comment_notification = @actor.notifications.where(type: "ObjectCommentedNotifier::Notification").last
    assert_not_nil comment_notification

    # Filter by new_follower
    get notifications_path(notification_type: "new_follower")
    assert_response :success
    assert_includes response.body, "new_follower_notifier_notification_#{follow_notification.id}"
    assert_not_includes response.body, "post_published_notifier_notification_#{@notification.id}"
    assert_not_includes response.body, "object_commented_notifier_notification_#{comment_notification.id}"

    # Filter by like (none exist yet)
    get notifications_path(notification_type: "like")
    assert_response :success
    assert_not_includes response.body, "new_follower_notifier_notification_#{follow_notification.id}"
    assert_not_includes response.body, "post_published_notifier_notification_#{@notification.id}"
    assert_not_includes response.body, "object_commented_notifier_notification_#{comment_notification.id}"

    # Filter by comment
    get notifications_path(notification_type: "comment")
    assert_response :success
    assert_includes response.body, "object_commented_notifier_notification_#{comment_notification.id}"
    assert_not_includes response.body, "new_follower_notifier_notification_#{follow_notification.id}"
    assert_not_includes response.body, "post_published_notifier_notification_#{@notification.id}"
  end
end
