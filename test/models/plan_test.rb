# frozen_string_literal: true

require "test_helper"

class PlanTest < ActiveSupport::TestCase
  test "Plan.all returns all defined plans" do
    plans = Plan.all
    assert_equal 2, plans.size
    assert_equal [ "monthly", "annual" ], plans.map(&:id)
  end

  test "Plan.find resolves plans by id" do
    monthly = Plan.find(:monthly)
    assert_not_nil monthly
    assert_equal "Profissional Mensal", monthly.name
    assert_equal 3000, monthly.amount_cents
    assert_equal 30.0, monthly.amount
    assert_equal "brl", monthly.currency
    assert_equal "month", monthly.interval
    assert_equal 30, monthly.trial_period_days

    annual = Plan.find(:annual)
    assert_not_nil annual
    assert_equal "Profissional Anual", annual.name
    assert_equal 30000, annual.amount_cents
    assert_equal 300.0, annual.amount
    assert_equal "brl", annual.currency
    assert_equal "year", annual.interval
    assert_equal 30, annual.trial_period_days
  end

  test "Plan.find returns nil for unknown plan" do
    assert_nil Plan.find(:invalid)
  end

  test "Plan.resolve maps trial to monthly and resolves annual and monthly" do
    assert_equal "monthly", Plan.resolve(:trial).id
    assert_equal "monthly", Plan.resolve(:monthly).id
    assert_equal "annual", Plan.resolve(:annual).id
    assert_nil Plan.resolve(:invalid)
    assert_nil Plan.resolve(nil)
  end

  test "Plan#stripe_price_id resolves from environment if set" do
    plan = Plan.find(:monthly)
    ENV["STRIPE_PRICE_MONTHLY"] = "price_env_123"
    assert_equal "price_env_123", plan.stripe_price_id
  ensure
    ENV.delete("STRIPE_PRICE_MONTHLY")
  end
end
