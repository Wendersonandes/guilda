require "test_helper"

class GroupMembershipServiceTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @carol_user = User.create!(email: "carol@example.com", password: "password123", profile_name: "Carol")
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @carol_actor = @carol_user.current_profile
    @group = create_group_with_admin(@alice_actor)
    @group_actor = @group.actor
  end

  test "add member with default role" do
    assert_difference [ "Contact.count", "Tie.count" ], 1 do
      GroupMembershipService.new(@group_actor, @bob_actor).add
    end
    assert @group_actor.has_relation_with?(@bob_actor, "Member")
  end

  test "add member with admin role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "admin")
    assert @group_actor.has_relation_with?(@bob_actor, "Admin")
  end

  test "add member with owner role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "owner")
    assert @group_actor.has_relation_with?(@bob_actor, "Owner")
  end

  test "add member with moderator role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "moderator")
    assert @group_actor.has_relation_with?(@bob_actor, "Moderator")
  end

  test "change_role switches relation" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "member")
    assert @group_actor.has_relation_with?(@bob_actor, "Member")

    GroupMembershipService.new(@group_actor, @bob_actor).change_role(from: "member", to: "moderator")
    assert_not @group_actor.has_relation_with?(@bob_actor, "Member")
    assert @group_actor.has_relation_with?(@bob_actor, "Moderator")
  end

  test "remove with specific role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "member")
    assert_difference "Tie.count", -1 do
      GroupMembershipService.new(@group_actor, @bob_actor).remove(role: "member")
    end
    assert_not @group_actor.has_relation_with?(@bob_actor, "Member")
  end

  test "add replaces existing role" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "member")
    assert @group_actor.has_relation_with?(@bob_actor, "Member")

    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "moderator")
    assert @group_actor.has_relation_with?(@bob_actor, "Moderator")
    assert_not @group_actor.has_relation_with?(@bob_actor, "Member")
    assert_equal 1, @group_actor.ties_to(@bob_actor).count
  end

  test "remove all roles" do
    GroupMembershipService.new(@group_actor, @bob_actor).add(role: "member")

    assert_difference "Tie.count", -1 do
      GroupMembershipService.new(@group_actor, @bob_actor).remove
    end
    assert_empty @group_actor.member_roles_for(@bob_actor)
  end

  test "add_role adds role additively on site" do
    site_actor = Site.instance.actor
    GroupMembershipService.new(site_actor, @bob_actor).add(role: "member")
    assert site_actor.has_relation_with?(@bob_actor, "Member")
    assert_not @bob_actor.can?(:publish, :project, site_actor)

    GroupMembershipService.new(site_actor, @bob_actor).add_role("professional")
    assert site_actor.has_relation_with?(@bob_actor, "Member")
    assert site_actor.has_relation_with?(@bob_actor, "Professional")
    assert @bob_actor.can?(:publish, :project, site_actor)
  end

  test "silenced replaces all positive roles and adding positive role clears silenced" do
    site_actor = Site.instance.actor
    GroupMembershipService.new(site_actor, @bob_actor).add(role: "member")
    GroupMembershipService.new(site_actor, @bob_actor).add_role("professional")
    assert site_actor.has_relation_with?(@bob_actor, "Member")
    assert site_actor.has_relation_with?(@bob_actor, "Professional")

    # Apply silenced
    GroupMembershipService.new(site_actor, @bob_actor).add(role: "silenced")
    assert site_actor.has_relation_with?(@bob_actor, "Silenced")
    assert_not site_actor.has_relation_with?(@bob_actor, "Member")
    assert_not site_actor.has_relation_with?(@bob_actor, "Professional")
    assert_not @bob_actor.can?(:create, :post, site_actor)

    # Re-grant member
    GroupMembershipService.new(site_actor, @bob_actor).add(role: "member")
    assert site_actor.has_relation_with?(@bob_actor, "Member")
    assert_not site_actor.has_relation_with?(@bob_actor, "Silenced")
    assert @bob_actor.can?(:create, :post, site_actor)
  end

  test "losing publish project permission automatically reverts public projects to draft" do
    site_actor = Site.instance.actor
    GroupMembershipService.new(site_actor, @bob_actor).add(role: "professional")
    assert @bob_actor.can?(:publish, :project, site_actor)

    profile = @bob_actor.actorable
    project = profile.projects.create!(title: "Meu Portfólio", about: "<p>Sobre</p>", visibility: :public)
    assert project.visibility_public?

    # Downgrade to member (who cannot publish projects)
    GroupMembershipService.new(site_actor, @bob_actor).add(role: "member")
    assert_not @bob_actor.can?(:publish, :project, site_actor)

    project.reload
    assert project.visibility_draft?, "Project should revert to draft when publisher loses publish permission"
  end

  private

  def create_group_with_admin(admin_actor)
    group = Group.new
    group.build_actor(name: "Test Group Service")
    GroupCreation.new(admin_actor, group).call
  end
end
