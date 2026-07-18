require "test_helper"

class ProfileStepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @user = users(:alice)
    @actor = create_profile_for(@user)
    # Mark it as incomplete for testing the wizard
    @actor.actorable.update_columns(wizard_complete: false, country: nil, state: nil, city: nil)
    @actor.actorable.occupation_list = []
    @actor.actorable.save(validate: false)
    @profile = @actor.actorable
  end

  test "should redirect to location step when profile is incomplete" do
    sign_in @user
    get activities_path
    assert_redirected_to profile_step_path(:location)
  end

  test "should get location step" do
    sign_in @user
    get profile_step_path(:location)
    assert_response :success
  end

  test "should redirect to location step if accessing occupation step directly" do
    sign_in @user
    get profile_step_path(:occupation)
    assert_redirected_to profile_step_path(:location)
  end

  test "should update location and redirect to occupation" do
    sign_in @user
    put profile_step_path(:location), params: {
      profile: { country: "BR", state: "SP", city: "São Paulo" }
    }
    assert_redirected_to profile_step_path(:occupation)
    
    @profile.reload
    assert_equal "BR", @profile.country
    assert_equal "SP", @profile.state
    assert_equal "São Paulo", @profile.city
  end

  test "should not update location with invalid data" do
    sign_in @user
    put profile_step_path(:location), params: {
      profile: { country: "", state: "", city: "" }
    }
    assert_response :unprocessable_entity
  end

  test "should get occupation step once location is filled" do
    sign_in @user
    # Fill location first
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")
    
    get profile_step_path(:occupation)
    assert_response :success
  end

  test "should update occupation and finish wizard" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      profile: { occupation_list: ["Developer"] }
    }
    assert_redirected_to root_path
    
    @profile.reload
    assert @profile.wizard_complete?
    assert_equal ["Developer"], @profile.occupation_list
  end

  test "should not finish wizard if no occupation is selected" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      profile: { occupation_list: [] }
    }
    assert_response :unprocessable_entity
    
    @profile.reload
    assert_not @profile.wizard_complete?
  end
end
