require "test_helper"

# Guards that every literal +can?/+has_permission?+ call site in the application uses a pair that
# exists in the Permission catalog. Catches typos and capabilities that were used but never
# configured (the failure mode that left Relation::LocalAdmin permission-less).
class CallSiteCoverageTest < ActiveSupport::TestCase
  # Matches `.can?(:read, :admin)` / `can?(:follow, nil)` while ignoring dynamic calls such as
  # `actor.can?(action, object, record)`.
  CALL_SITE = /\b(?:can|has_permission)\?\(\s*:(\w+)\s*,\s*(:(\w+)|nil)/
  GLOBS = [ "app/**/*.rb", "app/**/*.erb" ].freeze

  setup do
    seed_permissions_and_relations
    PermissionSync.new.call
  end

  test "every literal capability used in app code exists in the catalog" do
    pairs = call_site_pairs

    assert pairs.any?, "expected to find can?/has_permission? call sites in app code"

    pairs.each do |action, object|
      assert Permission.exists?(action: action, object: object),
             "`can?(:#{action}, #{object.inspect})` is used in app code but missing from the Permission catalog"
    end
  end

  private

  def call_site_pairs
    GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }
         .flat_map { |path| File.read(path).scan(CALL_SITE) }
         .map { |action, _object, name| [ action.to_sym, name&.to_sym ] }
         .uniq
  end
end
