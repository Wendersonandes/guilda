# Editing of the signed-in user's {Profile} (personal fields and the delegated {Actor}
# identity). +show+ simply redirects to the actor's public page. Location selects are populated
# from the +countries+/+cities+ (CS) gem.
#
# @see Profile
# @see ActorPolicy
class ProfilesController < ApplicationController
  before_action :set_profile, only: [ :edit, :update ]
  skip_after_action :verify_policy_scoped, only: [ :index ]

  # GET /profiles
  def index
    authorize Actor, :index?
    
    @profiles = Profile.joins(:actor)
                       .includes(actor: [avatar_attachment: :blob, cover_image_attachment: :blob])
                       .where.not(id: current_actor&.actorable_id)
                       .order("actors.name ASC")

    if params[:q].present?
      query = "%#{params[:q].downcase}%"
      @profiles = @profiles.where(
        "LOWER(actors.name) LIKE :query OR LOWER(profiles.city) LIKE :query OR LOWER(profiles.state) LIKE :query OR LOWER(actors.description) LIKE :query",
        query: query
      )
    end

    @pagy, @profiles = pagy(@profiles, limit: 12)
  end

  def show
    redirect_to public_path_for(current_actor)
  end

  # Renders the profile form, preloading the state list and (when a state is set) its cities
  # from the CS gem. Authorized via +ActorPolicy#edit?+ on the profile's actor.
  def edit
    authorize @profile.actor
    states_hash = CS.states(:BR)
    @states = states_hash

    if @profile.state.present?
      code = states_hash.key(@profile.state) || @profile.state
      @cities = CS.cities(code.to_sym, :BR) || []
    else
      @cities = []
    end
  end

  # Updates the profile and its nested actor attributes (authorized via +ActorPolicy#update?+).
  def update
    authorize @profile.actor
    if @profile.update(profile_params)
      redirect_to public_path_for(current_actor), notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_profile
    @profile = current_user.profiles.first!
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "No profile found. Please create one first."
  end

  def profile_params
    params.require(:profile).permit(
      :birthday, :phone, :mobile,
      :address, :city, :state, :country, :zipcode,
      :website, :organization,
      actor_attributes: [ :id, :name, :description, :email, :avatar, :cover_image ]
    )
  end
end
