# Controller for static and marketing pages of the application.
# It handles public requests like the landing page, and bypasses
# normal authentication and authorization checks.
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :landing ]
  skip_after_action :verify_authorized, only: [ :landing ]

  # Renders the public landing page.
  def landing
    @profiles_count = Profile.where(wizard_complete: true).count
    @occupations = Profile::OCCUPATIONS
  end
end
