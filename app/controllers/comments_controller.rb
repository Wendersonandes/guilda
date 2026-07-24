# Handles comments interactions: creating, editing, updating, deleting (soft-delete),
# upvoting/downvoting, and flagging.
class CommentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show ]
  before_action :set_comment, only: [ :edit, :update, :destroy, :reply, :flag_form, :upvote, :downvote, :flag, :unflag ]

  # GET /c/:short_id
  # Redirects to the root post's show page with the comment's anchor.
  def show
    skip_authorization
    comment = Comment.find_by!(short_id: params[:short_id])
    
    # Walk up parent activities to find the root post activity
    post_activity = comment.activity
    while post_activity && post_activity.parent_id.present?
      post_activity = post_activity.parent
    end

    if post_activity
      redirect_to activity_path(post_activity, anchor: ActionView::RecordIdentifier.dom_id(comment.activity))
    else
      redirect_to root_path, alert: "Comment parent post not found."
    end
  end

  # POST /activities/:activity_id/comments
  # Creates a new comment or reply comment.
  def create
    @parent_activity = Activity.find(params[:activity_id])
    
    # We authorize commenting based on whether we can see the parent activity
    authorize @parent_activity, :show?, policy_class: ActivityPolicy

    # Authorize comment creation based on the parent activity's owner
    comment = Comment.new
    comment.build_activity_object(owner: @parent_activity.owner, author: current_actor)
    authorize comment, :create?

    @comment_activity = CommentCreation.new(
      author: current_actor,
      user_author: current_user,
      parent_activity: @parent_activity,
      text: comment_params[:text]
    ).call

    @comment = @comment_activity.direct_object.objectable
    
    # Optimistic local hydration for the author
    @comment_activity.current_user_vote = 1
    @comment_activity.current_user_flagged = false

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to activity_path(@parent_activity.root) }
    end
  rescue ActiveRecord::RecordInvalid => e
    # Re-render with errors
    @comment = Comment.new(text: comment_params[:text])
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: e.message }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@parent_activity, :reply_form),
          partial: "comments/form",
          locals: { parent_activity: @parent_activity, comment: @comment }
        )
      end
    end
  end

  # GET /comments/:id/reply
  # Lazy loaded reply form for nesting replies.
  def reply
    authorize @comment
    @reply_comment = Comment.new
    
    respond_to do |format|
      format.turbo_stream
      format.html { render partial: "comments/form", locals: { parent_activity: @comment.activity, comment: @reply_comment } }
    end
  end

  # GET /comments/:id/edit
  def edit
    authorize @comment
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  # PATCH /comments/:id
  def update
    authorize @comment
    if @comment.update(comment_params.merge(last_edited_at: Time.current))
      MentionManager.new(@comment.activity_object).call(@comment.text)
      @comment_activity = @comment.activity
      CommentVoteHydrator.new([@comment_activity], current_actor)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to comment_permalink_path(@comment.short_id) }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /comments/:id
  # Soft delete to preserve sub-thread structures.
  def destroy
    authorize @comment
    @comment.update!(deleted: true)
    
    @comment_activity = @comment.activity
    CommentVoteHydrator.new([@comment_activity], current_actor)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to comment_permalink_path(@comment.short_id) }
    end
  end

  # POST /comments/:id/upvote
  def upvote
    authorize @comment
    CommentVoteService.new(
      actor: current_actor,
      user: current_user,
      comment_activity: @comment.activity,
      value: 1
    ).call

    @comment_activity = @comment.activity
    CommentVoteHydrator.new([@comment_activity], current_actor)

    respond_to do |format|
      format.turbo_stream { render :vote }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  # POST /comments/:id/downvote
  def downvote
    authorize @comment
    CommentVoteService.new(
      actor: current_actor,
      user: current_user,
      comment_activity: @comment.activity,
      value: -1
    ).call

    @comment_activity = @comment.activity
    CommentVoteHydrator.new([@comment_activity], current_actor)

    respond_to do |format|
      format.turbo_stream { render :vote }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  # GET /comments/:id/flag_form
  def flag_form
    authorize @comment
    render partial: "comments/flag_form", locals: { comment: @comment }
  end

  # POST /comments/:id/flag
  def flag
    authorize @comment
    Activity.transaction do
      flag_activity = Activity.find_by(
        parent_id: @comment.activity.id,
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
          owner: @comment.activity.author
        )
        flag.save!

        flag_activity = Activity.create!(
          parent_id: @comment.activity.id,
          author_id: current_actor.id,
          verb: :flag,
          user_author: current_user,
          owner: @comment.activity.author
        )

        flag_activity.activity_object_activities.create!(
          activity_object: flag.activity_object,
          object_type: "Flag"
        )
        
        CreateActivityAudiencesJob.perform_later(flag_activity.id, @comment.activity.relation_ids)
      end
    end

    @comment_activity = @comment.activity
    CommentVoteHydrator.new([@comment_activity], current_actor)

    respond_to do |format|
      format.turbo_stream { render :vote }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  # POST /comments/:id/unflag
  def unflag
    authorize @comment
    Activity.transaction do
      flag_activity = Activity.find_by(
        parent_id: @comment.activity.id,
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

    @comment_activity = @comment.activity
    CommentVoteHydrator.new([@comment_activity], current_actor)

    respond_to do |format|
      format.turbo_stream { render :vote }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def set_comment
    @comment = Comment.find_by!(short_id: params[:id])
  end

  def comment_params
    params.require(:comment).permit(:text)
  end
end
