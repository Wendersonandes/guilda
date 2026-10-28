# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:bob)
    create_profile_for(@user, name: "Bob")
  end

  test "show renders successfully for authenticated user" do
    sign_in @user
    get account_path
    assert_response :success
    assert_select "h3", text: "Assinatura"
  end

  test "show renders manage subscription button when user has processor_id" do
    sign_in @user
    customer = @user.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test_123")

    get account_path
    assert_response :success
    assert_select "button", text: /Gerenciar assinatura/
  end

  test "show renders view plans link pointing to pricing_path when user has no active subscription" do
    sign_in @user
    get account_path
    assert_response :success
    assert_select "a[href=?]", pricing_path, text: /Ver planos/
  end
end
