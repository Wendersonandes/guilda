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

    test "renders the edit form with the gallery" do
      project = @alice.actorable.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")

      get edit_my_project_path(project)

      assert_response :success
    end

    test "creates a project" do
      assert_difference("Project.count", 1) do
        post my_projects_path, params: { project: { title: "Novo Projeto", visibility: "draft", about: "<p>Sobre</p>" } }
      end

      assert_redirected_to my_projects_path
    end

    test "does not create a project without a title" do
      assert_no_difference("Project.count") do
        post my_projects_path, params: { project: { title: "", about: "<p>Sobre</p>" } }
      end

      assert_response :unprocessable_entity
    end

    test "reorders projects" do
      first = @alice.actorable.projects.create!(title: "Primeiro", about: "<p>S</p>")
      second = @alice.actorable.projects.create!(title: "Segundo", about: "<p>S</p>")

      patch reorder_my_projects_path, params: { ids: [ second.id, first.id ] }, as: :json

      assert_response :success
      assert_equal 1, second.reload.position
      assert_equal 2, first.reload.position
    end
  end
end
