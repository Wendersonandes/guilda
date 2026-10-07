require "test_helper"

# == Schema Information
#
# Table name: permissions
#
#  id         :bigint           not null, primary key
#  action     :integer          not null
#  object     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_permissions_on_action_and_object            (action,object) UNIQUE
#  index_permissions_on_action_where_object_is_null  (action) UNIQUE WHERE (object IS NULL)
#
class PermissionTest < ActiveSupport::TestCase
  test "validates presence of action" do
    permission = Permission.new(object: :activity)
    assert_not permission.valid?
    assert_includes permission.errors[:action], "can't be blank"
  end

  test "action enum maps correctly" do
    assert_equal 0, Permission.actions[:create]
    assert_equal 1, Permission.actions[:read]
    assert_equal 4, Permission.actions[:follow]
    assert_equal 5, Permission.actions[:represent]
  end

  test "object enum maps correctly" do
    assert_equal 0, Permission.objects[:activity]
    assert_equal 2, Permission.objects[:post]
    assert_equal 3, Permission.objects[:comment]
  end

  test ".instances creates unique records" do
    assert_difference "Permission.count", 2 do
      Permission.instances([ [ :read, :activity ], [ :follow, nil ] ])
    end

    assert_no_difference "Permission.count" do
      Permission.instances([ [ :read, :activity ] ])
    end
  end

  test ".follow scope returns follow permissions" do
    Permission.instances([ [ :follow, nil ], [ :read, :activity ] ])
    assert_equal 1, Permission.follow.count
    assert_equal 0, Permission.follow.map(&:object).compact.size
  end

  test "follow permission allows nil object" do
    perm = Permission.find_or_create_by(action: :follow, object: nil)
    assert perm.valid?
    assert_nil perm.object
  end

  test "does not allow duplicate permissions for a nil object" do
    Permission.find_or_create_by!(action: :follow, object: nil)

    duplicate = Permission.new(action: :follow, object: nil)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:object], "has already been taken"
  end
end
