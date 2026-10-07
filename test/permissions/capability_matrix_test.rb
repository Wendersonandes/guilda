require "test_helper"

# Asserts the role -> capability matrix (see docs/permissions.md). The expected sets are curated
# on purpose (not derived from the config) so an accidental change to the grants fails here.
class CapabilityMatrixTest < ActiveSupport::TestCase
  # Every action x object pair, plus the broad +follow+/+represent+ pairs.
  PAIRS = (
    Permission.actions.keys.map(&:to_sym).product(Permission.objects.keys.map(&:to_sym)) +
    [ [ :follow, nil ], [ :represent, nil ] ]
  ).freeze

  SITE = {
    admin: [
      [ :create, :activity ], [ :read, :activity ], [ :update, :activity ], [ :destroy, :activity ],
      [ :represent, nil ],
      [ :create, :post ], [ :read, :post ], [ :update, :post ], [ :destroy, :post ],
      [ :create, :comment ], [ :read, :comment ], [ :update, :comment ], [ :destroy, :comment ],
      [ :read, :admin ], [ :update, :role ]
    ],
    editor: [
      [ :create, :activity ], [ :read, :activity ], [ :update, :activity ],
      [ :create, :post ], [ :read, :post ], [ :update, :post ],
      [ :create, :comment ], [ :read, :comment ], [ :update, :comment ]
    ],
    moderator: [
      [ :read, :activity ], [ :destroy, :activity ],
      [ :read, :post ], [ :destroy, :post ],
      [ :read, :comment ], [ :destroy, :comment ]
    ],
    member: [
      [ :read, :activity ], [ :create, :activity ],
      [ :read, :post ], [ :create, :post ],
      [ :read, :comment ], [ :create, :comment ]
    ],
    silenced: [ [ :read, :activity ], [ :read, :post ], [ :read, :comment ] ],
    banned: []
  }.freeze

  GROUP = {
    owner: [
      [ :create, :activity ], [ :read, :activity ], [ :update, :activity ], [ :destroy, :activity ],
      [ :follow, nil ], [ :represent, nil ],
      [ :create, :post ], [ :read, :post ], [ :update, :post ], [ :destroy, :post ],
      [ :create, :comment ], [ :read, :comment ], [ :update, :comment ], [ :destroy, :comment ],
      [ :read, :group ], [ :update, :group ], [ :destroy, :group ],
      [ :read, :member ], [ :create, :member ], [ :update, :member ], [ :destroy, :member ]
    ],
    admin: [
      [ :create, :activity ], [ :read, :activity ], [ :update, :activity ], [ :destroy, :activity ],
      [ :represent, nil ],
      [ :create, :post ], [ :read, :post ], [ :update, :post ], [ :destroy, :post ],
      [ :create, :comment ], [ :read, :comment ], [ :update, :comment ], [ :destroy, :comment ],
      [ :read, :group ], [ :update, :group ],
      [ :read, :member ], [ :create, :member ], [ :update, :member ], [ :destroy, :member ]
    ],
    moderator: [
      [ :create, :activity ], [ :read, :activity ], [ :update, :activity ],
      [ :create, :post ], [ :read, :post ], [ :update, :post ],
      [ :create, :comment ], [ :read, :comment ], [ :update, :comment ],
      [ :read, :group ], [ :read, :member ]
    ],
    member: [
      [ :read, :activity ], [ :create, :activity ],
      [ :read, :post ], [ :create, :post ],
      [ :read, :comment ], [ :create, :comment ],
      [ :read, :group ], [ :read, :member ]
    ],
    silenced: [ [ :read, :activity ], [ :read, :post ], [ :read, :comment ] ]
  }.freeze

  setup do
    seed_permissions_and_relations
    @site_actor = Site.instance.actor
  end

  test "site role capability matrix" do
    SITE.each do |role, expected|
      actor = site_actor_with_role(role)
      assert_capabilities actor, expected, @site_actor, "site:#{role}"
    end
  end

  test "group role capability matrix" do
    group_actor = build_group
    group_owner = @group_owner

    GROUP.each do |role, expected|
      actor = role == :owner ? group_owner : connect_to_group(group_actor, role)
      assert_capabilities actor, expected, group_actor, "group:#{role}"
    end
  end

  test "group roles form a linear superset hierarchy" do
    order = [ :silenced, :member, :moderator, :admin, :owner ]

    order.each_cons(2) do |lower, higher|
      lower_set = capability_set_for_group(lower)
      higher_set = capability_set_for_group(higher)

      assert_empty lower_set - higher_set,
                   "#{higher} should grant everything #{lower} grants; missing: #{(lower_set - higher_set).to_a.inspect}"
    end
  end

  private

  def build_user(label)
    User.create!(
      email: "#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      profile_name: label
    )
  end

  def build_actor(label)
    create_profile_for(build_user(label), name: label)
  end

  def site_actor_with_role(role)
    actor = build_actor("site-#{role}")
    GroupMembershipService.new(@site_actor, actor).add(role: role.to_s)
    actor
  end

  def build_group
    @group_owner = build_actor("group-owner")
    group = Group.new(privacy: :public_group)
    group.build_actor(name: "Matrix Group")
    GroupCreation.new(@group_owner, group).call
    group.actor
  end

  def connect_to_group(group_actor, role)
    actor = build_actor("group-#{role}")
    group_actor.connect_to(actor, as: role.to_s)
    actor
  end

  def capability_set_for_group(role)
    group_actor = build_group
    actor = role == :owner ? @group_owner : connect_to_group(group_actor, role)
    actual_capabilities(actor, group_actor)
  end

  def assert_capabilities(actor, expected, context, label)
    expected_set = expected.to_set
    actual = actual_capabilities(actor, context)

    assert_equal expected_set, actual, <<~MSG
      #{label} capability mismatch
        missing: #{(expected_set - actual).to_a.sort.inspect}
        extra:   #{(actual - expected_set).to_a.sort.inspect}
    MSG
  end

  def actual_capabilities(actor, context)
    PAIRS.select { |action, object| actor.can?(action, object, context) }.to_set
  end
end
