require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
  end

  test "renders tabs, plan switcher and Google signup button" do
    get new_user_registration_path
    assert_response :success
    assert_select "button[data-signup-intent-target='tabProfessional']"
    assert_select "button[data-signup-intent-target='tabContractor']"
    assert_select "button[data-plan-id='annual']"
    assert_select "button[data-plan-id='monthly']"
    assert_select "form[action=?]", user_google_oauth2_omniauth_authorize_path
    assert_select "button", text: /Cadastrar com o Google/
  end

  test "blocks direct email/password registration when password_authentication is disabled" do
    Flipper.disable(:password_authentication)

    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          profile_name: "Test User",
          email: "test_disabled@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to new_user_registration_path
    assert_equal "O cadastro com e-mail e senha está temporariamente indisponível. Utilize o cadastro rápido com o Google.", flash[:alert]
  end

  test "allows email/password registration when password_authentication is enabled" do
    Flipper.enable(:password_authentication)

    assert_difference "User.count", 1 do
      post user_registration_path, params: {
        user: {
          profile_name: "Test User",
          email: "test_enabled@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :redirect
  end
end
