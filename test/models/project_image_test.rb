require "test_helper"

# == Schema Information
#
# Table name: project_images
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#
# Indexes
#
#  index_project_images_on_project_id               (project_id)
#  index_project_images_on_project_id_and_position  (project_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
class ProjectImageTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user, name: "Alice")
    @profile = @actor.actorable
    @project = @profile.projects.create!(title: "Projeto", about: "<p>S</p>")
  end

  test "requires an image" do
    image = @project.project_images.build

    assert_not image.valid?
    assert_includes image.errors[:image], "não pode ficar em branco"
  end

  test "assigns position on create" do
    image = build_image(@project)
    assert_equal 1, image.position
  end

  test "enforces the per-project image limit" do
    Project::MAX_IMAGES.times { build_image(@project) }

    extra = @project.project_images.build
    extra.image.attach(io: StringIO.new("x"), filename: "extra.png", content_type: "image/png")

    assert_not extra.valid?
    assert_includes extra.errors[:base], "limite de #{Project::MAX_IMAGES} imagens por projeto atingido"
  end

  private

  def build_image(project)
    image = project.project_images.build
    image.image.attach(io: StringIO.new("x"), filename: "img-#{SecureRandom.hex(4)}.png", content_type: "image/png")
    image.save!
    image
  end
end
