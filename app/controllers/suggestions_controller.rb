class SuggestionsController < ApplicationController
  include FeatureGated

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  feature_gated_by :suggestions

  def index
    render layout: false
  end
end
