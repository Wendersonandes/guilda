# Handles follow/unfollow actions on the {ActivityObject} behind an {Activity} (its
# {Activity#direct_object}). Each action is materialized as an {ActivityAction} for the current
# actor.
#
# @see ActivityAction
# @see ActivityActionPolicy
class ActivityActionsController < ApplicationController
  include FeatureGated

  feature_gated_by :follow_objects

  before_action :set_ao

  # Follows the object: finds or builds the current actor's {ActivityAction} and marks it as a
  # follow. Authorized via +ActivityActionPolicy#create?+.
  #
  # @note Responds via Turbo Stream to swap the follow button state in place.
  def create
    action = @ao.received_actions.find_or_initialize_by(actor: current_actor)
    authorize action
    action.follow!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: activities_path }
    end
  end

  # Unfollows the object (authorized via +ActivityActionPolicy#destroy?+).
  #
  # @note Responds via Turbo Stream to swap the follow button state in place.
  def destroy
    action = @ao.received_actions.find_by!(actor: current_actor)
    authorize action
    action.unfollow!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: activities_path }
    end
  end

  private

  # Loads the activity and its direct object; redirects back when there is nothing to act on.
  def set_ao
    @activity = Activity.find(params[:activity_id])
    @ao = @activity.direct_object
    redirect_back fallback_location: activities_path, alert: t("flash.no_object_to_act_on") unless @ao
  end
end
