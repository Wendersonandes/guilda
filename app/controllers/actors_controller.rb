# Public-facing access to {Actor Actors}: a JSON search endpoint (used by autocomplete/mention
# pickers) and an actor's profile page with its activity feed.
#
# @see ActorPolicy
class ActorsController < ApplicationController
  ROLE_PRIORITY = %w[admin editor moderator professional tester member silenced banned].freeze

  skip_before_action :authenticate_user!, only: [ :show ]
  skip_after_action :verify_policy_scoped, only: [ :index ]

  # JSON actor search by name (authorized via +ActorPolicy#index?+). When
  # +params[:include_site_roles]+ is "true", each result is enriched with the actor's role on
  # the {Site} (resolved from the site actor's {Tie Ties}).
  def index
    authorize Actor
    @actors = Actor.name_search(params[:q])
                   .where.not(id: params[:exclude].presence&.split(","))
                   .includes(avatar_attachment: :blob)
                   .limit(20)

    respond_to do |format|
      format.html do
        @actors = Actor.includes(avatar_attachment: :blob)
                       .alphabetic
        @pagy, @actors = pagy(@actors, limit: 24)
      end
      format.json do
        if params[:include_site_roles] == "true"
          site_actor = Site.instance.actor
          actor_ids = @actors.map(&:id)

          ties = Tie.joins(:contact, :relation)
                    .where(contacts: { sender_id: site_actor.id, receiver_id: actor_ids })
                    .select("contacts.receiver_id", "relations.name as relation_name")

          actor_roles = {}
          actor_all_roles = Hash.new { |h, k| h[k] = [] }
          ties.each do |tie|
            new_role = tie.relation_name.downcase
            actor_all_roles[tie.receiver_id] << new_role unless actor_all_roles[tie.receiver_id].include?(new_role)
            current = actor_roles[tie.receiver_id]
            if current.nil? || (ROLE_PRIORITY.index(new_role) || 99) < (ROLE_PRIORITY.index(current) || 99)
              actor_roles[tie.receiver_id] = new_role
            end
          end

          render json: @actors.map { |a|
            roles_for_actor = actor_all_roles[a.id].sort_by { |r| ROLE_PRIORITY.index(r) || 99 }
            {
              id: a.id,
              name: a.name,
              slug: a.slug,
              type: a.actorable_type,
              role: actor_roles[a.id] || "none",
              roles: roles_for_actor,
              avatar_url: a.avatar.attached? ? rails_representation_path(a.avatar.variant(:thumb)) : nil
            }
          }
        else
          render json: @actors.map { |a|
            {
              id: a.id,
              name: a.name,
              slug: a.slug,
              type: a.actorable_type,
              avatar_url: a.avatar.attached? ? rails_representation_path(a.avatar.variant(:thumb)) : nil
            }
          }
        end
      end
    end
  end

  # Redirects an actor slug lookup to its canonical public page (+/profiles/:slug+ or +/groups/:id+).
  # Authorized via +ActorPolicy#show?+.
  def show
    @actor = Actor.find_by!(slug: params[:id])
    authorize @actor

    case @actor.actorable_type
    when "Profile", "Group"
      redirect_to public_path_for(@actor)
    else
      redirect_to root_path
    end
  end
end
