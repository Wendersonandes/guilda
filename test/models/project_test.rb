require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user, name: "Alice")
    @profile = @actor.actorable
  end

  test "requires title and about" do
    project = @profile.projects.build

    assert_not project.valid?
    assert_includes project.errors[:title], "não pode ficar em branco"
    assert_includes project.errors[:about], "não pode ficar em branco"
  end

  test "assigns position and slug on create" do
    project = @profile.projects.create!(title: "Meu Projeto", about: "<p>Sobre</p>")
    assert_equal 1, project.position
    assert_equal "meu-projeto", project.slug

    second = @profile.projects.create!(title: "Segundo Projeto", about: "<p>Sobre</p>")
    assert_equal 2, second.position
  end

  test "publicly_visible scope excludes drafts and private" do
    public_project = @profile.projects.create!(title: "Público", about: "<p>S</p>", visibility: :public)
    draft = @profile.projects.create!(title: "Rascunho", about: "<p>S</p>", visibility: :draft)
    private_project = @profile.projects.create!(title: "Privado", about: "<p>S</p>", visibility: :private)

    visible = @profile.projects.publicly_visible

    assert_includes visible, public_project
    assert_not_includes visible, draft
    assert_not_includes visible, private_project
  end

  test "visible_to? is true for public and for the owner" do
    bob_actor = create_profile_for(users(:bob), name: "Bob")
    draft = @profile.projects.create!(title: "Rascunho", about: "<p>S</p>", visibility: :draft)

    assert draft.visible_to?(@actor)
    assert_not draft.visible_to?(nil)
    assert_not draft.visible_to?(bob_actor)

    draft.update!(visibility: :public)
    assert draft.visible_to?(nil)
    assert draft.visible_to?(bob_actor)
  end
end
