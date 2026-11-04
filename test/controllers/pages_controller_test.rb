require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @user.update!(current_profile: @actor)
    @user.reload
  end

  test "guest user should get landing page at root" do
    get root_url
    assert_response :success
    assert_select "title", text: /Guilda — Portfólio e Diretório para Profissionais da Cultura/
    assert_select "h1", text: /Apresente os projetos que você construiu e seja encontrado por quem contrata na cultura/
  end

  test "guest user should get landing page at about path" do
    get about_url
    assert_response :success
    assert_select "title", text: /Guilda — Portfólio e Diretório para Profissionais da Cultura/
    assert_select "h1", text: /Apresente os projetos que você construiu e seja encontrado por quem contrata na cultura/
    assert_select "h2", text: /Uma ferramenta de trabalho para expandir sua atuação na cultura/
    assert_select "h2", text: /O que artistas, galerias, museus e produtoras buscam aqui/
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

  test "guest user should get pricing page at pricing path" do
    get pricing_url
    assert_response :success
    assert_select "title", text: /Planos e Preços — Guilda/
    assert_select "h2", text: /Investimento transparente para valorizar seu ofício/
    assert_select "a[href=?]", new_user_registration_path(plan: :trial)
    assert_select "a[href=?]", new_user_registration_path(plan: :annual)
    assert_select "a[href=?]", new_user_registration_path(plan: :monthly)
  end

  test "authenticated user should get pricing page at pricing path with checkout buttons" do
    sign_in @user
    get pricing_url
    assert_response :success
    assert_select "title", text: /Planos e Preços — Guilda/
    assert_select "a[href=?]", account_path
    assert_select "button", text: /Testar Plano Anual/
    assert_select "button", text: /Testar Plano Mensal/
  end
end
