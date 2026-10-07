class RemoveLegacyActivityActionsFeatureFlag < ActiveRecord::Migration[8.1]
  # The feature flag `activity_actions` was renamed to `follow_objects`. This data migration
  # removes the orphaned feature (and any of its gates) left behind in Flipper's store.
  def up
    execute "DELETE FROM flipper_gates WHERE feature_key = 'activity_actions'"
    execute "DELETE FROM flipper_features WHERE key = 'activity_actions'"
  end

  def down
    # no-op: the flag was renamed to follow_objects
  end
end
