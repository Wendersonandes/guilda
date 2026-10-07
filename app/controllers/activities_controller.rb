# Handles the activity stream: the home timeline, showing a single {Activity}, and publishing
# or removing activities. Creation delegates the heavy lifting (building the {Post}/
# {ActivityObject} and distributing to {Audience audiences}) to {ActivityCreation}.
#
# @see ActivityCreation
# @see ActivityPolicy
class ActivitiesController < ApplicationController
  include FeatureGated

  skip_before_action :authenticate_user!, only: [ :show ]
  before_action :set_activity, only: [ :destroy, :flag_form, :flag, :unflag ]
  before_action :set_activity_with_includes, only: [ :show ]

  feature_gated_by :social_feed, only: [ :index, :new, :create ], fallback: -> { profiles_path }

  # The signed-in actor's home timeline, paginated and narrowed to what they may see.
  #
  # Authorized via +ActivityPolicy#index?+; the listing is scoped through
  # +ActivityPolicy::Scope+ before {Activity.home_timeline}.
  def index
    authorize Activity
    @pagy, @activities = pagy(
      policy_scope(Activity).home_timeline(current_actor),
      limit: 10
    )
    if current_actor
      @activity = Activity.new(verb: :post, author: current_actor, owner: current_actor)
      
      activity_ids = @activities.map(&:id)
      if activity_ids.any?
        flagged_ids = Activity.where(parent_id: activity_ids, author_id: current_actor.id, verb: :flag)
                              .pluck(:parent_id).to_set
        @activities.each do |act|
          act.current_user_flagged = flagged_ids.include?(act.id)
        end
      end
    end
  end

  def show
    authorize @activity
    if current_actor
      @activity.current_user_flagged = Activity.exists?(parent_id: @activity.id, author_id: current_actor.id, verb: :flag)
    end
    @comments = Activity.comment_thread_tree(@activity)
  end

  def new
    owner = params[:owner_id].present? ? Actor.find(params[:owner_id]) : current_actor
    @activity = Activity.new(verb: :post, author: current_actor, owner: owner)
    authorize @activity
  end

  # Publishes a new activity. The current actor is set as author and owner, and the current
  # user as +user_author+. The persistence of the post content and the audience distribution
  # are delegated to {ActivityCreation}.
  #
  # Authorized via +ActivityPolicy#create?+. On validation failure re-renders +new+ with 422.
  #
  # @note Responds via Turbo Stream by prepending the rendered activity to the +feed+ element,
  #   updating the stream in place without a full page reload.
  def create
    @activity = Activity.new(activity_params.except(:text, :relation_ids).merge(
      author: current_actor, user_author: current_user
    ))
    @activity.owner = current_actor unless @activity.owner_id.present?

    relation_ids = activity_params[:relation_ids]
    if relation_ids.blank? && @activity.owner != current_actor
      relation_ids = @activity.owner.activity_relation_ids
    end
    @activity.relation_ids_to_authorize = relation_ids

    authorize @activity

    @activity = ActivityCreation.new(
      @activity,
      text: activity_params[:text],
      relation_ids: relation_ids
    ).call

    respond_to do |format|
      format.turbo_stream do
        @new_activity = Activity.new(verb: :post, author: current_actor, owner: @activity.owner)
        render turbo_stream: [
          turbo_stream.prepend("feed", partial: "shared/activity", locals: { activity: @activity }),
          turbo_stream.replace("activity_form_container", partial: "activities/form", locals: { activity: @new_activity, clear_inputs: true })
        ]
      end
      format.html { redirect_to @activity, notice: "Post created." }
    end
  rescue ActiveRecord::RecordInvalid => e
    @activity = e.record.is_a?(Activity) ? e.record : @activity
    @activity.errors.add(:base, e.message) unless e.record.is_a?(Activity)
    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("activity_form_container", partial: "activities/form", locals: { activity: @activity }), status: :unprocessable_entity
      end
    end
  end

  # Removes the activity (authorized via +ActivityPolicy#destroy?+).
  #
  # @note Responds via Turbo Stream by removing the activity's element from the page.
  def destroy
    authorize @activity
    DestroyActivityJob.perform_later(@activity.id)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@activity) }
      format.html { redirect_to activities_path, notice: "Activity deletion enqueued." }
    end
  end

  # GET /activities/:id/flag_form
  def flag_form
    authorize @activity
    render partial: "activities/flag_form", locals: { activity: @activity }
  end

  # POST /activities/:id/flag
  def flag
    authorize @activity
    Activity.transaction do
      flag_activity = Activity.find_by(
        parent_id: @activity.id,
        author_id: current_actor.id,
        verb: :flag
      )

      unless flag_activity
        flag = Flag.new(
          reason: params[:reason],
          note: params[:note]
        )
        flag.build_activity_object(
          author: current_actor,
          user_author: current_user,
          owner: @activity.author
        )
        flag.save!

        flag_activity = Activity.create!(
          parent_id: @activity.id,
          author_id: current_actor.id,
          verb: :flag,
          user_author: current_user,
          owner: @activity.author
        )

        flag_activity.activity_object_activities.create!(
          activity_object: flag.activity_object,
          object_type: "Flag"
        )
        
        CreateActivityAudiencesJob.perform_later(flag_activity.id, @activity.relation_ids)
      end
    end

    @activity.current_user_flagged = true

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  # POST /activities/:id/unflag
  def unflag
    authorize @activity
    Activity.transaction do
      flag_activity = Activity.find_by(
        parent_id: @activity.id,
        author_id: current_actor.id,
        verb: :flag
      )
      if flag_activity
        flag_ao = flag_activity.activity_objects.find_by(objectable_type: "Flag")
        flag = flag_ao&.objectable
        
        flag_activity.destroy!
        flag&.destroy!
      end
    end

    @activity.current_user_flagged = false

    respond_to do |format|
      format.turbo_stream { render :flag }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def set_activity
    @activity = Activity.find_by!(id: params[:id])
  end

  def set_activity_with_includes
    @activity = Activity.includes({ author: :avatar_attachment }, :user_author, { activity_objects: { mentions: :actor } }, { parent: :author }).find_by!(id: params[:id])
  end

  def activity_params
    params.require(:activity).permit(:verb, :owner_id, :parent_id, text: {}, relation_ids: [])
  end
end
