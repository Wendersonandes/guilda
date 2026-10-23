require "test_helper"

class ActorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @alice_actor.actorable.update!(mobile: "11999999999")
    @bob = users(:bob)
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @bob_actor.actorable.update!(mobile: "11999999999")
  end

  test "contact card invites to contact another professional" do
    get profile_path(@bob_actor)

    assert_response :success
    assert_match I18n.t("shared.contact_card.title"), response.body
    assert_no_match I18n.t("shared.contact_card.own_title"), response.body
  end

  test "whatsapp link prefills the guest message with the professional's name" do
    get profile_path(@bob_actor)

    assert_match %r{wa\.me/5511999999999\?text=Ol%C3%A1%2C%20Bob}, response.body
  end

  test "guest sees the sign-up call to action in the sidebar" do
    get profile_path(@bob_actor)

    assert_match I18n.t("shared.right_sidebar.guest_title"), response.body
  end

  test "contact card shows the owner's contact info on their own profile" do
    sign_in @alice

    get profile_path(@alice_actor)

    assert_response :success
    assert_match I18n.t("shared.contact_card.own_title"), response.body
    assert_no_match I18n.t("shared.contact_card.title"), response.body
  end

  test "whatsapp link prefills the signed-in sender's message" do
    sign_in @alice

    get profile_path(@bob_actor)

    assert_match %r{\?text=Ol%C3%A1%2C%20Bob%21%20Sou%20Alice}, response.body
  end

  test "signed-in visitor does not see the sign-up call to action" do
    sign_in @alice

    get profile_path(@bob_actor)

    assert_no_match I18n.t("shared.right_sidebar.guest_title"), response.body
  end

  test "profile owner sees edit profile action and global new project in nav" do
    sign_in @alice

    get profile_path(@alice_actor)

    assert_response :success
    assert_match I18n.t("actors.show.edit_profile"), response.body
    assert_match I18n.t("shared.nav.new_project"), response.body
    assert_match I18n.t("actors.show.tab_portfolio"), response.body
    assert_match I18n.t("actors.show.tab_activity"), response.body
  end

  test "visitor sees connection button instead of owner edit profile" do
    sign_in @alice

    get profile_path(@bob_actor)

    assert_response :success
    assert_no_match I18n.t("actors.show.edit_profile"), response.body
    assert_match I18n.t("shared.connection_button.connect"), response.body
  end

  test "index json returns actor search results without unused eager loading" do
    sign_in @alice
    get actors_path(format: :json, q: "Bob")
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json.size
    assert_equal @bob_actor.name, json.first["name"]
    assert_equal @bob_actor.slug, json.first["slug"]
  end

  test "index json returns highest priority site role when requested" do
    sign_in @alice
    site_actor = Site.instance.actor
    GroupMembershipService.new(site_actor, @bob_actor).add(role: "member")
    GroupMembershipService.new(site_actor, @bob_actor).add_role("professional")

    get actors_path(format: :json, q: "Bob", include_site_roles: "true")
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json.size
    assert_equal "professional", json.first["role"]
    assert_equal [ "professional", "member" ], json.first["roles"]
  end
end
