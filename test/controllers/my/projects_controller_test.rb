require "test_helper"

module My
  class ProjectsControllerTest < ActionDispatch::IntegrationTest
    setup do
      seed_permissions_and_relations
      @alice_user = users(:alice)
      @alice = create_profile_for(@alice_user, name: "Alice")
      @alice_user.update!(current_profile: @alice)
      sign_in @alice_user
    end

    test "index lists the profile's projects" do
      get my_projects_path

      assert_response :success
    end

    test "renders the new form" do
      get new_my_project_path

      assert_response :success
    end

    test "the new form accepts multiple gallery images" do
      get new_my_project_path

      assert_select "input[type=file][name='project[gallery_signed_ids][]'][multiple]"
    end

    test "renders the wizard with tabs, preview and publish actions" do
      get new_my_project_path

      assert_response :success
      assert_select "div[data-controller~='project-wizard'][data-controller~='project-preview']"
      assert_select "input[type=radio][name='project[visibility]'][value='draft']"
      assert_select "input[type=radio][name='project[visibility]'][value='public']"
      assert_select "input[type=submit][value='Salvar projeto']"
    end

    test "the wizard page is full width without the sidebar frame" do
      get new_my_project_path

      assert_select "div.grid.grid-cols-12", count: 0
    end

    test "the wizard uses independently scrollable panes" do
      get new_my_project_path

      assert_select "[class*='lg:overflow-y-auto']", count: 2
    end

    test "renders the edit form with the gallery" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")

      get edit_my_project_path(project)

      assert_response :success
      assert_select "label[data-controller='dropzone']"
      assert_select "input[type=file][name='project[gallery_signed_ids][]'][multiple]"
    end

    test "creates a project" do
      assert_difference("Project.count", 1) do
        post my_projects_path, params: { project: { title: "Novo Projeto", visibility: "draft", about: "<p>Sobre</p>" } }
      end

      assert_redirected_to my_projects_path
    end

    test "renders flash messages with the auto-dismiss controller" do
      post my_projects_path, params: { project: { title: "Projeto Flash", visibility: "draft", about: "<p>Sobre</p>" } }
      follow_redirect!

      assert_response :success
      assert_select "div[data-controller='flash'][data-flash-timeout-value='4000']"
      assert_select "button[data-action='flash#dismiss']"
    end

    test "creates a project with gallery images from signed ids" do
      signed_ids = 2.times.map { |i| image_blob("foto-#{i}.png").signed_id }

      assert_difference("Project.count", 1) do
        assert_difference("ProjectImage.count", 2) do
          post my_projects_path, params: {
            project: { title: "Novo Projeto", about: "<p>Sobre</p>", gallery_signed_ids: signed_ids }
          }
        end
      end

      assert_redirected_to my_projects_path
    end

    test "creates a public project when publishing" do
      post my_projects_path, params: { project: { title: "Público", about: "<p>Sobre</p>", visibility: "public" } }

      assert_predicate Project.find_by(title: "Público"), :visibility_public?
    end

    test "sets the cover from the selected gallery image" do
      blobs = 2.times.map { |i| image_blob("capa-#{i}.png") }

      post my_projects_path, params: {
        project: { title: "Com capa", about: "<p>Sobre</p>", gallery_signed_ids: blobs.map(&:signed_id), cover_index: "1" }
      }

      project = Project.find_by(title: "Com capa")

      assert project.cover.attached?
      assert_equal blobs[1].id, project.cover.blob.id
    end

    test "preserves the selected gallery order" do
      blobs = 3.times.map { |i| image_blob("ordem-#{i}.png") }
      ordered = [ blobs[2], blobs[0], blobs[1] ]

      post my_projects_path, params: {
        project: { title: "Ordem", about: "<p>Sobre</p>", gallery_signed_ids: ordered.map(&:signed_id) }
      }

      project = Project.find_by(title: "Ordem")

      assert_equal ordered.map(&:id), project.project_images.ordered.map { |image| image.image.blob.id }
    end

    test "ignores gallery signed ids beyond the limit and warns" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
      Project::MAX_IMAGES.times { |i| project.project_images.create!(image: image_blob("fill-#{i}.png")) }
      signed_ids = 2.times.map { |i| image_blob("extra-#{i}.png").signed_id }

      assert_no_difference("ProjectImage.count") do
        patch my_project_path(project), params: { project: { gallery_signed_ids: signed_ids } }
      end

      assert_redirected_to my_projects_path
      assert_match(/não foram adicionadas/, flash[:alert].to_s)
    end

    test "does not create a project without a title" do
      assert_no_difference("Project.count") do
        post my_projects_path, params: { project: { title: "", about: "<p>Sobre</p>" } }
      end

      assert_response :unprocessable_entity
      assert_select "div[data-controller='flash'][role='alert']"
      assert_select "button[data-action='flash#dismiss']"
    end

    test "reorders projects" do
      first = @alice.actorable.projects.create!(title: "Primeiro", about: "<p>S</p>")
      second = @alice.actorable.projects.create!(title: "Segundo", about: "<p>S</p>")

      patch reorder_my_projects_path, params: { ids: [ second.id, first.id ] }, as: :json

      assert_response :success
      assert_equal 1, second.reload.position
      assert_equal 2, first.reload.position
    end

    private

    def image_blob(filename)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake-image-#{filename}"),
        filename: filename,
        content_type: "image/png",
        identify: false
      )
    end
  end
end
