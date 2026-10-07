# == Schema Information
#
# Table name: relations
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  receiver_type :string
#  sender_type   :string
#  type          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  actor_id      :bigint
#  parent_id     :bigint
#
# Indexes
#
#  index_relations_on_actor_id   (actor_id)
#  index_relations_on_parent_id  (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => actors.id) ON DELETE => restrict
#  fk_rails_...  (parent_id => relations.id) ON DELETE => nullify
#

# A {Relation} defines the *type* of a {Tie} between two {Actor Actors} (friend, follower,
# public, etc.). It is the bridge between the social graph and authorization: relations carry
# {Permission Permissions}, so establishing a {Tie} grants the receiver the permissions of its
# relation.
#
# == Relation types
# Relations use Single Table Inheritance. The subclasses are:
# * {Relation::Custom}     — user-defined relations, owned by an {Actor} and given a name and permissions.
# * {Relation::Public}     — the default relation for public activities; readable by everyone.
# * {Relation::Follow}     — grants create/read activity and the +follow+ permission.
# * {Relation::Owner}      — full permissions of a {Group} owner.
# * {Relation::LocalAdmin} — administrative permissions over the {Site}.
# * {Relation::Reject}     — marks that a subject does not want to connect; creates no activity.
# * {Relation::Single}     — abstract base for the system-wide (unowned) relations above.
#
# == Relations and audiences
# Each {Activity} is attached to one or more relations through {Audience Audiences}. This
# defines who can reach the activity and the {Permission Permissions} that rule that access.
#
# @see Tie        The link whose type is a relation.
# @see Permission The action/object pairs a relation grants.
# @see Audience   How relations gate access to activities.
class Relation < ApplicationRecord
  belongs_to :actor, optional: true
  belongs_to :parent, class_name: "Relation", optional: true
  has_many :children, class_name: "Relation", foreign_key: :parent_id, dependent: :nullify

  has_many :relation_permissions, dependent: :destroy
  has_many :permissions, through: :relation_permissions
  has_many :ties, class_name: "Tie", dependent: :destroy
  has_many :contacts, through: :ties
  has_many :audiences, dependent: :destroy
  has_many :activities, through: :audiences
  has_many :activity_object_audiences, dependent: :destroy

  validates :name, presence: true

  # Positive relations only (the STI types considered real, active links).
  #
  # @return [ActiveRecord::Relation<Relation>]
  # @see .positive_names
  scope :positive, -> { where(type: positive_names) }

  # Relations granting the permission to perform +action+ on +object+ (authorization).
  #
  # @param action [Symbol, String] the permission action. Valid values are the keys of {Permission.actions} (e.g. :create, :read).
  # @param object [Symbol, String] the permission object. Valid values are the keys of {Permission.objects} (e.g. :activity, :tie).
  # @return [ActiveRecord::Relation<Relation>]
  # @see Permission
  scope :allowing, ->(action, object) {
    joins(:permissions).merge(Permission.where(action: action, object: object))
  }

  class << self
    POSITIVE_NAMES = %w[Relation::Custom Relation::Public Relation::Follow Relation::Owner Relation::LocalAdmin].freeze

    # The STI class names considered *positive* (i.e. real, active links).
    #
    # @return [Array<String>]
    def positive_names
      POSITIVE_NAMES
    end

    # Whether ties of this relation type publish a contact {Activity}. Overridden to
    # +false+ by subclasses such as {Relation::Reject}, {Relation::Owner} and
    # {Relation::LocalAdmin}.
    #
    # @return [Boolean]
    def create_activity?
      true
    end

    # Coerces its argument into a {Relation}.
    #
    # A +String+ is resolved as a {Relation::Custom} name and therefore requires a
    # +:sender+ in +options+.
    #
    # @param r [Relation, String, Integer, Array] the value to normalize.
    # @param options [Hash]
    # @option options [Actor] :sender required when +r+ is a relation name.
    # @return [Relation, Array<Relation>]
    # @raise [RuntimeError] when the value cannot be resolved.
    def normalize(r, options = {})
      case r
      when Relation then r
      when String
        options[:sender]&.relation_custom(r) ||
          raise("Must provide a sender when looking up relations from name: #{r}")
      when Integer then find(r)
      when Array  then r.map { |e| normalize(e, options) }
      else raise "Unable to normalize relation #{r.class}: #{r.inspect}"
      end
    end

    # Coerces its argument into a relation id. See {.normalize} for accepted values.
    #
    # @param r [Relation, String, Integer, Array]
    # @param options [Hash] forwarded to {.normalize}.
    # @return [Integer, Array<Integer>]
    def normalize_id(r, options = {})
      case r
      when Integer then r
      when Array then r.map { |e| normalize_id(e, options) }
      else normalize(r, options).id
      end
    end

    # All the relations that let +subject+ perform +action+ on +object+.
    #
    # Reading activities also includes {Relation::Public} unless disabled.
    #
    # @param subject [Actor] the actor whose access is evaluated (the tie receiver).
    # @param action [Symbol] the permission action. Valid values are the keys of {Permission.actions} (e.g. :create, :read).
    # @param object [Symbol] the permission object. Valid values are the keys of {Permission.objects} (e.g. :activity, :tie).
    # @param options [Hash]
    # @option options [Boolean] :public (true) include {Relation::Public} for +read activity+.
    # @option options [Relation, Integer, Array] :in restrict candidates to these relations.
    # @return [ActiveRecord::Relation<Relation>]
    def allow(subject, action, object, options = {})
      q = select("DISTINCT relations.*")
            .joins(:contacts, :permissions)

      conds = Permission.arel_table[:action].eq(Permission.actions[action])
                       .and(Permission.arel_table[:object].eq(Permission.objects[object]))

      if action == :read && object == :activity && options[:public] != false
        conds = conds.or(Relation.arel_table[:type].eq("Relation::Public"))
      end

      if options[:in].present?
        conds = conds.and(Relation.arel_table[:id].in(normalize_id(Array(options[:in]))))
      end

      conds = conds.and(Contact.arel_table[:receiver_id].eq(Actor.normalize_id(subject)))

      q.where(conds)
    end

    # Boolean variant of {.allow}.
    #
    # @return [Boolean]
    def allow?(*args)
      allow(*args).exists?
    end

    # The relation ids an {Activity} may be shared with so that +subject+ can reach it:
    # {Relation::Public} plus the subject's own and received relation ids.
    #
    # @param subject [Actor, nil]
    # @return [Array<Integer>]
    def ids_shared_with(subject)
      ids = [ Relation::Public.instance.id ]

      if subject.present?
        ids += subject.relation_ids + subject.received_relation_ids
      end

      ids.uniq
    end
  end

  # A scope of relations sharing this relation's sender/receiver mode.
  #
  # @param st [String] sender type.
  # @param rt [String] receiver type.
  # @return [ActiveRecord::Relation<Relation>]
  def mode(st, rt)
    Relation.where(sender_type: st, receiver_type: rt)
  end

  # Is this a positive relation (a real, active link)?
  #
  # @return [Boolean]
  def positive?
    self.class.positive_names.include?(self.class.to_s)
  end

  # Does this relation grant the +follow+ permission?
  #
  # @return [Boolean]
  def follow?
    permissions.follow.exists?
  end

  # The permissions that may be assigned to this relation, used by privacy forms.
  # Overridden by subclasses ({Relation::Custom}, {Relation::Single}).
  #
  # @return [Array, ActiveRecord::Relation<Permission>]
  def available_permissions
    []
  end
end
