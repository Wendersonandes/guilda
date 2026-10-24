require "test_helper"

class ActorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob = users(:bob)
    @bob_actor = create_profile_for(@bob, name: "Bob")
  end

  test "show redirects profile actor to canonical profile path" do
    get actor_path(@bob_actor)

    assert_redirected_to profile_path(@bob_actor)
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
