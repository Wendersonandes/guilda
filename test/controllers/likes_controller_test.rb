require "test_helper"

class LikesControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @user.update!(current_profile: @actor)

    @bob_user = users(:bob)
    @bob_actor = create_profile_for(@bob_user)
    @bob_user.update!(current_profile: @bob_actor)

    sign_in @user

    # Create a post as Bob
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

    @post_activity = Activity.create!(
      verb: :post,
      author: @bob_actor,
      owner: @bob_actor,
      user_author: @bob_user,
      activity_objects: [ @post_activity_object ],
      relation_ids: [ Relation::Public.instance.id ]
    )
  end

  test "should redirect create when not signed in" do
    sign_out @user
    assert_no_difference("Activity.count") do
      post activity_likes_path(@post_activity)
    end
    assert_redirected_to new_user_session_path
  end

  test "should create like on activity" do
    assert_difference("Activity.count", 1) do
      post activity_likes_path(@post_activity)
    end
    assert_redirected_to activities_path
    
    like_activity = Activity.last
    assert_equal "like", like_activity.verb
    assert_equal @actor, like_activity.author
    assert_equal @post_activity, like_activity.parent
    assert_equal 1, @post_activity_object.reload.like_count
  end

  test "should create like via turbo stream" do
    assert_difference("Activity.count", 1) do
      post activity_likes_path(@post_activity), as: :turbo_stream
    end
    assert_response :success
    assert_match /turbo-stream action="replace" target="actions_activity_#{@post_activity.id}"/, response.body
  end

  test "should destroy like" do
    # First, Bob likes his own post
    like = Like.build(@bob_actor, @bob_user, @post_activity)
    like.save!
    like_activity = like.like

    # Log in as Bob
    sign_out @user
    sign_in @bob_user

    assert_difference("Activity.count", -1) do
      delete activity_like_path(@post_activity, like_activity)
    end
    assert_redirected_to activities_path
    assert_equal 0, @post_activity_object.reload.like_count
  end

  test "should destroy like via turbo stream" do
    like = Like.build(@actor, @user, @post_activity)
    like.save!
    like_activity = like.like

    assert_difference("Activity.count", -1) do
      delete activity_like_path(@post_activity, like_activity), as: :turbo_stream
    end
    assert_response :success
    assert_match /turbo-stream action="replace" target="actions_activity_#{@post_activity.id}"/, response.body
  end

  test "should not destroy others like" do
    # Bob likes the post
    like = Like.build(@bob_actor, @bob_user, @post_activity)
    like.save!
    like_activity = like.like

    # Logged in as Alice, try to delete Bob's like
    assert_no_difference("Activity.count") do
      delete activity_like_path(@post_activity, like_activity)
    end
    assert_redirected_to root_path
    assert_equal "Você não tem permissão para executar esta ação.", flash[:alert]
  end
end
