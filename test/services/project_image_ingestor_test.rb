require "test_helper"

class ProjectImageIngestorTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    @project = @actor.actorable.projects.create!(title: "Projeto", about: "<p>Sobre</p>")
  end

  test "creates images from signed ids" do
    signed_ids = 2.times.map { |i| image_blob("foto-#{i}.png").signed_id }

    result = ProjectImageIngestor.new(@project, signed_ids).call

    assert_equal 2, result[:created]
    assert_equal 0, result[:skipped]
    assert_equal 2, @project.project_images.count
  end

  test "ignores blank and invalid signed ids" do
    result = ProjectImageIngestor.new(@project, [ "", nil, "invalid-signed-id" ]).call

    assert_equal 0, result[:created]
    assert_equal 1, result[:skipped]
  end

  test "skips images beyond the limit" do
    (Project::MAX_IMAGES - 1).times { |i| @project.project_images.create!(image: image_blob("fill-#{i}.png")) }
    signed_ids = 2.times.map { |i| image_blob("extra-#{i}.png").signed_id }

    result = ProjectImageIngestor.new(@project, signed_ids).call

    assert_equal 1, result[:created]
    assert_equal 1, result[:skipped]
    assert_equal Project::MAX_IMAGES, @project.project_images.count
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
