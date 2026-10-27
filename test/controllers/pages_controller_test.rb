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
    assert_select "title", text: /Guilda — Rede e Diretório de Profissionais da Cultura/
    assert_select "h1", text: /Para quem constrói a cultura nacional com as próprias mãos/
    assert_select "a[href=?]", new_user_registration_path(plan: :trial)
    assert_select "a[href=?]", new_user_registration_path(plan: :annual)
    assert_select "a[href=?]", new_user_registration_path(plan: :monthly)
    assert_select "a[href=?]", profiles_path(occupation: "Produção Cultural")
  end

  test "authenticated user should get the profiles directory at root" do
    sign_in @user
    get root_url
    assert_response :success
    assert_select "h1", text: "Profissionais e Fornecedores"
    assert_select "a[href=?]", account_path
    assert_select "a[href=?]", edit_my_profile_path
  end
end
