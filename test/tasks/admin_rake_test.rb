require "test_helper"
require "rake"

class AdminRakeTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @bob = users(:bob)
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @bob.update!(current_profile: @bob_actor)
    @site_actor = Site.instance.actor

    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:grant")
    Rake::Task["admin:grant"].reenable
    Rake::Task["admin:revoke"].reenable
    Rake::Task["admin:list"].reenable
  end

  test "admin:grant assigns admin role to actor by email" do
    assert_not @site_actor.has_relation_with?(@bob_actor, "Admin")

    assert_output(/✓ Papel de Administrador concedido/) do
      Rake::Task["admin:grant"].invoke(@bob.email)
    end

    assert @site_actor.has_relation_with?(@bob_actor, "Admin")
  end

  test "admin:revoke removes admin role from actor by slug" do
    GroupMembershipService.new(@site_actor, @bob_actor).add_role("admin")
    assert @site_actor.has_relation_with?(@bob_actor, "Admin")

    assert_output(/✓ Papel de Administrador revogado/) do
      Rake::Task["admin:revoke"].invoke(@bob_actor.slug)
    end

    assert_not @site_actor.has_relation_with?(@bob_actor, "Admin")
  end

  test "admin:list lists administrators" do
    GroupMembershipService.new(@site_actor, @bob_actor).add_role("admin")

    assert_output(/Administradores da plataforma/) do
      Rake::Task["admin:list"].invoke
    end
  end
end
