# Editing of the signed-in user's {Profile} (personal fields and the delegated {Actor}
# identity). +show+ simply redirects to the actor's public page. Location selects are populated
# from the +countries+/+cities+ (CS) gem.
#
# @see Profile
# @see ActorPolicy
class ProfilesController < ApplicationController
  # The directory and public profile pages are reachable while signed out.
  skip_before_action :authenticate_user!, only: [ :index ]
  skip_before_action :authenticate_user!, only: [ :show ], if: -> { params[:id].present? }
  before_action :set_profile, only: [ :edit, :update ]
  skip_after_action :verify_policy_scoped, only: [ :index ]

  # GET /profiles
  def index
    authorize Actor, :index?

    @cities = Profile.listed_in_directory.where.not(city: [ nil, "" ]).order(:city).pluck(:city).uniq
    @occupations = Profile::OCCUPATIONS.map { |o| o["name"] }

    @profiles = Profile.listed_in_directory
                       .joins(:actor)
                       .includes(:occupations, :projects, actor: [ avatar_attachment: :blob, cover_image_attachment: :blob ])
                       .order("actors.name ASC")

    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      @profiles = @profiles.where("actors.name ILIKE :term", term: term)
    end

    if params[:occupation].present?
      @profiles = @profiles.tagged_with(params[:occupation], on: :occupations)
    end

    if params[:city].present?
      @profiles = @profiles.where(city: params[:city])
    end

    if params[:availability].present?
      @profiles = @profiles.where(availability: params[:availability])
    end

    @pagy, @profiles = pagy(@profiles, limit: 12)
  end

  # GET /profiles/:id (public profile dossier) or GET /my/profile (redirects to current actor's public page)
  def show
    if params[:id].blank?
      skip_authorization
      redirect_to public_path_for(current_actor)
      return
    end

    @actor = Actor.where(actorable_type: "Profile")
                  .includes(avatar_attachment: :blob, cover_image_attachment: :blob, actorable: :occupations)
                  .find_by!(slug: params[:id])
    @profile = @actor.actorable
    authorize @actor

    @activities = policy_scope(Activity).where(author: @actor)
                                        .roots.recent
                                        .includes(:owner, { author: :avatar_attachment }, :user_author, { activity_objects: { mentions: :actor } }, { parent: :author })
    @pagy, @activities = pagy(@activities)

    projects = @profile.projects
    projects = projects.publicly_visible unless @actor == current_actor
    @projects = projects.with_cover_or_first.includes(:rich_text_about).ordered
  end

  include ApplicationHelper

  # Renders the profile form, preloading the state list and (when a state is set) its cities
  # from the CS gem. Authorized via +ActorPolicy#edit?+ on the profile's actor.
  def edit
    authorize @profile.actor
    setup_location_variables
  end

  # Updates the profile and its nested actor attributes (authorized via +ActorPolicy#update?+).
  def update
    authorize @profile.actor
    if @profile.update(profile_params)
      redirect_to public_path_for(current_actor), notice: t("flash.profile_updated")
    else
      setup_location_variables
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def setup_location_variables
    states_hash = CS.states(:BR) || {}
    @states = states_hash.map { |code, name| [ name, code.to_s ] }

    state_code = state_code_for(@profile.state)
    if state_code.present?
      @cities = CS.cities(state_code.to_sym, :BR) || []
    else
      @cities = []
    end
  end

  def set_profile
    @profile = current_user.profiles.first!
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: t("flash.profile_not_found")
  end

  def profile_params
    params.require(:profile).permit(
      :birthday, :phone, :mobile,
      :address, :city, :state, :country, :zipcode,
      :website, :organization, :availability, :instagram,
      actor_attributes: [ :id, :name, :description, :email, :avatar, :cover_image ],
      occupation_list: []
    )
  end
end
