# == Schema Information
#
# Table name: actors
#
#  id                    :bigint           not null, primary key
#  actorable_type        :string           not null
#  description           :text
#  email                 :string
#  name                  :string           not null
#  notification_settings :jsonb
#  sent_contacts_count   :integer          default(0), not null
#  slug                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  activity_object_id    :bigint
#  actorable_id          :bigint           not null
#
# Indexes
#
#  index_actors_on_activity_object_id               (activity_object_id)
#  index_actors_on_actorable_type_and_actorable_id  (actorable_type,actorable_id) UNIQUE
#  index_actors_on_slug                             (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (activity_object_id => activity_objects.id) ON DELETE => nullify
#

# An {Actor} represents a social entity: an individual ({Profile}), a {Group} or the
# {Site} itself. Actors are the *nodes* of the social network.
#
# Two actors are linked by {Tie Ties}. The type of a {Tie} is a {Relation}, and each
# actor can define and customize its own {Relation::Custom custom relations}. Actors
# perform {ActivityAction actions} (follow, like, etc.) on {ActivityObject activity objects}.
#
# == Actor subtypes (Subjects)
# The concrete subtype of an actor is called a *Subject*. It is resolved through Rails'
# +delegated_type :actorable+ and can be a {Profile}, a {Group} or a {Site}. Use {#subject}
# to reach the delegated record and {#subject_type} for its class name.
#
# @see Contact  The ordered pair of actors.
# @see Tie      The materialized link between two actors.
# @see Relation The type of a Tie, which carries {Permission Permissions}.
# @see Activity How actors publish and share content.
class Actor < ApplicationRecord
  extend FriendlyId

  delegated_type :actorable, types: %w[Profile Group Site]

  belongs_to :activity_object, optional: true
  has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"

  has_many :sent_contacts, class_name: "Contact", foreign_key: :sender_id, dependent: :destroy
  has_many :received_contacts, class_name: "Contact", foreign_key: :receiver_id, dependent: :destroy
  has_many :sent_ties, through: :sent_contacts, source: :ties
  has_many :received_ties, through: :received_contacts, source: :ties
  has_many :sent_relations, through: :sent_ties, source: :relation
  has_many :received_relations, through: :received_ties, source: :relation
  has_many :relations, dependent: :destroy
  has_many :sent_actions, class_name: "ActivityAction", dependent: :destroy
  has_many :followings, through: :sent_actions, source: :activity_object
  has_many :authored_activities, class_name: "Activity", foreign_key: :author_id, dependent: :destroy
  has_many :owned_activities, class_name: "Activity", foreign_key: :owner_id, dependent: :destroy

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [100, 100]
    attachable.variant :medium, resize_to_fill: [300, 300]
  end

  has_one_attached :cover_image do |attachable|
    attachable.variant :thumb, resize_to_fill: [800, 300]
  end

  validates :name, presence: true
  validates :actorable_type, presence: true

  friendly_id :name, use: :slugged

  # Actors ordered alphabetically by name.
  #
  # @return [ActiveRecord::Relation<Actor>]
  scope :alphabetic, -> { order(:name) }

  # Actors whose name matches +q+ (case-insensitive substring). Returns all actors when +q+ is blank.
  #
  # @param q [String, nil] the search term.
  # @return [ActiveRecord::Relation<Actor>]
  scope :name_search, ->(q) {
    return all unless q.present?
    where("actors.name ILIKE ?", "%#{sanitize_sql_like(q)}%")
  }

  # Actors restricted to the given subject type(s). Accepts a comma-separated string; aliases
  # such as "User" are normalized (to "Profile"). Returns all actors when +t+ is blank.
  #
  # @param t [String, nil] one or more subject types, comma-separated.
  # @return [ActiveRecord::Relation<Actor>]
  # @see .map_subject_type
  scope :subject_type, ->(t) {
    return all unless t.present?
    types = t.split(",").map { |v| map_subject_type(v) }
    where(actorable_type: types)
  }

  after_create :create_initial_relations

  # The delegated subtype record backing this actor ({Profile}, {Group} or {Site}).
  #
  # @return [Profile, Group, Site] the delegated subject.
  def subject
    actorable
  end

  # The class name of the {#subject} (e.g. "Profile", "Group", "Site").
  #
  # @return [String]
  def subject_type
    actorable_type
  end

  # Normalizes a user-facing subject type into a stored +actorable_type+.
  #
  # "User" is an alias kept for backwards compatibility and maps to "Profile".
  #
  # @param value [String, Symbol] the subject type to normalize (e.g. :user, "group").
  # @return [String] the corresponding +actorable_type+.
  def self.map_subject_type(value)
    type = value.classify
    type == "User" ? "Profile" : type
  end

  # Coerces its argument into an {Actor}.
  #
  # Accepts an {Actor} (returned as-is), an id, an array (mapped element by element),
  # or any subject responding to +#actor+ or +#current_profile+.
  #
  # @param a [Actor, Integer, Array, #actor, #current_profile] the value to normalize.
  # @return [Actor, Array<Actor>] the resolved actor(s).
  # @raise [RuntimeError] when the value cannot be resolved to an {Actor}.
  def self.normalize(a)
    case a
    when Actor then a
    when Integer then find(a)
    when Array then a.map { |e| normalize(e) }
    else
      if a.respond_to?(:actor)
        a.actor || raise("Unable to normalize Actor: #{a.inspect}")
      elsif a.respond_to?(:current_profile)
        a.current_profile || raise("Unable to normalize Actor: #{a.inspect}")
      else
        raise "Unable to normalize Actor: #{a.inspect}"
      end
    end
  end

  # Coerces its argument into an actor id.
  #
  # @param a [Actor, Integer, Array] the value to normalize.
  # @return [Integer, Array<Integer>] the resolved id(s).
  def self.normalize_id(a)
    case a
    when Integer then a
    when Array then a.map { |e| normalize_id(e) }
    else normalize(a).id
    end
  end

  # All the {Relation::Custom custom relations} defined by this actor.
  #
  # @return [ActiveRecord::Relation<Relation::Custom>]
  def relation_customs
    if relations.loaded?
      relations.select { |r| r.type == "Relation::Custom" }
    else
      relations.where(type: "Relation::Custom")
    end
  end

  # Finds a {Relation::Custom} owned by this actor by its (case-insensitive) name.
  #
  # @param name [String, Symbol] the relation name (e.g. "friend").
  # @return [Relation::Custom, nil]
  def relation_custom(name)
    if relations.loaded?
      relation_customs.detect { |r| r.name.to_s.downcase == name.to_s.downcase }
    else
      relation_customs.where("LOWER(name) = ?", name.to_s.downcase).first
    end
  end

  # Ids of the {Relation Relations} this actor owns.
  #
  # @return [Array<Integer>]
  def relation_ids
    @relation_ids ||= relations.pluck(:id)
  end

  # Ids of the {Relation Relations} through which this actor is a receiver of {Tie Ties}.
  #
  # @return [Array<Integer>]
  def received_relation_ids
    @received_relation_ids ||= received_relations.pluck(:id)
  end

  # The default {Relation Relations} used to share an {Activity} owned by this actor,
  # i.e. those granting +read activity+.
  #
  # @return [ActiveRecord::Relation<Relation>]
  def activity_relations
    rels = relations.allowing(:read, :activity)
    if actorable_type == "Group"
      rels = Relation.where(id: rels.pluck(:id) + [Relation::Owner.instance.id])
    end
    rels
  end

  # Ids of the {#activity_relations}.
  #
  # @return [Array<Integer>]
  def activity_relation_ids
    @activity_relation_ids ||= activity_relations.pluck(:id)
  end

  # The {Contact} sent by this actor to +receiver+, if it exists.
  #
  # @param receiver [Actor] the receiving actor.
  # @return [Contact, nil]
  def contact_to(receiver)
    sent_contacts.find_by(receiver: receiver)
  end

  # The {Contact} sent by this actor to +receiver+, creating it when absent.
  #
  # @param receiver [Actor, Integer] the receiving actor or its id.
  # @return [Contact]
  def contact_to!(receiver)
    contact_to(receiver) || sent_contacts.create!(receiver_id: Actor.normalize_id(receiver))
  end

  # All the {Actor Actors} this one is connected to through {Tie Ties}.
  #
  # @param options [Hash] query filters.
  # @option options [Symbol] :direction (:sent) +:sent+ returns the actors this one ties
  #   to; +:received+ returns the actors tying to this one.
  # @option options [String, Array<String>] :type (%w[Profile Group]) restricts the result
  #   to these subject types (aliases such as "User" are normalized).
  # @option options [Relation, Integer, Array] :relations restricts to ties made with these
  #   relations.
  # @option options [Boolean] :include_self (false) whether to include this actor.
  # @option options [Boolean] :positive (true) when +false+, do not restrict to positive relations.
  # @return [ActiveRecord::Relation<Actor>]
  # @example
  #   actor.contact_actors(direction: :sent, type: "Group")
  def contact_actors(options = {})
    direction = options[:direction] || :sent
    as = Actor.where(actorable_type: Array(options[:type] || %w[Profile Group]).map { |t| Actor.map_subject_type(t.to_s) })
    as = as.where.not(id: id) unless options[:include_self]

    as = case direction
    when :sent then as.joins(:received_ties).merge(Contact.sent_by(self))
    when :received then as.joins(:sent_ties).merge(Contact.received_by(self))
    else raise "Unknown direction: #{direction}"
    end

    as = as.merge(Tie.related_by(Relation.normalize_id(options[:relations]))) if options[:relations].present?
    as = as.merge(Relation.positive) if options[:positive] != false
    as
  end

  # The {#subject subjects} behind this actor's {#contact_actors}.
  #
  # @param options [Hash] the same filters accepted by {#contact_actors}.
  # @return [Array<Profile, Group, Site>]
  def contact_subjects(options = {})
    contact_actors(options).includes(:actorable).map(&:subject)
  end

  # Connects this actor to +other_actor+ through one of its {Relation::Custom custom relations},
  # creating the {Contact} and {Tie} when needed.
  #
  # @param other_actor [Actor] the actor to connect to.
  # @param as [String, Symbol] the name of the custom relation to use (or "follow" for the system follow relation).
  # @return [Tie] the resulting tie.
  # @raise [ArgumentError] when no custom relation matches +as+.
  def connect_to(other_actor, as:)
    relation = relation_custom(as) ||
               (as.to_s == "follow" ? Relation::Follow.instance : nil) ||
               (as.to_s == "owner" ? Relation::Owner.instance : nil) ||
               (as.to_s == "local_admin" ? Relation::LocalAdmin.instance : nil) ||
               raise(ArgumentError, "Unknown relation: #{as}")

    contact = sent_contacts.find_or_create_by!(receiver: other_actor)
    contact.sender = self
    contact.receiver = other_actor

    tie = contact.ties.find_by(relation: relation) || contact.ties.build(relation: relation)
    tie.save!
  end

  # Removes the {Tie Ties} of a given relation from this actor to +actor+.
  #
  # @param actor [Actor] the connected actor.
  # @param relation_name [String, Symbol] the custom relation name (or "follow" for the system follow relation).
  # @return [void]
  def disconnect_from(actor, relation_name)
    relation = relation_custom(relation_name) ||
               (relation_name.to_s == "follow" ? Relation::Follow.instance : nil) ||
               (relation_name.to_s == "owner" ? Relation::Owner.instance : nil) ||
               (relation_name.to_s == "local_admin" ? Relation::LocalAdmin.instance : nil)
    return unless relation
    ties_to(actor).where(relation: relation).destroy_all
  end

  # The {Actor Actors} tied to this one through the named {Relation::Custom custom relation}.
  #
  # @param relation_name [String, Symbol] the custom relation name.
  # @return [ActiveRecord::Relation<Actor>]
  def contacts_for(relation_name)
    relation = relation_custom(relation_name) ||
               (relation_name.to_s == "follow" ? Relation::Follow.instance : nil) ||
               (relation_name.to_s == "owner" ? Relation::Owner.instance : nil) ||
               (relation_name.to_s == "local_admin" ? Relation::LocalAdmin.instance : nil)
    return Actor.none unless relation
    Actor.where(id: sent_contacts.joins(:ties).where(ties: { relation_id: relation.id }).select(:receiver_id))
  end

  # Whether this actor has an established (positive) {Contact} to +other_actor+.
  #
  # @param other_actor [Actor]
  # @return [Boolean]
  def connected_with?(other_actor)
    sent_contacts.find_by(receiver: other_actor)&.established?
  end

  # Whether this actor has a {Tie} to +actor+ using a relation named +relation_name+.
  #
  # @param actor [Actor]
  # @param relation_name [String, Symbol]
  # @return [Boolean]
  def has_relation_with?(actor, relation_name)
    ties_to(actor).joins(:relation).where("LOWER(relations.name) = ?", relation_name.to_s.downcase).exists?
  end

  # The role names this actor holds within +group_actor+, derived from the tie relations.
  #
  # @param group_actor [Actor] the {Group}'s actor.
  # @return [Array<String>] downcased role names.
  def member_roles_for(group_actor)
    ties_to(group_actor).joins(:relation).pluck(:"relations.name").map(&:downcase)
  end

  # Incoming contacts still awaiting a reply from this actor.
  #
  # @return [ActiveRecord::Relation<Contact>]
  def pending_contacts
    received_contacts.pending
  end

  # The {Tie Ties} sent by this actor and received by +subject+.
  #
  # @param subject [Actor, Integer] the receiver actor or its id.
  # @return [ActiveRecord::Relation<Tie>]
  def ties_to(subject)
    sent_ties.joins(:contact).where(contacts: { receiver_id: Actor.normalize_id(subject) })
  end

  # Does this actor grant +subject+ permission to perform +action+ on +object+?
  #
  # @param subject [Actor] the actor whose permissions are checked.
  # @param action [Symbol, String] the permission action. Valid values are the keys of {Permission.actions} (e.g. :create, :read).
  # @param object [Symbol, String] the permission object. Valid values are the keys of {Permission.objects} (e.g. :activity, :tie).
  # @return [Boolean]
  def allow?(subject, action, object)
    ties_to(subject).allowing(action, object).exists?
  end

  # Can this actor be represented by +subject+? True for itself, or when a tie grants the
  # +represent+ permission.
  #
  # @param subject [Actor, nil]
  # @return [Boolean]
  def represented_by?(subject)
    return false if subject.blank?
    Actor.normalize(subject) == self ||
      ties_to(subject).joins(relation: :permissions)
                      .where(permissions: { action: :represent }).exists?
  end

  # Receiver ids of this actor's active (established) sent contacts.
  #
  # @return [Array<Integer>]
  def sent_active_contact_ids
    sent_contacts.active.pluck(:receiver_id)
  end

  # Suggests contacts to actors this one is not connected to yet, drawn at random from the
  # subject types configured in +SocialStream.suggested_models+. Each suggestion is
  # materialized as a {Contact}.
  #
  # @param size [Integer] how many suggestions to build.
  # @return [Array<Contact>]
  def suggestions(size = 1)
    candidates = Actor.where(actorable_type: SocialStream.suggested_models.map { |m| m.to_s.classify })
                       .where.not(id: sent_active_contact_ids + [ id ])
                       .order(Arel.sql("RANDOM()"))
                       .limit(size)
    candidates.map { |a| Contact.new(sender: self, receiver: a) }
  end

  # Establishes a bidirectional group membership role or site administration role.
  #
  # @param role [String, Symbol] the role name (e.g. :admin, :member).
  # @param other [Actor, Group, Site] the group or site granting the role.
  # @return [void]
  def add_role(role, other)
    other_actor = other.is_a?(Actor) ? other : other.actor
    other_actor.connect_to(self, as: role)
    self.connect_to(other_actor, as: "follow")
  end

  # Removes a specific role and disconnects the reciprocal follow if no roles remain.
  #
  # @param role [String, Symbol] the role name to remove.
  # @param other [Actor, Group, Site] the group or site.
  # @return [void]
  def remove_role(role, other)
    other_actor = other.is_a?(Actor) ? other : other.actor
    GroupMembershipService.new(other_actor, self).remove(role: role.to_s)
  end

  # Whether this actor holds the role named +role+ within +other+. This is an identity check
  # (which relation the actor is tied by), not an authorization decision — use {#can?} for that.
  #
  # @param role [String, Symbol] the role name.
  # @param other [Actor, Group, Site] the group or site.
  # @return [Boolean]
  def role?(role, other)
    other_actor = other.is_a?(Actor) ? other : other.actor
    other_actor.has_relation_with?(self, role)
  end
  alias_method :has_role?, :role?

  # Whether this actor is allowed to perform +action+ on +object+ within +context+, based on
  # the {Permission Permissions} granted by the {Relation} of the {Tie} the context holds over
  # this actor. This is the single authorization predicate of the domain.
  #
  # @param action [Symbol, String] the permission action (see {Permission.actions}).
  # @param object [Symbol, String, nil] the permission object (see {Permission.objects}).
  # @param context [Actor, Group, Site] the context (defaults to the Site).
  # @return [Boolean]
  def can?(action, object = nil, context = Site.instance)
    context_actor = context.is_a?(Actor) ? context : context.actor
    context_actor ? context_actor.allow?(self, action, object) : false
  end
  alias_method :has_permission?, :can?

  # Stable identifier used by Flipper to gate features per actor. Namespaced by class so it can
  # never collide with another flippable record.
  #
  # @return [String]
  def flipper_id
    "Actor;#{id}"
  end

  # Uses the friendly {#slug} as the URL parameter.
  #
  # @return [String]
  def to_param
    slug
  end

  def self.ransackable_attributes(auth_object = nil)
    ["name", "description"]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  private

  # +after_create+ callback: seeds this actor's default {Relation::Custom custom relations}.
  def create_initial_relations
    Relation::Custom.defaults_for(self)
  end
end
