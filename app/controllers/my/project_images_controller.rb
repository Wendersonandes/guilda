# Management of a {Project}'s gallery images ({ProjectImage}): upload, remove, reorder and set
# one as the project cover. Scoped to the current profile's projects.
#
# @see ProjectImage
# @see Project
module My
  class ProjectImagesController < ApplicationController
    include FeatureGated

    feature_gated_by :projects

    before_action :ensure_profile!
    before_action :set_project

    # POST /my/projects/:project_id/images
    def create
      authorize @project, :update?
      image = @project.project_images.build(image: params.dig(:project_image, :image))

      if image.save
        redirect_to edit_my_project_path(@project), notice: t("flash.project_image_added")
      else
        redirect_to edit_my_project_path(@project), alert: image.errors.full_messages.to_sentence
      end
    end

    # DELETE /my/projects/:project_id/images/:id
    def destroy
      authorize @project, :update?
      @project.project_images.find(params[:id]).destroy

      redirect_to edit_my_project_path(@project), notice: t("flash.project_image_removed")
    end

    # PATCH /my/projects/:project_id/images/reorder
    def reorder
      skip_authorization
      ids = Array(params[:ids]).map(&:to_i)

      @project.project_images.where(id: ids).find_each do |image|
        image.update_column(:position, ids.index(image.id) + 1)
      end

      head :ok
    end

    # POST /my/projects/:project_id/images/:id/cover
    def cover
      authorize @project, :update?
      image = @project.project_images.find(params[:id])
      @project.cover.attach(image.image.blob)

      redirect_to edit_my_project_path(@project), notice: t("flash.project_cover_set")
    end

    private

    def ensure_profile!
      return if current_actor&.actorable.is_a?(Profile)

      redirect_to root_path, alert: t("flash.projects_require_profile")
    end

    def current_profile
      current_actor.actorable
    end

    def set_project
      @project = current_profile.projects.friendly.find(params[:project_id])
    end
  end
end
