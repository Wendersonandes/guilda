# frozen_string_literal: true

# Routing constraint that only lets authenticated site admins reach a mounted Rack app (used to
# protect the Flipper UI, which bypasses Pundit and the application controllers).
#
# @see Flipper::UI
class AdminConstraint
  # @param request [ActionDispatch::Request]
  # @return [Boolean]
  def matches?(request)
    user = request.env["warden"]&.authenticate(scope: :user)
    return false unless user

    user.current_profile&.can?(:read, :admin)
  end
end
