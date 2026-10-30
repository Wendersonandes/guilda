require "test_helper"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  test "signs in existing user and redirects" do
    bob = users(:bob)
    create_profile_for(bob, name: "Bob")

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "123456",
      info: {
        email: bob.email,
        name: "Bob"
      }
    )

    post user_google_oauth2_omniauth_callback_path
    assert_redirected_to root_path
    assert_equal I18n.t("devise.omniauth_callbacks.success", kind: "Google"), flash[:notice]
  end

  test "creates and signs in new user then redirects to next step" do
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "987654",
      info: {
        email: "newgoogleuser@example.com",
        name: "New Google User"
      }
    )

    assert_difference "User.count", 1 do
      post user_google_oauth2_omniauth_callback_path
    end

    new_user = User.find_by(email: "newgoogleuser@example.com")
    assert_not_nil new_user
    assert_equal "google_oauth2", new_user.provider
    assert_equal "987654", new_user.uid
    assert_response :redirect
  end

  test "redirects to root with alert on failure" do
    get "/users/auth/failure?message=access_denied&strategy=google_oauth2"
    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end
end
