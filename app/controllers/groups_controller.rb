# CRUD for {Group Groups}. Because a group participates in the graph through its {Actor},
# authorization operates on +@group.actor+ with an explicit +policy_class: GroupPolicy+, and
# creation is delegated to {GroupCreation} (which builds the activity object and the founder's
# admin tie).
#
# @see GroupCreation
# @see GroupPolicy
class GroupsController < ApplicationController
  include FeatureGated

  feature_gated_by :groups

  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_group, only: [ :show, :edit, :update, :destroy ]

  # Lists group actors, paginated. Scoped through +ActorPolicy::Scope+ and filtered to groups.
  def index
    authorize Actor
    @groups = policy_scope(Actor).where(actorable_type: "Group")
                                 .includes(:actorable, :avatar_attachment)
    @pagy, @groups = pagy(@groups, limit: 10)
    @groups = @groups.to_a

    if current_actor
      group_ids = @groups.map(&:id)
      member_ties = Tie.joins(:contact, :relation)
                       .where(contacts: { sender_id: group_ids, receiver_id: current_actor.id })
                       .select("contacts.sender_id, relations.name")
      @membership_map = member_ties.group_by(&:sender_id)
                                   .transform_values { |ties| ties.map { |t| t[:name]&.downcase } }
    end
  end

  def show
    authorize @group.actor, policy_class: GroupPolicy
    @activities = policy_scope(Activity).owned_by(@group.actor)
                                        .roots.recent
                                        .includes(:owner, { author: :avatar_attachment }, :user_author, { activity_objects: [:received_actions, { mentions: :actor }] }, { parent: :author }, :likes)
    @pagy, @activities = pagy(@activities, limit: 10)

    @is_member = current_actor && @group.actor.member_roles_for(current_actor).any?
    if @is_member
      @owners     = @group.actor.contacts_for("owner").includes(:avatar_attachment).to_a
      @admins     = @group.actor.contacts_for("admin").includes(:avatar_attachment).to_a
      @moderators = @group.actor.contacts_for("moderator").includes(:avatar_attachment).to_a
      @members    = @group.actor.contacts_for("member").includes(:avatar_attachment).to_a
      @silenced   = @group.actor.contacts_for("silenced").includes(:avatar_attachment).to_a
      @is_admin   = current_actor && current_actor.can?(:update, :member, @group.actor)
      @activity   = Activity.new(verb: :post, author: current_actor, owner: @group.actor)
    end
  end

  def new
    @group = Group.new
    @group.build_actor
    authorize @group.actor, policy_class: GroupPolicy
  end

  # Creates a group, delegating persistence and the founder's admin tie to {GroupCreation}.
  #
  # Authorized via +GroupPolicy#create?+ (on the built actor). On validation failure re-renders
  # +new+ with 422.
  def create
    @group = Group.new(group_params)
    authorize @group.actor, policy_class: GroupPolicy

    @group = GroupCreation.new(current_actor, @group).call
    redirect_to group_path(@group), notice: t("flash.group_created")
  rescue ActiveRecord::RecordInvalid => e
    @group = e.record
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @group.actor, policy_class: GroupPolicy
  end

  def update
    authorize @group.actor, policy_class: GroupPolicy
    if @group.update(group_params)
      redirect_to group_path(@group), notice: t("flash.group_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @group.actor, policy_class: GroupPolicy
    @group.actor.destroy
    redirect_to groups_path, notice: t("flash.group_deleted")
  end

  private

  def set_group
    @group = Group.includes(:actor).find_by!(id: params[:id])
  end

  def group_params
    params.require(:group).permit(
      :privacy,
      actor_attributes: [ :id, :name, :description, :email, :avatar, :cover_image ]
    )
  end
end
