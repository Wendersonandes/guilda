require "test_helper"

class ProjectPolicyTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @alice_user = users(:alice)
    @bob_user = users(:bob)
    @alice = create_profile_for(@alice_user, name: "Alice")
    @bob = create_profile_for(@bob_user, name: "Bob")

    @public_project = @alice.actorable.projects.create!(title: "Público", about: "<p>S</p>", visibility: :public)
    @draft_project = @alice.actorable.projects.create!(title: "Rascunho", about: "<p>S</p>", visibility: :draft)
  end

  test "public project is visible to guests" do
    assert ProjectPolicy.new(nil, @public_project).show?
  end

  test "draft project is only visible to its owner" do
    assert_not ProjectPolicy.new(@bob_user, @draft_project).show?
    assert ProjectPolicy.new(@alice_user, @draft_project).show?
  end

  test "only the owner can manage the project" do
    assert ProjectPolicy.new(@alice_user, @draft_project).update?
    assert_not ProjectPolicy.new(@bob_user, @draft_project).update?
    assert_not ProjectPolicy.new(@bob_user, @draft_project).destroy?
  end

  test "scope resolves public plus own projects" do
    resolved = ProjectPolicy::Scope.new(@bob_user, Project).resolve
    assert_includes resolved, @public_project
    assert_not_includes resolved, @draft_project
  end
end
