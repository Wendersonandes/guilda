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
  def initialize(project, signed_ids, cover_index: nil)
    @project = project
    @signed_ids = Array(signed_ids).reject(&:blank?)
    @cover_index = cover_index
  end

  # Creates the gallery images.
  #
  # @return [Hash] +{ created: Integer, skipped: Integer }+
  def call
    remaining = Project::MAX_IMAGES - @project.project_images.count
    created = 0
    cover_image = nil

    @signed_ids.each_with_index do |signed_id, index|
      break if remaining.zero?

      blob = ActiveStorage::Blob.find_signed(signed_id)
      next unless blob

      image = @project.project_images.build(image: blob)
      if image.save
        cover_image = image if index == @cover_index
        created += 1
        remaining -= 1
      end
    end

    @project.cover.attach(cover_image.image.blob) if cover_image

    { created: created, skipped: @signed_ids.size - created }
  end
end
