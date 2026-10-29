# frozen_string_literal: true

# Redirects users to the Stripe Customer Portal to manage subscriptions, payment methods, and invoices.
class BillingPortalsController < ApplicationController
  skip_before_action :ensure_wizard_complete!

  def create
    authorize :checkout, :create?

    unless current_user.payment_processor&.processor_id.present?
      redirect_to pricing_path, alert: "Você ainda não possui uma assinatura ativa para gerenciar."
      return
    end

    portal_session = create_portal_session

    redirect_to portal_session.url, allow_other_host: true, status: :see_other
  rescue Pay::Error, Stripe::StripeError => e
    Rails.logger.error("[BillingPortalsController#create] Error: #{e.message}")
    redirect_to account_path, alert: "Não foi possível abrir o portal de faturamento: #{e.message}"
  end

  private

  def create_portal_session
    current_user.payment_processor.billing_portal(return_url: account_url)
  rescue Pay::Error, Stripe::StripeError => e
    raise unless e.message.include?("No such customer")

    # In development or after seed resets, if the processor_id does not exist in Stripe,
    # find or create a valid customer in Stripe and retry.
    ::Stripe.api_key = Pay::Stripe.private_key if Pay::Stripe.private_key.present?
    stripe_customer = ::Stripe::Customer.list(email: current_user.email, limit: 1).data.first ||
                     ::Stripe::Customer.create(
                       email: current_user.email,
                       name: current_user.pay_customer_name,
                       metadata: { user_id: current_user.id }
                     )
    current_user.payment_processor.update!(processor_id: stripe_customer.id)
    current_user.payment_processor.billing_portal(return_url: account_url)
  end
end
