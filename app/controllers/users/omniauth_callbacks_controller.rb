class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    plan_param = request.env.dig("omniauth.params", "plan").presence || params[:plan].presence
    if plan_param.present?
      if plan_param == "none"
        session.delete(:selected_plan)
      elsif (plan = Plan.resolve(plan_param))
        session[:selected_plan] = plan.id
      end
    end

    intent_param = request.env.dig("omniauth.params", "intent").presence || params[:intent].presence
    if intent_param.present?
      session[:signup_intent] = intent_param
    end

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
