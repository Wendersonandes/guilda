require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @bob = users(:bob)
    @bob_actor = create_profile_for(@bob)

    @post = Post.new
    @post.build_activity_object(
      description: "My first post",
      author: @actor,
      user_author: @user,
      owner: @actor
    )
    @post.save!

    @activity = Activity.new(
      verb: :post,
      author: @actor,
      user_author: @user,
      owner: @actor
    )
    @activity.activity_objects << @post.activity_object
    @activity.save!
    @activity.audiences.create!(relation: Relation::Public.instance)

    perform_enqueued_jobs do
      @comment_activity = CommentCreation.new(
        author: @actor,
        user_author: @user,
        parent_activity: @activity,
        text: "Flagged comment!"
      ).call
    end
    @comment = @comment_activity.direct_object.objectable

    sign_in @bob
  end

  test "GET flag_form renders inline flag form" do
    get flag_form_comment_path(@comment.short_id), as: :turbo_stream
    assert_response :success
    assert_match "Motivo", response.body
    assert_match "Observação", response.body
  end

  test "POST flag creates Flag object with reason and note metadata" do
    assert_difference -> { Flag.count } => 1 do
      post flag_comment_path(@comment.short_id), params: { reason: "spam", note: "This is spam advertisement" }, as: :turbo_stream
    end

    assert_response :success
    flag = Flag.last
    assert_equal "spam", flag.reason
    assert_equal "This is spam advertisement", flag.note

    flag_activity = Activity.find_by(verb: :flag, author_id: @bob_actor.id, parent_id: @comment_activity.id)
    assert_not_nil flag_activity
    assert_equal flag.activity_object, flag_activity.activity_objects.first
  end

  test "POST unflag destroys Flag object and Activity" do
    post flag_comment_path(@comment.short_id), params: { reason: "harassment", note: "" }, as: :turbo_stream
    assert_equal 1, Flag.count

    assert_difference -> { Flag.count } => -1 do
      post unflag_comment_path(@comment.short_id), as: :turbo_stream
    end
    assert_response :success

    flag_activity = Activity.find_by(verb: :flag, author_id: @bob_actor.id, parent_id: @comment_activity.id)
    assert_nil flag_activity
  end

  test "GET show redirects to parent activity with anchor" do
    get comment_permalink_path(@comment.short_id)
    assert_redirected_to activity_path(@activity, anchor: "activity_#{@comment_activity.id}")
  end
end
