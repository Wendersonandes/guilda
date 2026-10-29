# frozen_string_literal: true

# Handles Stripe Checkout sessions for subscriptions.
class CheckoutsController < ApplicationController
  skip_before_action :ensure_wizard_complete!
  before_action :set_plan, only: [ :create ]

  def create
    authorize :checkout, :create?
    redirect_to_plan_checkout(@plan, fallback_path: root_path)
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
    @plan = Plan.resolve(params[:plan])
  end
end
