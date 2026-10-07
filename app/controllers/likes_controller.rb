# Handles liking/unliking of an {Activity}. Each action is materialized as an
# {Activity} with verb: :like.
#
# @see Like
# @see LikePolicy
class LikesController < ApplicationController
  include FeatureGated

  feature_gated_by :likes

  before_action :set_activity

  # Creates a like: builds a new {Like} wrapper around an activity with verb: :like and saves it.
  # Authorized via +LikePolicy#create?+.
  #
  # @note Responds via Turbo Stream to swap the actions block state in place.
  def create
    @like = Like.build(current_actor, current_user, @activity)
    authorize @like

    if @like.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: activities_path }
      end
    else
      redirect_back fallback_location: activities_path, alert: "Unable to like this item."
    end
  end

  # Destroys a like (authorized via +LikePolicy#destroy?+).
  #
  # @note Responds via Turbo Stream to swap the actions block state in place.
  def destroy
    activity = Activity.find(params[:id])
    @like = Like.new(activity)
    authorize @like

    if @like.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: activities_path }
      end
    else
      redirect_back fallback_location: activities_path, alert: "Unable to unlike this item."
    end
  end

  private

  # Loads the activity that is the target of the like actions.
  def set_activity
    @activity = Activity.find(params[:activity_id])
  end
end
