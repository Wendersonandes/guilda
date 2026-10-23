require "test_helper"

class Admin::RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @alice.update!(current_profile: @alice_actor)
    @bob.update!(current_profile: @bob_actor)
    @site_actor = Site.instance.actor
    GroupMembershipService.new(@site_actor, @alice_actor).add(role: "admin")
  end

  test "admin can see roles index" do
    sign_in @alice
    get admin_roles_path
    assert_response :success
    assert_select "h1", text: I18n.t("admin.roles.index.title")
    assert_select "div.grid.grid-cols-1.lg\\:grid-cols-12"
    assert_select "aside.hidden.lg\\:block.lg\\:col-span-4"
    assert_select "input#role_search_query[role='combobox']"
    assert_select "label[for='role_search_query']"
    assert_select "span", text: I18n.t("admin.roles.roles.admin.singular")
    assert_select "h2", text: /#{I18n.t("admin.roles.roles.admin.plural")}/
  end

  test "non-admin cannot see roles index" do
    sign_in @bob
    get admin_roles_path
    assert_response :redirect
  end

  test "admin can update a role" do
    sign_in @alice
    patch admin_role_path(@bob_actor), params: { from_role: "member", to_role: "editor" }
    assert_redirected_to admin_roles_path
    assert @site_actor.has_relation_with?(@bob_actor, "Editor")
  end

  test "non-admin cannot update a role" do
    sign_in @bob
    patch admin_role_path(@bob_actor), params: { from_role: "member", to_role: "editor" }
    assert_response :redirect
    assert_not @site_actor.has_relation_with?(@bob_actor, "Editor")
  end

  test "admin can assign a role to a user without one" do
    sign_in @alice
    post admin_roles_path, params: { actor_id: @bob_actor.slug, to_role: "moderator" }
    assert_redirected_to admin_roles_path
    assert @site_actor.has_relation_with?(@bob_actor, "Moderator")
  end

  test "assign adds role additively, allowing multiple roles" do
    sign_in @alice
    GroupMembershipService.new(@site_actor, @bob_actor).add(role: "member")
    bob_actor_reloaded = Actor.find(@bob_actor.id)

    post admin_roles_path, params: { actor_id: bob_actor_reloaded.slug, to_role: "editor" }
    site_reloaded = Site.instance.actor

    assert site_reloaded.has_relation_with?(bob_actor_reloaded, "Editor")
    assert site_reloaded.has_relation_with?(bob_actor_reloaded, "Member")
  end

  test "admin can remove a specific role from a user with multiple roles" do
    sign_in @alice
    GroupMembershipService.new(@site_actor, @bob_actor).add(role: "member")
    GroupMembershipService.new(@site_actor, @bob_actor).add_role("professional")

    delete admin_role_path(@bob_actor), params: { role: "professional" }
    assert_redirected_to admin_roles_path
    follow_redirect!
    assert_match I18n.t("flash.role_removed"), response.body

    site_reloaded = Site.instance.actor
    bob_reloaded = Actor.find(@bob_actor.id)
    assert site_reloaded.has_relation_with?(bob_reloaded, "Member")
    assert_not site_reloaded.has_relation_with?(bob_reloaded, "Professional")
  end

  test "admin index renders admin members as read-only" do
    sign_in @alice
    get admin_roles_path
    assert_response :success
    assert_select "span", text: I18n.t("admin.roles.index.managed_via_cli")
    assert_select "form[action='#{admin_role_path(@alice_actor)}']", 0
  end

  test "cannot assign admin role via post create" do
    sign_in @alice
    post admin_roles_path, params: { actor_id: @bob_actor.slug, to_role: "admin" }
    assert_redirected_to admin_roles_path
    follow_redirect!
    assert_match I18n.t("flash.admin_role_protected"), response.body
    assert_not @site_actor.has_relation_with?(@bob_actor, "Admin")
  end

  test "cannot change role to or from admin via patch update" do
    sign_in @alice
    patch admin_role_path(@bob_actor), params: { from_role: "member", to_role: "admin" }
    assert_redirected_to admin_roles_path
    follow_redirect!
    assert_match I18n.t("flash.admin_role_protected"), response.body
    assert_not @site_actor.has_relation_with?(@bob_actor, "Admin")

    patch admin_role_path(@alice_actor), params: { from_role: "admin", to_role: "editor" }
    assert_redirected_to admin_roles_path
    follow_redirect!
    assert_match I18n.t("flash.admin_role_protected"), response.body
    assert @site_actor.has_relation_with?(@alice_actor, "Admin")
  end

  test "cannot remove admin role via delete destroy" do
    sign_in @alice
    delete admin_role_path(@alice_actor), params: { role: "admin" }
    assert_redirected_to admin_roles_path
    follow_redirect!
    assert_match I18n.t("flash.admin_role_protected"), response.body
    assert @site_actor.has_relation_with?(@alice_actor, "Admin")
  end
end
