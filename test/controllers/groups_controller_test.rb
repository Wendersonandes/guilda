require "test_helper"

class GroupsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @user.update!(current_profile: @actor)
    GroupMembershipService.new(Site.instance.actor, @actor).add(role: "admin")
    sign_in @user
    @group = create_group_with_admin(@actor)
  end

  test "should get index" do
    get groups_path
    assert_response :success
  end

  test "should get index without layout for turbo frame request" do
    get groups_path, headers: { "Turbo-Frame" => "groups_page_2" }
    assert_response :success
    assert_no_match /<html/i, response.body
  end

  test "should render groups infinite scroll frame structure" do
    # Create multiple groups to get pagination
    # Default pagy page size for groups listing is typically 20, let's create 25 groups
    25.times do |i|
      group = Group.new
      group.build_actor(name: "Test Group #{i}")
      GroupCreation.new(@actor, group).call
    end

    get groups_path(page: 2), headers: { "Turbo-Frame" => "groups_page_2" }
    assert_response :success
    assert_select "turbo-frame#groups_page_2"
    # Since page size is 2, page 2 is not the last page, so there should be a next page frame
    assert_select "turbo-frame#groups_page_3", count: 1
  end

  test "should get show" do
    get group_path(@group)
    assert_response :success
  end

  test "should get show without layout for turbo frame request" do
    get group_path(@group), headers: { "Turbo-Frame" => "group_activities_page_2" }
    assert_response :success
    assert_no_match /<html/i, response.body
  end

  test "should render group activities infinite scroll frame structure" do
    # Create multiple posts in the group to get pagination
    perform_enqueued_jobs do
      25.times do |i|
        create_post(author: @actor, owner: @group.actor, title: "Post #{i}")
      end
    end

    get group_path(@group, page: 2), headers: { "Turbo-Frame" => "group_activities_page_2" }
    assert_response :success
    assert_select "turbo-frame#group_activities_page_2"
    # Since page size is 2, page 2 is not the last page, so there should be a next page frame
    assert_select "turbo-frame#group_activities_page_3", count: 1
  end

  test "new group form uses direct upload for the image fields" do
    get new_group_path

    assert_response :success
    assert_select "input[type=file][data-direct-upload-url]", count: 2
  end

  test "edit group form uses direct upload for the image fields" do
    get edit_group_path(@group)

    assert_response :success
    assert_select "input[type=file][data-direct-upload-url]", count: 2
  end

  test "new group form requires site admin" do
    get new_group_path
    assert_response :success

    bob = users(:bob)
    bob_actor = create_profile_for(bob)
    bob.update!(current_profile: bob_actor)
    sign_in bob

    get new_group_path
    assert_redirected_to root_path
    assert_equal I18n.t("flash.not_authorized"), flash[:alert]
  end

  test "create group requires site admin" do
    assert_difference -> { Group.count }, 1 do
      post groups_path, params: {
        group: {
          privacy: "public_group",
          actor_attributes: { name: "Admin Group", description: "Created by admin" }
        }
      }
    end
    assert_redirected_to group_path(Group.last)

    bob = users(:bob)
    bob_actor = create_profile_for(bob)
    bob.update!(current_profile: bob_actor)
    sign_in bob

    assert_no_difference -> { Group.count } do
      post groups_path, params: {
        group: {
          privacy: "public_group",
          actor_attributes: { name: "Bob Group", description: "Denied" }
        }
      }
    end
    assert_redirected_to root_path
    assert_equal I18n.t("flash.not_authorized"), flash[:alert]
  end

  test "index shows new group button only for site admin" do
    get groups_path
    assert_response :success
    assert_select "a[href='#{new_group_path}']"

    bob = users(:bob)
    bob_actor = create_profile_for(bob)
    bob.update!(current_profile: bob_actor)
    sign_in bob

    get groups_path
    assert_response :success
    assert_select "a[href='#{new_group_path}']", count: 0
  end

  private

  def create_group_with_admin(admin_actor)
    group = Group.new
    group.build_actor(name: "Test Group Controller")
    GroupCreation.new(admin_actor, group).call
  end

  def create_post(author:, owner:, title:, body: "Default body content")
    activity = Activity.new(verb: :post, author: author, owner: owner)
    activity.user_author = author.subject.is_a?(Profile) ? author.subject.user : nil
    ActivityCreation.new(
      activity,
      text: { title: title, body: body },
      relation_ids: owner.activity_relation_ids
    ).call
  end
end
