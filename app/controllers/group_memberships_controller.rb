# Manages the membership lifecycle of a {Group}: listing members by role, join requests and
# invites, role changes, removals and leaving, plus an insights dashboard.
#
# Membership is modeled as {Tie Ties} between the group's {Actor} and each member's actor, so
# role changes are delegated to {GroupMembershipService}. Authorization goes through
# {GroupPolicy} using named checks ({GroupPolicy#add_member?}, {GroupPolicy#join?},
# {GroupPolicy#change_role?}, {GroupPolicy#remove_member?}, {GroupPolicy#leave?}).
#
# @see GroupMembershipService
# @see GroupPolicy
class GroupMembershipsController < ApplicationController
  include FeatureGated

  feature_gated_by :groups

  skip_before_action :authenticate_user!, only: [ :index ]
  skip_after_action :verify_policy_scoped, only: [ :index, :insights, :approve_request, :reject_request, :accept_invite, :decline_invite ]
  before_action :set_group

  # Lists members grouped by role (admins, moderators, members), pending join requests (for
  # admins only), and headline counts. Authorized via +GroupPolicy#index?+.
  def index
    authorize @group_actor, policy_class: GroupPolicy
    @owners = @group_actor.contacts_for("owner").includes(:avatar_attachment).to_a
    @admins = @group_actor.contacts_for("admin").includes(:avatar_attachment).to_a
    @moderators = @group_actor.contacts_for("moderator").includes(:avatar_attachment).to_a
    @members = @group_actor.contacts_for("member").includes(:avatar_attachment).to_a
    @silenced = @group_actor.contacts_for("silenced").includes(:avatar_attachment).to_a
    @is_admin = current_actor && current_actor.can?(:update, :member, @group_actor)
    @pending_requests = if @is_admin
      @group_actor.received_contacts.pending.includes(sender: :avatar_attachment).to_a
    else
      Contact.none
    end
    @member_roles = current_actor ? @group_actor.member_roles_for(current_actor) : []
    @total_members = @group.actor.sent_contacts.active.count
    @total_posts = @group.actor.authored_activities.posts.count
  end

  # Admin-only analytics dashboard (authorized via +GroupPolicy#manage_members?+).
  def insights
    authorize @group_actor, :manage_members?, policy_class: GroupPolicy
    @stats = build_insights
  end

  # Dual-purpose entry point:
  # * When an +actor_id+ other than the current actor is given, an admin *invites* that actor
  #   (authorized via +GroupPolicy#add_member?+): a tie group → member is created.
  # * Otherwise the current actor *joins* (authorized via +GroupPolicy#join?+). It short-circuits
  #   if already a member or already pending. A member → group tie is created; public groups
  #   reciprocate immediately, private groups leave the request pending admin approval.
  def create
    @member = params[:actor_id].present? ? find_actor(params[:actor_id]) : nil

    if @member && @member != current_actor
      authorize @group_actor, :add_member?, policy_class: GroupPolicy
      @group_actor.connect_to(@member, as: params[:role] || "member")
      redirect_to group_memberships_path(@group), notice: "Invite sent."
    else
      @member = current_actor
      authorize @group_actor, :join?, policy_class: GroupPolicy

      if @group_actor.member_roles_for(@member).any?
        return redirect_to group_memberships_path(@group), notice: "You are already a member."
      end

      existing = @member.contact_to(@group_actor)
      if existing&.established?
        return redirect_to group_memberships_path(@group), notice: "Your request is already pending."
      end

      ActiveRecord::Base.transaction do
        existing&.destroy
        @member.connect_to(@group_actor, as: "follow")
        if @group.public_group?
          @group_actor.connect_to(@member, as: "member")
        end
      end

      if @group.public_group?
        redirect_to group_memberships_path(@group), notice: "You joined the group."
      else
        redirect_to group_memberships_path(@group), notice: "Request sent. Awaiting approval."
      end
    end
  end

  # Current actor accepts a pending invite from the group, creating the reciprocal member tie
  # (authorized via +GroupPolicy#join?+).
  def accept_invite
    authorize @group_actor, :join?, policy_class: GroupPolicy
    invite = current_actor.received_contacts.pending.find_by(sender: @group_actor)
    if invite
      current_actor.connect_to(@group_actor, as: "follow")
      redirect_to group_memberships_path(@group), notice: "Invite accepted."
    else
      redirect_to group_memberships_path(@group), alert: "No pending invite found."
    end
  end

  # Current actor declines a pending invite, destroying the invite contact
  # (authorized via +GroupPolicy#join?+).
  def decline_invite
    authorize @group_actor, :join?, policy_class: GroupPolicy
    contact = current_actor.received_contacts.pending
                            .find_by(id: params[:contact_id], sender: @group_actor)
    if contact&.destroy
      redirect_to group_memberships_path(@group), notice: "Invite declined."
    else
      redirect_to group_memberships_path(@group), alert: "Invite not found."
    end
  end

  # Admin approves a pending join request by connecting the group to the requester with the
  # given role (authorized via +GroupPolicy#add_member?+).
  def approve_request
    authorize @group_actor, :add_member?, policy_class: GroupPolicy
    contact = @group_actor.received_contacts.pending.find(params[:contact_id])
    @group_actor.connect_to(contact.sender, as: params[:role] || "member")
    redirect_to group_memberships_path(@group), notice: "Request approved."
  end

  # Admin rejects a pending join request, destroying the request contact
  # (authorized via +GroupPolicy#add_member?+).
  def reject_request
    authorize @group_actor, :add_member?, policy_class: GroupPolicy
    contact = @group_actor.received_contacts.pending.find(params[:contact_id])
    contact.destroy
    redirect_to group_memberships_path(@group), notice: "Request rejected."
  end

  # Changes a member's role from one relation to another, delegating to
  # {GroupMembershipService#change_role} (authorized via +GroupPolicy#change_role?+).
  def update
    authorize @group_actor, :change_role?, policy_class: GroupPolicy
    @member = find_actor(params[:id])
    GroupMembershipService.new(@group_actor, @member).change_role(
      from: params[:from_role],
      to: params[:to_role]
    )
    redirect_to group_memberships_path(@group), notice: "Role updated."
  end

  # Removes a member (or the current actor leaving). Authorization differs: leaving uses
  # +GroupPolicy#leave?+, removing someone else uses +GroupPolicy#remove_member?+. Delegates to
  # {GroupMembershipService#remove}.
  def destroy
    @member = find_actor(params[:id])
    if @member == current_actor
      authorize @group_actor, :leave?, policy_class: GroupPolicy
    else
      authorize @group_actor, :remove_member?, policy_class: GroupPolicy
    end
    GroupMembershipService.new(@group_actor, @member).remove(role: params[:role])
    redirect_to after_destroy_path, notice: after_destroy_notice
  end

  private

  def set_group
    @group = Group.includes(:actor).find_by!(id: params[:group_id])
    @group_actor = @group.actor
  end

  def find_actor(value)
    value.to_s.match?(/\A\d+\z/) ? Actor.find(value) : Actor.find_by!(slug: value)
  end

  # Computes the last-7-days insights for the dashboard: new members and posts, active authors,
  # a daily new-members series (labeled by weekday) and the top contributors by post count.
  #
  # @return [Hash] aggregated metrics consumed by the insights view.
  def build_insights
    range = 7.days.ago..Time.current
    posts = Activity.roots.posts.where(owner: @group_actor)

    new_members = Tie.joins(:contact)
                     .where(contacts: { sender_id: @group_actor.id })
                     .where(created_at: range).count

    new_posts = posts.where(created_at: range).count

    active_authors = posts.where(created_at: range)
                          .where.not(author: @group_actor)
                          .distinct.count(:author_id)

    daily_members = Tie.joins(:contact)
                       .where(contacts: { sender_id: @group_actor.id })
                       .where(created_at: range)
                       .group("DATE(ties.created_at)")
                       .order(Arel.sql("DATE(ties.created_at)"))
                       .count

    daily_members_labeled = daily_members.transform_keys { |d| Date.parse(d.to_s).strftime("%a") }

    raw_top = posts.where.not(author: @group_actor)
                   .group(:author_id)
                   .order(Arel.sql("COUNT(*) DESC"))
                   .limit(10)
                   .count

    author_ids = raw_top.keys
    author_map = Actor.where(id: author_ids).includes(:avatar_attachment).index_by(&:id)
    top_contributors = raw_top.map { |id, count| { actor: author_map[id], count: count } }

    {
      new_members: new_members,
      new_posts: new_posts,
      active_members: active_authors,
      daily_members: daily_members_labeled,
      top_contributors: top_contributors
    }
  end

  def after_destroy_path
    @member == current_actor ? groups_path : group_memberships_path(@group)
  end

  def after_destroy_notice
    @member == current_actor ? "You left the group." : "Member removed."
  end
end
