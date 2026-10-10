# Ingests gallery images into a {Project} from Active Storage signed ids (as produced by a
# multi-file direct upload). It respects {Project::MAX_IMAGES}: images beyond the remaining
# slots (or with invalid/unsupported blobs) are skipped.
#
# @see Project
# @see ProjectImage
class ProjectImageIngestor
  # @param project [Project] the project receiving the images.
  # @param signed_ids [Array<String>, nil] the uploaded blob signed ids.
  def initialize(project, signed_ids)
    @project = project
    @signed_ids = Array(signed_ids).reject(&:blank?)
  end

  # Creates the gallery images.
  #
  # @return [Hash] +{ created: Integer, skipped: Integer }+
  def call
    remaining = Project::MAX_IMAGES - @project.project_images.count
    created = 0

    @signed_ids.each do |signed_id|
      break if remaining.zero?

      blob = ActiveStorage::Blob.find_signed(signed_id)
      next unless blob

      image = @project.project_images.build(image: blob)
      if image.save
        created += 1
        remaining -= 1
      end
    end

    { created: created, skipped: @signed_ids.size - created }
  end
end
