require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations

    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor   = create_profile_for(@bob, name: "Bob")

    @alice.update!(current_profile: @alice_actor)
    @bob.update!(current_profile: @bob_actor)

    # Alice is promoted to site admin
    @site_actor = Site.instance.actor
    GroupMembershipService.new(@site_actor, @alice_actor).add(role: "admin")
  end

  ADMIN_PATHS = [
    [ "/admin/roles",       "Roles" ],
    [ "/admin/ties",        "Ties" ],
    [ "/admin/audiences",   "Audiences" ],
    [ "/admin/permissions", "Permissions" ]
  ]

  test "site admin can access all admin pages" do
    sign_in @alice
    ADMIN_PATHS.each do |path, name|
      get path
      assert_response :success, "#{name} (#{path}) should be accessible by site admin"
    end
  end

  test "non-admin cannot access admin pages" do
    sign_in @bob
    ADMIN_PATHS.each do |path, name|
      get path
      assert_redirected_to root_path, "#{name} (#{path}) should deny non-admin"
      assert_equal "You are not authorized to perform this action.", flash[:alert]
    end
  end

  test "site admin can view admin index pages and see content" do
    sign_in @alice
    get admin_roles_path
    assert_select "h1", text: "Platform Roles"

    get admin_ties_path
    assert_select "h1", text: "Ties"

    get admin_audiences_path
    assert_select "h1", text: "Audiences"

    get admin_permissions_path
    assert_select "h1", text: "Permissions"
  end

  test "non-admin visiting admin roles via direct path is blocked" do
    sign_in @bob
    get admin_roles_path
    assert_redirected_to root_path
  end

  test "signed out user cannot access admin pages" do
    ADMIN_PATHS.each do |path, name|
      get path
      assert_redirected_to new_user_session_path, "#{name} (#{path}) should redirect to login"
    end
  end

  test "site admin can create and update roles" do
    sign_in @alice

    post admin_roles_path, params: { actor_id: @bob_actor.slug, to_role: "editor" }
    assert_response :redirect
    assert_equal "Role assigned.", flash[:notice]

    follow_redirect!
    assert_response :success

    patch admin_role_path(@bob_actor), params: { from_role: "editor", to_role: "member" }
    assert_response :redirect
    assert_equal "Role updated.", flash[:notice]
  end

  test "non-admin cannot create roles" do
    sign_in @bob

    post admin_roles_path, params: { actor_id: @bob_actor.slug, to_role: "editor" }
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  test "site admin can view tie details" do
    sign_in @alice
    tie = Tie.first
    get "/admin/ties/#{tie.id}"
    assert_response :success
  end

  test "non-admin cannot view tie details" do
    sign_in @bob
    tie = Tie.first
    get "/admin/ties/#{tie.id}"
    assert_redirected_to root_path
  end

  test "site admin can access the feature flags dashboard" do
    sign_in @alice

    get "/admin/flipper"
    follow_redirect!

    assert_response :success
  end

  test "non-admin cannot access the feature flags dashboard" do
    sign_in @bob

    get "/admin/flipper"

    assert_response :not_found
  end

  test "signed out user cannot access the feature flags dashboard" do
    get "/admin/flipper"

    assert_response :not_found
  end
end
