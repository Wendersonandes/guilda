# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  position    :integer          default(0), not null
#  slug        :string           not null
#  title       :string           not null
#  visibility  :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  profile_id  :bigint           not null
#
# Indexes
#
#  index_projects_on_profile_id               (profile_id)
#  index_projects_on_profile_id_and_position  (profile_id,position)
#  index_projects_on_slug                     (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (profile_id => profiles.id) ON DELETE => cascade
#

# A {Project} is a portfolio entry owned by a {Profile}: work the professional
# contributed to, performed or executed. It holds a title, a rich text +about+, a
# +cover+ image and up to {MAX_IMAGES} reorderable {ProjectImage gallery images}.
#
# Visibility is controlled by the +visibility+ enum: +draft+ (only the owner),
# +public+ (everyone) and +private+.
#
# @see ProjectImage
# @see Profile
class Project < ApplicationRecord
  extend FriendlyId

  # Maximum number of gallery images per project.
  MAX_IMAGES = 10
  # Allowed content types and max size for the cover image.
  ALLOWED_COVER_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_COVER_SIZE = 5.megabytes

  belongs_to :profile
  has_rich_text :about
  has_one_attached :cover do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 400, 300 ]
  end
  has_many :project_images, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :project

  enum :visibility, { draft: 0, public: 1, private: 2 }, prefix: :visibility

  validates :title, presence: true
  validate :about_must_be_present
  validate :cover_must_be_acceptable, if: -> { cover.attached? }

  before_validation :assign_position, on: :create

  friendly_id :title, use: :slugged

  # Projects in display order.
  scope :ordered, -> { order(:position, :id) }

  # Eager loads the associations used by {#cover_or_first} (cover + first gallery image).
  scope :with_cover_or_first, -> { with_attached_cover.includes(project_images: { image_attachment: :blob }) }

  # Publicly visible projects.
  scope :publicly_visible, -> { where(visibility: self.visibilities[:public]) }

  # Whether +viewer+ (an {Actor}) may see this project.
  #
  # @param viewer [Actor, nil]
  # @return [Boolean]
  def visible_to?(viewer)
    visibility_public? || (viewer.present? && viewer.id == profile.actor&.id)
  end

  # Localized label for the current visibility.
  #
  # @return [String]
  def visibility_label
    I18n.t("projects.visibilities.#{visibility}")
  end

  # The image used as the project cover: the uploaded cover when present, otherwise the first
  # gallery image.
  #
  # @return [ActiveStorage::Attached::One, ActiveStorage::Attached::One, nil]
  def cover_or_first
    cover.attached? ? cover : project_images.first&.image
  end

  private

  def about_must_be_present
    errors.add(:about, "não pode ficar em branco") if about.to_plain_text.blank?
  end

  def cover_must_be_acceptable
    blob = cover.blob
    unless ALLOWED_COVER_TYPES.include?(blob.content_type)
      errors.add(:cover, "deve ser uma imagem PNG, JPEG ou WebP")
    end
    errors.add(:cover, "deve ter no máximo #{MAX_COVER_SIZE / 1.megabyte}MB") if blob.byte_size > MAX_COVER_SIZE
  end

  def assign_position
    return if position.to_i.positive?

    self.position = (profile ? (profile.projects.maximum(:position) || 0) + 1 : 1)
  end
end
