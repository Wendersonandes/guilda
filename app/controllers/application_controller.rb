# Base controller for the whole application. It wires up the authorization backbone shared by
# every request:
#
# * {https://github.com/varvet/pundit Pundit} — enforces that every non-Devise action calls
#   +authorize+ (+verify_authorized+) and that every +index+ resolves a policy scope
#   (+verify_policy_scoped+). Controllers that legitimately opt out use +skip_after_action+.
# * {https://github.com/ddnexus/pagy Pagy} — pagination helpers.
# * Devise — +authenticate_user!+ guards all actions unless a controller skips it.
#
# The distinction between the login identity and the acting graph node lives here: +current_user+
# is the {User}, while {#current_actor} is the {Actor} it currently acts as
# ({User#current_profile}) — the value passed to policies and used across the domain.
#
# @see ApplicationPolicy The Pundit base that mirrors this +user+ vs +actor+ split.
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  layout -> { false if turbo_frame_request? }

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :ensure_wizard_complete!
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :verify_authorized, unless: :devise_controller?
  after_action :verify_policy_scoped, if: -> { action_name == "index" }, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def ensure_wizard_complete!
    return if devise_controller? || controller_name == "profile_steps" || controller_name == "locations"
    return unless current_user && current_actor

    if current_actor.actorable_type == "Profile" && !current_actor.actorable.wizard_complete?
      redirect_to profile_step_path(current_actor.actorable.current_step)
    end
  end

  # The {Actor} the signed-in {User} is currently acting as. This is the entity handed to
  # Pundit policies and used throughout the domain layer.
  #
  # @return [Actor, nil] the current profile's actor, or +nil+ when signed out.
  def current_actor
    @current_actor ||= begin
      actor = current_user&.current_profile
      if actor
        ActiveRecord::Associations::Preloader.new(records: [actor], associations: :actorable).call
        if actor.actorable.is_a?(Profile)
          actor.actorable.user = current_user
        end
      end
      actor
    end
  end
  helper_method :current_actor

  # Generates the correct public-facing URL for an {Actor} based on its +actorable_type+.
  # Profiles are routed at +/profiles/:slug+, Groups at +/groups/:id+, and everything else
  # falls back to +/actors/:slug+.
  #
  # @param actor [Actor] the actor to link to.
  # @return [String] the URL path.
  def public_path_for(actor)
    case actor.actorable_type
    when "Profile"
      profile_path(actor)
    when "Group"
      group_path(actor.actorable_id)
    else
      actor_path(actor)
    end
  end
  helper_method :public_path_for

  # Whether a {https://github.com/flippercloud/flipper Flipper} feature is enabled for the
  # current actor. Exposed to views so entry points to disabled features can be hidden.
  #
  # @param name [Symbol, String] the feature flag name (see {FeatureFlags::FEATURES}).
  # @return [Boolean]
  def feature_enabled?(name)
    Flipper.enabled?(name, current_actor)
  end
  helper_method :feature_enabled?

  # Adds +:profile_name+ to the permitted Devise sign-up parameters so the initial {Profile}
  # can be created (see {User#setup_initial_profile!}).
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :profile_name ])
  end

  # Handles {Pundit::NotAuthorizedError}: flashes an alert and redirects back (or to root).
  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end
end
