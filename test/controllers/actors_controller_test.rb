require "test_helper"

class ActorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob = users(:bob)
    @bob_actor = create_profile_for(@bob, name: "Bob")
  end

  test "contact card invites to contact another professional" do
    get profile_path(@bob_actor)

    assert_response :success
    assert_match I18n.t("shared.contact_card.title"), response.body
    assert_no_match I18n.t("shared.contact_card.own_title"), response.body
  end

  test "contact card shows the owner's contact info on their own profile" do
    sign_in @alice

    get profile_path(@alice_actor)

    assert_response :success
    assert_match I18n.t("shared.contact_card.own_title"), response.body
    assert_no_match I18n.t("shared.contact_card.title"), response.body
  end
end
