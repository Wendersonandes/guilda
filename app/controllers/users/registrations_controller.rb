class Users::RegistrationsController < Devise::RegistrationsController
  before_action :ensure_password_auth_enabled!, only: [ :create ]

  def create
    super do |resource|
      if resource.persisted?
        is_contractor = (params[:intent] == "contractor" || params[:plan] == "none" || session[:signup_intent] == "contractor")
        if is_contractor
          resource.profiles.last&.update_columns(wizard_complete: true)
          session.delete(:selected_plan)
          session.delete(:signup_intent)
          session[:open_onboarding] = true
          session[:new_contractor_signup] = true
        end
      end
    end
  end

  protected

  def after_sign_up_path_for(resource)
    if session.delete(:new_contractor_signup) || (resource.profiles.last&.wizard_complete? && resource.profiles.last&.contractor?)
      profiles_path
    else
      profile = resource.profiles.last
      if profile && !profile.wizard_complete?
        profile_step_path(profile.current_step)
      else
        super
      end
    end
  end

  private

  def ensure_password_auth_enabled!
    return if Flipper.enabled?(:password_authentication)

    redirect_to new_user_registration_path, alert: "O cadastro com e-mail e senha está temporariamente indisponível. Utilize o cadastro rápido com o Google."
  end
end
