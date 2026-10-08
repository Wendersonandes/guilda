# frozen_string_literal: true

# Controller concern that blocks access to actions whose backing
# {https://github.com/flippercloud/flipper Flipper} feature is disabled for the current actor.
#
# It complements the view-level checks (which hide entry points) with a server-side guard, so a
# disabled feature cannot be reached by guessing a URL. Because the guard runs before the action,
# it also short-circuits Pundit's +verify_authorized+/+verify_policy_scoped+ after-actions.
#
# @example
#   class LikesController < ApplicationController
#     include FeatureGated
#     feature_gated_by :likes
#   end
module FeatureGated
  extend ActiveSupport::Concern

  class_methods do
    # Declares that the given actions require a Flipper feature to be enabled.
    #
    # @param name [Symbol] the feature flag name.
    # @param fallback [Symbol, Proc] a path helper name (or a proc returning a path) to redirect
    #   HTML requests to when the feature is disabled. Defaults to +:root_path+.
    # @param options [Hash] extra options forwarded to +before_action+ (e.g. +only:+).
    def feature_gated_by(name, fallback: :root_path, **options)
      before_action(**options) { require_feature!(name, fallback) }
    end
  end

  private

  # Halts the request when the feature is disabled. HTML clients are redirected to the fallback;
  # every other format receives a +404 Not Found+.
  #
  # @param name [Symbol] the feature flag name.
  # @param fallback [Symbol, Proc] the redirect target for HTML requests.
  # @return [void]
  def require_feature!(name, fallback)
    return if feature_enabled?(name)

    skip_authorization
    skip_policy_scope

    destination = fallback.respond_to?(:call) ? instance_exec(&fallback) : public_send(fallback)

    respond_to do |format|
      format.html { redirect_to destination, alert: t("flash.feature_unavailable") }
      format.turbo_stream { head :not_found }
      format.any { head :not_found }
    end
  end
end
