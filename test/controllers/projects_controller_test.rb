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

  test "shows the project label, section headings and gallery lightbox" do
    @public_project.project_images.create!(image: image_blob("foto.png"))

    get project_path(@public_project)

    assert_response :success
    assert_select "p", text: I18n.t("projects.show.project_label")
    assert_select "h2", text: I18n.t("projects.show.images")
    assert_select "h2", text: I18n.t("projects.show.about")
    # The trigger must live inside the lightbox controller scope for the action to bind.
    assert_select "div[data-controller='lightbox'] button[data-action='click->lightbox#open'] img[loading='lazy']"
    assert_select "div[data-controller='lightbox'] [data-lightbox-target='overlay'][role='dialog'][aria-modal='true']"
    assert_select "div[data-controller='lightbox'][data-lightbox-images-value*='active_storage']"
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
