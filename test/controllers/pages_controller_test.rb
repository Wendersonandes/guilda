require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @user.update!(current_profile: @actor)
    @user.reload
  end

  test "guest user should get the profiles directory at root" do
    get root_url
    assert_response :success
    assert_select "h1", text: "Profissionais e Fornecedores"
  end

  test "guest user should get landing page at about path" do
    get about_url
    assert_response :success
    assert_select "h1", text: /Conectando o trabalho invisível das artes visuais/
  end

  test "authenticated user should get the profiles directory at root" do
    sign_in @user
    get root_url
    assert_response :success
    assert_select "h1", text: "Profissionais e Fornecedores"
    assert_select "a[href=?]", account_path
  end
end
