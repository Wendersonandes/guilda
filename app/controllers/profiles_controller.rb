# Editing of the signed-in user's {Profile} (personal fields and the delegated {Actor}
# identity). +show+ simply redirects to the actor's public page. Location selects are populated
# from the +countries+/+cities+ (CS) gem.
#
# @see Profile
# @see ActorPolicy
class ProfilesController < ApplicationController
  # The directory is the public application root, reachable while signed out.
  skip_before_action :authenticate_user!, only: [ :index ]
  before_action :set_profile, only: [ :edit, :update ]
  skip_after_action :verify_policy_scoped, only: [ :index ]

  # GET /profiles
  def index
    authorize Actor, :index?
    
    @cities = Profile.where(wizard_complete: true).where.not(city: [nil, ""]).order(:city).pluck(:city).uniq
    @occupations = Profile::OCCUPATIONS.map { |o| o["name"] }

    @profiles = Profile.joins(:actor)
                       .includes(:occupations, actor: [avatar_attachment: :blob, cover_image_attachment: :blob])
                       .where(wizard_complete: true)
                       .where.not(id: current_actor&.actorable_id)
                       .order("actors.name ASC")

    if params[:name_query].present?
      @profiles = @profiles.where("actors.name ILIKE :q OR actors.description ILIKE :q", q: "%#{params[:name_query]}%")
    end

    if params[:city].present?
      @profiles = @profiles.where(city: params[:city])
    end

    if params[:occupation].present?
      @profiles = @profiles.tagged_with(params[:occupation], on: :occupations)
    end

    @pagy, @profiles = pagy(@profiles, limit: 12)
  end

  def show
    redirect_to public_path_for(current_actor)
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
    @states = states_hash.map { |code, name| [name, code.to_s] }

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
      :website, :organization, :availability,
      actor_attributes: [ :id, :name, :description, :email, :avatar, :cover_image ],
      occupation_list: []
    )
  end
end
