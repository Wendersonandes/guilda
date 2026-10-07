class HardenPermissionsUniqueness < ActiveRecord::Migration[8.1]
  # The `object` column is nullable and the existing unique index on (action, object) treats
  # NULLs as distinct in PostgreSQL, so duplicate (action, NULL) permissions were possible.
  # This migration removes the legacy `tie` permission (enum value 1, no longer part of the
  # vocabulary), de-duplicates NULL-object rows, and adds a partial unique index enforcing at
  # most one permission per action when the object is NULL.
  def up
    execute "DELETE FROM relation_permissions WHERE permission_id IN (SELECT id FROM permissions WHERE object = 1)"
    execute "DELETE FROM permissions WHERE object = 1"

    execute <<~SQL
      DELETE FROM relation_permissions
      WHERE permission_id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY action ORDER BY id) AS rn
          FROM permissions
          WHERE object IS NULL
        ) ranked
        WHERE rn > 1
      )
    SQL

    execute <<~SQL
      DELETE FROM permissions
      WHERE object IS NULL
        AND id IN (
          SELECT id FROM (
            SELECT id, ROW_NUMBER() OVER (PARTITION BY action ORDER BY id) AS rn
            FROM permissions
            WHERE object IS NULL
          ) ranked
          WHERE rn > 1
        )
    SQL

    add_index :permissions, :action,
              unique: true,
              where: "object IS NULL",
              name: "index_permissions_on_action_where_object_is_null"
  end

  def down
    remove_index :permissions, name: "index_permissions_on_action_where_object_is_null"
  end
end
