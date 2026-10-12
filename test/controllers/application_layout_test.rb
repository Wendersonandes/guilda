require "test_helper"

class ApplicationLayoutTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @alice_actor = create_profile_for(@alice, name: "Alice")
  end

  test "guest sees the sidebar frame, public navigation and sign-up call to action" do
    get groups_path

    assert_response :success
    assert_select "div.grid.grid-cols-12"
    assert_match I18n.t("shared.left_sidebar.guest_blurb"), response.body
    assert_match I18n.t("shared.right_sidebar.guest_title"), response.body
  end

  test "profiles index stays full width without the sidebar" do
    get profiles_path

    assert_response :success
    assert_select "div.grid.grid-cols-12", count: 0
    assert_no_match I18n.t("shared.left_sidebar.guest_blurb"), response.body
    assert_no_match I18n.t("shared.right_sidebar.guest_title"), response.body
  end

  test "about page stays full width without the sidebar" do
    get about_path

    assert_response :success
    assert_select "div.grid.grid-cols-12", count: 0
    assert_no_match I18n.t("shared.left_sidebar.guest_blurb"), response.body
    assert_no_match I18n.t("shared.right_sidebar.guest_title"), response.body
  end

  test "signed-in pages render the sidebar frame with the member navigation" do
    sign_in @alice

    get activities_path

    assert_response :success
    assert_select "div.grid.grid-cols-12"
    assert_match I18n.t("shared.left_sidebar.connections"), response.body
    assert_no_match I18n.t("shared.left_sidebar.guest_blurb"), response.body
    assert_no_match I18n.t("shared.right_sidebar.guest_title"), response.body
  end
end
