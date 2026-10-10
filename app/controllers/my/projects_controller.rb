# Management of the signed-in profile's {Project Projects} (portfolio). Scoped to the current
# profile, so a user can only manage their own projects.
#
# @see Project
# @see ProjectPolicy
module My
  class ProjectsController < ApplicationController
    include FeatureGated

    feature_gated_by :projects

    before_action :ensure_profile!
    before_action :set_project, only: [ :edit, :update, :destroy ]

    # GET /my/projects
    def index
      authorize Project, :index?
      @projects = policy_scope(current_profile.projects).with_cover_or_first.ordered
    end

    # GET /my/projects/new
    def new
      @project = current_profile.projects.build
      authorize @project
    end

    # POST /my/projects
    def create
      @project = current_profile.projects.build(project_params)
      authorize @project

      if @project.save
        ingest_gallery
        redirect_to my_projects_path, notice: t("flash.project_created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /my/projects/:id/edit
    def edit
      authorize @project
    end

    # PATCH/PUT /my/projects/:id
    def update
      authorize @project

      if @project.update(project_params)
        ingest_gallery
        redirect_to my_projects_path, notice: t("flash.project_updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /my/projects/:id
    def destroy
      authorize @project
      @project.destroy
      redirect_to my_projects_path, notice: t("flash.project_deleted")
    end

    # PATCH /my/projects/reorder
    def reorder
      skip_authorization
      ids = Array(params[:ids]).map(&:to_i)

      current_profile.projects.where(id: ids).find_each do |project|
        project.update_column(:position, ids.index(project.id) + 1)
      end

      head :ok
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
      @project = current_profile.projects.friendly.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:title, :visibility, :about, :cover)
    end

    def gallery_signed_ids
      Array(params.dig(:project, :gallery_signed_ids))
    end

    def ingest_gallery
      result = ProjectImageIngestor.new(@project, gallery_signed_ids).call

      if result[:skipped].positive?
        flash[:alert] = t("flash.project_gallery_skipped", count: result[:skipped])
      end
    end
  end
end
