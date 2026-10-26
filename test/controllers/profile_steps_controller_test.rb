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
      profile: { occupation_list: [ "Developer" ] }
    }
    assert_redirected_to root_path

    @profile.reload
    assert @profile.wizard_complete?
    assert_equal [ "Developer" ], @profile.occupation_list
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

  test "should not crash with ParameterMissing when submitting occupation step with empty form payload" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    # Simulates browser form submission with no checkboxes checked
    put profile_step_path(:occupation), params: {}
    assert_response :unprocessable_entity

    @profile.reload
    assert_not @profile.wizard_complete?
  end

  test "should not finish wizard when submitting with blank hidden field value" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      profile: { occupation_list: [ "" ] }
    }
    assert_response :unprocessable_entity

    @profile.reload
    assert_not @profile.wizard_complete?
  end

  test "renders location step with hidden country, responsive grid and touch targets" do
    sign_in @user
    get profile_step_path(:location)
    assert_response :success

    assert_select "input[type='hidden'][data-location-target='country'][value='BR']"
    assert_select "select[data-location-target='state'].min-h-11"
    assert_select "select[data-location-target='city'].min-h-11"
  end

  test "renders occupation step with counter target, hidden fallback and accessible pill focus" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    get profile_step_path(:occupation)
    assert_response :success

    assert_select "span[data-occupations-target='counter']"
    assert_select "input[type='hidden'][name='profile[occupation_list][]']"
    assert_select "div[role='group'][aria-labelledby='occupations_section_heading']"
  end

  test "persists occupation selection when clicking back button" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      wizard_action: "back",
      profile: { occupation_list: [ "Design de Portfólio", "Expografia" ] }
    }
    assert_redirected_to profile_step_path(:location)

    @profile.reload
    assert_equal [ "Design de Portfólio", "Expografia" ].sort, @profile.occupation_list.sort

    # Visiting location and returning forward preserves selections
    get profile_step_path(:location)
    assert_response :success

    put profile_step_path(:location), params: {
      profile: { country: "BR", state: "SP", city: "Campinas" }
    }
    assert_redirected_to profile_step_path(:occupation)

    get profile_step_path(:occupation)
    assert_response :success
    assert_select "input[type='checkbox'][value='Design de Portfólio'][checked='checked']"
    assert_select "input[type='checkbox'][value='Expografia'][checked='checked']"
  end

  test "persists occupation selection when navigating via stepper button" do
    sign_in @user
    @profile.update!(country: "BR", state: "SP", city: "São Paulo")

    put profile_step_path(:occupation), params: {
      target_step: "location",
      profile: { occupation_list: [ "Expografia" ] }
    }
    assert_redirected_to profile_step_path(:location)

    @profile.reload
    assert_equal [ "Expografia" ], @profile.occupation_list

    # Stepper navigation from location to occupation validates location and advances
    put profile_step_path(:location), params: {
      target_step: "occupation",
      profile: { country: "BR", state: "SP", city: "São Paulo" }
    }
    assert_redirected_to profile_step_path(:occupation)

    get profile_step_path(:occupation)
    assert_response :success
    assert_select "input[type='checkbox'][value='Expografia'][checked='checked']"
  end
end
