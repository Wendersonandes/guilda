require "test_helper"

class PermissionSyncTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
  end

  test "is idempotent" do
    PermissionSync.new.call

    assert_no_difference [ "Permission.count", "RelationPermission.count" ] do
      PermissionSync.new.call
    end
  end

  test "grants the site permissions to Relation::LocalAdmin" do
    local_admin = Relation::LocalAdmin.instance

    assert local_admin.permissions.exists?(action: :read, object: :admin)
    assert local_admin.permissions.exists?(action: :update, object: :role)
  end
end
