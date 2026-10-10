# Public read access to a {Project} portfolio entry. Visibility is enforced by
# {ProjectPolicy#show?}: public projects are readable by everyone, while drafts and private
# projects are only readable by the owning profile.
#
# @see Project
# @see ProjectPolicy
class ProjectsController < ApplicationController
  include FeatureGated

  skip_before_action :authenticate_user!, only: [ :show ]

  feature_gated_by :projects

  # GET /projects/:slug
  def show
    @project = Project.friendly.find(params[:id])
    authorize @project
    @images = @project.project_images.includes(image_attachment: :blob).ordered
  end
end
