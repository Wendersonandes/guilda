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
    assert_redirected_to pricing_path
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

  test "recovers and recreates customer when Stripe reports No such customer" do
    sign_in @user
    customer = @user.set_payment_processor(:stripe)
    customer.update!(processor_id: "cus_stale_123")

    attempts = 0
    original_billing_portal = Pay::Stripe::Customer.instance_method(:billing_portal)
    mock_portal = Struct.new(:url).new("https://billing.stripe.com/p/session_recovered")

    Pay::Stripe::Customer.define_method(:billing_portal) do |**_kwargs|
      attempts += 1
      if attempts == 1
        raise Pay::Stripe::Error, "(Status 400) No such customer: 'cus_stale_123'"
      else
        mock_portal
      end
    end

    original_list = Stripe::Customer.method(:list)
    original_create = Stripe::Customer.method(:create)
    Stripe::Customer.define_singleton_method(:list) { |**_args| Struct.new(:data).new([]) }
    Stripe::Customer.define_singleton_method(:create) { |**_args| Struct.new(:id).new("cus_fresh_456") }

    post billing_portal_path
    assert_redirected_to "https://billing.stripe.com/p/session_recovered"
    assert_equal "cus_fresh_456", customer.reload.processor_id
  ensure
    Pay::Stripe::Customer.define_method(:billing_portal, original_billing_portal)
    Stripe::Customer.define_singleton_method(:list, original_list) if original_list
    Stripe::Customer.define_singleton_method(:create, original_create) if original_create
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
