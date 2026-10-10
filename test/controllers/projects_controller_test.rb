require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @alice_user = users(:alice)
    @alice = create_profile_for(@alice_user, name: "Alice")
    @alice_user.update!(current_profile: @alice)

    @public_project = @alice.actorable.projects.create!(title: "Projeto Público", about: "<p>Sobre</p>", visibility: :public)
    @draft_project = @alice.actorable.projects.create!(title: "Projeto Rascunho", about: "<p>Sobre</p>", visibility: :draft)
  end

  test "guest can view a public project" do
    get project_path(@public_project)

    assert_response :success
    assert_match "Projeto Público", response.body
  end

  test "guest cannot view a draft project" do
    get project_path(@draft_project)

    assert_response :redirect
  end

  test "owner can view a draft project" do
    sign_in @alice_user

    get project_path(@draft_project)

    assert_response :success
  end
end
