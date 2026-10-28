# Controller for static and marketing pages of the application.
# It handles public requests like the landing page, and bypasses
# normal authentication and authorization checks.
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :landing, :pricing ]
  skip_after_action :verify_authorized, only: [ :landing, :pricing ]

  # Renders the public landing page.
  def landing
    @profiles_count = Profile.listed_in_directory.count
    @occupations = Profile::OCCUPATIONS
  end

  # Renders the pricing and plans page.
  def pricing
  end
end
