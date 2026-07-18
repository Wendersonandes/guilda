class ProfileStepsController < ApplicationController
  include Wicked::Wizard
  steps(*Profile::FORM_STEPS.keys)

  skip_after_action :verify_authorized

  before_action :set_profile

  def show
    # Redirect to current_step unless they are allowed to access this step
    unless @profile.allowed_step?(step)
      redirect_to profile_step_path(@profile.current_step) and return
    end

    setup_location_variables if step == :location
    render :show
  end

  def update
    @profile.form_step = step
    if @profile.update(profile_params)
      if step == steps.last
        redirect_to finish_wizard_path
      else
        redirect_to next_wizard_path
      end
    else
      setup_location_variables if step == :location
      render :show, status: :unprocessable_entity
    end
  end

  private

  def setup_location_variables
    states_hash = CS.states(:BR)
    @states = states_hash

    if @profile.state.present?
      code = states_hash.key(@profile.state) || @profile.state
      @cities = CS.cities(code.to_sym, :BR) || []
    else
      @cities = []
    end
  end

  def set_profile
    # Using the current logged in user's profile
    @profile = current_user.profiles.last
    unless @profile
      redirect_to root_path, alert: "Profile not found."
    end
  end

  def profile_params
    if step == :occupation
      params.require(:profile).permit(occupation_list: [])
    else
      params.require(:profile).permit(Profile::FORM_STEPS[step.to_sym])
    end
  end

  def finish_wizard_path
    @profile.update!(wizard_complete: true)
    root_path
  end
end
