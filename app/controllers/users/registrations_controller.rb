class Users::RegistrationsController < Devise::RegistrationsController
  before_action :ensure_password_auth_enabled!, only: [ :create ]

  private

  def ensure_password_auth_enabled!
    return if Flipper.enabled?(:password_authentication)

    redirect_to new_user_registration_path, alert: "O cadastro com e-mail e senha está temporariamente indisponível. Utilize o cadastro rápido com o Google."
  end
end
