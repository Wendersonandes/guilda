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

# Abstract base for *system* (unowned) {Relation Relations}: those that exist once for the
# whole application rather than per {Actor}. Subclasses declare their permissions through the
# +PERMISSIONS+ constant (an array of +[action, object]+ pairs) and are reached as singletons
# through {.instance}.
#
# @abstract Subclassed by {Relation::Public}, {Relation::Follow}, {Relation::Owner},
#   {Relation::LocalAdmin} and {Relation::Reject}.
# @see Relation
class Relation::Single < Relation
  PERMISSIONS = [].freeze

  class << self
    # The singleton record for this system relation, creating it (with its {.permissions})
    # on first access.
    #
    # @return [Relation::Single]
    def instance
      if @instance&.persisted? && exists?(@instance.id)
        @instance
      else
        @instance = first || create!(
          name: name.demodulize.underscore,
          permissions: permissions
        )
      end
    end

    # The {Permission Permissions} declared by this subclass's +PERMISSIONS+ constant.
    #
    # @return [ActiveRecord::Relation<Permission>]
    def permissions
      with_object = self::PERMISSIONS.select { |_, obj| obj.present? }
      without_object = self::PERMISSIONS.select { |_, obj| obj.blank? }

      scope = Permission.none
      scope = scope.or(Permission.where(action: with_object.map(&:first), object: with_object.map(&:second))) if with_object.any?
      scope = scope.or(Permission.where(action: without_object.map(&:first), object: nil)) if without_object.any?
      scope
    end

    # @return [Boolean] whether ties of this relation publish a contact {Activity}.
    def create_activity?
      true
    end
  end

  # The localized display name of this system relation.
  #
  # @return [String]
  def name
    I18n.t("relation.#{self.class.name.demodulize.underscore}.name")
  end

  # The permissions assignable to this relation (its subclass's declared permissions).
  #
  # @return [ActiveRecord::Relation<Permission>]
  def available_permissions
    self.class.permissions
  end
end
