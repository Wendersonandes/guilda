# Ingests gallery images into a {Project} from Active Storage signed ids (as produced by a
# multi-file direct upload). It respects {Project::MAX_IMAGES}: images beyond the remaining
# slots (or with invalid/unsupported blobs) are skipped.
#
# @see Project
# @see ProjectImage
class ProjectImageIngestor
  # @param project [Project] the project receiving the images.
  # @param signed_ids [Array<String>, nil] the uploaded blob signed ids.
  # @param cover_index [Integer, nil] the position (in +signed_ids+) of the image to use as cover.
  # @param cover_image_id [Integer, nil] the id of an existing ProjectImage to use as cover.
  # @param image_order [Array<String>, String, nil] the ordered sequence of existing and new image tokens.
  def initialize(project, signed_ids, cover_index: nil, cover_image_id: nil, image_order: nil)
    @project = project
    @signed_ids = Array(signed_ids).reject(&:blank?)
    @cover_index = cover_index
    @cover_image_id = cover_image_id.presence&.to_i
    @image_order = parse_image_order(image_order)
  end

  # Creates the gallery images.
  #
  # @return [Hash] +{ created: Integer, skipped: Integer }+
  def call
    remaining = Project::MAX_IMAGES - @project.project_images.count
    created = 0
    new_images = []
    cover_image = nil

    @signed_ids.each_with_index do |signed_id, index|
      break if remaining.zero?

      blob = ActiveStorage::Blob.find_signed(signed_id)
      next unless blob

      image = @project.project_images.build(image: blob)
      if image.save
        new_images << image
        cover_image = image if index == @cover_index
        created += 1
        remaining -= 1
      end
    end

    if cover_image
      @project.cover.attach(cover_image.image.blob)
    elsif @cover_image_id
      existing_cover = @project.project_images.find_by(id: @cover_image_id)
      @project.cover.attach(existing_cover.image.blob) if existing_cover
    end

    apply_image_order(new_images) if @image_order.present?

    { created: created, skipped: @signed_ids.size - created }
  end

  private

  def parse_image_order(order)
    return [] if order.blank?

    parsed = order.is_a?(String) ? (JSON.parse(order) rescue []) : Array(order)
    Array(parsed).map(&:to_s).reject(&:blank?)
  end

  def apply_image_order(new_images)
    ordered_records = []
    existing_by_id = @project.project_images.index_by(&:id)

    @image_order.each do |token|
      if token.start_with?("existing:")
        id = token.delete_prefix("existing:").to_i
        image = existing_by_id[id]
        ordered_records << image if image
      elsif token.start_with?("new:")
        idx = token.delete_prefix("new:").to_i
        image = new_images[idx]
        ordered_records << image if image
      elsif token.match?(/\A\d+\z/)
        image = existing_by_id[token.to_i]
        ordered_records << image if image
      end
    end

    all_images = @project.project_images.to_a
    unlisted = all_images - ordered_records
    final_order = (ordered_records + unlisted).uniq

    final_order.each_with_index do |image, index|
      image.update_column(:position, index + 1)
    end
  end
end
