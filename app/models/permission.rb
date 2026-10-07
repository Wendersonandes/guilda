# == Schema Information
#
# Table name: permissions
#
#  id         :bigint           not null, primary key
#  action     :integer          not null
#  object     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_permissions_on_action_and_object            (action,object) UNIQUE
#  index_permissions_on_action_where_object_is_null  (action) UNIQUE WHERE (object IS NULL)
#

# A {Permission} is the unit of authorization in the network. It is a pair of *action* and
# *object* (e.g. +read activity+, +create post+, +follow+). Permissions are assigned to
# {Relation Relations} through {RelationPermission}, so when an actor establishes a {Tie}
# with a given relation, its receiver is granted the relation's permissions.
#
# == Actions
# +create+, +read+, +update+, +destroy+, +follow+ (subscribe to updates) and +represent+
# (act on behalf of another actor).
#
# == Objects
# +activity+, +post+, +comment+, +group+, +member+, +admin+, +role+. A +nil+ object applies the
# action broadly (e.g. +follow+).
#
# @see Relation           The role permissions are attached to.
# @see RelationPermission The join model between relations and permissions.
class Permission < ApplicationRecord
  enum :action, { create: 0, read: 1, update: 2, destroy: 3, follow: 4, represent: 5 }, prefix: :action
  enum :object, { activity: 0, post: 2, comment: 3, group: 4, member: 5, admin: 6, role: 7 }, prefix: :object

  has_many :relation_permissions, dependent: :destroy
  has_many :relations, through: :relation_permissions

  validates :action, presence: true
  validates :object, uniqueness: { scope: :action }

  # Permissions with the +follow+ action.
  #
  # @return [ActiveRecord::Relation<Permission>]
  scope :follow, -> { where(action: :follow) }

  # Permissions with the +represent+ action.
  #
  # @return [ActiveRecord::Relation<Permission>]
  scope :represent, -> { where(action: :represent) }

  class << self
    # Finds or creates each permission described by an array of +[action, object]+ pairs.
    #
    # @param ary [Array<Array(Symbol, Symbol)>] the action/object pairs.
    # @return [Array<Permission>]
    def instances(ary)
      ary.map { |action, object| find_or_create_by(action: action, object: object) }
    end

    # The permissions configured as available for +subject+ (via
    # +SocialStream.available_permissions+), falling back to its base class.
    #
    # @param subject [Profile, Group, Site] the subject whose permissions are looked up.
    # @return [Array] the configured [action, object] permissions.
    # @raise [RuntimeError] when no permissions are configured for the subject type.
    def available(subject)
      subject_type = subject.class.to_s.underscore
      SocialStream.available_permissions[subject_type] ||
        SocialStream.available_permissions[subject.class.base_class.to_s.underscore] ||
        raise("Configure SocialStream.available_permissions[:#{subject_type}]")
    end
  end
end
