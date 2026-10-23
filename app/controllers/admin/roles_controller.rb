# Site administration of member roles. It manages the {Tie Ties} from the {Site}'s {Actor} to
# each member (admin, editor, moderator, silenced, banned, member), delegating role changes to
# {GroupMembershipService}. Restricted to site admins via {Admin::RolePolicy}.
#
# @see GroupMembershipService
# @see Admin::RolePolicy
# @see Relation::LocalAdmin
class Admin::RolesController < ApplicationController
  PROTECTED_ROLES = %w[admin].freeze

  before_action :set_site_actor
  before_action :ensure_not_admin_role, only: [ :create, :update, :destroy ]
  skip_after_action :verify_policy_scoped, only: [ :index, :create, :destroy ]

  # Lists members of the site grouped by role. Authorized via +Admin::RolePolicy#index?+.
  def index
    authorize @site_actor, policy_class: Admin::RolePolicy
    @admins = @site_actor.contacts_for("admin").includes(:avatar_attachment).to_a
    @editors = @site_actor.contacts_for("editor").includes(:avatar_attachment).to_a
    @moderators = @site_actor.contacts_for("moderator").includes(:avatar_attachment).to_a
    @professionals = @site_actor.contacts_for("professional").includes(:avatar_attachment).to_a
    @testers = @site_actor.contacts_for("tester").includes(:avatar_attachment).to_a
    @silenced = @site_actor.contacts_for("silenced").includes(:avatar_attachment).to_a
    @banned = @site_actor.contacts_for("banned").includes(:avatar_attachment).to_a
    @total_members = @site_actor.contacts_for("member").count
  end

  # Assigns a role to an actor additively on the site, delegating to {GroupMembershipService#add_role}.
  # Authorized via +Admin::RolePolicy#create?+.
  def create
    authorize @site_actor, policy_class: Admin::RolePolicy
    member = find_actor(params[:actor_id])
    GroupMembershipService.new(@site_actor, member).add_role(params[:to_role] || "member")
    redirect_to admin_roles_path, notice: t("flash.role_assigned")
  end

  # Changes an actor's site role, delegating to {GroupMembershipService#change_role}.
  # Authorized via +Admin::RolePolicy#update?+.
  def update
    authorize @site_actor, policy_class: Admin::RolePolicy
    member = find_actor(params[:id])
    GroupMembershipService.new(@site_actor, member).change_role(
      from: params[:from_role],
      to: params[:to_role]
    )
    redirect_to admin_roles_path, notice: t("flash.role_updated")
  end

  # Removes a specific role from an actor on the site, delegating to {GroupMembershipService#remove}.
  # Authorized via +Admin::RolePolicy#destroy?+.
  def destroy
    authorize @site_actor, policy_class: Admin::RolePolicy
    member = find_actor(params[:id])
    GroupMembershipService.new(@site_actor, member).remove(role: params[:role])
    redirect_to admin_roles_path, notice: t("flash.role_removed")
  end

  private

  def set_site_actor
    @site_actor = Site.instance.actor
  end

  def ensure_not_admin_role
    roles = [ params[:to_role], params[:from_role], params[:role] ].compact.map { |r| r.to_s.downcase }
    if (roles & PROTECTED_ROLES).any?
      redirect_to admin_roles_path, alert: t("flash.admin_role_protected")
    end
  end

  def find_actor(value)
    value.to_s.match?(/\A\d+\z/) ? Actor.find(value) : Actor.find_by!(slug: value)
  end
end
