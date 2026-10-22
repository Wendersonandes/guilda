require "test_helper"

# == Schema Information
#
# Table name: ties
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  contact_id  :bigint           not null
#  relation_id :bigint           not null
#
# Indexes
#
#  index_ties_on_contact_id_and_relation_id  (contact_id,relation_id) UNIQUE
#  index_ties_on_relation_id                 (relation_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => restrict
#  fk_rails_...  (relation_id => relations.id) ON DELETE => restrict
#
class TieTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @sender = create_profile_for(@alice)
    @receiver = create_profile_for(@bob)
    @contact = Contact.create!(sender: @sender, receiver: @receiver)
  end

  test "counter cache increments contact.ties_count" do
    assert_difference "@contact.reload.ties_count", 1 do
      Tie.create!(contact: @contact, relation: Relation::Public.instance)
    end
  end

  test "validates relation belongs to sender for custom relations" do
    @sender.connect_to(@receiver, as: "follower")
    follower_relation = @sender.relation_custom("follower")

    tie = Tie.new(contact: @contact, relation: follower_relation)
    assert tie.valid?
  end

  include ActiveJob::TestHelper

  test "creates follow activity on first tie via background job" do
    clear_enqueued_jobs
    assert_enqueued_with(job: CreateContactActivityJob) do
      Tie.create!(contact: @contact, relation: Relation::Public.instance)
    end

    assert_difference "Activity.where(verb: :follow).count", 1 do
      perform_enqueued_jobs
    end
  end

  test "#positive? returns true for positive relations" do
    Tie.create!(contact: @contact, relation: Relation::Public.instance)
    tie = Tie.last
    assert tie.positive?
  end

  test "does not create activity for Reject relation" do
    assert_no_enqueued_jobs do
      Tie.create!(contact: @contact, relation: Relation::Reject.instance)
    end
  end
end
