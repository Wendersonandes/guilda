require "test_helper"

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
class ActorTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @carol_user = User.create!(email: "carol@example.com", password: "password123", profile_name: "Carol")
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @carol_actor = @carol_user.current_profile
    @group = create_group_with_admin(@alice_actor)
  end

  test "has_relation_with? returns true for connected actor with matching relation" do
    @group.actor.connect_to(@bob_actor, as: "member")
    assert @group.actor.has_relation_with?(@bob_actor, "Member")
    assert_not @group.actor.has_relation_with?(@bob_actor, "Admin")
  end

  test "has_relation_with? returns false for unconnected actor" do
    assert_not @group.actor.has_relation_with?(@carol_actor, "Member")
  end

  test "disconnect_from removes specific relation tie" do
    @group.actor.connect_to(@bob_actor, as: "member")
    assert_difference "Tie.count", -1 do
      @group.actor.disconnect_from(@bob_actor, "member")
    end
    assert_not @group.actor.has_relation_with?(@bob_actor, "Member")
  end

  test "disconnect_from does nothing if relation does not exist" do
    assert_no_difference "Tie.count" do
      @group.actor.disconnect_from(@carol_actor, "member")
    end
  end

  test "member_roles_for returns all roles for a connected actor" do
    @group.actor.connect_to(@bob_actor, as: "member")
    roles = @group.actor.member_roles_for(@bob_actor)
    assert_includes roles, "member"
    assert_not_includes roles, "admin"
  end

  test "member_roles_for returns empty array for unconnected actor" do
    roles = @group.actor.member_roles_for(@carol_actor)
    assert_empty roles
  end

  test "connect_to with multiple relations creates separate ties" do
    @group.actor.connect_to(@bob_actor, as: "member")
    assert_difference "Tie.count", 1 do
      @group.actor.connect_to(@bob_actor, as: "moderator")
    end
    roles = @group.actor.member_roles_for(@bob_actor)
    assert_includes roles, "member"
    assert_includes roles, "moderator"
  end

  test "Actor role and permission helpers work correctly" do
    # 1. Test has_permission? (Bob shouldn't have update on group by default)
    assert_not @bob_actor.has_permission?(:update, :activity, @group)

    # 2. Test add_role
    assert_difference "Tie.count", 2 do # 1 from group -> bob (member), 1 from bob -> group (follow)
      @bob_actor.add_role(:member, @group)
    end

    assert @bob_actor.has_role?(:member, @group)
    assert @bob_actor.has_relation_with?(@group.actor, "follow")

    # 3. Test has_permission? (Bob should now be able to read activity/post/comment in the group)
    assert @bob_actor.has_permission?(:read, :activity, @group)
    assert @bob_actor.has_permission?(:create, :post, @group)

    # 4. Test remove_role
    assert_difference "Tie.count", -2 do # Removes both the group -> bob tie and bob -> group follow tie
      @bob_actor.remove_role(:member, @group)
    end

    assert_not @bob_actor.has_role?(:member, @group)
    assert_not @bob_actor.has_relation_with?(@group.actor, "follow")
  end

  test "can? resolves capabilities from the group role grants" do
    @group.actor.connect_to(@bob_actor, as: "member")

    assert @bob_actor.can?(:read, :group, @group)
    assert @bob_actor.can?(:read, :member, @group)
    assert_not @bob_actor.can?(:update, :member, @group)
    assert_not @bob_actor.can?(:destroy, :group, @group)
  end

  test "can? distinguishes group admin from owner" do
    @group.actor.connect_to(@bob_actor, as: "admin")

    assert @bob_actor.can?(:update, :group, @group)
    assert @bob_actor.can?(:update, :member, @group)
    assert_not @bob_actor.can?(:destroy, :group, @group)

    # @alice_actor founded the group and is its owner.
    assert @alice_actor.can?(:destroy, :group, @group)
  end

  test "role? is an alias of has_role?" do
    @group.actor.connect_to(@bob_actor, as: "member")

    assert @bob_actor.role?("Member", @group)
    assert_equal @bob_actor.role?("Member", @group), @bob_actor.has_role?("Member", @group)
  end

  test "rejects image attachments with a disallowed content type" do
    @bob_actor.avatar.attach(io: StringIO.new("data"), filename: "note.txt", content_type: "text/plain")

    assert_not @bob_actor.valid?
    assert_includes @bob_actor.errors[:avatar], "deve ser uma imagem PNG, JPEG ou WebP"
  end

  test "rejects image attachments larger than the limit" do
    @bob_actor.avatar.attach(io: StringIO.new("data"), filename: "big.png", content_type: "image/png")
    @bob_actor.avatar.blob.define_singleton_method(:byte_size) { 6.megabytes }

    assert_not @bob_actor.valid?
    assert_includes @bob_actor.errors[:avatar], "deve ter no máximo 5MB"
  end

  test "accepts allowed image attachments" do
    @bob_actor.cover_image.attach(io: StringIO.new("data"), filename: "cover.webp", content_type: "image/webp")

    assert @bob_actor.valid?
  end

  private

  def create_group_with_admin(admin_actor)
    group = Group.new
    group.build_actor(name: "Test Group")
    GroupCreation.new(admin_actor, group).call
  end
end
