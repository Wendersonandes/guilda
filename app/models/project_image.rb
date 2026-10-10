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
#  index_project_images_on_project_id                (project_id)
#  index_project_images_on_project_id_and_position   (project_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#

# A {ProjectImage} is a gallery image attached to a {Project}. Up to {Project::MAX_IMAGES}
# images are allowed per project, they can be reordered and one of them can be used as the
# project cover.
#
# @see Project
class ProjectImage < ApplicationRecord
  # Allowed content types and max size for gallery images.
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_IMAGE_SIZE = 10.megabytes

  belongs_to :project
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 400, 400 ]
  end

  validates :image, presence: true
  validate :image_must_be_acceptable, if: -> { image.attached? }
  validate :within_limit, on: :create

  before_validation :assign_position, on: :create

  # Images in display order.
  scope :ordered, -> { order(:position, :id) }

  private

  def image_must_be_acceptable
    blob = image.blob
    unless ALLOWED_IMAGE_TYPES.include?(blob.content_type)
      errors.add(:image, "deve ser uma imagem PNG, JPEG ou WebP")
    end
    errors.add(:image, "deve ter no máximo #{MAX_IMAGE_SIZE / 1.megabyte}MB") if blob.byte_size > MAX_IMAGE_SIZE
  end

  def within_limit
    return if project.blank?
    return if ProjectImage.where(project: project).count < Project::MAX_IMAGES

    errors.add(:base, "limite de #{Project::MAX_IMAGES} imagens por projeto atingido")
  end

  def assign_position
    return if position.to_i.positive?

    self.position = (project ? (project.project_images.maximum(:position) || 0) + 1 : 1)
  end
end
