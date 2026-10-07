require "test_helper"

# Consistency between the SocialStream configuration, the Permission catalog and the grants held
# by the system relations. Guards against the kind of drift that left Relation::LocalAdmin with
# no permissions.
class CatalogConsistencyTest < ActiveSupport::TestCase
  SYSTEM_RELATIONS = [
    Relation::Public,
    Relation::Follow,
    Relation::Reject,
    Relation::Owner,
    Relation::LocalAdmin
  ].freeze

  setup do
    seed_permissions_and_relations
    PermissionSync.new.call
  end

  test "every configured pair has a Permission row" do
    PermissionSync.pairs.each do |action, object|
      assert Permission.exists?(action: action, object: object),
             "missing permission #{action}/#{object.inspect}"
    end
  end

  test "configured pairs only use known actions and objects" do
    PermissionSync.pairs.each do |action, object|
      assert Permission.actions.key?(action.to_s), "unknown action #{action.inspect}"
      assert object.nil? || Permission.objects.key?(object.to_s), "unknown object #{object.inspect}"
    end
  end

  test "system relations declare catalogued permissions and actually hold them" do
    SYSTEM_RELATIONS.each do |klass|
      relation = klass.instance

      klass.permissions.each do |permission|
        assert relation.permissions.exists?(permission.id),
               "#{klass} is missing #{permission.action}/#{permission.object.inspect}"
      end
    end
  end

  test "Relation::Owner holds the full group catalog" do
    owner = Relation::Owner.instance
    expected = SocialStream.available_permissions["group"]

    expected.each do |action, object|
      assert owner.permissions.exists?(action: action, object: object),
             "Relation::Owner is missing #{action}/#{object.inspect}"
    end
  end
end
