require "test_helper"

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
class RelationTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @public = Relation::Public.instance
    @follow = Relation::Follow.instance
    @reject = Relation::Reject.instance
  end

  test "#positive? returns true for Public, Follow" do
    assert @public.positive?
    assert @follow.positive?
    assert_not @reject.positive?
  end

  test "#follow? checks permissions for follow action" do
    assert @follow.follow?
    assert_not @public.follow?
  end

  test ".allow returns relations with matching permissions" do
    alice = users(:alice)
    actor = create_profile_for(alice)
    bob = users(:bob)
    bob_actor = create_profile_for(bob)

    actor.connect_to(bob_actor, as: "friend")
    allowed = Relation.allow(bob_actor, :read, :activity)
    assert allowed.exists?
  end

  test ".ids_shared_with includes Public relation id" do
    ids = Relation.ids_shared_with(nil)
    assert_includes ids, @public.id
  end

  test "Relation::Public is a singleton" do
    assert_equal @public.id, Relation::Public.instance.id
  end

  test "Relation::Follow has all configured permissions" do
    assert_equal 3, @follow.permissions.count
  end

  test "Relation::Follow.create_activity? is true" do
    assert Relation::Follow.create_activity?
  end

  test "Relation::Reject.create_activity? is false" do
    assert_not Relation::Reject.create_activity?
  end

  test "Relation::LocalAdmin grants the site permissions" do
    local_admin = Relation::LocalAdmin.instance

    assert_equal SocialStream.available_permissions["site"].size, local_admin.permissions.count
    assert local_admin.permissions.exists?(action: :read, object: :activity)
  end
end
