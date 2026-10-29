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
    if params[:wizard_action] == "back" || params[:target_step].present?
      target = params[:target_step].presence&.to_sym
      step_keys = Profile::FORM_STEPS.keys
      target = target if step_keys.include?(target)
      target ||= previous_step_for(step)

      if step == :occupation
        raw_list = params.fetch(:profile, {}).fetch(:occupation_list, [])
        cleaned_list = Array(raw_list).reject(&:blank?)
        if cleaned_list.size <= 3
          @profile.occupation_list = cleaned_list
          @profile.save(validate: false)
        end
        redirect_to wizard_path(target) and return
      elsif step == :location
        @profile.form_step = :location
        if @profile.update(profile_params)
          redirect_to wizard_path(target) and return
        else
          setup_location_variables
          render :show, status: :unprocessable_entity and return
        end
      end
    end

    @profile.form_step = step
    if @profile.update(profile_params)
      if step == steps.last
        complete_wizard_and_redirect
      else
        redirect_to next_wizard_path
      end
    else
      setup_location_variables if step == :location
      render :show, status: :unprocessable_entity
    end
  end

  private

  include ApplicationHelper

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
    # Using the current logged in user's profile
    @profile = current_user.profiles.last
    unless @profile
      redirect_to root_path, alert: t("flash.profile_not_found")
    end
  end

  def profile_params
    if step == :occupation
      raw_list = params.fetch(:profile, {}).fetch(:occupation_list, [])
      cleaned_list = Array(raw_list).reject(&:blank?)
      ActionController::Parameters.new(profile: { occupation_list: cleaned_list }).require(:profile).permit(occupation_list: [])
    else
      params.require(:profile).permit(Profile::FORM_STEPS[step.to_sym])
    end
  end

  def previous_step_for(current_step)
    keys = Profile::FORM_STEPS.keys
    idx = keys.index(current_step.to_sym)
    (idx && idx > 0) ? keys[idx - 1] : keys.first
  end

  def complete_wizard_and_redirect
    @profile.update!(wizard_complete: true)
    plan_id = session.delete(:selected_plan)
    plan = Plan.resolve(plan_id) if plan_id.present?

    if plan && !current_user.subscribed?
      redirect_to_plan_checkout(plan, fallback_path: pricing_path)
    else
      redirect_to finish_wizard_path
    end
  end

  def finish_wizard_path
    root_path
  end
end
