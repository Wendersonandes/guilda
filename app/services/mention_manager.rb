# Service object to manage mentions of {Actor Actors} within an {ActivityObject}'s text content.
# It parses the text for @[Name](slug) syntax, resolves the actors, verifies their read permission
# to the content, and synchronizes the {Mention} records. It also triggers notifications
# for newly mentioned actors.
class MentionManager
  # Matches: @[Name](slug)
  # Captures: 1 = Name, 2 = Slug
  MENTION_REGEX = /@\[([^\]]+)\]\(([\w-]+)\)/

  # @param activity_object [ActivityObject] the backing activity object containing the text
  def initialize(activity_object)
    @activity_object = activity_object
    @author = activity_object.author
  end

  # Synchronizes mentions for the activity object based on the new text description.
  #
  # @param text [String, nil] the raw text containing potential mentions
  # @return [Boolean] true if sync was completed, false otherwise
  def call(text)
    return false if @activity_object.nil?
    return false unless Flipper.enabled?(:mentions, @author)

    if text.blank?
      @activity_object.mentions.destroy_all
      return true
    end

    # 1. Parse slugs from the text
    slugs = text.scan(MENTION_REGEX).map(&:second).uniq

    if slugs.blank?
      @activity_object.mentions.destroy_all
      return true
    end

    # 2. Lookup actors matching those slugs (preload actorable)
    actors = Actor.where(slug: slugs).includes(:actorable).to_a

    # 3. Filter actors: must exist, not be the author, and have permission to view the content
    eligible_actors = actors.select do |actor|
      next false if @author && actor.id == @author.id
      @activity_object.visible_to?(actor)
    end

    # 4. Synchronize Mention records
    target_actor_ids = eligible_actors.map(&:id)
    current_mentions = @activity_object.mentions.index_by(&:actor_id)

    # Remove mentions that are no longer in the text
    to_delete_ids = current_mentions.keys - target_actor_ids
    if to_delete_ids.any?
      @activity_object.mentions.where(actor_id: to_delete_ids).destroy_all
    end

    # Create new mentions and notify
    to_create_ids = target_actor_ids - current_mentions.keys
    
    to_create_ids.each do |actor_id|
      actor = eligible_actors.find { |a| a.id == actor_id }
      next unless actor

      @activity_object.mentions.create!(actor: actor)

      # Trigger notification only for new mentions
      # Validation on ApplicationNotifier requires params[:activity] to be present.
      # post_activity gets the creation activity (verb: :post) for this object.
      post_activity = @activity_object.post_activity
      if post_activity
        ActorMentionedNotifier.with(activity: post_activity).deliver_later(actor)
      end
    end

    true
  rescue => e
    Rails.logger.error "MentionManager failed for ActivityObject #{@activity_object.id}: #{e.message}"
    false
  end
end
