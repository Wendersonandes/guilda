# == Schema Information
#
# Table name: audiences
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  activity_id :bigint           not null
#  relation_id :bigint           not null
#
# Indexes
#
#  index_audiences_on_activity_id_and_relation_id  (activity_id,relation_id) UNIQUE
#  index_audiences_on_relation_id                  (relation_id)
#
# Foreign Keys
#
#  fk_rails_...  (activity_id => activities.id) ON DELETE => cascade
#  fk_rails_...  (relation_id => relations.id) ON DELETE => cascade
#

# Join model sharing an {Activity} with a {Relation}. Each {Audience} is equivalent to a
# {Relation}, which defines the {Actor Actors} assigned to it and the {Permission Permissions}
# granted to that audience. Together, an activity's audiences determine who can reach it.
#
# @see Activity
# @see Relation
class Audience < ApplicationRecord
  belongs_to :activity
  belongs_to :relation
end
