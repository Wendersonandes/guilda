require "test_helper"

# == Schema Information
#
# Table name: profiles
#
#  id              :bigint           not null, primary key
#  address         :string
#  birthday        :date
#  city            :string
#  country         :string
#  mobile          :string
#  organization    :string
#  phone           :string
#  state           :string
#  website         :string
#  wizard_complete :boolean          default(FALSE), not null
#  zipcode         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_profiles_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => restrict
#
class ProfileTest < ActiveSupport::TestCase
  test "validates presence of user" do
    profile = Profile.new
    assert_not profile.valid?
    assert_includes profile.errors[:user], "must exist"
  end

  test "delegates name to actor" do
    alice = users(:alice)
    actor = create_profile_for(alice, name: "Alice Profile")
    profile = actor.profile

    assert_equal "Alice Profile", profile.name
    assert_equal alice, profile.user
  end

  test "ProfileCreation creates Actor and ActivityObject in transaction" do
    alice = users(:alice)

    assert_difference "Profile.count", 1 do
      assert_difference "Actor.count", 2 do
        assert_difference "ActivityObject.count", 1 do
          @actor = ProfileCreation.new(alice, name: "Alice").call
        end
      end
    end

    assert @actor.persisted?
    assert @actor.profile?
    assert_not_nil @actor.activity_object
    assert_equal "Alice", @actor.activity_object.title
  end

  test "validates country, state, city when form_step is location" do
    profile = Profile.new(form_step: "location")
    assert_not profile.valid?
    assert_includes profile.errors[:country], "can't be blank"
    assert_includes profile.errors[:state], "can't be blank"
    assert_includes profile.errors[:city], "can't be blank"
  end

  test "validates presence of at least one occupation when form_step is occupation" do
    profile = Profile.new(form_step: "occupation", country: "BR", state: "SP", city: "São Paulo")
    assert_not profile.valid?
    assert_includes profile.errors[:occupation_list], "selecione pelo menos 1 categoria"
  end

  test "does not validate location or occupation when wizard is incomplete and form_step is nil" do
    profile = Profile.new(wizard_complete: false)
    # user is required but let's test only our wizard fields
    profile.valid?
    assert_not_includes profile.errors[:country], "can't be blank"
    assert_not_includes profile.errors[:occupation_list], "selecione pelo menos 1 categoria"
  end

  test "validates everything when wizard is complete" do
    profile = Profile.new(wizard_complete: true)
    profile.valid?
    assert_includes profile.errors[:country], "can't be blank"
    assert_includes profile.errors[:occupation_list], "selecione pelo menos 1 categoria"
  end
end
