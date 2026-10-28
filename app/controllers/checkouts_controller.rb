# frozen_string_literal: true

# Handles Stripe Checkout sessions for subscriptions.
class CheckoutsController < ApplicationController
  skip_before_action :ensure_wizard_complete!
  before_action :set_plan, only: [ :create ]

  def create
    authorize :checkout, :create?

    unless @plan
      redirect_to root_path, alert: "Plano inválido selecionado."
      return
    end

    price_id = @plan.stripe_price_id
    if price_id.blank?
      redirect_to root_path, alert: "Não foi possível carregar o preço do plano no momento. Tente novamente mais tarde."
      return
    end

    checkout_params = {
      mode: "subscription",
      line_items: price_id,
      success_url: success_checkout_url(session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: cancel_checkout_url,
      allow_promotion_codes: true
    }

    # Grant 30 days trial for users without an active subscription
    if @plan.trial_period_days.to_i.positive? && !current_user.subscribed?
      checkout_params[:subscription_data] = {
        trial_period_days: @plan.trial_period_days
      }
    end

    checkout_session = current_user.payment_processor.checkout(**checkout_params)

    redirect_to checkout_session.url, allow_other_host: true, status: :see_other
  rescue Pay::Error, Stripe::StripeError => e
    Rails.logger.error("[CheckoutsController#create] Error: #{e.message}")
    redirect_to root_path, alert: "Erro ao iniciar o checkout: #{e.message}"
  end

  def success
    authorize :checkout, :success?
    @session_id = params[:session_id]

    if @session_id.present?
      begin
        Pay::Stripe.sync_checkout_session(@session_id)
      rescue Pay::Error, Stripe::StripeError => e
        Rails.logger.warn("[CheckoutsController#success] Aviso na sincronização imediata: #{e.message}")
      end
    end

    current_user.sync_professional_role!
  end

  def cancel
    authorize :checkout, :cancel?
  end

  private

  def set_plan
    @plan = Plan.find(params[:plan])
  end
end
