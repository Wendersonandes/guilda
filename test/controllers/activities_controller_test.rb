require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)

    @user.update!(current_profile: @actor)
    sign_in @user
  end

  test "should redirect index when not signed in" do
    sign_out @user
    get activities_path
    assert_redirected_to new_user_session_path
  end

  test "should get index when signed in" do
    get activities_path
    assert_response :success
  end

  test "should redirect new when not signed in" do
    sign_out @user
    get new_activity_path
    assert_redirected_to new_user_session_path
  end

  test "should get new when signed in" do
    get new_activity_path
    assert_response :success
  end

  test "should create post activity" do
    post activities_path, params: {
      activity: {
        verb: :post,
        text: { title: "Hello world", body: "My first post" }
      }
    }
    assert_redirected_to activity_path(Activity.last)
    assert_equal "Publicação criada.", flash[:notice]
  end

  test "should destroy own activity" do
    activity = Activity.create!(verb: :post, author: @actor, owner: @actor,
                                user_author: @user)
    activity.audiences.create!(relation: Relation::Public.instance)

    assert_difference("Activity.count", -1) do
      perform_enqueued_jobs do
        delete activity_path(activity)
      end
    end
    assert_redirected_to activities_path
  end

  test "should not destroy others activity" do
    bob = create_profile_for(users(:bob))
    activity = Activity.create!(verb: :post, author: bob, owner: bob,
                                user_author: users(:bob))
    activity.audiences.create!(relation: Relation::Public.instance)

    assert_no_difference("Activity.count") do
      perform_enqueued_jobs do
        delete activity_path(activity)
      end
    end
    assert_redirected_to root_path
  end

  test "should not destroy activity as group owner if not the author" do
    # Create group with current user (Alice) as admin
    group = Group.new(privacy: :public_group)
    group.build_actor(name: "Alice Owner Group")
    GroupCreation.new(@actor, group).call
    group_actor = group.actor

    # Sign in as Bob (who is a member and author)
    sign_out @user
    bob = users(:bob)
    bob_actor = create_profile_for(bob, name: "Bob Member")
    bob.update!(current_profile: bob_actor)
    sign_in bob

    # Bob creates a post in Alice's group
    activity = Activity.create!(
      verb: :post,
      author: bob_actor,
      owner: group_actor,
      user_author: bob
    )
    activity.audiences.create!(relation: Relation::Public.instance)

    # Sign in back as Alice
    sign_out bob
    @user.update!(current_profile: @actor)
    sign_in @user

    # Alice (group owner) tries to delete Bob's post in her group
    assert_no_difference("Activity.count") do
      perform_enqueued_jobs do
        delete activity_path(activity)
      end
    end
    assert_redirected_to root_path
    assert_equal "Você não tem permissão para executar esta ação.", flash[:alert]
  end

  test "member should create post in group" do
    # Create group with current user as admin/member
    group = Group.new(privacy: :public_group)
    group.build_actor(name: "Post Test Group")
    GroupCreation.new(@actor, group).call
    group_actor = group.actor

    post activities_path, params: {
      activity: {
        verb: :post,
        owner_id: group_actor.id,
        text: { title: "Group post", body: "Posted in the group" }
      }
    }
    assert_redirected_to activity_path(Activity.last)
    assert_equal "Publicação criada.", flash[:notice]
    assert_equal group_actor.id, Activity.last.owner_id
    assert_not Activity.last.public?
  end

  test "non-member should not create post in group" do
    # Create group owned by Alice
    alice_actor = create_profile_for(users(:alice), name: "Alice Group Owner")
    group = Group.new(privacy: :public_group)
    group.build_actor(name: "Exclusive Group")
    GroupCreation.new(alice_actor, group).call
    group_actor = group.actor

    # Sign in as Bob (not a member)
    sign_out @user
    bob = users(:bob)
    bob_actor = create_profile_for(bob, name: "Bob NonMember")
    bob.update!(current_profile: bob_actor)
    sign_in bob

    post activities_path, params: {
      activity: {
        verb: :post,
        owner_id: group_actor.id,
        text: { title: "Attempted post", body: "Should not work" }
      }
    }
    assert_redirected_to root_path
    assert_equal "Você não tem permissão para executar esta ação.", flash[:alert]
  end

  test "member creates post in private group with restricted audience" do
    # Create private group with current user as admin/member
    group = Group.new(privacy: :private_group)
    group.build_actor(name: "Private Post Group")
    GroupCreation.new(@actor, group).call
    group_actor = group.actor

    perform_enqueued_jobs do
      post activities_path, params: {
        activity: {
          verb: :post,
          owner_id: group_actor.id,
          text: { title: "Private post", body: "Visible only to members" }
        }
      }
    end
    assert_redirected_to activity_path(Activity.last)
    assert_equal "Publicação criada.", flash[:notice]
    assert_equal group_actor.id, Activity.last.owner_id
    assert_not Activity.last.public?
    # Audience should be the group's activity relations, not public
    audience_relation_ids = Activity.last.audiences.map(&:relation_id).sort
    assert_equal group_actor.activity_relation_ids.sort, audience_relation_ids
  end

  test "non-member blocked from posting in private group" do
    # Create private group owned by Alice
    alice_actor = create_profile_for(users(:alice), name: "Alice Private Owner")
    group = Group.new(privacy: :private_group)
    group.build_actor(name: "Private Exclusive")
    GroupCreation.new(alice_actor, group).call
    group_actor = group.actor

    # Sign in as Bob (not a member)
    sign_out @user
    bob = users(:bob)
    bob_actor = create_profile_for(bob, name: "Bob Private NonMember")
    bob.update!(current_profile: bob_actor)
    sign_in bob

    post activities_path, params: {
      activity: {
        verb: :post,
        owner_id: group_actor.id,
        text: { title: "Attempted private post", body: "Should not work" }
      }
    }
    assert_redirected_to root_path
    assert_equal "Você não tem permissão para executar esta ação.", flash[:alert]
  end

  test "should create post activity via turbo stream" do
    assert_difference("Activity.count", 1) do
      post activities_path, params: {
        activity: {
          verb: :post,
          text: { title: "Turbo Title", body: "Turbo Body" }
        }
      }, as: :turbo_stream
    end
    assert_response :success
    assert_match /turbo-stream action="prepend" target="feed"/, response.body
    assert_match /turbo-stream action="replace" target="activity_form_container"/, response.body
    assert_match /Turbo Title/, response.body
    assert_match /Turbo Body/, response.body
  end

  test "should return error via turbo stream on invalid post" do
    assert_no_difference("Activity.count") do
      post activities_path, params: {
        activity: {
          verb: :post,
          text: { title: "", body: "" }
        }
      }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_match /turbo-stream action="replace" target="activity_form_container"/, response.body
    assert_match /A validação falhou: Text não pode ficar em branco/, response.body
  end

  test "should get index without layout for turbo frame request" do
    get activities_path, headers: { "Turbo-Frame" => "activities_page_2" }
    assert_response :success
    assert_no_match /<html/i, response.body
  end

  test "should render turbo frame wrapper for page 2 turbo frame request" do
    # Create enough activities to ensure pagination is active (at least 2 pages)
    # Default pagy page size is typically 20 or similar, let's create 25 activities
    activities = 25.times.map do |i|
      Activity.create!(verb: :post, author: @actor, owner: @actor, user_author: @user)
    end
    activities.each { |a| a.audiences.create!(relation: Relation::Public.instance) }

    get activities_path(page: 2), headers: { "Turbo-Frame" => "activities_page_2" }
    assert_response :success
    assert_select "turbo-frame#activities_page_2"
    # Since page size is 2, page 2 is not the last page, so there should be a next page frame
    assert_select "turbo-frame#activities_page_3", count: 1
  end

  test "GET flag_form renders post flag form" do
    activity = Activity.create!(verb: :post, author: @actor, owner: @actor, user_author: @user)
    activity.audiences.create!(relation: Relation::Public.instance)

    bob = users(:bob)
    bob_actor = create_profile_for(bob)
    sign_in bob

    get flag_form_activity_path(activity), as: :turbo_stream
    assert_response :success
    assert_match "Motivo", response.body
  end

  test "POST flag creates Flag object for post" do
    activity = Activity.create!(verb: :post, author: @actor, owner: @actor, user_author: @user)
    activity.audiences.create!(relation: Relation::Public.instance)

    bob = users(:bob)
    bob_actor = create_profile_for(bob)
    sign_in bob

    assert_difference -> { Flag.count } => 1 do
      post flag_activity_path(activity), params: { reason: "spam", note: "Spam post" }, as: :turbo_stream
    end
    assert_response :success

    flag = Flag.last
    assert_equal "spam", flag.reason
    assert_equal "Spam post", flag.note
  end

  test "POST unflag destroys Flag object for post" do
    activity = Activity.create!(verb: :post, author: @actor, owner: @actor, user_author: @user)
    activity.audiences.create!(relation: Relation::Public.instance)

    bob = users(:bob)
    bob_actor = create_profile_for(bob)
    sign_in bob

    post flag_activity_path(activity), params: { reason: "offtopic" }, as: :turbo_stream
    assert_equal 1, Flag.count

    assert_difference -> { Flag.count } => -1 do
      post unflag_activity_path(activity), as: :turbo_stream
    end
    assert_response :success
  end
end
