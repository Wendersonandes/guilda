# Synchronizes the {Permission} catalog and the relation grants with the
# {SocialStream} configuration. It is idempotent, so it is safe to run on every deploy (and it
# is the operation required after changing `SocialStream.available_permissions` or
# `SocialStream.custom_relations` so existing, already-seeded relations pick up the changes).
#
# Steps:
# 1. Create the missing {Permission} rows for every configured +[action, object]+ pair.
# 2. Grant the missing permissions to the system ({Relation::Single}) relations.
# 3. Grant the missing permissions to every actor's {Relation::Custom custom relations}.
#
# @example
#   PermissionSync.new.call
class PermissionSync
  # Every configured +[action, object]+ pair, from `available_permissions` and
  # `custom_relations`.
  #
  # @return [Array<Array(Symbol, Symbol, nil)>]
  def self.pairs
    pairs = []
    SocialStream.available_permissions.each_value { |list| pairs.concat(list) }
    SocialStream.custom_relations.each_value do |relations|
      relations.each_value { |cfg| pairs.concat(Array(cfg[:permissions])) }
    end
    pairs.map { |action, object| [ action, object ] }.uniq
  end

  def call
    created_permissions = sync_permissions
    single_grants = sync_single_relations
    custom_grants = sync_custom_relations

    { permissions: created_permissions, single_grants: single_grants, custom_grants: custom_grants }
  end

  private

  SINGLE_RELATIONS = [
    Relation::Public,
    Relation::Follow,
    Relation::Reject,
    Relation::Owner,
    Relation::LocalAdmin
  ].freeze

  def sync_permissions
    self.class.pairs.count do |action, object|
      permission = Permission.find_or_initialize_by(action: action, object: object)
      next false unless permission.new_record?
      permission.save!
      true
    end
  end

  def sync_single_relations
    SINGLE_RELATIONS.sum do |klass|
      relation = klass.instance
      klass.permissions.count do |permission|
        grant(relation, permission)
      end
    end
  end

  def sync_custom_relations
    Actor.find_each.sum do |actor|
      subject_type = actor.subject.class.to_s.underscore
      config = SocialStream.custom_relations.with_indifferent_access[subject_type]
      next 0 if config.nil?

      config.sum do |name, cfg|
        relation = actor.relation_custom(name)
        next 0 unless relation

        Array(cfg[:permissions]).count do |action, object|
          permission = Permission.find_by(action: action, object: object)
          permission ? grant(relation, permission) : false
        end
      end
    end
  end

  # Grants +permission+ to +relation+ when missing.
  #
  # @return [Boolean] whether a new grant was created.
  def grant(relation, permission)
    return false if relation.permissions.exists?(permission.id)
    relation.permissions << permission
    true
  end
end
