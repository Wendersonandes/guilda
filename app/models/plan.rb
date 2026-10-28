# frozen_string_literal: true

# Value object representing subscription plans available in Guilda.
# Corresponds to the plans presented on the landing page (monthly and annual).
class Plan
  PLANS = {
    monthly: {
      id: "monthly",
      name: "Profissional Mensal",
      amount_cents: 3000,
      currency: "brl",
      interval: "month",
      trial_period_days: 30
    },
    annual: {
      id: "annual",
      name: "Profissional Anual",
      amount_cents: 30000,
      currency: "brl",
      interval: "year",
      trial_period_days: 30
    }
  }.with_indifferent_access.freeze

  attr_reader :id, :name, :amount_cents, :currency, :interval, :trial_period_days

  def self.all
    PLANS.keys.map { |plan_id| find(plan_id) }
  end

  def self.find(plan_id)
    config = PLANS[plan_id.to_s]
    return nil unless config

    new(config)
  end

  def initialize(attributes)
    @id = attributes[:id].to_s
    @name = attributes[:name]
    @amount_cents = attributes[:amount_cents]
    @currency = attributes[:currency]
    @interval = attributes[:interval]
    @trial_period_days = attributes[:trial_period_days]
  end

  def amount
    amount_cents / 100.0
  end

  # Resolves the Stripe Price ID:
  # 1. From credentials (e.g. stripe.price_monthly / stripe.price_annual)
  # 2. From environment variables (STRIPE_PRICE_MONTHLY / STRIPE_PRICE_ANNUAL)
  # 3. Dynamic lookup or creation via Stripe API (ideal for development & testing)
  def stripe_price_id
    from_credentials || from_env || from_stripe_api
  end

  private

  def from_credentials
    Rails.application.credentials.dig(Rails.env.to_sym, :stripe, :"price_#{id}") ||
      Rails.application.credentials.dig(:stripe, :"price_#{id}")
  end

  def from_env
    ENV["STRIPE_PRICE_#{id.upcase}"]
  end

  def from_stripe_api
    return nil if Pay::Stripe.private_key.blank?

    ::Stripe.api_key = Pay::Stripe.private_key

    # Search for an existing active recurring price for this interval and amount
    prices = ::Stripe::Price.list(limit: 20, active: true)
    matching = prices.data.find do |p|
      p.currency == currency &&
        p.unit_amount == amount_cents &&
        p.recurring&.interval == interval
    end

    return matching.id if matching

    product = find_or_create_product
    price = ::Stripe::Price.create(
      product: product.id,
      unit_amount: amount_cents,
      currency: currency,
      recurring: { interval: interval }
    )

    price.id
  rescue ::Stripe::StripeError => e
    Rails.logger.error("[Plan#from_stripe_api] Erro ao sincronizar preço no Stripe: #{e.message}")
    nil
  end

  def find_or_create_product
    products = ::Stripe::Product.list(limit: 20, active: true)
    existing = products.data.find { |p| p.name == "Guilda - #{name}" }
    return existing if existing

    ::Stripe::Product.create(
      name: "Guilda - #{name}",
      description: "Assinatura do plano #{name} na Guilda"
    )
  end
end
