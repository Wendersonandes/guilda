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

  test "plan=trial selects annual plan by default" do
    get new_user_registration_path(plan: :trial)
    assert_response :success
    assert_select "button[data-plan-id='annual'][aria-checked='true']"
    assert_select "button[data-plan-id='monthly'][aria-checked='false']"
    assert_equal "annual", session[:selected_plan]
  end

  test "plan=monthly selects monthly plan" do
    get new_user_registration_path(plan: :monthly)
    assert_response :success
    assert_select "button[data-plan-id='annual'][aria-checked='false']"
    assert_select "button[data-plan-id='monthly'][aria-checked='true']"
    assert_equal "monthly", session[:selected_plan]
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

  test "allows email/password registration as professional and redirects to wizard" do
    Flipper.enable(:password_authentication)

    assert_difference "User.count", 1 do
      post user_registration_path, params: {
        plan: "annual",
        intent: "professional",
        user: {
          profile_name: "Test Professional",
          email: "test_prof@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to profile_step_path(:location)
    user = User.find_by(email: "test_prof@example.com")
    assert_not user.profiles.last.wizard_complete?
  end

  test "allows email/password registration as contractor and redirects directly to profiles" do
    Flipper.enable(:password_authentication)

    assert_difference "User.count", 1 do
      post user_registration_path, params: {
        plan: "none",
        intent: "contractor",
        user: {
          profile_name: "Test Contractor",
          email: "test_cont@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to profiles_path
    assert_equal true, session[:open_onboarding]
    user = User.find_by(email: "test_cont@example.com")
    assert user.profiles.last.wizard_complete?
  end
end
