class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user&.persisted?
      flash[:notice] = I18n.t("devise.omniauth_callbacks.success", kind: "Google")
      sign_in_and_redirect @user, event: :authentication
    else
      auth_data = request.env["omniauth.auth"]
      session["devise.google_data"] = auth_data.except("extra") if auth_data
      error_message = @user&.errors&.full_messages&.to_sentence.presence ||
                      I18n.t("devise.omniauth_callbacks.failure", kind: "Google", reason: "Erro desconhecido")
      redirect_to new_user_registration_url, alert: error_message
    end
  end

  def failure
    redirect_to root_path, alert: I18n.t("devise.omniauth_callbacks.failure", kind: "Google", reason: failure_message)
  end
end
