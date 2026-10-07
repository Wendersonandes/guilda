require "test_helper"

# Regression guard: authorization must be decided through Actor#can? (permissions), not by role
# names. Role-name helpers are only allowed for identity/business rules, which are explicitly
# allowlisted below.
class AuthorizationRegressionTest < ActiveSupport::TestCase
  VIOLATION = /has_relation_with\?|has_role\?|\.role\?\(/
  GLOBS = [ "app/policies/**/*.rb", "app/controllers/**/*.rb" ].freeze

  # Allowed identity checks (not authorization decisions).
  ALLOWED = [
    # GroupPolicy#owner? — identity used by the "owner cannot leave" business rule.
    /record\.has_relation_with\?\(actor, "Owner"\)/
  ].freeze

  test "authorization in policies and controllers does not rely on role names" do
    violations = []

    GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }.each do |path|
      File.readlines(path).each_with_index do |line, index|
        next unless line.match?(VIOLATION)
        next if ALLOWED.any? { |allowed| line.match?(allowed) }

        violations << "#{path.delete_prefix(Rails.root.to_s + "/")}:#{index + 1}: #{line.strip}"
      end
    end

    assert_empty violations, <<~MSG
      Use Actor#can? for authorization. Role-name checks are only allowed for identity (see ALLOWED):
      #{violations.join("\n")}
    MSG
  end
end
