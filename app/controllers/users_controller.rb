# Account settings for the signed-in {User} (the authentication identity). Every action
# operates on +current_user+ and is authorized via {UserPolicy} (a user may only manage itself).
#
# @see User
# @see UserPolicy
class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update ]

  def show
    authorize @user
  end

  def edit
    authorize @user
  end

  # Updates account credentials with the current password (Devise's +update_with_password+),
  # re-authenticating the session when the password changes. Authorized via +UserPolicy#update?+.
  def update
    authorize @user
    if @user.update_with_password(user_params)
      bypass_sign_in(@user) if user_params[:password].present?
      redirect_to account_path, notice: t("flash.account_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:email, :current_password, :password, :password_confirmation)
  end
end
