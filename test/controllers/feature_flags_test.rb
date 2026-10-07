require "test_helper"

# Covers the server-side enforcement of Flipper feature flags: when a feature is disabled its
# actions are blocked (HTML redirects to the fallback, other formats get a 404) and its UI entry
# points are hidden.
class FeatureFlagsTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @user.update!(current_profile: @actor)
    sign_in @user
  end

  test "feed redirects to profiles when social_feed is disabled" do
    Flipper.disable(:social_feed)

    get activities_path

    assert_redirected_to profiles_path
  end

  test "feed is reachable when social_feed is enabled" do
    get activities_path

    assert_response :success
  end

  test "authenticated root renders the profiles directory without a gated alert" do
    Flipper.disable(:social_feed)

    get root_path

    assert_response :success
    assert_no_match(/This feature is not available yet/, response.body)
  end

  test "contacts index is gated" do
    Flipper.disable(:contacts)

    get contacts_path

    assert_redirected_to root_path
  end

  test "groups index is gated" do
    Flipper.disable(:groups)

    get groups_path

    assert_redirected_to root_path
  end

  test "suggestions index is gated" do
    Flipper.disable(:suggestions)

    get suggestions_path

    assert_redirected_to root_path
  end

  test "notifications index is gated" do
    Flipper.disable(:notifications)

    get notifications_path

    assert_redirected_to root_path
  end

  test "like creation is gated" do
    Flipper.disable(:likes)

    assert_no_difference("Activity.count") do
      post activity_likes_path(1)
    end

    assert_redirected_to root_path
  end

  test "gated actions answer 404 for non-HTML formats" do
    Flipper.disable(:likes)

    assert_no_difference("Activity.count") do
      post activity_likes_path(1), as: :json
    end

    assert_response :not_found
  end

  test "comment creation is gated" do
    Flipper.disable(:comments)

    assert_no_difference("Activity.count") do
      post activity_comments_path(1), params: { comment: { text: "hi" } }
    end

    assert_redirected_to root_path
  end

  test "follow actions are gated" do
    Flipper.disable(:follow_objects)

    assert_no_difference("Activity.count") do
      post activity_activity_actions_path(1)
    end

    assert_redirected_to root_path
  end

  test "disabled social links are hidden from the layout" do
    [ :social_feed, :contacts, :groups, :notifications ].each { |feature| Flipper.disable(feature) }

    get profiles_path

    assert_response :success
    assert_no_match(/href="#{contacts_path}"/, response.body)
    assert_no_match(/href="#{groups_path}"/, response.body)
    assert_no_match(/href="#{activities_path}"/, response.body)
    assert_no_match(/href="#{notifications_path}"/, response.body)
  end

  test "profile feed and social counters are hidden when flags are disabled" do
    post = Post.new
    post.build_activity_object(
      title: "VisiblePostTitle",
      description: "Visible",
      author: @actor,
      user_author: @user,
      owner: @actor
    )
    post.save!
    Activity.create!(
      verb: :post,
      author: @actor,
      owner: @actor,
      user_author: @user,
      activity_objects: [ post.activity_object ],
      relation_ids: [ Relation::Public.instance.id ]
    )

    get profile_path(@actor)
    assert_match(/VisiblePostTitle/, response.body)

    Flipper.disable(:social_feed)
    Flipper.disable(:contacts)

    get profile_path(@actor)

    assert_response :success
    assert_no_match(/VisiblePostTitle/, response.body)
    assert_no_match(/connections/, response.body)
  end
end
