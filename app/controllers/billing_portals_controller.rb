# frozen_string_literal: true

# Redirects users to the Stripe Customer Portal to manage subscriptions, payment methods, and invoices.
class BillingPortalsController < ApplicationController
  skip_before_action :ensure_wizard_complete!

  def create
    authorize :checkout, :create?

    unless current_user.payment_processor&.processor_id.present?
      redirect_to root_path(anchor: "pricing"), alert: "Você ainda não possui uma assinatura ativa para gerenciar."
      return
    end

    portal_session = current_user.payment_processor.billing_portal(
      return_url: account_url
    )

    redirect_to portal_session.url, allow_other_host: true, status: :see_other
  rescue Pay::Error, Stripe::StripeError => e
    Rails.logger.error("[BillingPortalsController#create] Error: #{e.message}")
    redirect_to account_path, alert: "Não foi possível abrir o portal de faturamento: #{e.message}"
  end
end
