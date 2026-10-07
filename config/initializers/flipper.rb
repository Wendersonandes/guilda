# frozen_string_literal: true

require "flipper/adapters/active_record"
require "flipper/adapters/strict"

# Central configuration for Flipper feature flags.
#
# Every toggleable feature is listed in {FeatureFlags::FEATURES}. Flags are disabled by default,
# so the application ships with all staggered social features off. Enable them globally, per
# {Actor}, through the +:admins+ group, or progressively from the admin UI mounted at
# +/admin/flipper+.
#
# @see FeatureFlags
module FeatureFlags
  # The social features that can be toggled at runtime. The hash maps the flag name to a short
  # human description and acts as the single source of truth for valid flags.
  FEATURES = {
    social_feed: "Home timeline and post composer",
    contacts: "Connections between actors",
    groups: "Groups and memberships",
    likes: "Likes on activities",
    comments: "Comments and replies",
    mentions: "@mentions in posts and comments",
    follow_objects: "Follow (bell) on activity objects and profiles",
    notifications: "Notification center and badge",
    suggestions: "Suggested profiles in the right sidebar"
  }.freeze

  # @return [Array<Symbol>] the names of every registered feature flag.
  def self.names
    FEATURES.keys
  end
end

Flipper.configure do |config|
  config.adapter do
    Rails.env.test? ? Flipper::Adapters::Memory.new : Flipper::Adapters::ActiveRecord.new
  end
end

# Actors that belong to the +:admins+ group can be used to gate features for internal staff
# before a wider rollout (+Flipper.enable_group :feature, :admins+).
Flipper.register(:admins) do |actor|
  actor.respond_to?(:has_role?) && actor.has_role?(:admin, Site.instance)
end

# Materialize the registered features in the configured store so they show up in the Flipper UI
# and so checking them does not warn under the development Strict adapter. The database may not be
# available yet (db:create, assets:precompile), so failures are swallowed and features are added
# lazily on the next boot.
Rails.application.config.after_initialize do
  next if Rails.env.test?
  next unless ActiveRecord::Base.connection.data_source_exists?("flipper_features")

  # Sync mode lets us create the features without the Strict adapter warning that each one is
  # missing right before we create it.
  Flipper::Adapters::Strict.with_sync_mode do
    FeatureFlags.names.each { |name| Flipper.add(name) }
  end
rescue ActiveRecord::ActiveRecordError
  nil
end
