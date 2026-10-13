class RenameOccupationTags < ActiveRecord::Migration[8.1]
  # Occupation names are stored as acts_as_taggable_on tags (Profile#occupation_list), and the
  # directory filters match the tag name exactly. Renaming the generic options in
  # config/occupations.yml must rename (or merge) the existing tags so profiles keep matching
  # the filters and stay checked in the forms.
  RENAMES = {
    "Montador de Exposições" => "Montagem de Exposições",
    "Produtora Cultural" => "Produção Cultural"
  }.freeze

  def up
    RENAMES.each { |from, to| rename_tag(from, to) }
  end

  def down
    RENAMES.each { |from, to| rename_tag(to, from) }
  end

  private

  def rename_tag(from, to)
    old_tag = ActsAsTaggableOn::Tag.find_by(name: from)
    return unless old_tag

    new_tag = ActsAsTaggableOn::Tag.find_by(name: to)
    new_tag ? merge_tags(old_tag, new_tag) : old_tag.update_column(:name, to)
  end

  def merge_tags(old_tag, new_tag)
    ActsAsTaggableOn::Tagging.where(tag_id: old_tag.id).find_each do |tagging|
      if duplicate_tagging?(tagging, new_tag)
        tagging.destroy
      else
        tagging.update_column(:tag_id, new_tag.id)
      end
    end

    old_tag.destroy
    new_tag.update_column(:taggings_count, ActsAsTaggableOn::Tagging.where(tag_id: new_tag.id).count)
  end

  def duplicate_tagging?(tagging, new_tag)
    ActsAsTaggableOn::Tagging.where(
      tag_id: new_tag.id,
      taggable_id: tagging.taggable_id,
      taggable_type: tagging.taggable_type,
      context: tagging.context,
      tagger_id: tagging.tagger_id,
      tagger_type: tagging.tagger_type
    ).exists?
  end
end
