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

# The default {Relation} for public content. An {Activity} shared with the public relation
# is readable by everyone, regardless of ties. It grants a single permission: +read activity+.
#
# @see Relation::Single The system-relation base.
# @see Relation#ids_shared_with
class Relation::Public < Relation::Single
  PERMISSIONS = [
    [ "read", "activity" ]
  ].freeze

  # Grants only +read activity+; every other action/object is denied.
  #
  # @param user [Object] unused; kept for interface symmetry.
  # @param action [String]
  # @param object [String]
  # @return [Boolean]
  def allow?(user, action, object)
    action == "read" && object == "activity"
  end
end
