# frozen_string_literal: true

require "test_helper"

class BillingPortalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:bob)
    create_profile_for(@user, name: "Bob")
  end

  test "unauthenticated user cannot access billing portal" do
    post billing_portal_path
    assert_redirected_to new_user_session_path
  end

  test "authenticated user without active customer is redirected to pricing" do
    sign_in @user
    post billing_portal_path
    assert_redirected_to root_path(anchor: "pricing")
    assert_equal "Você ainda não possui uma assinatura ativa para gerenciar.", flash[:alert]
  end

  test "authenticated user with customer is redirected to billing portal URL" do
    sign_in @user
    customer = @user.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_test_123")

    with_mock_portal("https://billing.stripe.com/p/session_test") do
      post billing_portal_path
      assert_redirected_to "https://billing.stripe.com/p/session_test"
    end
  end

  private

  def with_mock_portal(url)
    original_method = Pay::Stripe::Customer.instance_method(:billing_portal)
    mock_portal = Struct.new(:url).new(url)
    Pay::Stripe::Customer.define_method(:billing_portal) { |**_kwargs| mock_portal }
    yield
  ensure
    Pay::Stripe::Customer.define_method(:billing_portal, original_method)
  end
end
