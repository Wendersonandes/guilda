# frozen_string_literal: true

require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:bob)
    create_profile_for(@user, name: "Bob")
  end

  test "unauthenticated user cannot create checkout" do
    post checkout_path(plan: :annual)
    assert_redirected_to new_user_session_path
  end

  test "authenticated user with invalid plan is redirected to root" do
    sign_in @user
    post checkout_path(plan: :invalid)
    assert_redirected_to root_path
    assert_equal "Plano inválido selecionado.", flash[:alert]
  end

  test "authenticated user initiates checkout session successfully" do
    sign_in @user

    with_mock_checkout("https://checkout.stripe.com/c/pay_test_session") do
      with_stubbed_price("price_mock_123") do
        post checkout_path(plan: :annual)
        assert_redirected_to "https://checkout.stripe.com/c/pay_test_session"
      end
    end
  end

  test "success action renders successfully for authenticated user" do
    sign_in @user
    get success_checkout_path(session_id: "cs_test_123")
    assert_response :success
    assert_select "a[href=?]", new_my_project_path
    assert_select "a[href=?]", edit_my_profile_path
  end

  test "cancel action renders successfully for authenticated user" do
    sign_in @user
    get cancel_checkout_path
    assert_response :success
  end

  private

  def with_mock_checkout(url)
    original_method = Pay::Stripe::Customer.instance_method(:checkout)
    mock_session = Struct.new(:url).new(url)
    Pay::Stripe::Customer.define_method(:checkout) { |**_kwargs| mock_session }
    yield
  ensure
    Pay::Stripe::Customer.define_method(:checkout, original_method)
  end

  def with_stubbed_price(price_id)
    original_method = Plan.instance_method(:stripe_price_id)
    Plan.define_method(:stripe_price_id) { price_id }
    yield
  ensure
    Plan.define_method(:stripe_price_id, original_method)
  end
end
