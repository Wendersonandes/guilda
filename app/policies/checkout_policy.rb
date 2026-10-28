# frozen_string_literal: true

# Authorization policy for Stripe Checkouts.
class CheckoutPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def success?
    user.present?
  end

  def cancel?
    user.present?
  end
end
