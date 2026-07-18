ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with threads
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml
    fixtures :all

    include Devise::Test::IntegrationHelpers

    def create_profile_for(user, name: nil)
      actor = ProfileCreation.new(user, name: name || user.email.split("@").first).call
      actor.actorable.update!(wizard_complete: true, country: "BR", state: "SP", city: "São Paulo", occupation_list: ["Developer"])
      user.update!(current_profile: actor)
      actor
    end

    def sign_in_user(user)
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
    end

    def seed_permissions_and_relations
      Permission.instances([
        [ :create, :activity ],
        [ :read,   :activity ],
        [ :update, :activity ],
        [ :destroy, :activity ],
        [ :follow, nil ],
        [ :represent, nil ]
      ])

      # Clear singleton caches for fresh records per test
      [ Relation::Public, Relation::Follow, Relation::Reject ].each do |klass|
        klass.instance_variable_set(:@instance, nil)
      end

      Relation::Public.instance
      Relation::Follow.instance
      Relation::Reject.instance
    end
  end
end
