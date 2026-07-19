# == Schema Information
#
# Table name: activities
#
#  id             :bigint           not null, primary key
#  verb           :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  author_id      :bigint           not null
#  owner_id       :bigint           not null
#  parent_id      :bigint
#  user_author_id :bigint
#
# Indexes
#
#  index_activities_on_author_id       (author_id)
#  index_activities_on_created_at      (created_at)
#  index_activities_on_owner_id        (owner_id)
#  index_activities_on_parent_id       (parent_id)
#  index_activities_on_user_author_id  (user_author_id)
#  index_activities_on_verb            (verb)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => actors.id) ON DELETE => restrict
#  fk_rails_...  (owner_id => actors.id) ON DELETE => restrict
#  fk_rails_...  (parent_id => activities.id) ON DELETE => nullify
#  fk_rails_...  (user_author_id => users.id) ON DELETE => restrict
#

# An {Activity} follows the {https://activitystrea.ms/ Activity Streams} standard: it records
# something an actor did (e.g. "John liked this post"). The action itself is the {#verb}.
#
# Every activity distinguishes three roles:
# * *author* — the {Actor} that originated the activity (posted, liked, etc.).
# * *user_author* — the {User} logged in when the activity was created. When a user acts on
#   behalf of another entity (e.g. a {Group}), the user_author still points to that user.
# * *owner* — the {Actor} whose wall the activity lands on (whose post was liked, etc.).
#
# == Audiences and visibility
# An activity is attached to one or more {Relation Relations} through {Audience Audiences},
# which define who can reach it. With a {Relation::Public public relation} everyone can see it;
# with {Relation::Custom custom relations} only the actors holding a {Tie} of that relation can.
# See {#public?} and {#visible_to?}.
#
# == Threading
# Activities form a tree through +parent+/+children+ (a comment or like is a child of the
# activity it targets), rather than a flat list.
#
# @see ActivityObject The content ({Post}, actor, etc.) an activity is about.
# @see Audience       The join with relations that defines visibility.
# @see Relation       The audience/permission rules.
class Activity < ApplicationRecord
  enum :verb, { follow: 0, like: 1, make_friend: 2, post: 3, update: 4, join: 5, dislike: 6, flag: 7 }, prefix: :verb

  attr_accessor :relation_ids_to_authorize, :current_user_vote, :current_user_flagged

  belongs_to :author, class_name: "Actor"
  belongs_to :owner, class_name: "Actor"
  belongs_to :user_author, class_name: "User", optional: true
  belongs_to :parent, class_name: "Activity", optional: true
  has_many :children, class_name: "Activity", foreign_key: :parent_id, dependent: :destroy
  has_many :likes, -> { where(verb: :like) }, class_name: "Activity", foreign_key: :parent_id, dependent: :destroy
  has_many :noticed_events, as: :record, class_name: "Noticed::Event", dependent: :destroy

  has_many :audiences, dependent: :destroy, autosave: true
  has_many :relations, through: :audiences
  has_many :activity_object_activities, dependent: :destroy
  has_many :activity_objects, through: :activity_object_activities

  validates :verb, presence: true
  validates :author, :owner, presence: true

  after_create :increment_like_count, if: :verb_like?
  after_destroy :decrement_like_count, if: :verb_like?

  after_create_commit :notify_followers_of_new_post, if: -> { verb_post? && root? && direct_object&.objectable_type == "Post" }
  after_create_commit :notify_owner_of_new_like, if: -> { verb_like? && parent.present? && parent.author != author }
  after_create_commit :notify_owner_of_new_comment, if: -> { verb_post? && parent.present? && direct_object&.objectable_type == "Comment" && parent.author != author }
  after_create_commit :notify_owner_of_new_follower, if: -> { (verb_follow? || verb_make_friend?) && owner.present? && owner != author && !author.subject.is_a?(Site) }


  # Activities authored by +actor+. Returns all activities when +actor+ is blank.
  #
  # @param actor [Actor, Integer, nil] the author (or its id).
  # @return [ActiveRecord::Relation<Activity>]
  scope :authored_by, ->(actor) { where(author: Actor.normalize_id(actor)) if actor.present? }

  # Activities owned by +actor+ (landed on its wall). Returns all activities when +actor+ is blank.
  #
  # @param actor [Actor, Integer, nil] the owner (or its id).
  # @return [ActiveRecord::Relation<Activity>]
  scope :owned_by, ->(actor) { where(owner: Actor.normalize_id(actor)) if actor.present? }

  # Activities +subject+ is allowed to reach, resolved through their {Audience audiences}: the
  # relations shared with the subject plus the {Relation::Public public relation}.
  #
  # @param subject [Actor, nil] the viewer; +nil+ yields only public activities.
  # @return [ActiveRecord::Relation<Activity>]
  # @see Relation.ids_shared_with
  scope :shared_with, ->(subject) {
    joins(:audiences).merge(Audience.where(relation_id: Relation.ids_shared_with(subject)))
  }

  # Root activities only (no parent), i.e. excluding comments and likes.
  #
  # @return [ActiveRecord::Relation<Activity>]
  scope :roots, -> { where(parent_id: nil) }

  # Post activities only (excluding likes, comments, follows, etc.).
  #
  # @return [ActiveRecord::Relation<Activity>]
  scope :posts, -> { where(verb: :post) }

  # Activities ordered from newest to oldest by creation time.
  #
  # @return [ActiveRecord::Relation<Activity>]
  scope :recent, -> { order(created_at: :desc) }

  # The wall timeline: the root activities visible to +actor+, most recent first, eager-loading
  # the associations needed to render the stream.
  #
  # @param actor [Actor] the viewer.
  # @return [ActiveRecord::Relation<Activity>]
  # @see .shared_with
  scope :timeline, ->(actor) {
    select("DISTINCT activities.*")
      .roots
      .includes(:owner, { author: :avatar_attachment }, :user_author, { activity_objects: [:received_actions, { mentions: :actor }] }, { parent: :author }, :likes)
      .shared_with(actor)
      .recent
  }

  # The home timeline: root activities authored by +actor+ or by its active contacts, filtered
  # to those +actor+ can reach, most recent first.
  #
  # @param actor [Actor] the viewer.
  # @return [ActiveRecord::Relation<Activity>]
  # @see Actor#sent_active_contact_ids
  # @see .shared_with
  scope :home_timeline, ->(actor) {
    ids = actor.sent_active_contact_ids + [ actor.id ]
    select("DISTINCT activities.*")
      .roots
      .includes(:owner, { author: :avatar_attachment }, :user_author, { activity_objects: [:received_actions, { mentions: :actor }] }, { parent: :author }, :likes)
      .where(author_id: ids)
      .shared_with(actor)
      .recent
  }

  # Returns the recursive tree of comment activities for the given root activity (e.g. a Post),
  # ordered by Wilson confidence and creation date, preserving the tree depth hierarchy.
  #
  # @param root_activity [Activity]
  # @return [Array<Activity>]
  def self.comment_thread_tree(root_activity)
    activities = find_by_sql([<<~SQL, root_activity_id: root_activity.id])
      WITH RECURSIVE thread AS (
        SELECT a.*, (1.0 - c.confidence) AS sort_confidence, 0 AS sort_depth
        FROM activities a
        INNER JOIN activity_object_activities aoa ON aoa.activity_id = a.id AND aoa.object_type = 'Comment'
        INNER JOIN activity_objects ao ON ao.id = aoa.activity_object_id
        INNER JOIN comments c ON c.id = ao.objectable_id AND ao.objectable_type = 'Comment'
        WHERE a.parent_id = :root_activity_id
        
        UNION ALL
        
        SELECT a.*, (1.0 - c.confidence) AS sort_confidence, thread.sort_depth + 1
        FROM activities a
        INNER JOIN activity_object_activities aoa ON aoa.activity_id = a.id AND aoa.object_type = 'Comment'
        INNER JOIN activity_objects ao ON ao.id = aoa.activity_object_id
        INNER JOIN comments c ON c.id = ao.objectable_id AND ao.objectable_type = 'Comment'
        INNER JOIN thread ON a.parent_id = thread.id
      )
      SEARCH DEPTH FIRST BY sort_confidence, created_at SET sort_order
      SELECT * FROM thread
      ORDER BY sort_order
    SQL

    ActiveRecord::Associations::Preloader.new(
      records: activities,
      associations: [
        { author: :avatar_attachment },
        :user_author,
        { activity_objects: :objectable }
      ]
    ).call

    activities
  end

  # Is this a root activity (no parent), i.e. not a comment or like of another activity?
  #
  # @return [Boolean]
  def root?
    parent_id.nil?
  end

  # The root of this activity's thread: its {#parent} or itself.
  #
  # @return [Activity]
  def root
    parent || self
  end

  # Does this activity have the same author and owner (posted on one's own wall)?
  #
  # @return [Boolean]
  def reflexive?
    author_id == owner_id
  end

  # Was the {#author} acting on behalf of another entity (author differs from user_author)?
  #
  # @return [Boolean]
  def represented_author?
    author_id != user_author_id
  end

  # Is this activity shared through a {Relation::Public public relation} (visible to everyone)?
  #
  # @return [Boolean]
  def public?
    relations.where(type: "Relation::Public").exists?
  end

  # Can +subject+ reach this activity? True when public, or when +subject+ holds a relation
  # this activity is shared with.
  #
  # @param subject [Actor, nil]
  # @return [Boolean]
  def visible_to?(subject)
    return true if public?
    return true if subject.present? && relations.exists?(id: Relation.ids_shared_with(subject))
    false
  end

  # The {Actor} that originated this activity. Alias of {#author}.
  #
  # @return [Actor]
  def sender
    author
  end

  # The {Actor} whose wall this activity belongs to. Alias of {#owner}.
  #
  # @return [Actor]
  def receiver
    owner
  end

  # The child activities that are comments on this one.
  #
  # @return [ActiveRecord::Relation<Activity>]
  def comments
    children.includes(:activity_objects)
            .joins(:activity_object_activities)
            .where(activity_object_activities: { object_type: "Comment" })
  end



  # Has +actor+ liked this activity?
  #
  # @param actor [Actor]
  # @return [Boolean]
  def liked_by?(actor)
    likes.exists?(author: actor)
  end

  # The first {ActivityObject} attached to this activity (its direct object).
  #
  # @return [ActivityObject, nil]
  def direct_object
    activity_objects.first
  end

  # The {Actor Actors} this activity is shared with: its author, user_author's profile and
  # owner, plus everyone holding a {Tie} of the activity's relations.
  #
  # @return [Array<Actor>]
  # @raise [RuntimeError] when the activity is public (audience is unbounded).
  def audience
    raise "Cannot get the audience of a public activity!" if public?

    [ author, user_author&.current_profile, owner ].compact.uniq |
      Actor.joins(:received_ties)
           .merge(Tie.where(relation_id: relation_ids))
  end

  # A localized, human-readable description of who can see this activity, from +subject+'s
  # point of view (public, the relations they see, or hidden).
  #
  # @param subject [Actor] the viewer.
  # @param details [Symbol] the I18n detail level (:full by default).
  # @return [String]
  def audience_in_words(subject, details: :full)
    public_relation = relations.select { |r| r.is_a?(Relation::Public) }

    visibility, audience =
      if public_relation.present?
        [ :public, nil ]
      else
        visible_relations = relations.select { |r| r.actor_id == Actor.normalize_id(subject) }

        if visible_relations.present?
          [ :visible, visible_relations.map(&:name).uniq.join(", ") ]
        else
          [ :hidden, relations.map(&:actor).map(&:name).uniq.join(", ") ]
        end
      end

    I18n.t("activity.audience.#{visibility}.#{details}", audience: audience)
  end

  private

  def targeted_activity_object
    if root?
      direct_object
    else
      parent&.direct_object
    end
  end

  def increment_like_count
    targeted_activity_object&.increment!(:like_count)
  end

  def decrement_like_count
    targeted_activity_object&.decrement!(:like_count)
  end

  def notify_followers_of_new_post
    return unless author&.activity_object
    followers = author.activity_object.followers.merge(ActivityAction.followed)
    PostPublishedNotifier.with(activity: self, record: self).deliver_later(followers, wait: 5.seconds)
  end

  def notify_owner_of_new_like
    return unless parent&.author
    ObjectLikedNotifier.with(activity: self, record: self).deliver_later(parent.author, wait: 5.seconds)
  end

  def notify_owner_of_new_comment
    return unless parent&.author
    ObjectCommentedNotifier.with(activity: self, record: self).deliver_later(parent.author, wait: 5.seconds)
  end

  def notify_owner_of_new_follower
    return unless owner
    NewFollowerNotifier.with(activity: self, record: self).deliver_later(owner, wait: 5.seconds)
  end
end
