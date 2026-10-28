# frozen_string_literal: true

Pay.setup do |config|
  config.application_name = "Guilda"
  config.business_name = "Guilda"
  config.default_product_name = "default"
  config.default_plan_name = "default"

  # Routes are mounted explicitly in config/routes.rb
  config.automount_routes = false
  config.routes_path = "/pay"

  # Only enable Stripe as the payment processor
  config.enabled_processors = [ :stripe ]
end

# Automatically synchronize the "Professional" role on the user profile
# whenever a subscription is created, updated (status change/cancellation) or deleted.
Rails.application.config.to_prepare do
  Pay::Subscription.class_eval do
    after_commit :sync_owner_professional_role, on: [ :create, :update, :destroy ]

    private

    def sync_owner_professional_role
      owner = customer&.owner
      owner.sync_professional_role! if owner.respond_to?(:sync_professional_role!)
    end
  end
end
